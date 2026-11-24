@tool
extends SceneTree
## Verifies that touch event frequency doesn't change sculpted heights.
## Run: godot --headless --path /project --script res://addons/terra_forge/tests/test_brush_sampling.gd
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")

func _make_terrain() -> TerraForgeTerrain:
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.height_data = STORE.new()
    terrain.height_data.initialize(Vector2i(64, 64), 1.0)
    return terrain

func _draw_path(terrain: TerraForgeTerrain, event_step: int) -> void:
    terrain.begin_stroke()
    for x in range(8, 57, event_step):
        terrain.paint_at(Vector3(float(x), 0.0, 32.0), 0, 7.0, 3.0)
    # Include the final endpoint even for event cadences that don't divide 48.
    terrain.paint_at(Vector3(56.0, 0.0, 32.0), 0, 7.0, 3.0)
    terrain.end_stroke()

func _initialize() -> void:
    var sparse: TerraForgeTerrain = _make_terrain()
    var dense: TerraForgeTerrain = _make_terrain()
    _draw_path(sparse, 12)
    _draw_path(dense, 1)
    var sparse_heights: PackedFloat32Array = sparse.height_data.heights
    var dense_heights: PackedFloat32Array = dense.height_data.heights
    var changed: int = 0
    for i in range(sparse_heights.size()):
        if absf(sparse_heights[i] - dense_heights[i]) > 0.0001:
            _fail("Height differs with touch-event cadence at index %d" % i, sparse, dense)
            return
        if sparse_heights[i] != 0.0:
            changed += 1
    if changed < 30:
        _fail("Stroke painted too few samples", sparse, dense)
        return
    sparse.undo_stroke()
    for h in sparse.height_data.heights:
        if h != 0.0:
            _fail("Undo failed to restore original heights", sparse, dense)
            return
    sparse.redo_stroke()
    for i in range(sparse_heights.size()):
        if absf(sparse.height_data.heights[i] - dense_heights[i]) > 0.0001:
            _fail("Redo failed to restore the stroke", sparse, dense)
            return
    sparse.free()
    dense.free()
    print("PASS: Touch event-rate independence and stroke Undo/Redo")
    quit(0)

func _fail(message: String, a: Node, b: Node) -> void:
    push_error("TerraForge brush regression: " + message)
    a.free()
    b.free()
    quit(1)
