extends "res://addons/terra_forge/tests/test_f2_long_shadow_v1.gd"
## Test-only closed-loop experiment: temporarily choose a horizon for the
## actual sample call; restore the reference controller immediately.
## All loading, support, movement and hard caps remain production paths.
var _candidate: bool=false
var _applied: int=0
var _changed: int=0
var _horizon_sum: float=0.0

func _sample_motion(from: Vector2,actual: Vector2,intent: Vector2,session: int,revision: int) -> Error:
    var old: float=_p._motion_latency.horizon
    var chosen: float=old
    if intent.length_squared()>=0.0001:
        var plan: Dictionary=FOOT.plan(from,from+intent*0.5,RADIUS,_p.world_extent(),32.0)
        if plan["ready"] and plan["tiles"].size() in [1,2,4]:
            var rec: Dictionary=_q.recommend(plan["tiles"].size(),Engine.physics_ticks_per_second,old)
            if rec.get("error",FAILED)==OK and rec["qualified"]:
                _applied+=1
                if _candidate:
                    chosen=float(rec["horizon"])
                _changed+=int(not is_equal_approx(chosen,old))
                _horizon_sum+=chosen
    _p._motion_latency.horizon=chosen
    var status: Error=super._sample_motion(from,actual,intent,session,revision)
    _p._motion_latency.horizon=old
    return status

func _run() -> void:
    var format: int=_format()
    _builder=V1.new() if format==0 else V2.new()
    var err: Error=_builder.start(Vector2i(576,576),true) if format==0 else _builder.start(Vector2i(576,576))
    if err!=OK:
        _fail("paired fixture start")
        return
    var made: Dictionary={}
    for attempt in range(15000):
        made=_builder.take_result()
        if made["error"]!=ERR_BUSY:
            break
        OS.delay_msec(2)
    if made.get("error",FAILED)!=OK:
        _fail("paired fixture")
        return
    # One paired cache condition per format keeps within the 90s script
    # timeout. Counterbalance arm order between formats; not ABBA repeats.
    var order: Array[bool]=[false,true]
    if format!=0:
        order.reverse()
    var arms: Array[Dictionary]=[]
    for candidate in order:
        _candidate=candidate
        _q=Q.new()
        _watch.clear()
        _counts={"probes":0,"already_ready":0,"started":0,"resolved":0,"cancelled":0,"cancel_reasons":{},"untracked":0,"invalid":0,"max_ticks":0,"size_1":0,"size_2":0,"size_4":0,"qualified":0,"old_short":0,"new_short":0,"old_horizon_sum":0.0,"new_horizon_sum":0.0}
        _applied=0
        _changed=0
        _horizon_sum=0.0
        var result: Dictionary=await _case(made["directory"],format,7,9,true)
        if result.get("error",FAILED)!=OK or _counts["invalid"]!=0 or _counts["started"]!=_counts["resolved"]+_counts["cancelled"]+int(not _watch.is_empty()):
            _fail("paired arm "+str(result)+" "+str(_counts))
            return
        var record: Dictionary={"candidate":candidate,"format":format+1,"cache":9,"qualified_calls":_applied,"changed_calls":_changed,"mean_qualified_horizon":_horizon_sum/maxi(1,_applied),"counts":_counts.duplicate(true),"metrics":result,"unresolved":int(not _watch.is_empty())}
        arms.append(record)
        print("F2_PAIRED_POLICY ",JSON.stringify(record))
    if arms.size()!=2 or arms[0]["metrics"]["completed_laps"]!=arms[1]["metrics"]["completed_laps"]:
        _fail("paired route mismatch")
        return
    _builder.close()
    _builder=null
    print("PASS: F2 paired actual horizon selection, matched routes and existing physics bounds; qualification and net gain must be reviewed separately")
    quit(0)
