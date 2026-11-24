@tool
extends SceneTree
## Regression checks for geometry quality and mobile LOD stability.
## godot --headless --path /project --script res://addons/terra_forge/tests/test_shape_quality.gd
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const SHAPES = preload("res://addons/terra_forge/core/brush_shapes.gd")
const LOD = preload("res://addons/terra_forge/core/lod_policy.gd")

func _fail(message: String) -> void:
    push_error("TerraForge shape quality: " + message)
    quit(1)

func _initialize() -> void:
    # LOD hysteresis prevents rapid switching back and forth near thresholds.
    if LOD.choose_stable_lod(76.0, 72.0, 144.0, 224.0, 0, 8.0) != 0:
        _fail("LOD0 did not retain its level inside the hysteresis band")
        return
    if LOD.choose_stable_lod(84.0, 72.0, 144.0, 224.0, 0, 8.0) != 1:
        _fail("LOD0 was not promoted outside the hysteresis band")
        return
    if LOD.choose_stable_lod(68.0, 72.0, 144.0, 224.0, 1, 8.0) != 1:
        _fail("LOD1 switched back too early")
        return
    if LOD.choose_stable_lod(60.0, 72.0, 144.0, 224.0, 1, 8.0) != 0:
        _fail("LOD1 did not switch back after exiting the band")
        return

    var noise: FastNoiseLite = FastNoiseLite.new()
    noise.seed = 137
    noise.frequency = 1.0 / 26.0
    var center: Vector2 = Vector2(35.0, 35.0)
    if SHAPES.organic_stamp(0, center, center, 16.0, noise) < 0.99:
        _fail("Hill center has unexpected height")
        return
    if SHAPES.organic_stamp(0, center + Vector2(16, 0), center, 16.0, noise) != 0.0:
        _fail("Stamp leaked past the brush radius")
        return
    var x_profile: float = SHAPES.organic_stamp(0, center + Vector2(6, 0), center, 16.0, noise)
    var z_profile: float = SHAPES.organic_stamp(0, center + Vector2(0, 6), center, 16.0, noise)
    if absf(x_profile - z_profile) < 0.0001:
        _fail("Organic stamp remains perfectly rotationally symmetric")
        return

    # A spike around the brush center must smooth without X/Z scan bias.
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.height_data = STORE.new()
    terrain.height_data.initialize(Vector2i(64, 64), 1.0)
    terrain.height_data.heights[terrain.height_data.index_of(32, 32)] = 15.0
    terrain.begin_stroke()
    terrain.paint_at(Vector3(32, 0, 32), 2, 8.0, 12.0)
    if not terrain._dirty_tiles.has(Vector2i(0, 0)) or not terrain._dirty_tiles.has(Vector2i(1, 1)):
        _fail("Edited border did not invalidate neighbor tiles")
        terrain.free()
        return
    terrain.end_stroke()
    var west: float = terrain.height_data.get_height(31, 32)
    var east: float = terrain.height_data.get_height(33, 32)
    var north: float = terrain.height_data.get_height(32, 31)
    var south: float = terrain.height_data.get_height(32, 33)
    if absf(west - east) > 0.00001 or absf(north - south) > 0.00001:
        _fail("Smooth operation is biased by vertex processing order")
        terrain.free()
        return
    if terrain.height_data.get_height(32, 32) >= 15.0:
        _fail("Smooth did not reduce a large spike")
        terrain.free()
        return
    terrain.free()
    print("PASS: organic stamps, scan-independent smoothing, LOD hysteresis, dirty tile halo")
    quit(0)
