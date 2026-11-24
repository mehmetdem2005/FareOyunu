extends "res://addons/terra_forge/tests/test_critical_worker_reservation.gd"
const GATED=preload("res://addons/terra_forge/tests/fixtures/gated_geometry_worker.gd")

func _run() -> void:
    for format in _formats():
        _builder=V1.new() if format==0 else V2.new()
        var err: Error=_builder.start(Vector2i(576,576),true) if format==0 else _builder.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=_builder.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture")
            return
        for cap in [2,4]:
            for cancel in [false,true]:
                var evidence: Dictionary=_diagnostic_case(made["directory"],format,cap,cancel)
                if evidence.get("error",FAILED)!=OK:
                    _fail("latency diagnostic "+str([format,cap,cancel])+" "+str(evidence))
                    return
                print("QUEUE_LATENCY_TRACE ",JSON.stringify({"format":format+1,"cap":cap,"cancel":cancel,"metrics":evidence}))
        _builder.close()
        _builder=null
    print("PASS: gated running worker, classified latency, epoch cancellation, exact parity and fixed ownership")
    quit(0)

func _diagnostic_case(folder: String,format: int,cap: int,cancel: bool) -> Dictionary:
    var src=ASYNC.new()
    var worker=GATED.new()
    var err: Error=src.open(folder,16,4,false) if format==0 else src.open_v2(folder,16,4,false,2)
    if err!=OK or worker.start(src,cap,true,false,true,true,true)!=OK:
        worker.gate.post()
        worker.close()
        src.close()
        return {"error":FAILED,"stage":"open"}
    var result: Dictionary=_diagnostic_exercise(src,worker,cap,cancel)
    # Release even on any failed assertion; never join a gated thread.
    worker.gate.post()
    worker.close()
    src.close()
    return result

func _diagnostic_exercise(src,worker,cap: int,cancel: bool) -> Dictionary:
    var a=Vector2i(15,15)
    var b=Vector2i(16,15)
    var c=Vector2i(15,16)
    var desired: Dictionary={a:0,b:1,c:2}
    var keys: Array[Vector2i]=[]
    for tile in desired:
        for page in G.required_pages(src,tile.x,tile.y,desired[tile]):
            if not keys.has(page):
                keys.append(page)
    if not _load(src,keys) or worker.set_critical_demand(src,false)!=OK:
        return {"error":FAILED,"stage":"pages"}
    var first: Dictionary=worker.submit(src,b,1,desired)
    if first["error"]!=OK:
        return {"error":FAILED,"stage":"first optional"}
    for step in range(4000):
        if worker.stats()["inflight"]==1:
            break
        OS.delay_msec(1)
    if worker.stats()["inflight"]!=1 or worker.stats()["finished"]!=0:
        return {"error":FAILED,"stage":"gated running"}
    var far_ids: Array[int]=[first["id"]]
    for i in range(cap-1):
        var more: Dictionary=worker.submit(src,c,2,desired)
        if more["error"]!=OK:
            return {"error":FAILED,"stage":"fill"}
        far_ids.append(more["id"])
    if worker.set_critical_demand(src,true)!=OK or worker.submit(src,a,0,desired)["error"]!=ERR_BUSY:
        return {"error":FAILED,"stage":"full critical denial"}
    OS.delay_msec(10)
    var blocked: Dictionary=worker.latency_profile()
    if blocked["ownership"]["owned"]!=cap or blocked["outstanding_age_us"]["optional"]["running_us"]<=0 or blocked["outstanding_age_us"]["optional"]["pending_us"]<=0 or blocked["optional"]["build_ms"]["count"]!=0:
        return {"error":FAILED,"stage":"censored snapshot","detail":blocked}
    if cancel:
        if src.set_generation(int(src.stats()["generation"])+1)!=OK or worker.reconcile(src,desired,{a:0,b:1,c:2})!=OK:
            return {"error":FAILED,"stage":"epoch cancellation"}
        if worker.stats()["slots"]!=1 or worker.stats()["dropped"]!=cap-1:
            return {"error":FAILED,"stage":"running ownership after epoch"}
        worker.gate.post()
        for step in range(4000):
            if worker.stats()["slots"]==0:
                break
            OS.delay_msec(1)
        var cancelled: Dictionary=worker.latency_profile()
        if cancelled["ownership"]["owned"]!=0 or cancelled["ownership"]["dropped"]!=cap or cancelled["optional"]["build_ms"]["count"]!=0 or worker.poll(src,desired)["error"]!=ERR_BUSY:
            return {"error":FAILED,"stage":"cancelled samples","detail":cancelled}
        if not _load(src,keys):
            return {"error":FAILED,"stage":"reload after epoch"}
    else:
        worker.gate.post()
        if not _await_finished(worker,cap):
            return {"error":FAILED,"stage":"release"}
        # Withhold delivery deliberately, separate from execution delay.
        OS.delay_msec(10)
        var waiting: Dictionary=worker.latency_profile()
        if waiting["outstanding_age_us"]["optional"]["finished_us"]<=0 or waiting["optional"]["delivery_ms"]["count"]!=0:
            return {"error":FAILED,"stage":"delivery snapshot"}
        var item: Dictionary=worker.poll(src,desired)
        if item["error"]!=OK or item["result"]["id"]!=far_ids[0] or not B.equal(item["result"]["geometry"],G.generate(src,b.x,b.y,1,desired)):
            return {"error":FAILED,"stage":"first drain parity"}
        far_ids.pop_front()
    var critical: Dictionary=worker.submit(src,a,0,desired)
    if critical["error"]!=OK or not _await_finished(worker,1 if cancel else cap):
        return {"error":FAILED,"stage":"critical recovery"}
    var close_result: Dictionary=worker.poll(src,desired,-1,true)
    if close_result["error"]!=OK or close_result["result"]["id"]!=critical["id"] or not B.equal(close_result["result"]["geometry"],G.generate(src,a.x,a.y,0,desired)):
        return {"error":FAILED,"stage":"critical parity"}
    if not cancel:
        for id in far_ids:
            var far: Dictionary=worker.poll(src,desired)
            if far["error"]!=OK or far["result"]["id"]!=id or not B.equal(far["result"]["geometry"],G.generate(src,c.x,c.y,2,desired)):
                return {"error":FAILED,"stage":"far parity"}
    var final: Dictionary=worker.latency_profile()
    var stats: Dictionary=worker.stats()
    var expected_optional: int=0 if cancel else cap
    for stage in ["queue_ms","build_ms","delivery_ms","stage_sum_ms"]:
        if final["critical"][stage]["count"]!=1 or final["optional"][stage]["count"]!=expected_optional:
            return {"error":FAILED,"stage":"sample accounting","detail":final}
    if stats["slots"]!=0 or stats["peak_slots"]!=cap or stats["submitted"]!=stats["delivered"]+stats["dropped"] or stats["dropped"]!=(cap if cancel else 0):
        return {"error":FAILED,"stage":"ownership","stats":stats}
    return {"error":OK,"injected_gate":true,"blocked":blocked,"final":final,"stats":stats}
