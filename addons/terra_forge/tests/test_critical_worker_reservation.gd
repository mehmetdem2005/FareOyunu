extends "res://addons/terra_forge/tests/test_support_transfer.gd"
const ASYNC=preload("res://addons/terra_forge/core/async_region_source.gd")
const WORKER=preload("res://addons/terra_forge/core/geometry_worker.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const B=preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")

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
        for cap in [1,2,4]:
            var evidence: Dictionary=_queue_case(made["directory"],format,cap)
            if evidence.get("error",FAILED)!=OK:
                _fail("reservation queue "+str([format,cap])+" "+str(evidence))
                return
            print("RESERVE_QUEUE ",JSON.stringify({"format":format+1,"cap":cap,"metrics":evidence}))
        var order: Array[int]=[1,2]
        if format==1:
            order.reverse()
        for trial in order:
            var result: Dictionary=await _case(made["directory"],format,5,12,24.0,true,true,true,16,trial)
            if result.get("error",FAILED)!=OK:
                _fail("live reservation "+str([format,trial])+" "+str(result))
                return
            print("RESERVE_TRACE ",JSON.stringify({"format":format+1,"trial":trial,"metrics":result}))
        _builder.close()
        _builder=null
    print("PASS: bounded LOD0 reservation, cap1 progress, parity, ownership accounting and paired physics")
    quit(0)

func _queue_case(folder: String,format: int,cap: int) -> Dictionary:
    var src=ASYNC.new()
    var worker=WORKER.new()
    var err: Error=src.open(folder,16,4,false) if format==0 else src.open_v2(folder,16,4,false,2)
    if err!=OK or worker.start(src,cap,true,false,true)!=OK:
        worker.close()
        src.close()
        return {"error":FAILED,"stage":"open"}
    var result: Dictionary=_exercise(src,worker,cap)
    worker.close()
    src.close()
    return result

func _exercise(src,worker,cap: int) -> Dictionary:
    var a=Vector2i(15,15)
    var b=Vector2i(16,15)
    var c=Vector2i(15,16)
    var desired: Dictionary={a:0,b:1,c:2}
    var keys: Array[Vector2i]=[]
    for tile in desired:
        for page in G.required_pages(src,tile.x,tile.y,desired[tile]):
            if not keys.has(page):
                keys.append(page)
    if not _load(src,keys):
        return {"error":FAILED,"stage":"pages"}
    var optional_count: int=maxi(1,cap-1)
    var optional_ids: Array[int]=[]
    for i in range(optional_count):
        var job: Dictionary=worker.submit(src,b,1,desired)
        if job["error"]!=OK:
            return {"error":FAILED,"stage":"fill optional","detail":job}
        optional_ids.append(job["id"])
    var denied: Dictionary=worker.submit(src,c,2,desired)
    if denied["error"]!=ERR_BUSY or bool(denied.get("reserved_critical",false))!=(cap>=2):
        return {"error":FAILED,"stage":"optional admission","detail":denied}
    if cap==1:
        if not _await_finished(worker,1):
            return {"error":FAILED,"stage":"cap1 finish"}
        var optional: Dictionary=worker.poll(src,desired)
        if optional["error"]!=OK or optional["result"]["id"]!=optional_ids[0]:
            return {"error":FAILED,"stage":"cap1 progress"}
        optional_ids.clear()
    var critical: Dictionary=worker.submit(src,a,0,desired)
    if critical["error"]!=OK:
        return {"error":FAILED,"stage":"critical admission","detail":critical}
    if not _await_finished(worker,optional_ids.size()+1):
        return {"error":FAILED,"stage":"finish"}
    # Intentionally put the far jobs ahead of the critical result.
    # Critical-only poll must find the LOD0 output without dropping far.
    if worker.reconcile(src,desired,{b:0,c:1,a:2})!=OK:
        return {"error":FAILED,"stage":"reconcile"}
    var first: Dictionary=worker.poll(src,desired,-1,true)
    if first["error"]!=OK or first["result"]["id"]!=critical["id"] or not B.equal(first["result"]["geometry"],G.generate(src,a.x,a.y,0,desired)):
        return {"error":FAILED,"stage":"critical delivery parity"}
    if cap>=2:
        var hold: Dictionary=worker.poll(src,desired,-1,true)
        if hold["error"]!=ERR_BUSY or not hold.get("deferred_optional",false) or int(worker.stats()["optional_slots"])!=optional_ids.size():
            return {"error":FAILED,"stage":"optional retention"}
    for id in optional_ids:
        var item: Dictionary=worker.poll(src,desired)
        if item["error"]!=OK or item["result"]["id"]!=id or not B.equal(item["result"]["geometry"],G.generate(src,b.x,b.y,1,desired)):
            return {"error":FAILED,"stage":"optional parity"}
    # Once critical demand has drained, optional work must progress again.
    var later: Dictionary=worker.submit(src,c,2,desired)
    if later["error"]!=OK or not _await_finished(worker,1):
        return {"error":FAILED,"stage":"optional recovery"}
    var done: Dictionary=worker.poll(src,desired)
    var stats: Dictionary=worker.stats()
    if done["error"]!=OK or done["result"]["id"]!=later["id"] or not B.equal(done["result"]["geometry"],G.generate(src,c.x,c.y,2,desired)) or stats["slots"]!=0 or stats["optional_slots"]!=0 or stats["peak_slots"]>cap or stats["submitted"]!=stats["delivered"]+stats["dropped"] or stats["reservation_deferrals"]!=(1 if cap>=2 else 0):
        return {"error":FAILED,"stage":"ownership/progress","stats":stats}
    # New epoch must invalidate a completed optional result, freeing its
    # reservation without increasing capacity or publishing stale geometry.
    var stale: Dictionary=worker.submit(src,b,1,desired)
    if stale["error"]!=OK or not _await_finished(worker,1) or src.set_generation(int(src.stats()["generation"])+1)!=OK or worker.reconcile(src,desired,{a:0,b:1,c:2})!=OK:
        return {"error":FAILED,"stage":"epoch setup"}
    var after: Dictionary=worker.stats()
    if after["slots"]!=0 or after["optional_slots"]!=0 or after["dropped"]!=1 or after["submitted"]!=after["delivered"]+after["dropped"]:
        return {"error":FAILED,"stage":"epoch accounting","stats":after}
    return {"error":OK,"optional_fill":optional_count,"critical_admitted":true,"far_parity":true,"critical_parity":true,"epoch_reclaimed":true,"stats":after}

func _await_finished(worker,count: int) -> bool:
    for step in range(4000):
        if int(worker.stats()["finished"])==count:
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

