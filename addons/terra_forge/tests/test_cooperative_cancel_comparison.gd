extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")

func _initialize() -> void:
    for format in [0,1]:
        var b: Variant=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail(b,"fixture start")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail(b,"fixture")
            return
        for backend in [4,6]:
            for cap in [1,2]:
                var reference: Dictionary={}
                var order: Array[bool]=[false,true,true,false] if (format+backend+cap)%2==0 else [true,false,false,true]
                for trial in range(4):
                    var policy: Dictionary={"scalar":backend==6,"topology":backend==6,"crop":true,"cancel":order[trial]}
                    var result: Dictionary=EQ.run(made["directory"],format,7,cap,{},false,false,policy)
                    if result.get("error",FAILED)!=OK or result["completed"]!=32 or (not reference.is_empty() and result["fingerprints"]!=reference):
                        _fail(b,"equal work "+str(result))
                        return
                    reference=result["fingerprints"]
                    var w: Dictionary=result["worker"]
                    if w["submitted"]!=36 or w["delivered"]!=36 or w["dropped"]!=0 or w["slots"]!=0 or w["cooperative_cancel"]["enabled"]!=order[trial] or (w["cooperative_cancel"]["checks"]>0)!=order[trial] or w["cooperative_cancel"]["aborted"]!=0:
                        _fail(b,"equal accounting")
                        return
                    result["trial"]=trial
                    print("CANCEL_EQUAL_WORK ",JSON.stringify(result))
            for cache in [9,16]:
                var order: Array[bool]=[false,true,true,false] if (format+cache)%2==0 else [true,false,false,true]
                for trial in range(4):
                    var policy: Dictionary={"scalar":backend==6,"topology":backend==6,"crop":true,"cancel":order[trial]}
                    var result: Dictionary=TRACE.run(made["directory"],format,7,cache,2,8000,false,policy)
                    if result.get("error",FAILED)!=OK:
                        _fail(b,"camera trace "+str(result))
                        return
                    var w: Dictionary=result["geometry_worker"]
                    if w["submitted"]!=w["delivered"]+w["dropped"]+w["slots"] or w["discard_accounting"]["classified"]!=w["dropped"] or w["cooperative_cancel"]["enabled"]!=order[trial]:
                        _fail(b,"trace ownership")
                        return
                    result["trial"]=trial
                    result["backend"]=backend
                    print("CANCEL_CAMERA_WORK ",JSON.stringify(result))
        b.close()
    print("PASS: cancel on/off 32 equal-work arms (1024 measured tiles), 32 matched camera traces, exact parity and accounting; timing diagnostic only")
    quit(0)

func _fail(b,msg: String) -> void:
    b.close()
    push_error("Cancel comparison: "+msg)
    quit(1)
