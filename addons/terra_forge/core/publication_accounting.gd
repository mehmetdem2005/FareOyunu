@tool
extends RefCounted
## CPU source-array accounting, not renderer memory, driver upload bytes,
## GPU time, allocator overhead or actual draw calls. Vector allowances
## support both single and double precision engine builds.
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
const BYTE_TARGET: int=131072
const TIME_TARGET_US: int=1000
var _mesh=HIST.new()
var _shape=HIST.new()
var _publish=HIST.new()
var _pump_hist=HIST.new()
var _count: int=0
var _mesh_bytes: int=0
var _shape_bytes: int=0
var _triangles: int=0
var _lod_counts: Array[int]=[0,0,0]
var _pump_open: bool=false
var _pump_count: int=0
var _pump_bytes: int=0
var _pump_us: int=0
var _count_target: int=1
var _byte_target: int=BYTE_TARGET
var _time_target_us: int=TIME_TARGET_US
var _budget_enabled: bool=false
var _byte_deferrals: int=0
var _time_stops: int=0
var _count_stops: int=0
var _first_item_byte_exceptions: int=0
var _pumps: int=0
var _active_pumps: int=0
var _peak_count: int=0
var _peak_bytes: int=0
var _peak_us: int=0
var _over_bytes: int=0
var _over_time: int=0
var _over_count: int=0
var _max_byte_excess: int=0
var _max_time_excess_us: int=0
var _peak_resident_bytes: int=0
var _peak_resident_triangles: int=0
var _peak_resident_meshes: int=0
var _peak_resident_shapes: int=0

static func expected(lod: int) -> Dictionary:
    if lod<0 or lod>2:
        return {"error":ERR_INVALID_PARAMETER}
    var side: int=32>>lod
    var vertices: int=(side+1)*(side+1)
    var triangles: int=side*side*2
    var mesh_bytes: int=vertices*80+triangles*3*4
    var shape_bytes: int=vertices*4 if lod==0 else 0
    return {"error":OK,"vertices":vertices,"triangles":triangles,"mesh_bytes":mesh_bytes,"shape_bytes":shape_bytes,"total_bytes":mesh_bytes+shape_bytes,"meshes":1,"shapes":1 if lod==0 else 0}

## Check exact array kinds/counts, including unsupported channels. No scan
## of all samples/indices here: verified geometry builder owns validity.
static func describe(generated: Dictionary,lod: int) -> Dictionary:
    var e: Dictionary=expected(lod)
    if e["error"]!=OK:
        return e
    if generated.get("error",FAILED)!=OK:
        return {"error":int(generated.get("error",FAILED))}
    var arrays: Variant=generated.get("arrays")
    var heights: Variant=generated.get("collision_heights")
    if not arrays is Array or arrays.size()!=Mesh.ARRAY_MAX or not heights is PackedFloat32Array:
        return {"error":ERR_INVALID_DATA}
    if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array or not arrays[Mesh.ARRAY_COLOR] is PackedColorArray or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
        return {"error":ERR_INVALID_DATA}
    var n: int=arrays[Mesh.ARRAY_VERTEX].size()
    if n!=e["vertices"] or generated.get("vertex_count",-1)!=n or generated.get("width",-1)!=(32>>lod)+1 or arrays[Mesh.ARRAY_NORMAL].size()!=n or arrays[Mesh.ARRAY_TEX_UV].size()!=n or arrays[Mesh.ARRAY_COLOR].size()!=n or arrays[Mesh.ARRAY_INDEX].size()!=e["triangles"]*3 or heights.size()*4!=e["shape_bytes"]:
        return {"error":ERR_INVALID_DATA}
    for i in range(Mesh.ARRAY_MAX):
        if i not in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR,Mesh.ARRAY_INDEX] and arrays[i]!=null:
            return {"error":ERR_INVALID_DATA}
    return e

func configure_budget(enabled: bool,byte_target: int=BYTE_TARGET,time_target_us: int=TIME_TARGET_US) -> void:
    _budget_enabled=enabled
    _byte_target=byte_target
    _time_target_us=time_target_us

## -1: unlimited/first-item progress; 0: stop; positive: remaining allowance.
## Time is already measured publication work, not a prediction or hard cap.
func admission_bytes() -> int:
    if not _budget_enabled or not _pump_open or _pump_count==0:
        return -1
    if _pump_count>=_count_target:
        _count_stops+=1
        return 0
    if _pump_us>=_time_target_us:
        _time_stops+=1
        return 0
    if _pump_bytes>=_byte_target:
        _byte_deferrals+=1
        return 0
    return _byte_target-_pump_bytes

