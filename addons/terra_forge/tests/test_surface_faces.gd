@tool
extends SceneTree
## Godot: --headless --script res://addons/terra_forge/tests/test_surface_faces.gd
## Regression check for the "empty checkerboard" terrain bug.
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")

func _initialize() -> void:
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.height_data = STORE.new()
    terrain.height_data.initialize(Vector2i(32, 32), 1.0)
    terrain._terrain_material = StandardMaterial3D.new()
    var tile: Dictionary = terrain._create_tile(0, 0)
    for lod in range(3):
        terrain._rebuild_tile(0, 0, tile, lod)
        var mesh: Mesh = (tile["visual"] as MeshInstance3D).mesh
        if mesh == null or mesh.get_surface_count() != 1:
            _fail("Missing terrain surface at LOD " + str(lod))
            return
        var arrays: Array = mesh.surface_get_arrays(0)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
        if vertices.size() < 3 or indices.size() < 3:
            _fail("Empty terrain surface at LOD " + str(lod))
            return
        # Godot's front-facing winding for a top-facing XZ quad corresponds
        # to (b-a) x (c-a) with negative Y in this vertex/index convention.
        var a: Vector3 = vertices[indices[0]]
        var b: Vector3 = vertices[indices[1]]
        var c: Vector3 = vertices[indices[2]]
        var winding_y: float = (b - a).cross(c - a).y
        if winding_y >= 0.0 or normals[indices[0]].y < 0.5:
            _fail("Backface-culled top surface at LOD " + str(lod))
            return
    terrain.free()
    print("PASS: upward terrain surface visible at LOD0, LOD1, LOD2")
    quit(0)

func _fail(message: String) -> void:
    push_error("TerraForge terrain surface regression: " + message)
    quit(1)
