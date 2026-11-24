@tool
extends SceneTree
## Headless regression tests for Ridge, Valley, Ramp and procedural Stamp.
## Run: godot --headless --path /project --script res://addons/terra_forge/tests/test_advanced_brushes.gd
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const SHAPES = preload("res://addons/terra_forge/core/brush_shapes.gd")

func _terrain() -> TerraForgeTerrain:
    var t: TerraForgeTerrain = TERRAIN.new()
    t.height_data = STORE.new()
    t.height_data.initialize(Vector2i(128, 128), 1.0)
    return t

func _fail(message: String) -> void:
    push_error("TerraForge advanced brushes: " + message)
    quit(1)

func _initialize() -> void:
    if not is_equal_approx(SHAPES.ridge(0.0), 1.0) or SHAPES.ridge(1.0) != 0.0:
        _fail("Ridge profile boundary")
        return
    if SHAPES.valley(0.0) <= SHAPES.valley(0.5) or SHAPES.valley(1.0) != 0.0:
        _fail("Valley profile boundary")
        return
    if SHAPES.stamp(SHAPES.STAMP_CRATER, 0.0) >= 0.0:
        _fail("Crater must have a negative bowl")
        return
    if SHAPES.stamp(SHAPES.STAMP_CRATER, 0.75) <= 0.0:
        _fail("Crater must have a raised lip")
        return
    if SHAPES.stamp(SHAPES.STAMP_MESA, 0.3) < 0.95 or SHAPES.stamp(SHAPES.STAMP_MESA, 1.0) != 0.0:
        _fail("Mesa must have a flat top and smooth edge")
        return

    var ridge: TerraForgeTerrain = _terrain()
    ridge.begin_stroke()
    ridge.paint_at(Vector3(22, 0, 32), SHAPES.TOOL_RIDGE, 10.0, 3.0)
    ridge.paint_at(Vector3(60, 0, 32), SHAPES.TOOL_RIDGE, 10.0, 3.0)
    ridge.end_stroke()
    # New terrain corridors are asymmetric and coherently domain-warped.
    # Their maximum reach is slightly wider than the nominal radius.
    if ridge.height_data.get_height(40, 32) <= 0.0 or ridge.height_data.get_height(40, 48) != 0.0:
        _fail("Ridge centerline/extended edge")
        return
    ridge.undo_stroke()
    if absf(ridge.height_data.get_height(40, 32)) > 0.00001:
        _fail("Ridge Undo")
        return
    ridge.free()

    var valley: TerraForgeTerrain = _terrain()
    valley.begin_stroke()
    valley.paint_at(Vector3(22, 0, 32), SHAPES.TOOL_VALLEY, 10.0, 3.0)
    valley.paint_at(Vector3(60, 0, 32), SHAPES.TOOL_VALLEY, 10.0, 3.0)
    valley.end_stroke()
    if valley.height_data.get_height(40, 32) >= 0.0:
        _fail("Valley must lower the terrain")
        return
    valley.free()

    var stamp: TerraForgeTerrain = _terrain()
    stamp.begin_stroke()
    stamp.paint_at(Vector3(64, 0, 64), SHAPES.TOOL_STAMP, 12.0, 3.0, SHAPES.STAMP_CRATER)
    # One touch = one placement: moving the finger must not add another crater.
    stamp.paint_at(Vector3(95, 0, 64), SHAPES.TOOL_STAMP, 12.0, 3.0, SHAPES.STAMP_CRATER)
    stamp.end_stroke()
    if stamp.height_data.get_height(64, 64) >= 0.0:
        _fail("Crater center should be depressed")
        return
    # The organic warp makes the rim non-circular, so look for a raised
    # annulus rather than requiring the original exact +9 pixel offset.
    var raised_rim: bool = false
    for radius_offset in range(6, 12):
        for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var gx: int = 64 + direction.x * radius_offset
            var gz: int = 64 + direction.y * radius_offset
            if stamp.height_data.get_height(gx, gz) > 0.01:
                raised_rim = true
    if not raised_rim:
        _fail("Crater should have a raised annulus")
        return
    if stamp.height_data.get_height(95, 64) != 0.0:
        _fail("Stamp repeated during drag")
        return
    stamp.free()

    var hill: TerraForgeTerrain = _terrain()
    hill.begin_stroke()
    hill.paint_at(Vector3(44, 0, 44), SHAPES.TOOL_STAMP, 10.0, 3.0, SHAPES.STAMP_HILL)
    hill.end_stroke()
    if hill.height_data.get_height(44, 44) <= 0.0 or hill.height_data.get_height(54, 44) != 0.0:
        _fail("Hill stamp center/border")
        return
    hill.free()

    var mesa: TerraForgeTerrain = _terrain()
    mesa.begin_stroke()
    mesa.paint_at(Vector3(44, 0, 44), SHAPES.TOOL_STAMP, 10.0, 3.0, SHAPES.STAMP_MESA)
    mesa.end_stroke()
    var plateau_center: float = mesa.height_data.get_height(44, 44)
    if plateau_center <= 0.0 or absf(plateau_center - mesa.height_data.get_height(46, 44)) > 0.00001:
        _fail("Mesa stamp flat summit")
        return
    mesa.free()

    var ramp: TerraForgeTerrain = _terrain()
    ramp.begin_stroke()
    ramp.paint_at(Vector3(20, 0, 32), SHAPES.TOOL_RAMP, 8.0, 3.0, 0, 6.0)
    ramp.paint_at(Vector3(64, 0, 32), SHAPES.TOOL_RAMP, 8.0, 3.0, 0, 6.0)
    # Ramp should appear only once, when touch releases.
    if ramp.height_data.get_height(42, 32) != 0.0:
        _fail("Ramp prematurely modified data")
        return
    ramp.end_stroke()
    if absf(ramp.height_data.get_height(42, 32) - 3.0) > 0.00001:
        _fail("Ramp should interpolate a 6m rise over 44m")
        return
    if ramp.height_data.get_height(42, 40) != 0.0:
        _fail("Ramp edited outside its brush width")
        return
    ramp.undo_stroke()
    if ramp.height_data.get_height(42, 32) != 0.0:
        _fail("Ramp Undo")
        return
    ramp.redo_stroke()
    if absf(ramp.height_data.get_height(42, 32) - 3.0) > 0.00001:
        _fail("Ramp Redo")
        return
    ramp.free()
    var decline: TerraForgeTerrain = _terrain()
    decline.begin_stroke()
    decline.paint_at(Vector3(20, 0, 32), SHAPES.TOOL_RAMP, 8.0, 3.0, 0, -6.0)
    decline.paint_at(Vector3(64, 0, 32), SHAPES.TOOL_RAMP, 8.0, 3.0, 0, -6.0)
    decline.end_stroke()
    if absf(decline.height_data.get_height(42, 32) + 3.0) > 0.00001:
        _fail("Negative Rise must produce a descending ramp")
        return
    decline.free()
    print("PASS: ridge, valley, hill/crater/mesa stamps, ramps and Undo/Redo")
    quit(0)
