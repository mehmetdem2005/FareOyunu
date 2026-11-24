extends SceneTree
const ASYNC=preload("res://addons/terra_forge/core/async_region_source.gd")
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const BENCH=preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")
const WORKER=preload("res://addons/terra_forge/core/geometry_worker.gd")
const DENSE=preload("res://addons/terra_forge/core/tile_dense_buffer.gd")
const EQUAL=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")
const LOD=preload("res://addons/terra_forge/core/lod_policy.gd")

func _initialize() -> void:
    print("SCALAR_WORKER_ENV ",JSON.stringify({"os":OS.get_name(),"cpu":OS.get_processor_name(),"godot":Engine.get_version_info().get("string",""),"notes":"F/G same priority, dense ownership and geometry; warm equal work and fixed 8ms cadence off-tree, no raycast/GPU"}))
    var src=ASYNC.new()
    var w=WORKER.new()
    for version in [1,2]:
        var b: Variant=V1.new() if version==1 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if version==1 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start",src,w,b)
            return
        var made: Dictionary={}
        var deadline: int=Time.get_ticks_msec()+30000
        while Time.get_ticks_msec()<deadline:
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture",src,w,b)
            return
        var directory: String=made["directory"]
        err=src.open(directory,9,4,false) if version==1 else src.open_v2(directory,9,4,false,2)
        if err!=OK or w.start(src,2,true)!=OK:
            _fail("open",src,w,b)
            return
        var key=Vector2i(15,15)
        if w.submit(src,key,0,{key:0})["error"]!=ERR_BUSY:
            _fail("missing resident",src,w,b)
            return
        var cases: Array=[[key,0,false],[key,1,false],[key,2,false],[key,0,true],[Vector2i.ZERO,0,false],[Vector2i(17,17),2,false],[Vector2i(16,16),1,true]]
        var elapsed: int=0
        for c in cases:
            var tile: Vector2i=c[0]
            var lod: int=c[1]
            var desired: Dictionary={tile:lod}
            for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                var n: Vector2i=tile+direction
                if n.x>=0 and n.y>=0 and n.x<18 and n.y<18:
                    desired[n]=2 if c[2] else lod
            if not _load(src,G.required_pages(src,tile.x,tile.y,lod)):
                _fail("load",src,w,b)
                return
            var expected: Dictionary=G.generate(src,tile.x,tile.y,lod,desired)
            var acquired: Dictionary=src.acquire_tile_view(G.required_pages(src,tile.x,tile.y,lod))
            if acquired["error"]!=OK:
                _fail("lease for scalar bounds",src,w,b)
                return
            var copied: Dictionary=DENSE.build(acquired["view"],tile.x,tile.y,LOD.sample_stride(lod))
            src.release_tile_view(acquired["view"])
            if copied["error"]!=OK:
                _fail("dense copy",src,w,b)
                return
            var buffer=copied["buffer"]
            if not is_nan(buffer.read_finite_or_nan(-1,0)) or not is_nan(buffer.read_finite_or_nan(577,577)) or (lod>0 and not is_nan(buffer.read_finite_or_nan(tile.x*32+1,tile.y*32))):
                _fail("scalar bounds",src,w,b)
                return
            if not BENCH.equal(expected,G.generate_owned_dense_scalar(buffer,tile.x,tile.y,lod,desired)):
                _fail("dense scalar exact parity",src,w,b)
                return
            # Fault injection into independent scratch copy only.
            buffer._values[0]=NAN
            if not is_nan(buffer.read_finite_or_nan(buffer._first.x,buffer._first.y)):
                _fail("nonfinite sample",src,w,b)
                return
            # Restore from verified data before testing worker.
            var submitted: Dictionary=w.submit(src,tile,lod,desired)
            if submitted["error"]!=OK or src.stats()["tile_view_active_pages"]!=0:
                _fail("submit or lease",src,w,b)
                return
            # Drop all source pages after enqueue; worker must own its input.
            src.release_outside(Vector2i(18,18),Vector2i(18,18))
            var result: Dictionary=_wait(w,src,desired)
            if result.get("error",FAILED)!=OK or result["result"]["id"]!=submitted["id"] or not BENCH.equal(expected,result["result"]["geometry"]) or result["result"]["input_bytes"]>4900 or result["result"]["output_reserved_payload_bytes"]>131072:
                _fail("owned parity "+str(c),src,w,b)
                return
            elapsed+=result["result"]["build_elapsed_us"]
        var desired: Dictionary={key:0,Vector2i(16,15):0}
        if not _load(src,G.required_pages(src,key.x,key.y,0)):
            _fail("stress load",src,w,b)
            return
        if w.submit(src,key,0,desired)["error"]!=OK or w.submit(src,key,0,desired)["error"]!=OK or w.submit(src,key,0,desired)["error"]!=ERR_BUSY:
            _fail("queue bound",src,w,b)
            return
        var changed: Dictionary={key:0,Vector2i(16,15):2}
        for step in range(4000):
            var discarded: Dictionary=w.poll(src,changed)
            if discarded["error"]!=ERR_BUSY:
                _fail("stale neighbor delivered",src,w,b)
                return
            if w.stats()["slots"]==0:
                break
            OS.delay_msec(1)
        if w.stats()["slots"]!=0 or w.stats()["dropped"]!=2:
            _fail("neighbor discard",src,w,b)
            return
        if w.submit(src,key,0,desired)["error"]!=OK or w.submit(src,key,0,desired)["error"]!=OK or src.set_generation(1)!=OK:
            _fail("epoch setup",src,w,b)
            return
        for step in range(4000):
            if w.poll(src,desired)["error"]!=ERR_BUSY:
                _fail("stale epoch delivered",src,w,b)
                return
            if w.stats()["slots"]==0:
                break
            OS.delay_msec(1)
        var stats: Dictionary=w.stats()
        if stats["slots"]!=0 or stats["dropped"]!=4 or stats["submitted"]!=stats["delivered"]+stats["dropped"] or stats["peak_slots"]!=2:
            _fail("conservation "+str(stats),src,w,b)
            return
        if w.submit(src,key,0,desired)["error"]!=OK:
            _fail("reopen setup",src,w,b)
            return
        src.close()
        err=src.open(directory,9,4,false) if version==1 else src.open_v2(directory,9,4,false,2)
        if err!=OK or w.poll(src,desired)["error"]!=ERR_INVALID_DATA or w.submit(src,key,0,desired)["error"]!=ERR_INVALID_DATA:
            _fail("source reopen identity",src,w,b)
            return
        print("SCALAR_WORKER_PARITY ",JSON.stringify({"format":version,"parity_cases":7,"worker_build_elapsed_sum_us":elapsed,"stats_before_reopen":stats}))
        w.close()
        if w.stats()["slots"]!=0 or w.stats()["open"]:
            _fail("close",src,w,b)
            return
        src.close()
        var reference: Dictionary={}
        for repeat in range(4):
            var mode: int=4 if repeat==0 or repeat==3 else 5
            var result: Dictionary=EQUAL.run(directory,version-1,mode,2)
            if result.get("error",FAILED)!=OK or (not reference.is_empty() and result["fingerprints"]!=reference):
                _fail("equal work "+str(result),src,w,b)
                return
            reference=result["fingerprints"]
            result["order"]=repeat
            print("SCALAR_WORKER_EQUAL ",JSON.stringify(result))
        for cache in [9,16]:
            var order: Array=[2,3,4,5] if (version==1)==(cache==9) else [5,4,3,2]
            for mode in order:
                var result: Dictionary=TRACE.run(directory,version-1,mode,cache,2,8000)
                if result.get("error",FAILED)!=OK:
                    _fail("trace "+str(result),src,w,b)
                    return
                print("SCALAR_WORKER_TRACE ",JSON.stringify(result))
        b.close()
    print("PASS: G scalar owned buffers exact parity, bounds, stale neighbor/epoch/session, 8 equal-work F/G batches and 16 fixed cadence C/E/F/G traces")
    quit(0)

func _wait(w,src,desired: Dictionary) -> Dictionary:
    for step in range(4000):
        var result: Dictionary=w.poll(src,desired)
        if result["error"]!=ERR_BUSY:
            return result
        OS.delay_msec(1)
    return {"error":ERR_TIMEOUT}

func _load(src,keys: Array[Vector2i]) -> bool:
    for step in range(4000):
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

func _fail(msg: String,src,w,b) -> void:
    w.close()
    src.close()
    b.close()
    push_error("Scalar worker: "+msg)
    quit(1)
