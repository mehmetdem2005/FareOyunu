@tool
extends SceneTree
## LOD0/LOD2 normals must match a known analytic slope, without high-res
## normal noise leaking into low-resolution render surfaces.
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")

func _initialize() -> void:
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.height_data = STORE.new()
    terrain.height_data.initialize(Vector2i(64, 64), 1.0)
    for z in range(65):
        for x in range(65):
            terrain.height_data.heights[terrain.height_data.index_of(x, z)] = 0.5 * float(x) + 0.25 * float(z)
    terrain._terrain_material = StandardMaterial3D.new()
    var tile: Dictionary = terrain._create_tile(0, 0)
    var expected: Vector3 = Vector3(-0.5, 1.0, -0.25).normalized()
    for lod in [0, 1, 2]:
        terrain._desired_tiles = {Vector2i(0, 0): lod}
        terrain._rebuild_tile(0, 0, tile, lod)
        var arrays: Array = (tile["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
        var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
        var width: int = int(32 / (1 << lod)) + 1
        var mid: int = (width / 2) * width + (width / 2)
        var normal: Vector3 = normals[mid]
        if normal.distance_to(expected) > 0.001:
            push_error("Wrong normal at LOD %d: %s expected %s" % [lod, normal, expected])
            terrain.free()
            quit(1)
            return
    terrain.free()
    print("PASS: slope-aligned normals match at all terrain LOD levels")
    quit(0)
