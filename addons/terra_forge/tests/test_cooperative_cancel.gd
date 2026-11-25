extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const ASYNC=preload("res://addons/terra_forge/core/async_region_source.gd")
const W=preload("res://addons/terra_forge/tests/fixtures/gated_cancel_worker.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const B=preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")
var builder
var src
var worker

func _initialize() -> void:
    for format in [0,1]:
        builder=V1.new() if format==0 else V2.new()
        var err: Error=builder.start(Vector2i(96,96))
        if err!=OK:
            _fail("fixture start")
            return
        var made: Dictionary={}
        for attempt in range(10000):
            made=builder.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(1)
        if made.get("error",FAILED)!=OK:
            _fail("fixture")
            return
        for scalar in [false,true]:
            for epoch_cancel in [false,true]:
                src=ASYNC.new()
                err=src.open(made["directory"],9,4,false) if format==0 else src.open_v2(made["directory"],9,4,false,1)
                worker=W.new()
                if err!=OK or worker.start(src,2,scalar,scalar,false,false,false,true)!=OK:
                    _fail("open")
                    return
                var key:=Vector2i(1,1)
                var desired: Dictionary={key:0,Vector2i(2,1):0}
                var changed: Dictionary={key:0,Vector2i(2,1):2}
                if not _load(G.required_pages(src,key.x,key.y,0)):
                    _fail("warm")
                    return
                var first: Dictionary=worker.submit(src,key,0,desired)
                if first["error"]!=OK or not _wait_gate():
                    _fail("in-row gate")
                    return
                var pending: Dictionary=worker.submit(src,key,0,desired)
                if pending["error"]!=OK or worker.stats()["slots"]!=2:
                    _fail("queued ownership")
                    return
                if epoch_cancel and src.set_generation(1)!=OK:
                    _fail("epoch")
                    return
                var current: Dictionary=desired if epoch_cancel else changed
                if worker.reconcile(src,current,{key:0})!=OK or worker.stats()["slots"]!=1:
                    _fail("pending drop")
                    return
                worker.release_gate.post()
                for attempt in range(4000):
                    if worker.stats()["slots"]==0:
                        break
                    OS.delay_msec(1)
                var stats: Dictionary=worker.stats()
                if stats["slots"]!=0 or stats["dropped"]!=2 or stats["discard_accounting"]["classified"]!=2 or stats["cooperative_cancel"]["aborted"]!=1 or worker.poll(src,current)["error"]!=ERR_BUSY:
                    _fail("cancel ownership "+str(stats))
                    return
                if not _load(G.required_pages(src,key.x,key.y,0)):
                    _fail("recovery pages")
                    return
                var expected: Dictionary=G.generate(src,key.x,key.y,0,current)
                var next: Dictionary=worker.submit(src,key,0,current)
                var received: Dictionary={}
                for attempt in range(4000):
                    received=worker.poll(src,current)
                    if received["error"]!=ERR_BUSY:
                        break
                    OS.delay_msec(1)
                if next["error"]!=OK or received.get("error",FAILED)!=OK or received["result"]["id"]!=next["id"] or not B.equal(expected,received["result"]["geometry"]) or worker.stats()["slots"]!=0:
                    _fail("recovery parity")
                    return
                print("COOPERATIVE_CANCEL_CASE ",JSON.stringify({"format":format+1,"scalar":scalar,"epoch":epoch_cancel,"before_recovery":stats,"final":worker.stats()}))
                worker.close()
                worker=null
                src.close()
                src=null
        builder.close()
        builder=null
    print("PASS: bounded cooperative cancellation in row, pending discard, epoch/signature invalidation and exact recovery across eight cases")
    quit(0)

func _wait_gate() -> bool:
    for attempt in range(4000):
        if worker.entered.try_wait():
            return true
        OS.delay_msec(1)
    return false

func _load(keys: Array[Vector2i]) -> bool:
    for attempt in range(4000):
        src.poll_results(4)
        src.prioritize_resident(keys)
        var ready: bool=true
        for key in keys:
            var err: Error=src.page_status(key)
            if err==ERR_BUSY:
                ready=false
                src.request_page(key)
            elif err!=OK:
                return false
        if ready:
            return true
        OS.delay_msec(1)
    return false

func _fail(msg: String) -> void:
    if worker!=null:
        worker.release_gate.post()
        worker.close()
    if src!=null:
        src.close()
    if builder!=null:
        builder.close()
    push_error("Cooperative cancel: "+msg)
    quit(1)
