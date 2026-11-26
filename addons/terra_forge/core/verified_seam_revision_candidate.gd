@tool
extends RefCounted
## Diagnostic single-use revision. No cache across camera positions.
## Base generated internally from verified reader, not lossy mesh readback.
const R=preload("res://addons/terra_forge/core/async_region_source.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const W=preload("res://addons/terra_forge/core/geometry_worker.gd")
const C=preload("res://addons/terra_forge/core/seam_patch_candidate.gd")
const A=preload("res://addons/terra_forge/core/normal_base_cache_candidate.gd")
var _reader: WeakRef
var _serial: int=-1
var _epoch: int=-1
var _snapshot: String=""
var _key: Vector2i
var _lod: int=-1
var _before: Dictionary={}
var _base: Dictionary={}

func clear() -> void:
    _reader=null
    _serial=-1
    _epoch=-1
    _snapshot=""
    _lod=-1
    _before.clear()
    _base={}

func begin(reader,key: Vector2i,lod: int,before: Dictionary) -> Error:
    clear()
    if not reader is R or not reader.is_open():
        return ERR_INVALID_PARAMETER
    var sig: Dictionary=W.signature(key,lod,before,reader.cells)
    if sig["error"]!=OK:
        return ERR_INVALID_PARAMETER
    var base: Dictionary=G.generate(reader,key.x,key.y,lod,sig["desired"])
    if base.get("error",FAILED)!=OK:
        return int(base.get("error",FAILED))
    if A.payload(base)>131072:
        return ERR_INVALID_DATA
    var stats: Dictionary=reader.stats()
    _reader=weakref(reader)
    _serial=reader.session_serial()
    _epoch=stats["generation"]
    _snapshot=stats["snapshot_id"]
    _key=key
    _lod=lod
    _before=sig["desired"]
    _base=base
    return OK

func patch(reader,after: Dictionary) -> Dictionary:
    if _reader==null or not reader is R or _reader.get_ref()!=reader or not reader.is_open() or reader.session_serial()!=_serial:
        clear()
        return {"error":ERR_UNAVAILABLE}
    var stats: Dictionary=reader.stats()
    if stats["generation"]!=_epoch or stats["snapshot_id"]!=_snapshot:
        clear()
        return {"error":ERR_UNAVAILABLE}
    var result: Dictionary=C.patch(reader,_key,_lod,_before,after,_base)
    clear()
    return result

func retained_bytes() -> int:
    return 0 if _base.is_empty() else A.payload(_base)
