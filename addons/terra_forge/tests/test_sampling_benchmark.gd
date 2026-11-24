extends SceneTree
const ASYNC = preload("res://addons/terra_forge/core/async_region_source.gd")
const V1 = preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2 = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const G = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const DENSE = preload("res://addons/terra_forge/core/tile_dense_buffer.gd")
const BENCH = preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")

func _initialize() -> void:
    var src = ASYNC.new()
    print("SAMPLING_ENV ",JSON.stringify({"os":OS.get_name(),"cpu":OS.get_processor_name(),"godot":Engine.get_version_info().get("string",""),"headless":DisplayServer.get_name()=="headless","timing":"calling-thread elapsed us, warm resident, copy included, no GPU/IO, balanced six permutations"}))
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
        if G.generate_with_dense(src,15,15,0,{})["error"]!=ERR_BUSY or src.stats()["tile_view_active_pages"]!=0:
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
            var result: Dictionary=BENCH.run_case(src,key,lod,desired,24)
            if result.get("error",FAILED)!=OK:
                _fail("benchmark "+str(result),src,b)
                return
            var a: Dictionary=result["modes"]["A_direct"]["work"]
            var bv: Dictionary=result["modes"]["B_view"]["work"]
            var cv: Dictionary=result["modes"]["C_dense"]["work"]
            if a["direct_reads"]!=bv["view_reads"] or a["lru_touches"]!=a["direct_reads"] or bv["lru_touches"]!=pages.size()*24 or cv["lru_touches"]!=bv["lru_touches"] or cv["dense_payload_peak"]<=0 or cv["dense_payload_peak"]>4900 or cv["view_reads"]*4!=cv["dense_payload_peak"]*24:
                _fail("work accounting "+str(result),src,b)
                return
            result["format"]="TFM"+str(version)
            result["mixed"]=mixed
            print("SAMPLING_CASE ",JSON.stringify(result))
        # Validate the copied scalar buffer cannot serve off-grid/halo reads.
        var keys: Array[Vector2i]=G.required_pages(src,16,16,2)
        if not _load(src,keys):
            _fail("bounds load",src,b)
            return
        var acquired: Dictionary=src.acquire_tile_view(keys)
        if acquired["error"]!=OK:
            _fail("bounds lease",src,b)
            return
        var copied: Dictionary=DENSE.build(acquired["view"],16,16,4)
        src.release_tile_view(acquired["view"])
        if copied["error"]!=OK or copied["buffer"].get_height(513,512).has("height") or copied["buffer"].get_height(0,0).has("height") or copied["buffer"].get_height(512,512)["height"]!=V2.sample(512,512):
            _fail("copied buffer bounds/value",src,b)
            return
        src.close()
        b.close()
    print("PASS: A/B/C exact geometry, stride-aligned bounded Float32 buffers, 14 balanced warm resident cases, measured timings and operation accounting")
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
    push_error("Sampling benchmark: "+msg)
    quit(1)
