extends "res://addons/terra_forge/tests/test_h0_combined_controllers.gd"
## Matched relative injected pressure for 30/60 targets, actual stationary
## support, a 12-sample active recovery gap and manual override.
func _run() -> void:
    var format: int=_format()
    _builder=V1.new() if format==0 else V2.new()
    var err: Error=_builder.start(Vector2i(576,576),true) if format==0 else _builder.start(Vector2i(576,576))
    if err!=OK:
        _fail("M8 fixture")
        return
    var made: Dictionary={}
    for attempt in range(15000):
        made=_builder.take_result()
        if made["error"]!=ERR_BUSY:
            break
        OS.delay_msec(2)
    if made.get("error",FAILED)!=OK:
        _fail("M8 fixture result")
        return
    var directory: String=made["directory"]
    var manifest: String=directory.path_join("manifest.tfm" if format==0 else "manifest.tfm2")
    var hash: String=FileAccess.get_sha256(manifest)
    var order: Array[int]=[30,60]
    if format==1:
        order.reverse()
    var reference: Array=[]
    for target in order:
        var result: Dictionary=await _case(directory,format,5,target,true)
        if result.get("error",FAILED)!=OK or result.get("target_fps",0)!=target or result["skipped_pressure_samples"]!=12 or result["missing_rays"]!=0 or result["airborne_ticks"]!=0 or result["peak_ground_height_delta"]>0.0001:
            _fail("M8 "+str([format,target,result]))
            return
        var checkpoints: Array=[]
        for point in result["checkpoints"]:
            checkpoints.append([point["tick"],point["tier"],point["near"],point["far"]])
        if not reference.is_empty() and checkpoints!=reference:
            _fail("M8 normalized target parity "+str(checkpoints))
            return
        reference=checkpoints
        print("M8_TARGET_TRACE ",JSON.stringify({"format":format+1,"target_fps":target,"metrics":result,"note":"Injected relative pressure, no actual frame-rate target attainment; stationary real floor, missing pressure observations not OS lifecycle."}))
    if hash.is_empty() or FileAccess.get_sha256(manifest)!=hash:
        _fail("M8 source changed")
        return
    _builder.close()
    _builder=null
    print("PASS: M8 target-normalized adaptive quality and actual support")
    quit(0)
