extends "res://addons/terra_forge/tests/test_support_transfer.gd"
const M=preload("res://addons/terra_forge/core/motion_prefetch.gd")
func _run() -> void:
    var support: Array[Vector2i]=[OLD]
    var extent=Vector2(576,576)
    var point=Vector2(510,500)
    var forward: Dictionary=M.predict(point,Vector2.ZERO,Vector2(12,0),Vector2.ZERO,RADIUS,extent,32.0,support)
    var stopped: Dictionary=M.predict(point,Vector2(12,0),Vector2.ZERO,Vector2(12,0),RADIUS,extent,32.0,support)
    var reverse: Dictionary=M.predict(point,Vector2(12,0),Vector2(-12,0),Vector2(12,0),RADIUS,extent,32.0,support)
    var diagonal: Dictionary=M.predict(Vector2(510,510),Vector2.ZERO,Vector2(10000,10000),Vector2.ZERO,RADIUS,extent,32.0,support)
    var invalid: Dictionary=M.predict(point,Vector2.ZERO,Vector2(NAN,0),Vector2.ZERO,RADIUS,extent,32.0,support)
    if forward.get("keys",[])!=[NEW] or not stopped.get("keys",[]).is_empty() or not reverse.get("keys",[]).is_empty() or diagonal.get("keys",[]).size()!=2 or invalid["error"]==OK:
        _fail("pure motion corridor checks")
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
            for speed in [12.0,24.0]:
                var order: Array[bool]=[false,true]
                if speed==24.0:
                    order.reverse()
                var paired: Dictionary={}
                for predictive in order:
                    var outcome: Dictionary=await _case(made["directory"],format,mode,4,speed,predictive)
                    if outcome.get("error",FAILED)!=OK:
                        _fail(str([format,mode,speed,predictive])+" "+str(outcome))
                        return
                    paired[str(predictive)]=outcome
                    print("PREFETCH_TRACE ",JSON.stringify({"format":format+1,"mode":mode,"speed":speed,"cap":4,"predictive":predictive,"metrics":outcome}))
                # Do not assume a speed win. Record even a regression;
                # safety/resource invariants in _case are strict.
                print("PREFETCH_PAIR ",JSON.stringify({"format":format+1,"mode":mode,"speed":speed,"baseline_denied":paired["false"]["denied_ticks"],"predictive_denied":paired["true"]["denied_ticks"]}))
        _builder.close()
        _builder=null
    print("PASS: bounded motion corridor and paired actual physics traces, no assumed performance win")
    quit(0)
