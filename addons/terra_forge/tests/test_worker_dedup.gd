extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const S=preload("res://addons/terra_forge/core/async_region_source.gd")
const W=preload("res://addons/terra_forge/tests/fixtures/gated_dedup_worker.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const B=preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")
var builder
var src
var worker

func _initialize() -> void:
    for format in [0,1]:
        builder=V1.new() if format==0 else V2.new()
        if builder.start(Vector2i(96,96))!=OK:
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
        for cap in [1,4]:
            src=S.new()
            var err: Error=src.open(made["directory"],9,4,false) if format==0 else src.open_v2(made["directory"],9,4,false,1)
            worker=W.new()
            if err!=OK or worker.start(src,cap,true,true,false,false,false,true)!=OK:
                _fail("open")
                return
            var key:=Vector2i(1,1)
            var desired: Dictionary={key:0,Vector2i(2,1):0}
            var changed: Dictionary={key:0,Vector2i(2,1):2}
            var pages: Array[Vector2i]=G.required_pages(src,key.x,key.y,0)
            if not _load(pages):
                _fail("pages")
                return
            var first: Dictionary=worker.submit(src,key,0,desired)
            if first["error"]!=OK or not _wait_gate():
                _fail("gate")
                return
            var before: Dictionary=src.stats()
            if not _duplicate(key,desired,first["id"]):
                _fail("running dedup")
                return
            if src.stats()["tile_view_acquires"]!=before["tile_view_acquires"]:
                _fail("duplicate lease")
                return
            var different: Dictionary=worker.submit(src,key,0,changed)
            if cap==1:
                if different["error"]!=ERR_BUSY:
                    _fail("cap1 must reject different identity")
                    return
            else:
                if different["error"]!=OK or different["id"]==first["id"] or not _duplicate(key,changed,different["id"]):
                    _fail("pending identity")
                    return
            worker.release_gate.post()
            var expected_ready: int=1 if cap==1 else 2
            if not _wait_ready(expected_ready) or not _duplicate(key,desired,first["id"]):
                _fail("finished dedup")
                return
            if worker.reconcile(src,desired,{key:0})!=OK:
                _fail("reconcile")
                return
            var received: Dictionary=worker.poll(src,desired)
            if received["error"]!=OK or received["result"]["id"]!=first["id"] or not B.equal(received["result"]["geometry"],G.generate(src,key.x,key.y,0,desired)):
                _fail("parity")
                return
            var next: Dictionary=worker.submit(src,key,0,desired)
            if next["error"]!=OK or next["id"]==first["id"] or not _wait_ready(1):
                _fail("delivered not cached")
                return
            if src.set_generation(1)!=OK or worker.reconcile(src,desired,{})!=OK or not _load(pages):
                _fail("epoch")
                return
            var fresh: Dictionary=worker.submit(src,key,0,desired)
            if fresh["error"]!=OK or fresh["id"]==next["id"] or not _wait_ready(1):
                _fail("new epoch identity")
                return
            var final: Dictionary=worker.poll(src,desired)
            var stats: Dictionary=worker.stats()
            if final["error"]!=OK or final["result"]["id"]!=fresh["id"] or not B.equal(final["result"]["geometry"],G.generate(src,key.x,key.y,0,desired)) or stats["slots"]!=0 or stats["delivered"]!=2 or stats["submitted"]!=stats["delivered"]+stats["dropped"] or stats["deduplication"]["coalesced"]!=(2 if cap==1 else 3) or stats["peak_slots"]>cap:
                _fail("accounting "+str(stats))
                return
            print("DEDUP_CASE ",JSON.stringify({"format":format+1,"cap":cap,"stats":stats}))
            worker.close()
            if worker.stats()["deduplication"]["coalesced"]!=0 or worker.stats()["deduplication"]["enabled"]:
                _fail("close reset")
                return
            worker=null
            src.close()
            src=null
        builder.close()
        builder=null
    print("PASS: exact bounded coalescing in pending/running/finished, cap1/4, different signature and epoch isolation, exact recovery")
    quit(0)

func _duplicate(key: Vector2i,desired: Dictionary,id: int) -> bool:
    var duplicate: Dictionary=worker.submit(src,key,0,desired)
    return duplicate["error"]==OK and duplicate.get("coalesced",false) and duplicate["id"]==id and duplicate["input_bytes"]==0 and duplicate["copy_elapsed_us"]==0

func _wait_gate() -> bool:
    for attempt in range(4000):
        if worker.entered.try_wait():
            return true
        OS.delay_msec(1)
    return false

func _wait_ready(count: int) -> bool:
    for attempt in range(4000):
        if worker.stats()["finished"]==count:
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
    push_error("Dedup: "+msg)
    quit(1)
