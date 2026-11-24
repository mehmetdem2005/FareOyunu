extends "res://addons/terra_forge/tests/test_geometry_latency_profile.gd"

func _run() -> void:
    for format in [0, 1]:
        _builder = V1.new() if format == 0 else V2.new()
        var err: Error = _builder.start(Vector2i(576,576),true) if format == 0 else _builder.start(Vector2i(576,576))
        if err != OK:
            _fail("fixture start")
            return
        var made: Dictionary = {}
        for attempt in range(15000):
            made = _builder.take_result()
            if made["error"] != ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error", FAILED) != OK:
            _fail("fixture timeout")
            return
        for cap in [2, 4]:
            var report := _diagnostic_case(made["directory"], format, cap, false)
            if report.get("error", FAILED) != OK:
                _fail("controlled contention " + str(report))
                return
            print("SATURATION_FAIRNESS ", JSON.stringify({"format":format+1,"cap":cap,"metrics":report}))
        _builder.close()
        _builder = null
    print("PASS: controlled saturation and optional progress after bounded critical bursts")
    quit(0)

func _diagnostic_exercise(src, worker, cap: int, _cancel: bool) -> Dictionary:
    var critical := Vector2i(15,15)
    var optional := Vector2i(16,15)
    var desired := {critical:0, optional:1}
    var pages: Array[Vector2i] = []
    for tile in desired:
        for page in G.required_pages(src,tile.x,tile.y,desired[tile]):
            if not pages.has(page):
                pages.append(page)
    if not _load(src,pages) or worker.set_critical_demand(src,false) != OK:
        return {"error":FAILED,"stage":"preload"}
    var optional_ids: Array[int] = []
    for slot in range(cap):
        var job: Dictionary = worker.submit(src,optional,1,desired)
        if job["error"] != OK:
            return {"error":FAILED,"stage":"fill"}
        optional_ids.append(job["id"])
    if worker.set_critical_demand(src,true) != OK or worker.submit(src,critical,0,desired)["error"] != ERR_BUSY:
        return {"error":FAILED,"stage":"full gate"}
    worker.gate.post()
    if not _await_finished(worker,cap):
        return {"error":FAILED,"stage":"initial drain"}
    var first: Dictionary = worker.poll(src,desired)
    if first["error"] != OK or first["result"]["id"] != optional_ids.pop_front():
        return {"error":FAILED,"stage":"release slot"}
    var burst := 12
    for turn in range(burst):
        var urgent: Dictionary = worker.submit(src,critical,0,desired)
        if urgent["error"] != OK or not _await_finished(worker,cap):
            return {"error":FAILED,"stage":"critical progress","turn":turn}
        if worker.submit(src,optional,1,desired)["error"] != ERR_BUSY:
            return {"error":FAILED,"stage":"capacity"}
        var delivered: Dictionary = worker.poll(src,desired,-1,true)
        if delivered["error"] != OK or delivered["result"]["id"] != urgent["id"]:
            return {"error":FAILED,"stage":"critical identity"}
    if worker.set_critical_demand(src,false) != OK:
        return {"error":FAILED,"stage":"end burst"}
    for id in optional_ids:
        var retained: Dictionary = worker.poll(src,desired)
        if retained["error"] != OK or retained["result"]["id"] != id:
            return {"error":FAILED,"stage":"optional recovery"}
    var stats: Dictionary = worker.stats()
    if stats["slots"] != 0 or stats["dropped"] != 0 or stats["delivered"] != cap + burst or stats["peak_slots"] != cap:
        return {"error":FAILED,"stage":"accounting","stats":stats}
    return {"error":OK,"critical_deliveries_before_optional_recovery":burst,"deferred_optional_results":cap-1,"stats":stats,"profile":worker.latency_profile()}