func note_byte_deferral() -> void:
    _byte_deferrals+=1

func admit(lod: int) -> bool:
    var remaining: int=admission_bytes()
    if remaining<0:
        return true
    if remaining==0:
        return false
    if int(expected(lod)["total_bytes"])>remaining:
        note_byte_deferral()
        return false
    return true

func begin_pump(count_target: int) -> void:
    _pump_open=true
    _pump_count=0
    _pump_bytes=0
    _pump_us=0
    _count_target=maxi(1,count_target)

func record(lod: int,info: Dictionary,mesh_us: int,shape_us: int,publish_us: int) -> void:
    _count+=1
    _lod_counts[lod]+=1
    _mesh_bytes+=int(info["mesh_bytes"])
    _shape_bytes+=int(info["shape_bytes"])
    _triangles+=int(info["triangles"])
    _mesh.add(float(mesh_us)/1000.0)
    _shape.add(float(shape_us)/1000.0)
    _publish.add(float(publish_us)/1000.0)
    if _pump_open:
        if _budget_enabled and _pump_count==0 and int(info["total_bytes"])>_byte_target:
            _first_item_byte_exceptions+=1
        _pump_count+=1
        _pump_bytes+=int(info["total_bytes"])
        _pump_us+=publish_us

func end_pump(resident: Dictionary) -> void:
    if not _pump_open:
        return
    _pump_open=false
    _pumps+=1
    if _pump_count>0:
        _active_pumps+=1
    _pump_hist.add(float(_pump_us)/1000.0)
    _peak_count=maxi(_peak_count,_pump_count)
    _peak_bytes=maxi(_peak_bytes,_pump_bytes)
    _peak_us=maxi(_peak_us,_pump_us)
    if _pump_bytes>_byte_target:
        _over_bytes+=1
        _max_byte_excess=maxi(_max_byte_excess,_pump_bytes-_byte_target)
    if _pump_us>_time_target_us:
        _over_time+=1
        _max_time_excess_us=maxi(_max_time_excess_us,_pump_us-_time_target_us)
    if _pump_count>_count_target:
        _over_count+=1
    _peak_resident_bytes=maxi(_peak_resident_bytes,int(resident["total_bytes"]))
    _peak_resident_triangles=maxi(_peak_resident_triangles,int(resident["triangles"]))
    _peak_resident_meshes=maxi(_peak_resident_meshes,int(resident["meshes"]))
    _peak_resident_shapes=maxi(_peak_resident_shapes,int(resident["shapes"]))

func report(resident: Dictionary) -> Dictionary:
    return {"schema":"TF_PUBLICATION_1","source_array_allowance_only":true,"gpu_time_ms":null,"gpu_resident_bytes":null,"publication_count":_count,"lod_counts":_lod_counts.duplicate(),"mesh_source_bytes":_mesh_bytes,"shape_source_bytes":_shape_bytes,"total_source_bytes":_mesh_bytes+_shape_bytes,"published_triangles":_triangles,"mesh_main_ms":_mesh.report(),"shape_main_ms":_shape.report(),"publish_main_ms":_publish.report(),"pump_publish_main_ms":_pump_hist.report(),"pumps":_pumps,"active_pumps":_active_pumps,"peak_pump_count":_peak_count,"peak_pump_source_bytes":_peak_bytes,"peak_pump_publish_us":_peak_us,"budget_enabled":_budget_enabled,"observation_byte_target":_byte_target,"observation_time_target_us":_time_target_us,"byte_deferral_checks":_byte_deferrals,"time_stop_checks":_time_stops,"count_stop_checks":_count_stops,"first_item_byte_exceptions":_first_item_byte_exceptions,"over_byte_pumps":_over_bytes,"over_time_pumps":_over_time,"over_count_pumps":_over_count,"max_byte_excess":_max_byte_excess,"max_time_excess_us":_max_time_excess_us,"resident":resident,"peak_end_pump_resident_source_bytes":_peak_resident_bytes,"peak_end_pump_resident_triangles":_peak_resident_triangles,"peak_end_pump_resident_meshes":_peak_resident_meshes,"peak_end_pump_resident_shapes":_peak_resident_shapes}
