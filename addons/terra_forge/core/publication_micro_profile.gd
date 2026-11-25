@tool
extends RefCounted
## Optional main-thread wall-clock observations. No CPU/GPU attribution.
## Fixed histograms; at most 8 slow events, never a per-frame log.
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
const LIMIT: int=8
const SLOW_US: int=8000
const STAGES: Array[String]=["validate","root_allocate","root_attach","visual_allocate","visual_attach","body_allocate","body_attach","collision_node_allocate","collision_node_attach","tile_lookup","mesh_create_surface","mesh_assign","shape_compare_reuse","shape_create_data","shape_assign_release","metadata_signature","bookkeeping","accounting"]
var _h: Dictionary={}
var _total=HIST.new()
var _residual=HIST.new()
var _slow: Array[Dictionary]=[]
var _success: int=0
var _failed: int=0
var _invalid: int=0

func _init() -> void:
    for stage in STAGES:
        _h[stage]=HIST.new()

static func begin(key: Vector2i,lod: int,fresh: bool) -> Dictionary:
    var now: int=Time.get_ticks_usec()
    return {"key":[key.x,key.y],"lod":lod,"new_tile":fresh,"frame":Engine.get_process_frames(),"physics_tick":Engine.get_physics_frames(),"start_us":now,"last_us":now,"stages_us":{}}

static func mark(event: Dictionary,stage: String) -> void:
    var now: int=Time.get_ticks_usec()
    event["stages_us"][stage]=now-int(event["last_us"])
    event["last_us"]=now

func finish(event: Dictionary,status: Error,source_bytes: int) -> void:
    var total: int=Time.get_ticks_usec()-int(event["start_us"])
    record(event,total,status,source_bytes)

## Explicit duration input supports deterministic tests.
func record(event: Dictionary,total: int,status: Error,source_bytes: int) -> void:
    var stages: Dictionary=event["stages_us"]
    var summed: int=0
    for stage in stages:
        if not _h.has(stage) or int(stages[stage])<0:
            _invalid+=1
            return
        summed+=int(stages[stage])
    if total<summed or source_bytes<0:
        _invalid+=1
        return
    for stage in stages:
        _h[stage].add(float(stages[stage])/1000.0)
    _total.add(float(total)/1000.0)
    _residual.add(float(total-summed)/1000.0)
    if status==OK:
        _success+=1
    else:
        _failed+=1
    if total<SLOW_US or (_slow.size()>=LIMIT and total<=int(_slow.back()["total_us"])):
        return
    var entry: Dictionary={"key":event["key"],"lod":event["lod"],"new_tile":event["new_tile"],"frame":event["frame"],"physics_tick":event["physics_tick"],"total_us":total,"residual_us":total-summed,"stages_us":stages.duplicate(),"status":int(status),"source_bytes":source_bytes}
    var i: int=0
    while i<_slow.size() and int(_slow[i]["total_us"])>=total:
        i+=1
    _slow.insert(i,entry)
    if _slow.size()>LIMIT:
        _slow.pop_back()

func report() -> Dictionary:
    var hist: Dictionary={}
    for stage in STAGES:
        hist[stage]=_h[stage].report()
    return {"schema":"TF_PUBLICATION_MICRO_1","wall_time_only":true,"gpu_time_ms":null,"success":_success,"failed":_failed,"invalid_samples":_invalid,"total_ms":_total.report(),"residual_ms":_residual.report(),"stage_ms":hist,"slow_threshold_us":SLOW_US,"slow_limit":LIMIT,"slow_events":_slow.duplicate(true),"notes":"Contiguous stage wall time includes instrumentation and scheduler waits. Assignment can release old resources; no isolated driver or deallocation timing. Residual excludes final record cost. Top events only."}
