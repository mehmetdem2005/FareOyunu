extends SceneTree
const ASYNC=preload("res://addons/terra_forge/core/async_region_source.gd")
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const BENCH=preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")
const WORKER=preload("res://addons/terra_forge/core/geometry_worker.gd")
const TOP=preload("res://addons/terra_forge/core/tile_topology_cache.gd")
const EQUAL=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")

func _initialize() -> void:
    print("TOPOLOGY_ENV ",JSON.stringify({"cpu":OS.get_processor_name(),"os":OS.get_name(),"godot":Engine.get_version_info().get("string",""),"notes":"G/H same worker except fixed topology; owned copies, no GPU timing"}))
    var cache=TOP.new()
    if not cache.copy_indices(0).is_empty() or cache.initialize()!=OK or cache.payload_bytes()!=32256 or not cache.copy_indices(-1).is_empty():
        push_error("Topology initialization")
        quit(1)
        return
    for lod in range(3):
        var one: PackedInt32Array=cache.copy_indices(lod)
        var original: PackedInt32Array=cache.copy_indices(lod)
        one[0]=-1
        if cache.copy_indices(lod)!=original or original.size()!=(32>>lod)*(32>>lod)*6:
            push_error("Topology copy ownership")
            quit(1)
            return
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
        if err!=OK or w.start(src,2,true,true)!=OK:
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
        print("TOPOLOGY_PARITY ",JSON.stringify({"format":version,"parity_cases":7,"worker_build_elapsed_sum_us":elapsed,"stats_before_reopen":stats}))
        w.close()
        if w.stats()["slots"]!=0 or w.stats()["open"] or w.stats()["topology_cache_bytes"]!=0:
            _fail("close",src,w,b)
            return
        src.close()
        var reference: Dictionary={}
        for repeat in range(4):
            var mode: int=5 if repeat==0 or repeat==3 else 6
            var result: Dictionary=EQUAL.run(directory,version-1,mode,2)
            if result.get("error",FAILED)!=OK or (not reference.is_empty() and result["fingerprints"]!=reference):
                _fail("equal work "+str(result),src,w,b)
                return
            if result["worker"]["topology_cache_bytes"]!=(32256 if mode==6 else 0):
                _fail("cache accounting",src,w,b)
                return
            reference=result["fingerprints"]
            result["order"]=repeat
            print("TOPOLOGY_EQUAL ",JSON.stringify(result))
        for page_cap in [9,16]:
            var modes: Array=[5,6] if (version==1)==(page_cap==9) else [6,5]
            for mode in modes:
                var result: Dictionary=TRACE.run(directory,version-1,mode,page_cap,2,8000,true)
                if result.get("error",FAILED)!=OK:
                    _fail("trace "+str(result),src,w,b)
                    return
                print("TOPOLOGY_TRACE ",JSON.stringify(result))
        b.close()
    print("PASS: H topology private templates, independent copies, 14 exact worker cases, stale/close, 8 equal-work G/H runs and 8 cadence traces")
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
    push_error("Topology worker: "+msg)
    quit(1)
