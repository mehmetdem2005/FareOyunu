extends SceneTree
## Use a rendered window taller than 540 pixels to exercise both 3D budgets.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var menu := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(menu)
    var previous := root.scaling_3d_scale
    menu._world_button.pressed.emit()
    var world: Node3D = menu._world
    var deadline := Time.get_ticks_msec() + 60000
    while not world._playing and not world._failed and Time.get_ticks_msec() < deadline:
        await process_frame
    if not world._playing or root.scaling_3d_scale >= 1.0:
        _fail("world start or 540p render target")
        return
    var target_rid := RenderingServer.texture_get_rd_texture(root.get_texture().get_rid())
    var target := RenderingServer.get_rendering_device().texture_get_format(target_rid)
    if (world._render_target != Vector2i(target.width, target.height)
            or absf(root.scaling_3d_scale * target.height - 540.0) > 1.0):
        _fail("actual 3D target size disagrees with 540p budget")
        return
    var hud: Control = world._hud
    hud._compare.pressed.emit()
    if world._comparison == null or root.scaling_3d_scale != 1.0:
        _fail("start native arm")
        return
    hud._compare.pressed.emit()
    if world._comparison != null or root.scaling_3d_scale >= 1.0:
        _fail("cancel and restore")
        return
    hud._compare.pressed.emit()
    deadline = Time.get_ticks_msec() + 170000
    while world._comparison != null and not world._failed and Time.get_ticks_msec() < deadline:
        await process_frame
    var report: Dictionary = world.measurement()
    var runs: Array = report["comparison"]
    if world._failed or runs.size() != 4 or hud._save.disabled:
        _fail("comparison incomplete or export unavailable")
        return
    for i in range(4):
        var walk: Dictionary = runs[i]["walk"]
        var idle: Dictionary = runs[i]["idle"]
        if (runs[i]["arm"] != ["native", "540p", "540p", "native"][i]
                or idle["seconds"] < 2.5 or idle["player_distance_m"] > 0.5
                or absf(walk["player_distance_m"] - 72.0) > 1.0 or walk["airborne_steps"] > 0
                or walk["cost"]["stream_pump_ms"]["count"] != walk["frame_intervals_ms"]["count"]
                or walk["frame_intervals_ms"]["count"] < 1):
            _fail("wrong arm, distance, support or timing counts: " + JSON.stringify(runs[i]))
            return
    if not world._write_report("user://world_comparison.json", JSON.stringify(report, "  ")):
        _fail("write report")
        return
    hud._back.pressed.emit()
    await process_frame
    if not is_equal_approx(root.scaling_3d_scale, previous):
        _fail("menu scale restoration")
        return
    print("WORLD_COMPARISON_VERIFIED")
    quit(0)

func _fail(message: String) -> void:
    push_error("Free world comparison: " + message)
    quit(1)
