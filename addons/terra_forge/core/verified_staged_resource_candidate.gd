@tool
extends RefCounted
## E2 isolated authority adapter. Derive geometry from actual verified reader;
## recheck reader session/epoch, requested signature and target resources
## at each stage. Does not accept arbitrary caller result or token.
const S=preload("res://addons/terra_forge/core/staged_resource_candidate.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const W=preload("res://addons/terra_forge/core/geometry_worker.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
var _stage=S.new()
var _preview: WeakRef
var _reader: WeakRef
var _key: Vector2i
var _lod: int=-1
var _serial: int=-1
var _epoch: int=-1
var _snapshot: String=""
var _levels: Array=[]
var _visual: WeakRef
var _collision: WeakRef
var _old_mesh: Mesh
var _old_shape: Shape3D
var _identity: String=""

func cancel() -> void:
    _stage.cancel()
    _preview=null
    _reader=null
    _visual=null
    _collision=null
    _old_mesh=null
    _old_shape=null
    _identity=""
    _levels=[]
    _lod=-1

func begin(p,key: Vector2i,lod: int) -> Error:
    if _stage.report()["slots"]!=0:
        return ERR_BUSY
    if not p is P or p._reader==null or not p._reader.is_open() or not p._tiles.has(key):
        return ERR_INVALID_PARAMETER
    var reader=p._reader
    var sig: Dictionary=W.signature(key,lod,p._desired_tiles,reader.cells)
    if sig["error"]!=OK:
        return ERR_INVALID_PARAMETER
    var tile: Dictionary=p._tiles[key]
    var generated: Dictionary=G.generate(reader,key.x,key.y,lod,sig["desired"])
    if generated.get("error",FAILED)!=OK:
        return int(generated.get("error",FAILED))
    _preview=weakref(p)
    _reader=weakref(reader)
    _key=key
    _lod=lod
    _serial=reader.session_serial()
    var stats: Dictionary=reader.stats()
    _epoch=stats["generation"]
    _snapshot=stats["snapshot_id"]
    _levels=sig["levels"].duplicate()
    _visual=weakref(tile["visual"])
    _collision=weakref(tile["collision"])
    _old_mesh=tile["visual"].mesh
    _old_shape=tile["collision"].shape
    _identity=str(reader.get_instance_id())+":"+str(_serial)+":"+str(_epoch)+":"+str(key)+":"+str(_levels)
    var status: Error=_stage.stage_mesh(_identity,generated,lod)
    if status!=OK:
        cancel()
    return status

func _valid() -> bool:
    if _preview==null or _reader==null or _visual==null or _collision==null:
        return false
    var p=_preview.get_ref()
    var reader=_reader.get_ref()
    if p==null or reader==null or p._reader!=reader or not reader.is_open() or reader.session_serial()!=_serial or not p._tiles.has(_key) or p._blocked_tiles.has(_key):
        return false
    var stats: Dictionary=reader.stats()
    if stats["generation"]!=_epoch or stats["snapshot_id"]!=_snapshot:
        return false
    var sig: Dictionary=W.signature(_key,_lod,p._desired_tiles,reader.cells)
    if sig["error"]!=OK or sig["levels"]!=_levels:
        return false
    var tile: Dictionary=p._tiles[_key]
    return tile["visual"]==_visual.get_ref() and tile["collision"]==_collision.get_ref() and tile["visual"].mesh==_old_mesh and tile["collision"].shape==_old_shape

func prepare_shape() -> Error:
    if not _valid():
        cancel()
        return ERR_UNAVAILABLE
    return _stage.stage_shape(_identity)

func commit() -> Error:
    if not _valid():
        cancel()
        return ERR_UNAVAILABLE
    var status: Error=_stage.commit(_identity,_visual.get_ref(),_collision.get_ref(),_old_mesh,_old_shape)
    if status==OK:
        cancel()
    return status

func report() -> Dictionary:
    return _stage.report()
