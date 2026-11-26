@tool
extends RefCounted
## One staged slot, main-thread only. Never attach half a revision.
## Caller owns verified identity and physics-safe commit scheduling.
const A=preload("res://addons/terra_forge/core/publication_accounting.gd")
const CAP: int=131072
var _identity: String=""
var _mesh: ArrayMesh
var _shape: HeightMapShape3D
var _heights: PackedFloat32Array
var _width: int=0
var _phase: int=0
var _payload: int=0

func cancel() -> void:
    _identity=""
    _mesh=null
    _shape=null
    _heights=PackedFloat32Array()
    _width=0
    _phase=0
    _payload=0

func stage_mesh(identity: String,generated: Dictionary,lod: int) -> Error:
    if _phase!=0:
        return ERR_BUSY
    if identity.is_empty():
        return ERR_INVALID_PARAMETER
    var info: Dictionary=A.describe(generated,lod)
    if info["error"]!=OK or info["total_bytes"]>CAP:
        return ERR_INVALID_DATA
    _mesh=ArrayMesh.new()
    _mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,generated["arrays"])
    _heights=generated["collision_heights"].duplicate()
    _width=generated["width"]
    _identity=identity
    _payload=info["total_bytes"]
    _phase=1
    return OK

func stage_shape(identity: String) -> Error:
    if _phase!=1 or identity!=_identity:
        return ERR_UNAVAILABLE
    if not _heights.is_empty():
        _shape=HeightMapShape3D.new()
        _shape.map_width=_width
        _shape.map_depth=_width
        _shape.map_data=_heights
    _heights=PackedFloat32Array()
    _phase=2
    return OK

func commit(identity: String,visual: MeshInstance3D,collision: CollisionShape3D,old_mesh: Mesh,old_shape: Shape3D) -> Error:
    if _phase!=2 or identity!=_identity or not is_instance_valid(visual) or not is_instance_valid(collision) or visual.mesh!=old_mesh or collision.shape!=old_shape:
        return ERR_UNAVAILABLE
    if not Engine.is_in_physics_frame():
        return ERR_UNCONFIGURED
    # Both swaps in the same main-thread call; actual ray readiness is
    # checked after subsequent physics frames, not inferred from assignment.
    visual.mesh=_mesh
    collision.shape=_shape
    cancel()
    return OK

func report() -> Dictionary:
    return {"phase":_phase,"slots":int(_phase!=0),"source_payload":_payload,"cap":CAP}
