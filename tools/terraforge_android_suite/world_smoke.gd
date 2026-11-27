extends SceneTree
## Runs against the assembled project via --script. --capture writes render evidence.

const MOVE_FINGER := 4
const LOOK_FINGER := 9

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var menu := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(menu)
    current_scene = menu
    menu._world_button.pressed.emit()
    var world: Node3D = menu._world
    if world == null or menu._layer.visible:
        _fail("opening Serbest Dünya from the main menu")
        return
    var expires := Time.get_ticks_msec() + 55000
    while not world._playing and not world._failed and Time.get_ticks_msec() < expires:
        await process_frame
    if not world._playing:
        _fail("loading a grounded player and initial tile coverage")
        return
    var capture := OS.get_cmdline_user_args().has("--capture")
    if capture and (DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "mobile"):
        _fail("capture requires a rendered Mobile run")
        return
    var hud: Control = world._hud
    var start: Vector3 = world._body.global_position
    var left := hud.size * Vector2(0.20, 0.73)
    var right := hud.size * Vector2(0.76, 0.58)
    _touch(MOVE_FINGER, left, true)
    _touch(LOOK_FINGER, right, true)
    _drag(MOVE_FINGER, left, Vector2(66.0, 0.0))
    _drag(LOOK_FINGER, right, Vector2(42.0, 16.0))
    await physics_frame
    if hud.movement().x < 0.95 or absf(world._yaw) < 0.15 or world._pitch > deg_to_rad(-25.0):
        _fail("simultaneous two-finger movement and camera orbit")
        return
    _touch(LOOK_FINGER, right + Vector2(42.0, 16.0), false)
    if hud.movement().x < 0.95:
        _fail("releasing the camera finger also stopped the joystick")
        return
    var fps_seconds := 15.0 if capture else 3.5
    expires = Time.get_ticks_msec() + 40000
    while world._elapsed_usec < fps_seconds * 1000000.0 and not world._failed and Time.get_ticks_msec() < expires:
        await process_frame
    var measurement: Dictionary = world.measurement()
    var position: Vector3 = world._body.global_position
    if (
        world._failed or measurement["seconds"] < fps_seconds or measurement["average_fps"] <= 0.0
        or measurement["airborne_steps"] != 0 or measurement["player_distance_m"] < 25.0
        or start.x >= 512.0 or position.x <= 512.0 or not world._body.is_on_floor()
    ):
        _fail("grounded crossing or frame measurement: " + JSON.stringify(measurement))
        return
    var fps_rect: Rect2 = hud._metrics.get_global_rect()
    if (
        fps_rect.position.x <= hud.size.x * 0.5 or fps_rect.end.x > hud.size.x
        or fps_rect.position.y < 0.0 or fps_rect.position.y > 40.0
        or hud._fps.text.begins_with("—")
    ):
        _fail("FPS placement or display: %s / %s" % [fps_rect, hud._fps.text])
        return
    if capture:
        await RenderingServer.frame_post_draw
        var screenshot := root.get_texture().get_image()
        if (
            screenshot == null or screenshot.save_png("user://TerraForge_Free_World.png") != OK
            or not world._write_report("user://TerraForge_Free_World.json", JSON.stringify(measurement, "  "))
        ):
            _fail("saving the screenshot and rendered benchmark JSON")
            return
    _touch(MOVE_FINGER, left + Vector2(66.0, 0.0), false, true)
    if hud.movement() != Vector2.ZERO:
        _fail("canceled joystick touch remained stuck")
        return
    hud._reset.pressed.emit()
    if world.measurement()["seconds"] != 0.0 or world.measurement()["player_distance_m"] != 0.0:
        _fail("resetting measurement")
        return
    var fixture_dir: String = world._fixture_dir
    hud._back.pressed.emit()
    await process_frame
    if is_instance_valid(menu._world) or not menu._layer.visible or DirAccess.dir_exists_absolute(fixture_dir):
        _fail("return to the menu or fixture cleanup")
        return
    menu._world_button.pressed.emit()
    menu._world._hud._back.pressed.emit()
    expires = Time.get_ticks_msec() + 5000
    while is_instance_valid(menu._world) and Time.get_ticks_msec() < expires:
        await process_frame
    if not menu._layer.visible or is_instance_valid(menu._world):
        _fail("return while a new fixture is generating")
        return
    print("FREE_WORLD_VERIFIED ", JSON.stringify(measurement))
    quit(0)

func _touch(index: int, point: Vector2, down: bool, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = point
    event.pressed = down
    event.canceled = canceled
    root.push_input(event, true)

func _drag(index: int, point: Vector2, relative: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = point + relative
    event.relative = relative
    root.push_input(event, true)

func _fail(message: String) -> void:
    push_error("Free World: " + message)
    quit(1)
