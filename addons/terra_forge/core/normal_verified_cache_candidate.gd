@tool
extends RefCounted
## Isolated G1 adapter. Bind actual verified reader object + monotonic open
## serial, not a caller-provided string. Main thread only; not runtime wired.
const R=preload("res://addons/terra_forge/core/async_region_source.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const K=preload("res://addons/terra_forge/core/normal_base_cache_candidate.gd")
var _reader_ref: WeakRef
var _serial: int=-1
var _token: String=""
var _cache=K.new()

func clear() -> void:
    _cache.clear()
    _reader_ref=null
    _serial=-1
    _token=""

func begin(reader) -> Error:
    clear()
    if not reader is R or not reader.is_open():
        return ERR_INVALID_PARAMETER
    _reader_ref=weakref(reader)
    _serial=reader.session_serial()
    # TFM1 has no snapshot digest in stats. Exact object + open serial
    # still distinguishes immutable manifest sessions. TFM2 also pins root.
    _token=str(reader.get_instance_id())+":"+str(_serial)+":"+str(reader.stats()["snapshot_id"])
    return _cache.begin(_token,_serial)

func _matches(reader) -> bool:
    return _reader_ref!=null and reader is R and _reader_ref.get_ref()==reader and reader.is_open() and reader.session_serial()==_serial

func retain(reader,key: Vector2i,lod: int,desired: Dictionary) -> Error:
    if not _matches(reader):
        return ERR_UNAVAILABLE
    # Do not accept arbitrary caller-owned base arrays: generate from
    # the bound reader's currently SHA-verified resident pages.
    var base: Dictionary=G.generate(reader,key.x,key.y,lod,desired)
    if base.get("error",FAILED)!=OK:
        return int(base.get("error",FAILED))
    return _cache.retain(_token,_serial,key,lod,reader.spacing,reader.cells,desired,base)

func patch(reader,key: Vector2i,lod: int,desired: Dictionary) -> Dictionary:
    if not _matches(reader):
        return {"error":ERR_UNAVAILABLE}
    return _cache.patch(_token,_serial,reader,key,lod,desired)

func report() -> Dictionary:
    return _cache.report()
