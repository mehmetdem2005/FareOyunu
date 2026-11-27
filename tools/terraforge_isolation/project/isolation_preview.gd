extends "res://addons/terra_forge/terrain/paged_terrain_preview.gd"
## Test double for the publication boundary. Production arms call the original.
## The worker gets the same logical LOD0 readiness when resources are suppressed.
class LogicalCollision extends RefCounted:
    var shape: HeightMapShape3D

var sink := "full"
var marker := HeightMapShape3D.new()
var delivered := 0
var visuals := 0
var shapes := 0
var sync_us := 0
var publish_us := 0

func _sync_tiles() -> void:
    var began := Time.get_ticks_usec()
    super._sync_tiles()
    sync_us += Time.get_ticks_usec() - began

func _publish_geometry(key: Vector2i, lod: int, generated: Dictionary, started: int) -> Error:
    var began := Time.get_ticks_usec()
    var err := OK
    if sink == "full":
        err = super._publish_geometry(key, lod, generated, started)
    else:
        _publish_test_result(key, lod, generated)
    publish_us += Time.get_ticks_usec() - began
    if err == OK:
        delivered += 1
        visuals += int(sink != "receipt")
        shapes += int(sink == "full" and lod == 0)
    return err

func _publish_test_result(key: Vector2i, lod: int, generated: Dictionary) -> void:
    if not _tiles.has(key):
        var root := Node3D.new()
        root.position = Vector3(key.x, 0, key.y) * (TILE_CELLS * _reader.spacing)
        add_child(root, false, Node.INTERNAL_MODE_FRONT)
        var tile := {"root": root, "collision": LogicalCollision.new()}
        if sink == "mesh":
            var visual := MeshInstance3D.new()
            visual.material_override = _material
            root.add_child(visual)
            tile["visual"] = visual
        _tiles[key] = tile
    var tile: Dictionary = _tiles[key]
    if sink == "mesh":
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, generated["arrays"])
        tile["visual"].mesh = mesh
    tile["collision"].shape = marker if lod == 0 else null
    tile["lod"] = lod
    tile["vertex_count"] = generated["vertex_count"]
    tile["levels"] = WORKER.signature(key, lod, _desired_tiles, _reader.cells)["levels"]
    _pending_tiles.erase(key)
    _mesh_builds += 1
