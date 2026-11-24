@tool
extends SceneTree
## Regression: no gray tile skirts, only real top-surface vertices.
## Run with Godot 4.7.2:
## godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_lod_seams.gd
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")

func _initialize() -> void:
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.height_data = STORE.new()
    terrain.height_data.initialize(Vector2i(64, 32), 1.0)
    # Nonlinear test ridge: LOD0's raw intermediate edge heights DIFFER
    # from LOD2's straight border segments. Stitched heights must match.
    for z in range(33):
        for x in range(65):
            var index: int = terrain.height_data.index_of(x, z)
            terrain.height_data.heights[index] = 0.01 * float(z * z) + 0.02 * float(x)
    terrain._terrain_material = StandardMaterial3D.new()
    terrain._desired_tiles = {Vector2i(0, 0): 0, Vector2i(1, 0): 2}

    var fine: Dictionary = terrain._create_tile(0, 0)
    var coarse: Dictionary = terrain._create_tile(1, 0)
    terrain._rebuild_tile(0, 0, fine, 0)
    terrain._rebuild_tile(1, 0, coarse, 2)

    var fine_arrays: Array = (fine["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
    var coarse_arrays: Array = (coarse["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
    var fine_vertices: PackedVector3Array = fine_arrays[Mesh.ARRAY_VERTEX]
    var coarse_vertices: PackedVector3Array = coarse_arrays[Mesh.ARRAY_VERTEX]
    if fine_vertices.size() != 33 * 33 or coarse_vertices.size() != 9 * 9:
        _fail("Unexpected extra skirt vertices or mesh LOD sizes", terrain)
        return

    var interpolated_count: int = 0
    for z in range(33):
        var fine_height: float = fine_vertices[z * 33 + 32].y
        var coarse_index: int = int(z / 4)
        var local_phase: int = z % 4
        var start_h: float = coarse_vertices[coarse_index * 9].y
        var expected: float = start_h
        if local_phase > 0:
            var next_h: float = coarse_vertices[(coarse_index + 1) * 9].y
            expected = lerpf(start_h, next_h, float(local_phase) / 4.0)
        if absf(fine_height - expected) > 0.00001:
            _fail("LOD seam mismatch at z=" + str(z), terrain)
            return
        if absf(fine_height - terrain.height_data.get_height(32, z)) > 0.0001:
            interpolated_count += 1

    if interpolated_count == 0:
        _fail("Seam adjustment never ran", terrain)
        return
    terrain.free()
    print("PASS: LOD0/LOD2 boundary interpolation; no unnecessary skirt geometry")
    quit(0)

func _fail(message: String, terrain: Node) -> void:
    push_error("TerraForge LOD seam test failed: " + message)
    terrain.free()
    quit(1)
