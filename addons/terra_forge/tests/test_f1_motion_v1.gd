extends "res://addons/terra_forge/tests/test_motion_roundtrip.gd"
var _late: bool=false

func _format() -> int:
    return 0

func _f1_poll_after_sync() -> bool:
    return _late

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
        if made.get("error",FAILED)!=ERR_BUSY:
            break
        OS.delay_msec(2)
    if made.get("error",FAILED)!=OK:
        _fail("fixture")
        return
    for cache in [9,16]:
        var order: Array[bool]=[false,true]
        if (cache==16)!=(format==1):
            order.reverse()
        for late in order:
            _late=late
            var result: Dictionary=await _case(made["directory"],format,7,cache,true)
            if result.get("error",FAILED)!=OK:
                _fail("F1 route "+str([format,cache,late])+" "+str(result))
                return
            print("F1_MOTION_COMPARE ",JSON.stringify({"format":format+1,"cache":cache,"after_sync":late,"metrics":result}))
    _builder.close()
    _builder=null
    print("PASS: paired F1 poll ordering, actual guarded capsule roundtrip, reversal, remote camera, caps and lease lifecycle")
    quit(0)

func _shard_limit() -> int:
    return 1
