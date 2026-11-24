extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const EQUAL=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")

func _initialize() -> void:
    print("WORKER_COMPARE_ENV ",JSON.stringify({"cpu":OS.get_processor_name(),"os":OS.get_name(),"godot":Engine.get_version_info().get("string",""),"notes":"off-tree real resources; equal warm resident work separate from fixed 144-pump async trace; no GPU/raycast; ABBA per group"}))
    for format in [0,1]:
        var b: Variant=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start",b)
            return
        var made: Dictionary={}
        var deadline: int=Time.get_ticks_msec()+30000
        while Time.get_ticks_msec()<deadline:
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture",b)
            return
        var folder: String=made["directory"]
        var reference: Dictionary={}
        for cap in [1,2,4]:
            for repeat in range(4):
                var mode: int=2 if repeat==0 or repeat==3 else 3
                var result: Dictionary=EQUAL.run(folder,format,mode,cap)
                if result.get("error",FAILED)!=OK:
                    _fail("equal "+str(result),b)
                    return
                if not reference.is_empty() and result["fingerprints"]!=reference:
                    _fail("cross-mode fingerprints",b)
                    return
                reference=result["fingerprints"]
                result["pair_cap"]=cap
                result["order"]=repeat
                print("WORKER_EQUAL_CASE ",JSON.stringify(result))
        # Fixed step comparison is intentionally not equal completed work.
        for cache in [9,16]:
            for cap in [1,2,4]:
                for repeat in range(4):
                    var mode: int=2 if repeat==0 or repeat==3 else 3
                    var result: Dictionary=TRACE.run(folder,format,mode,cache,cap)
                    if result.get("error",FAILED)!=OK:
                        _fail("trace "+str(result),b)
                        return
                    result["pair_cap"]=cap
                    result["order"]=repeat
                    print("WORKER_TRACE_CASE ",JSON.stringify(result))
        b.close()
    print("PASS: equal C/E completed resource fingerprints, cap1/2/4, no duplicate work, in-flight close and repeated fixed streaming traces")
    quit(0)

func _fail(msg: String,b) -> void:
    b.close()
    push_error("Worker comparison: "+msg)
    quit(1)
