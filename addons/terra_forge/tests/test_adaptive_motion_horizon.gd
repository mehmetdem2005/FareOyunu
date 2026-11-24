extends "res://addons/terra_forge/tests/test_support_transfer.gd"
const WINDOW=preload("res://addons/terra_forge/core/motion_latency_window.gd")
const M=preload("res://addons/terra_forge/core/motion_prefetch.gd")
func _run() -> void:
    var estimator=WINDOW.new()
    if estimator.horizon!=0.25 or estimator.observe(-1,60)==OK or estimator.observe(1,0)==OK or estimator.samples!=0:
        _fail("initial/invalid latency")
        return
    if estimator.observe(2,60)!=OK or estimator.horizon!=0.125 or estimator.samples!=1:
        _fail("short latency")
        return
    for i in range(30):
        if estimator.observe(120,60)!=OK:
            _fail("bounded large observation")
            return
    if estimator.horizon!=0.5 or estimator.samples!=31:
        _fail("upper clamp")
        return
    for i in range(30):
        estimator.observe(1,60)
    if estimator.horizon<0.125 or estimator.horizon>0.15:
        _fail("recovery/hysteresis")
        return
    var extent=Vector2(576,576)
    var point=Vector2(533,500)
    var support: Array[Vector2i]=[NEW]
    var long: Dictionary=M.predict(point,Vector2(24,0),Vector2(24,0),Vector2(24,0),RADIUS,extent,32.0,support,0.5)
    var short: Dictionary=M.predict(point,Vector2(24,0),Vector2(24,0),Vector2(24,0),RADIUS,extent,32.0,support,0.125)
    var invalid: Dictionary=M.predict(point,Vector2.ZERO,Vector2(12,0),Vector2.ZERO,RADIUS,extent,32.0,support,NAN)
    if long.get("keys",[])!=[Vector2i(17,15)] or not short.get("keys",[]).is_empty() or invalid["error"]==OK:
        _fail("horizon corridor bounds")
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
            for cache in [9,16]:
                var order: Array[bool]=[false,true]
                if cache==16:
                    order.reverse()
                var paired: Dictionary={}
                for adaptive in order:
                    var outcome: Dictionary=await _case(made["directory"],format,mode,4,24.0,true,true,adaptive,cache)
                    if outcome.get("error",FAILED)!=OK:
                        _fail(str([format,mode,cache,adaptive])+" "+str(outcome))
                        return
                    paired[str(adaptive)]=outcome
                    print("ADAPTIVE_TRACE ",JSON.stringify({"format":format+1,"mode":mode,"cache":cache,"adaptive":adaptive,"metrics":outcome}))
                print("ADAPTIVE_PAIR ",JSON.stringify({"format":format+1,"mode":mode,"cache":cache,"fixed_denied":paired["false"]["denied_ticks"],"adaptive_denied":paired["true"]["denied_ticks"],"fixed_reads":paired["false"]["disk_reads_delta"],"adaptive_reads":paired["true"]["disk_reads_delta"]}))
        _builder.close()
        _builder=null
    print("PASS: bounded adaptive prediction horizon and paired real physics traces; tradeoff measured not assumed")
    quit(0)
