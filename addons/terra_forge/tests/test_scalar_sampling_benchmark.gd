extends SceneTree
const ASYNC = preload("res://addons/terra_forge/core/async_region_source.gd")
const V1 = preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2 = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const G = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const DENSE = preload("res://addons/terra_forge/core/tile_dense_buffer.gd")
const BENCH = preload("res://addons/terra_forge/core/scalar_sampling_benchmark.gd")

func _initialize() -> void:
    var src = ASYNC.new()
    print("SCALAR_ENV ",JSON.stringify({"os":OS.get_name(),"cpu":OS.get_processor_name(),"godot":Engine.get_version_info().get("string",""),"headless":DisplayServer.get_name()=="headless","timing":"calling-thread elapsed us, warm resident, copy included, no GPU/IO, balanced alternating B/D, same lease and topology"}))
    for version in [1,2]:
        var b: Variant = V1.new() if version==1 else V2.new()
        var err: Error = b.start(Vector2i(576,576),true) if version==1 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start",src,b)
            return
        var deadline: int=Time.get_ticks_msec()+30000
        var made: Dictionary={}
        while Time.get_ticks_msec()<deadline:
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture",src,b)
            return
        var directory: String=made["directory"]
        err=src.open(directory,9,4,false) if version==1 else src.open_v2(directory,9,4,false,2)
        if err!=OK:
            _fail("open",src,b)
            return
        if G.generate_with_scalar_view(src,15,15,0,{})["error"]!=ERR_BUSY or src.stats()["tile_view_active_pages"]!=0:
            _fail("missing resident data",src,b)
            return
        var cases: Array = [
            [Vector2i(15,15),0,false],
            [Vector2i(15,15),1,false],
            [Vector2i(15,15),2,false],
            [Vector2i(15,15),0,true],
            [Vector2i.ZERO,0,false],
            [Vector2i(17,17),2,false],
            [Vector2i(16,16),1,true]
        ]
        for c in cases:
            var key: Vector2i=c[0]
            var lod: int=c[1]
            var mixed: bool=c[2]
            var desired: Dictionary={key:lod}
            for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                var neighbor: Vector2i=key+direction
                if neighbor.x>=0 and neighbor.y>=0 and neighbor.x<18 and neighbor.y<18:
                    desired[neighbor]=2 if mixed else lod
            var pages: Array[Vector2i]=G.required_pages(src,key.x,key.y,lod)
            if not _load(src,pages):
                _fail("load halo",src,b)
                return
            var result: Dictionary=BENCH.run_case(src,key,lod,desired,32)
            if result.get("error",FAILED)!=OK:
                _fail("benchmark "+str(result),src,b)
                return
            if result["view_reads_each"]<=0 or result["lru_touches_each"]!=pages.size()*32:
                _fail("work accounting "+str(result),src,b)
                return
            result["format"]="TFM"+str(version)
            result["mixed"]=mixed
            print("SCALAR_CASE ",JSON.stringify(result))
        # Invalid halo and missing/corrupt page must fail without geometry.
        var keys: Array[Vector2i]=G.required_pages(src,0,0,0)
        if not _load(src,keys):
            _fail("edge load",src,b)
            return
        var invalid: Dictionary={Vector2i.ZERO:0,Vector2i.LEFT:0}
        var failed: Dictionary=G.generate_with_scalar_view(src,0,0,0,invalid)
        if failed["error"]==OK or failed.has("arrays") or src.stats()["tile_view_active_pages"]!=0:
            _fail("invalid halo leaked geometry or lease",src,b)
            return
        var acquired: Dictionary=src.acquire_tile_view(keys)
        if acquired["error"]!=OK:
            _fail("scalar lease",src,b)
            return
        var view=acquired["view"]
        if not is_nan(view.read_finite_or_nan(-1,0)) or not is_nan(view.read_finite_or_nan(576,576)):
            _fail("scalar bounds",src,b)
            return
        src.release_tile_view(view)
        if not is_nan(view.read_finite_or_nan(0,0)):
            _fail("revoked scalar read",src,b)
            return
        var path: String=directory.path_join("r_00000_00000.tfr")
        if src.release_outside(Vector2i(18,18),Vector2i(18,18))!=OK or DirAccess.remove_absolute(path)!=OK:
            _fail("cold missing setup",src,b)
            return
        src.request_page(Vector2i.ZERO)
        for attempt in range(4000):
            src.poll_results(4)
            if src.page_status(Vector2i.ZERO)!=ERR_BUSY:
                break
            OS.delay_msec(1)
        failed=G.generate_with_scalar_view(src,0,0,0,{})
        if failed["error"]!=ERR_FILE_NOT_FOUND or failed.has("arrays") or src.stats()["tile_view_active_pages"]!=0:
            _fail("cold missing error propagation",src,b)
            return
        src.close()
        b.close()
    print("PASS: B/D scalar sampling exact geometry, equal reads/LRU, 14 balanced resident cases, invalid halo/revoked view/cold missing fail closed")
    quit(0)

func _load(src,keys: Array[Vector2i]) -> bool:
    for attempt in range(4000):
        src.poll_results(4)
        src.prioritize_resident(keys)
        var ready: bool=true
        for key in keys:
            var status: Error=src.page_status(key)
            if status==ERR_BUSY:
                ready=false
                src.request_page(key)
            elif status!=OK:
                return false
        if ready:
            return true
        OS.delay_msec(1)
    return false

func _fail(msg: String,src,b) -> void:
    src.close()
    b.close()
    push_error("Scalar sampling benchmark: "+msg)
    quit(1)
