extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const ASYNC=preload("res://addons/terra_forge/core/async_region_source.gd")
const WORKER=preload("res://addons/terra_forge/core/geometry_worker.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const B=preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")

func _initialize() -> void:
    print("PRIORITY_ENV ",JSON.stringify({"os":OS.get_name(),"cpu":OS.get_processor_name(),"godot":Engine.get_version_info().get("string",""),"notes":"8ms target cadence with deadline misses, 2ms sleep baseline, fixed positions; off-tree, no rendered frame or raycast"}))
    for format in [0,1]:
        var builder: Variant=V1.new() if format==0 else V2.new()
        var err: Error=builder.start(Vector2i(576,576),true) if format==0 else builder.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start",builder)
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=builder.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture",builder)
            return
        var folder: String=made["directory"]
        if not _queue_case(folder,format):
            _fail("queue priority/parity",builder)
            return
        # Alternate E/F ordering across groups; C control in each cadence.
        for cadence in [0,8000]:
            for cache in [9,16]:
                var order: Array=[2,3,4] if (format==0)==(cache==9) else [4,3,2]
                for mode in order:
                    var result: Dictionary=TRACE.run(folder,format,mode,cache,2,cadence)
                    if result.get("error",FAILED)!=OK:
                        _fail("trace "+str(result),builder)
                        return
                    print("PRIORITY_CASE ",JSON.stringify(result))
        builder.close()
    print("PASS: F bounded priority/reconciliation, exact resource input parity, stale finished prune, priority delivery, 24 C/E/F fixed-step/cadence traces")
    quit(0)

func _queue_case(folder: String,format: int) -> bool:
    var src=ASYNC.new()
    var w=WORKER.new()
    var err: Error=src.open(folder,16,4,false) if format==0 else src.open_v2(folder,16,4,false,2)
    if err!=OK or w.start(src,4)!=OK:
        w.close()
        src.close()
        return false
    var a=Vector2i(15,15)
    var b=Vector2i(16,15)
    var c=Vector2i(15,16)
    var desired: Dictionary={a:0,b:1,c:2}
    var keys: Array[Vector2i]=[]
    for tile in desired:
        for page in G.required_pages(src,tile.x,tile.y,desired[tile]):
            if not keys.has(page):
                keys.append(page)
    var ok: bool=_load(src,keys)
    if ok:
        # Submit one independent stale job and two identical current
        # signatures, wait until finished to make ordering deterministic.
        var old: Dictionary=desired.duplicate()
        old.erase(b)
        var stale: Dictionary=w.submit(src,a,0,old)
        var x: Dictionary=w.submit(src,a,0,desired)
        var y: Dictionary=w.submit(src,b,1,desired)
        ok=stale["error"]==OK and x["error"]==OK and y["error"]==OK
        for step in range(4000):
            if w.stats()["finished"]==3:
                break
            OS.delay_msec(1)
        ok=ok and w.stats()["finished"]==3
        if ok:
            ok=w.reconcile(src,desired,{b:0,a:1})==OK
            var first: Dictionary=w.poll(src,desired)
            var second: Dictionary=w.poll(src,desired)
            ok=ok and first["error"]==OK and second["error"]==OK
            if ok:
                ok=first["result"]["id"]==y["id"] and second["result"]["id"]==x["id"] and B.equal(first["result"]["geometry"],G.generate(src,b.x,b.y,1,desired)) and B.equal(second["result"]["geometry"],G.generate(src,a.x,a.y,0,desired))
            var stats: Dictionary=w.stats()
            ok=ok and stats["pruned_finished"]==1 and stats["dropped"]==1 and stats["slots"]==0 and stats["submitted"]==stats["delivered"]+stats["dropped"]
            ok=ok and stats["discard_identity"]["changed_neighbors"]==1
        if ok:
            # Ready job with unchanged geometry: still drop on generation change.
            ok=w.submit(src,a,0,desired)["error"]==OK and _wait_ready(w,1)
            ok=ok and src.set_generation(1)==OK and w.reconcile(src,desired,{})==OK
            var same: Dictionary=w.stats()["discard_identity"]
            ok=ok and same["same_geometry_at_epoch"]==1 and w.stats()["slots"]==0
        if ok:
            ok=_load(src,keys)
            for tile in desired:
                if not ok:
                    break
                ok=w.submit(src,tile,desired[tile],desired)["error"]==OK
            ok=ok and _wait_ready(w,3)
            var changed: Dictionary={a:0,b:2}
            ok=ok and src.set_generation(2)==OK and w.reconcile(src,changed,{})==OK
            var final: Dictionary=w.stats()
            var identity: Dictionary=final["discard_identity"]
            ok=ok and final["slots"]==0 and final["dropped"]==5 and final["discard_accounting"]["classified"]==5 and final["submitted"]==final["delivered"]+final["dropped"]
            ok=ok and identity["removed_key"]==1 and identity["changed_lod"]==1 and identity["changed_neighbors"]==2 and identity["same_geometry_at_epoch"]==1 and identity["unknown"]==0 and identity["invalid_signature"]==0
            print("DISCARD_IDENTITY_CASE ",JSON.stringify({"format":format+1,"worker":final}))
    w.close()
    src.close()
    return ok

func _wait_ready(w,count: int) -> bool:
    for attempt in range(4000):
        if w.stats()["finished"]==count:
            return true
        OS.delay_msec(1)
    return false

func _load(src,keys: Array[Vector2i]) -> bool:
    for step in range(4000):
        src.poll_results(4)
        src.prioritize_resident(keys)
        var ready: bool=true
        for key in keys:
            var state: Error=src.page_status(key)
            if state==ERR_BUSY:
                ready=false
                src.request_page(key)
            elif state!=OK:
                return false
        if ready:
            return true
        OS.delay_msec(1)
    return false

func _fail(msg: String,b) -> void:
    b.close()
    push_error("Worker priority: "+msg)
    quit(1)
