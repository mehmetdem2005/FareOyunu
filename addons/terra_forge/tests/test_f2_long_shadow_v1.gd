extends "res://addons/terra_forge/tests/f2_long_motion_base.gd"
const Q=preload("res://addons/terra_forge/core/readiness_horizon_candidate.gd")
var _q
var _watch: Dictionary={}
var _counts: Dictionary={}

func _format() -> int:
    return 0

func _shard_limit() -> int:
    return 1

func _roundtrip_laps() -> int:
    return 4

func _cancel_watch(reason: String) -> void:
    if _watch.is_empty():
        return
    _counts["cancelled"]+=1
    var reasons: Dictionary=_counts["cancel_reasons"]
    reasons[reason]=int(reasons.get(reason,0))+1
    _watch.clear()

func _f2_shadow_tick(from: Vector2,intent: Vector2,tick: int) -> void:
    if intent.length_squared()<0.0001:
        _cancel_watch("stationary_intent")
        return
    var finish: Vector2=from+intent*0.5
    var plan: Dictionary=FOOT.plan(from,finish,RADIUS,_p.world_extent(),32.0)
    if not plan["ready"] or plan["tiles"].size() not in [1,2,4]:
        _cancel_watch("unsupported_footprint")
        _counts["untracked"]+=1
        return
    var size: int=plan["tiles"].size()
    var generation: int=_p._reader.stats()["generation"]
    if not _watch.is_empty():
        var generation_changed: bool=_watch["generation"]!=generation
        var footprint_changed: bool=_watch["tiles"]!=plan["tiles"]
        var reversed: bool=Vector2(_watch["direction"]).dot(intent)<0.0
        if generation_changed or footprint_changed or reversed:
            _cancel_watch("generation" if generation_changed else ("reversal" if reversed else "footprint_change"))
    var exclude: Array[RID]=[_body.get_rid()]
    var verdict: Dictionary=_p.inspect_collision_footprint(from,finish,RADIUS,exclude)
    _counts["probes"]+=1
    if _watch.is_empty():
        if verdict["ready"]:
            _counts["already_ready"]+=1
            return
        var old: float=_p.motion_prefetch_state()["latency"]["horizon_seconds"]
        var rec: Dictionary=_q.recommend(size,Engine.physics_ticks_per_second,old)
        if rec["error"]!=OK:
            _counts["invalid"]+=1
            return
        _watch={"tiles":plan["tiles"].duplicate(),"generation":generation,"tick":tick,"old":old,"rec":rec,"direction":intent.normalized()}
        _counts["started"]+=1
        return
    if not verdict["ready"]:
        return
    var elapsed: int=tick-int(_watch["tick"])
    var rec: Dictionary=_watch["rec"]
    var seconds: float=float(elapsed)/float(Engine.physics_ticks_per_second)
    _counts["resolved"]+=1
    _counts["max_ticks"]=maxi(_counts["max_ticks"],elapsed)
    _counts["size_"+str(size)]+=1
    if rec["qualified"]:
        _counts["qualified"]+=1
        _counts["old_short"]+=int(float(_watch["old"])+0.000001<seconds)
        _counts["new_short"]+=int(float(rec["horizon"])+0.000001<seconds)
        _counts["old_horizon_sum"]+=float(_watch["old"])
        _counts["new_horizon_sum"]+=float(rec["horizon"])
    if _q.observe(size,elapsed,Engine.physics_ticks_per_second)!=OK:
        _counts["invalid"]+=1
    _watch.clear()

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
        _q=Q.new()
        _watch.clear()
        _counts={"probes":0,"already_ready":0,"started":0,"resolved":0,"cancelled":0,"cancel_reasons":{},"untracked":0,"invalid":0,"max_ticks":0,"size_1":0,"size_2":0,"size_4":0,"qualified":0,"old_short":0,"new_short":0,"old_horizon_sum":0.0,"new_horizon_sum":0.0}
        var result: Dictionary=await _case(made["directory"],format,7,cache,true)
        if result.get("error",FAILED)!=OK or _counts["invalid"]!=0 or _counts["started"]!=_counts["resolved"]+_counts["cancelled"]+int(not _watch.is_empty()) or _counts["probes"]<=0:
            _fail("live shadow "+str(result)+" "+str(_counts))
            return
        var classified: int=0
        for value in _counts["cancel_reasons"].values():
            classified+=int(value)
        if classified!=_counts["cancelled"] or result["completed_laps"]!=4:
            _fail("cancellation or laps accounting")
            return
        print("F2_LONG_SHADOW ",JSON.stringify({"format":format+1,"cache":cache,"counts":_counts,"unresolved":int(not _watch.is_empty()),"return_tick":result["return_tick"],"laps":result["completed_laps"],"ticks":result["ticks"],"qualified_evidence":_counts["qualified"]>=4,"denied":result["denied_ticks"],"missing_rays":result["missing_rays"],"note":"Fixed 0.5s swept footprint sampled guard; current runtime unchanged; extra probe overhead; no causal performance claim"}))
    _builder.close()
    _builder=null
    print("PASS: F2 four same-session laps, classified cancellations and observation accounting; qualification reported separately")
    quit(0)
