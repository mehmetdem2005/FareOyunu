@tool
extends RefCounted
## Independent bounded wall clock attribution, not thread CPU time.
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
const LIMIT:int=8
const SLOW_US:int=8000
const STAGES:Array[String]=["io_accept","motion_expiry","sync_and_eviction","budget_setup","worker_reconcile","reconcile_error","critical_demand","lending_error","worker_delivery_publish","capacity_observe","pending_build_submit","post_submit_prune","publication_accounting","result_stats"]
const STOPS:Array[String]=["build_count","build_outer_time","delivery_count","delivery_outer_time"]
var _hist:Dictionary={}
var _stops:Dictionary={}
var _total=HIST.new()
var _residual=HIST.new()
var _pre_budget=HIST.new()
var _slow:Array[Dictionary]=[]
var _errors:int=0
var _invalid:int=0

func _init() -> void:
    for stage in STAGES:
        _hist[stage]=HIST.new()
    for reason in STOPS:
        _stops[reason]=0

static func begin(builds:int,pending:int,jobs:int) -> Dictionary:
    var now:int=Time.get_ticks_usec()
    return {"start_us":now,"last_us":now,"frame":Engine.get_process_frames(),"physics_tick":Engine.get_physics_frames(),"builds_before":builds,"pending_before":pending,"jobs_before":jobs,"stages_us":{},"stops":[]}

static func mark(event:Dictionary,stage:String) -> void:
    var now:int=Time.get_ticks_usec()
    event["stages_us"][stage]=now-int(event["last_us"])
    event["last_us"]=now

static func stop(event:Dictionary,reason:String) -> void:
    if not event["stops"].has(reason):
        event["stops"].append(reason)

func finish(event:Dictionary,status:Error,builds:int,budget_started:int) -> void:
    var elapsed:int=Time.get_ticks_usec()-int(event["start_us"])
    var pre:int=budget_started-int(event["start_us"]) if budget_started>0 else -1
    record(event,elapsed,status,builds,pre)

func record(event:Dictionary,total:int,status:Error,builds:int,pre:int) -> void:
    var stages:Dictionary=event["stages_us"]
    var summed:int=0
    for stage in stages:
        if not _hist.has(stage) or int(stages[stage])<0:
            _invalid+=1
            return
        summed+=int(stages[stage])
    for reason in event["stops"]:
        if not _stops.has(reason):
            _invalid+=1
            return
    if total<summed or builds<int(event["builds_before"]) or pre>total or pre< -1:
        _invalid+=1
        return
    for stage in stages:
        _hist[stage].add(float(stages[stage])/1000.0)
    for reason in event["stops"]:
        _stops[reason]+=1
    _total.add(float(total)/1000.0)
    _residual.add(float(total-summed)/1000.0)
    if pre>=0:
        _pre_budget.add(float(pre)/1000.0)
    if status!=OK:
        _errors+=1
    if total<SLOW_US or (_slow.size()>=LIMIT and total<=int(_slow.back()["total_us"])):
        return
    var item:Dictionary={"frame":event["frame"],"physics_tick":event["physics_tick"],"pending_before":event["pending_before"],"jobs_before":event["jobs_before"],"builds":builds-int(event["builds_before"]),"total_us":total,"pre_budget_us":pre,"residual_us":total-summed,"status":int(status),"stages_us":stages.duplicate(),"stops":event["stops"].duplicate()}
    var i:int=0
    while i<_slow.size() and int(_slow[i]["total_us"])>=total:
        i+=1
    _slow.insert(i,item)
    if _slow.size()>LIMIT:
        _slow.pop_back()

func report() -> Dictionary:
    var stages:Dictionary={}
    for stage in STAGES:
        stages[stage]=_hist[stage].report()
    return {"schema":"TF_PUMP_MICRO_1","wall_time_only":true,"total_ms":_total.report(),"pre_budget_ms":_pre_budget.report(),"residual_ms":_residual.report(),"stage_ms":stages,"outer_stops":_stops.duplicate(),"errors":_errors,"invalid_samples":_invalid,"slow_limit":LIMIT,"slow_threshold_us":SLOW_US,"slow_events":_slow.duplicate(true),"notes":"Stage wall times are inclusive; delivery/build include publication and scheduler waits. Outer stops are observed loop guard exits, not inner publication budget counters. Final recording overhead excluded. No GPU or CPU-only attribution."}
