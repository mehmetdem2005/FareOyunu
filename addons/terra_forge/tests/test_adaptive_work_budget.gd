extends "res://addons/terra_forge/tests/test_support_transfer.gd"
const BUDGET=preload("res://addons/terra_forge/core/adaptive_work_budget.gd")
func _run() -> void:
    var budget=BUDGET.new()
    budget.begin_pump(0,8000)
    if not budget.allows_optional(9000):
        _fail("unrestricted tier")
        return
    budget.begin_pump(1,8000)
    budget.record(0,100)
    if not budget.allows_optional(3999) or budget.allows_optional(4000):
        _fail("tier1 time")
        return
    budget.record(1,500)
    budget.record(2,1000)
    if budget.allows_optional(1001):
        _fail("tier1 count")
        return
    budget.begin_pump(2,8000)
    if not budget.allows_optional(2500):
        _fail("idle progress")
        return
    budget.record(2,2500)
    if budget.allows_optional(2501):
        _fail("tier2 count")
        return
    budget.record(0,2600)
    budget.note_deferral()
    if budget.report()["tier2_peak_optional"]!=1 or budget.report()["first_progress_exceptions"]!=1 or budget.report()["critical_attempts"]!=2:
        _fail("accounting")
        return
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
        for mode in [0,5]:
            var order: Array[int]=[0,1]
            if mode==5:
                order.reverse()
            for trial in order:
                var result: Dictionary=await _case(made["directory"],format,mode,12,24.0,true,true,true,16,trial)
                if result.get("error",FAILED)!=OK:
                    _fail(str([format,mode,trial])+" "+str(result))
                    return
                print("WORK_BUDGET_TRACE ",JSON.stringify({"format":format+1,"mode":mode,"trial":trial,"metrics":result}))
        _builder.close()
        _builder=null
    print("PASS: optional work soft budget, critical bypass, fixed caps and paired physics traces")
    quit(0)
