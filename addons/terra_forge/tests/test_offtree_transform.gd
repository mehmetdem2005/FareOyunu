@tool
extends SceneTree
## Covers the off-tree scratch sculpt path used in headless CI.
## No "Condition !is_inside_tree" errors should be emitted.
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")

func _initialize() -> void:
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.position = Vector3(12.0, 0.0, 7.0)
    terrain.height_data = STORE.new()
    terrain.height_data.initialize(Vector2i(64, 64), 1.0)
    terrain.begin_stroke()
    terrain.paint_at(Vector3(32.0, 0.0, 32.0), 0, 5.0, 4.0)
    terrain.end_stroke()
    if terrain.height_data.get_height(20, 25) <= 0.0:
        push_error("Off-tree transform did not map global brush position into terrain local space")
        terrain.free()
        quit(1)
        return
    if terrain.height_data.get_height(32, 32) != 0.0:
        push_error("Off-tree brush incorrectly treated global coordinates as local")
        terrain.free()
        quit(1)
        return
    terrain.free()
    print("PASS: off-tree sculpting respects local transform with no engine warnings")
    quit(0)
