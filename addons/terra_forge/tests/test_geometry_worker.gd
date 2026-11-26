extends SceneTree
const ASYNC=preload("res://addons/terra_forge/core/async_region_source.gd")
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const BENCH=preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")
const WORKER=preload("res://addons/terra_forge/core/geometry_worker.gd")

func _initialize() -> void:
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
        if err!=OK or w.start(src,2)!=OK:
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
        var poll_stats: Dictionary=w.stats()["discard_accounting"]
        if poll_stats["poll_stale"]!=2 or poll_stats["classified"]!=2 or poll_stats["copy_wall_us"]<=0 or poll_stats["build_wall_us"]<=0:
            _fail("stale poll accounting",src,w,b)
            return
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
        var discarded_stats: Dictionary=stats["discard_accounting"]
        if discarded_stats["classified"]!=4 or discarded_stats["epoch_pending"]+discarded_stats["epoch_finished"]+discarded_stats["epoch_running"]!=2 or discarded_stats["poll_stale"]!=2 or discarded_stats["copy_wall_us"]<poll_stats["copy_wall_us"] or discarded_stats["build_wall_us"]<poll_stats["build_wall_us"]:
            _fail("epoch discard accounting",src,w,b)
            return
        # Force one successful finished result before changing epoch. No
        # scheduling race: wait for actual ownership state, never poll it.
        var before_shadow: Dictionary=stats["epoch_reuse_shadow"]
        if w.submit(src,key,0,desired)["error"]!=OK:
            _fail("shadow finished setup",src,w,b)
            return
        for step in range(4000):
            if w.stats()["finished"]==1:
                break
            OS.delay_msec(1)
        if w.stats()["finished"]!=1 or src.set_generation(2)!=OK or w.poll(src,desired)["error"]!=ERR_BUSY:
            _fail("shadow epoch guard",src,w,b)
            return
        var after: Dictionary=w.stats()
        var shadow: Dictionary=after["epoch_reuse_shadow"]
        if shadow["successful_finished_candidates"]!=before_shadow["successful_finished_candidates"]+1 or shadow["candidate_finished_reserved_output_bytes_sum"]<=before_shadow["candidate_finished_reserved_output_bytes_sum"] or shadow["candidate_finished_build_wall_us"]<before_shadow["candidate_finished_build_wall_us"] or shadow["retained_payload_bytes"]!=0 or shadow["publication_enabled"] or after["slots"]!=0 or after["submitted"]!=after["delivered"]+after["dropped"]:
            _fail("shadow accounting "+str(shadow),src,w,b)
            return
        # An actual finished output with changed neighbors cannot become
        # a candidate, even when the source epoch also changes.
        if w.submit(src,key,0,desired)["error"]!=OK:
            _fail("shadow negative setup",src,w,b)
            return
        for step in range(4000):
            if w.stats()["finished"]==1:
                break
            OS.delay_msec(1)
        if w.stats()["finished"]!=1 or src.set_generation(3)!=OK or w.poll(src,changed)["error"]!=ERR_BUSY:
            _fail("shadow negative epoch",src,w,b)
            return
        var negative: Dictionary=w.stats()
        if negative["epoch_reuse_shadow"]!=shadow or negative["discard_identity"]["changed_neighbors"]!=after["discard_identity"]["changed_neighbors"]+1:
            _fail("changed neighbor counted as candidate",src,w,b)
            return
        print("M3_EPOCH_REUSE_SHADOW ",JSON.stringify({"format":version,"before":before_shadow,"positive":shadow,"negative":negative["epoch_reuse_shadow"],"discard_identity":negative["discard_identity"]}))
        if w.submit(src,key,0,desired)["error"]!=OK:
            _fail("reopen setup",src,w,b)
            return
        src.close()
        err=src.open(directory,9,4,false) if version==1 else src.open_v2(directory,9,4,false,2)
        if err!=OK or w.poll(src,desired)["error"]!=ERR_INVALID_DATA or w.submit(src,key,0,desired)["error"]!=ERR_INVALID_DATA:
            _fail("source reopen identity",src,w,b)
            return
        print("GEOMETRY_WORKER ",JSON.stringify({"format":version,"parity_cases":7,"worker_build_elapsed_sum_us":elapsed,"stats_before_reopen":stats}))
        w.close()
        if w.stats()["slots"]!=0 or w.stats()["open"] or w.stats()["discard_accounting"]["classified"]!=0 or w.stats()["epoch_reuse_shadow"]["successful_finished_candidates"]!=0 or w.stats()["epoch_reuse_shadow"]["candidate_finished_reserved_output_bytes_sum"]!=0:
            _fail("close",src,w,b)
            return
        src.close()
        b.close()
    print("PASS: isolated bounded geometry worker, owned copy survives cache eviction, 14 exact LOD/mixed cases, stale neighbor/epoch/session rejection and close")
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
    push_error("Geometry worker: "+msg)
    quit(1)
