@tool
extends RefCounted
## G1 session-owned base cache candidate. Main-thread owned; never share this
## mutable cache with workers. Caller supplies fresh verified source and
## authoritative snapshot token. Raw packed payload bound, not RSS or GPU.
const C=preload("res://addons/terra_forge/core/normal_edge_candidate.gd")
const W=preload("res://addons/terra_forge/core/geometry_worker.gd")
const MAX_ENTRIES: int=4
const MAX_BYTES: int=262144
var _snapshot: String=""
var _session: int=-1
var _entries: Dictionary={}
var _order: Array[Vector2i]=[]
var _bytes: int=0
var peak_bytes: int=0
var hits: int=0
var misses: int=0
var evictions: int=0

func begin(snapshot: String,session: int) -> Error:
    clear()
    if snapshot.is_empty() or session<0:
        return ERR_INVALID_PARAMETER
    _snapshot=snapshot
    _session=session
    return OK

func clear() -> void:
    _entries.clear()
    _order.clear()
    _bytes=0
    _snapshot=""
    _session=-1
    peak_bytes=0
    hits=0
    misses=0
    evictions=0

func report() -> Dictionary:
    return {"entries":_entries.size(),"bytes":_bytes,"peak_bytes":peak_bytes,"hits":hits,"misses":misses,"evictions":evictions}

static func payload(result: Dictionary) -> int:
    var a: Array=result.get("arrays",[])
    if a.size()!=Mesh.ARRAY_MAX:
        return -1
    if not a[Mesh.ARRAY_VERTEX] is PackedVector3Array or not a[Mesh.ARRAY_NORMAL] is PackedVector3Array or not a[Mesh.ARRAY_COLOR] is PackedColorArray or not a[Mesh.ARRAY_TEX_UV] is PackedVector2Array or not a[Mesh.ARRAY_INDEX] is PackedInt32Array or not result.get("collision_heights") is PackedFloat32Array:
        return -1
    for i in range(a.size()):
        if i not in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX] and a[i]!=null:
            return -1
    # Conservative Vector3/Vector2 double-size accounting across builds.
    return a[Mesh.ARRAY_VERTEX].size()*24+a[Mesh.ARRAY_NORMAL].size()*24+a[Mesh.ARRAY_COLOR].size()*16+a[Mesh.ARRAY_TEX_UV].size()*16+a[Mesh.ARRAY_INDEX].size()*4+result["collision_heights"].size()*4

func _drop(key: Vector2i) -> void:
    if _entries.has(key):
        _bytes-=int(_entries[key]["bytes"])
        _entries.erase(key)
        _order.erase(key)

func retain(snapshot: String,session: int,key: Vector2i,lod: int,spacing: float,cells: Vector2i,desired: Dictionary,result: Dictionary) -> Error:
    if _session<0 or snapshot!=_snapshot or session!=_session or not is_finite(spacing) or spacing<=0.0 or result.get("error",FAILED)!=OK:
        return ERR_INVALID_PARAMETER
    var signature: Dictionary=W.signature(key,lod,desired,cells)
    if signature.get("error",FAILED)!=OK:
        return ERR_INVALID_PARAMETER
    var bytes: int=payload(result)
    if bytes<=0 or bytes>MAX_BYTES:
        return ERR_INVALID_DATA
    _drop(key)
    while _entries.size()>=MAX_ENTRIES or _bytes+bytes>MAX_BYTES:
        if _order.is_empty():
            return ERR_BUG
        _drop(_order[0])
        evictions+=1
    # Store only whitelisted geometry, owned copies; no node or resource.
    var owned: Dictionary={"error":OK,"arrays":result["arrays"].duplicate(true),"collision_heights":result["collision_heights"].duplicate(),"width":result["width"],"vertex_count":result["vertex_count"]}
    _entries[key]={"lod":lod,"spacing":spacing,"cells":cells,"levels":signature["levels"].duplicate(),"desired":desired.duplicate(),"geometry":owned,"bytes":bytes}
    _order.append(key)
    _bytes+=bytes
    peak_bytes=maxi(peak_bytes,_bytes)
    return OK

func patch(snapshot: String,session: int,source,key: Vector2i,lod: int,after: Dictionary) -> Dictionary:
    if _session<0 or snapshot!=_snapshot or session!=_session or source==null or not source.is_open() or not _entries.has(key):
        misses+=1
        return {"error":ERR_UNAVAILABLE}
    var e: Dictionary=_entries[key]
    if lod!=e["lod"] or source.spacing!=e["spacing"] or source.cells!=e["cells"]:
        misses+=1
        return {"error":ERR_UNAVAILABLE}
    var result: Dictionary=C.patch(source,key,lod,e["desired"],after,e["geometry"])
    if result.get("error",FAILED)!=OK:
        misses+=1
        return result
    hits+=1
    _order.erase(key)
    _order.append(key)
    return result
