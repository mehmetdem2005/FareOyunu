@tool
extends SceneTree
## Same-LOD tile edges should share vertex normals even on curved terrain.
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")

func _fail(message: String, terrain: Node) -> void:
    terrain.free()
    push_error("TerraForge edge normals: " + message)
    quit(1)

func _initialize() -> void:
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.height_data = STORE.new()
    terrain.height_data.initialize(Vector2i(64, 64), 1.0)
    terrain._terrain_material = StandardMaterial3D.new()
    # A quadratic surface has nonconstant slope; one-sided differences
    # produce mismatched tile normals without centered border sampling.
    for z in range(65):
        for x in range(65):
            terrain.height_data.heights[terrain.height_data.index_of(x, z)] = (
                0.008 * float(x * x)
                + 0.017 * float(z * z)
                + 0.005 * float(x * z)
            )
    var left: Dictionary = terrain._create_tile(0, 0)
    var right: Dictionary = terrain._create_tile(1, 0)
    for lod in [0, 1, 2]:
        terrain._desired_tiles = {Vector2i(0, 0): lod, Vector2i(1, 0): lod}
        terrain._rebuild_tile(0, 0, left, lod)
        terrain._rebuild_tile(1, 0, right, lod)
        var a: Array = (left["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
        var b: Array = (right["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
        var normals_a: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
        var normals_b: PackedVector3Array = b[Mesh.ARRAY_NORMAL]
        var width: int = (32 >> lod) + 1
        for z in range(1, width - 1):
            var index_a: int = z * width + width - 1
            var index_b: int = z * width
            if normals_a[index_a].distance_to(normals_b[index_b]) > 0.00005:
                _fail("LOD %d border normal mismatch at z %d" % [lod, z], terrain)
                return
    terrain.free()
    print("PASS: matching same-LOD curved-surface normals on shared edges")
    quit(0)
