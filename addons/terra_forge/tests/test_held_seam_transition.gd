extends SceneTree
## Exercise both worker modes with a real curved TFM1 edge. The matched
## benchmark recipe is piecewise linear along this boundary.
const Builder = preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const Preview = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const POINT := Vector2(31.5, 7)
const KEY := Vector2i.ZERO
var builder := Builder.new()
var preview: Preview

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if builder.start(Vector2i(64, 32)) != OK:
        _finish("fixture start")
        return
    var result: Dictionary
    for attempt in range(240):
        result = builder.take_result()
        if result["error"] != ERR_BUSY:
            break
        await physics_frame
    if result["error"] != OK:
        _finish("fixture generation")
        return
    for mode in [3, 4]:
        preview = Preview.new()
        preview.sampling_strategy = mode
        preview.enable_support_retention = true
        preview.max_visible_tiles = 1
        preview.high_detail_distance = 32
        preview.medium_detail_distance = 64
        preview.view_distance = 96
        root.add_child(preview)
        if preview.start_preview(result["directory"], 16, 4) != OK:
            _finish("open")
            return
        preview.set_process(false)
        preview.set_stream_center(Vector3(16, 0, 16))
        var error: String = await _exercise()
        preview.free()
        preview = null
        if not error.is_empty():
            _finish("mode %d: %s" % [mode, error])
            return
    _finish("")

func _exercise() -> String:
    if not await _settle(1):
        return "initial tile"
    var lease := preview.update_support(POINT, 0.2, preview._support_session, preview._support_revision)
    if lease["error"] != OK:
        return "acquire support"
    var collision: CollisionShape3D = preview._tiles[KEY]["collision"]
    var original := collision.shape as HeightMapShape3D
    preview.max_visible_tiles = 2
    # Split normal selection and publication to inspect the pending interval.
    preview._sync_tiles()
    var check := preview.inspect_collision_footprint(POINT, POINT, 0.2)
    if not preview._pending_tiles.has(KEY) or not check["ready"] or check["ray_count"] != 1:
        return "equivalent pending edge must pass physics"
    if not await _settle(2) or collision.shape != original:
        return "equivalent publication must reuse shape"
    preview.set_stream_center(Vector3(0, 0, 16))
    preview._sync_tiles()
    check = preview.inspect_collision_footprint(POINT, POINT, 0.2)
    if preview._desired_tiles.get(Vector2i.RIGHT) != 1 or not preview._pending_tiles.has(KEY) or check["reason"] != "unsettled" or check["ready"]:
        return "changed pending edge must deny"
    if not await _settle(2):
        return "changed edge publication"
    var coarse := collision.shape as HeightMapShape3D
    var i := 7 * 33 + 32
    var heights := original.map_data
    if coarse == original or coarse.map_data[i] == heights[i] or not is_equal_approx(coarse.map_data[i], (heights[i-33] + heights[i+33]) * 0.5):
        return "edge sample must match coarse interpolation"
    check = preview.inspect_collision_footprint(POINT, POINT, 0.2)
    if not check["ready"] or check["ray_count"] != 1:
        return "confirmed support after replacement"
    return ""

func _settle(count: int) -> bool:
    for attempt in range(240):
        await physics_frame
        preview.pump_stream()
        if preview._tiles.size() == count and preview._pending_tiles.is_empty() and preview._geometry_jobs.is_empty():
            await physics_frame
            await physics_frame
            return true
    return false

func _finish(error: String) -> void:
    if is_instance_valid(preview):
        preview.free()
    builder.close()
    if error.is_empty():
        print("PASS: E/F held seam reuse, changed-height admission denial and replacement")
        quit(0)
    else:
        push_error(error)
        quit(1)
