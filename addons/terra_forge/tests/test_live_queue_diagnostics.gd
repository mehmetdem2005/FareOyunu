extends "res://addons/terra_forge/tests/test_motion_roundtrip.gd"
## Same real route with only the diagnostic flags changed.
func _run() -> void:
    var format: int=_format()
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
    for cache in [9,16]:
        var order: Array[bool]=[false,true]
        if cache==16:
            order.reverse()
        for diagnostics in order:
            var outcome: Dictionary=await _case(made["directory"],format,5,cache,true,diagnostics)
            if outcome.get("error",FAILED)!=OK:
                _fail(str([format,5,cache,diagnostics])+" "+str(outcome))
                return
            print("LIVE_DIAGNOSTICS_TRACE ",JSON.stringify({"format":format+1,"mode":5,"cache":cache,"diagnostics":diagnostics,"metrics":outcome}))
    _builder.close()
    _builder=null
    print("PASS: live diagnostic on/off multi-seam parity, gate/latency accounting, bounds and lifecycle")
    quit(0)

