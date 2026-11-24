extends "res://addons/terra_forge/tests/test_critical_worker_reservation.gd"

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
            var evidence: Dictionary=_loan_case(made["directory"],format,cap)
            if evidence.get("error",FAILED)!=OK:
                _fail("reservation queue "+str([format,cap])+" "+str(evidence))
                return
            print("LENDING_QUEUE ",JSON.stringify({"format":format+1,"cap":cap,"metrics":evidence}))
        var order: Array[int]=[2,3]
        if format==1:
            order.reverse()
        for trial in order:
            var result: Dictionary=await _case(made["directory"],format,5,12,24.0,true,true,true,16,trial)
            if result.get("error",FAILED)!=OK:
                _fail("live reservation "+str([format,trial])+" "+str(result))
                return
            print("LENDING_TRACE ",JSON.stringify({"format":format+1,"trial":trial,"metrics":result}))
        _builder.close()
        _builder=null
    print("PASS: demand-sensitive lending, lossless recall, exact parity and paired physics")
    quit(0)

func _loan_case(folder: String,format: int,cap: int) -> Dictionary:
    var src=ASYNC.new()
    var worker=WORKER.new()
    var err: Error=src.open(folder,16,4,false) if format==0 else src.open_v2(folder,16,4,false,2)
    if err!=OK or worker.start(src,cap,true,false,true,true)!=OK:
        worker.close()
        src.close()
        return {"error":FAILED,"stage":"open"}
    var result: Dictionary=_loan_exercise(src,worker,cap)
    worker.close()
    src.close()
    return result

func _loan_exercise(src,worker,cap: int) -> Dictionary:
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
        return {"error":FAILED,"stage":"pages/demand"}
    var ids: Array[int]=[]
    for i in range(cap):
        var job: Dictionary=worker.submit(src,b,1,desired)
        if job["error"]!=OK:
            return {"error":FAILED,"stage":"loan fill","detail":job}
        ids.append(job["id"])
    if not _await_finished(worker,cap):
        return {"error":FAILED,"stage":"loan finish"}
    var filled: Dictionary=worker.stats()
    if filled["optional_slots"]!=cap or filled["loan_admissions"]!=1 or filled["reservation_enforced"]:
        return {"error":FAILED,"stage":"loan accounting","stats":filled}
    if worker.set_critical_demand(src,true)!=OK:
        return {"error":FAILED,"stage":"recall"}
    var denied: Dictionary=worker.submit(src,a,0,desired)
    if denied["error"]!=ERR_BUSY or worker.stats()["dropped"]!=0:
        return {"error":FAILED,"stage":"full critical denial"}
    # Recall is lossless: allow one completed optional output to drain.
    # No preemption, extra slot, discard or unverified output.
    var first: Dictionary=worker.poll(src,desired)
    if first["error"]!=OK or first["result"]["id"]!=ids[0] or not B.equal(first["result"]["geometry"],G.generate(src,b.x,b.y,1,desired)):
        return {"error":FAILED,"stage":"drain parity"}
    ids.pop_front()
    var denied_far: Dictionary=worker.submit(src,c,2,desired)
    if denied_far["error"]!=ERR_BUSY or not denied_far.get("reserved_critical",false):
        return {"error":FAILED,"stage":"recall reservation"}
    var critical: Dictionary=worker.submit(src,a,0,desired)
    if critical["error"]!=OK or not _await_finished(worker,cap):
        return {"error":FAILED,"stage":"critical after drain"}
    var close_result: Dictionary=worker.poll(src,desired,-1,true)
    if close_result["error"]!=OK or close_result["result"]["id"]!=critical["id"] or not B.equal(close_result["result"]["geometry"],G.generate(src,a.x,a.y,0,desired)):
        return {"error":FAILED,"stage":"critical parity"}
    for id in ids:
        var far: Dictionary=worker.poll(src,desired)
        if far["error"]!=OK or far["result"]["id"]!=id or not B.equal(far["result"]["geometry"],G.generate(src,b.x,b.y,1,desired)):
            return {"error":FAILED,"stage":"remaining parity"}
    if worker.set_critical_demand(src,false)!=OK:
        return {"error":FAILED,"stage":"return loan"}
    for i in range(cap):
        if worker.submit(src,c,2,desired)["error"]!=OK:
            return {"error":FAILED,"stage":"re-lend"}
    if not _await_finished(worker,cap):
        return {"error":FAILED,"stage":"re-lend finish"}
    if src.set_generation(int(src.stats()["generation"])+1)!=OK or worker.reconcile(src,desired,{a:0,b:1,c:2})!=OK:
        return {"error":FAILED,"stage":"epoch"}
    var final: Dictionary=worker.stats()
    if final["slots"]!=0 or final["optional_slots"]!=0 or final["dropped"]!=cap or final["submitted"]!=final["delivered"]+final["dropped"] or final["peak_slots"]!=cap or final["loan_admissions"]!=2 or final["critical_full_denials"]!=1 or final["reservation_deferrals"]!=1 or final["demand_changes"]!=3:
        return {"error":FAILED,"stage":"ownership/accounting","stats":final}
    return {"error":OK,"full_optional_slots":cap,"drains_before_critical":1,"discarded_on_recall":0,"critical_parity":true,"far_parity":true,"stats":final}
