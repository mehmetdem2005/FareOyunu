extends Node3D

signal exit_requested

const PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const FIXTURE = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const HISTOGRAM = preload("res://addons/terra_forge/core/profile_histogram.gd")
const FRAME_COST = preload("res://world_frame_cost.gd")
const COMPARISON = preload("res://world_comparison.gd")
const WORLD_CELLS := Vector2i(1024, 1024)
const SPAWN := Vector2(500.0, 500.0)
const PAGE_LIMIT := 32
const IO_JOBS := 4
const GEOMETRY_JOBS := 2
const TILE_LIMIT := 32
const VIEW_DISTANCE := 160.0
const MOVE_SPEED := 12.0
const GRAVITY := 20.0
const SUPPORT_RADIUS := 0.41
const LOOK_SPEED := 0.005
const STREAM_TIMEOUT_MS := 45000

@onready var _body: CharacterBody3D = $Player
@onready var _orbit: Node3D = $Orbit
@onready var _arm: SpringArm3D = $Orbit/SpringArm
@onready var _hud = $Interface/HUD

var _fixture
var _fixture_dir := ""
var _preview
var _extent := Vector2.ZERO
var _exclude: Array[RID] = []
var _pitch := deg_to_rad(-24.0)
var _yaw := 0.0
var _support_session := 0
var _support_revision := 0
var _stream_started := 0
var _initial_tiles_ready := false
var _spawned := false
var _playing := false
var _leaving := false
var _failed := false
var _app_paused := false
var _window_focused := true
var _dialog_open := false
var _notice_until := 0
var _last_frame_usec := 0
var _elapsed_usec := 0
var _frames := 0
var _window_usec := 0
var _window_frames := 0
var _distance := 0.0
var _waiting_steps := 0
var _airborne_steps := 0
var _frame_times = HISTOGRAM.new()

var _cost = FRAME_COST.new()
var _pump_us := 0
var _controller_us := 0
var _physics_steps := 0
var _pending := 0
var _render_target := Vector2i.ZERO
var _original_scale := 1.0
var _render_timing := false
var _comparison: COMPARISON
var _comparison_runs: Array[Dictionary] = []

func _ready() -> void:
    _original_scale = get_viewport().scaling_3d_scale
    get_viewport().size_changed.connect(_resize_target)
    _resize_target()
    _hud.compare_requested.connect(_toggle_comparison)
    _hud.back_requested.connect(_leave)
    _hud.reset_requested.connect(_reset_measurement)
    _hud.save_requested.connect(_export_report)
    _hud.look_dragged.connect(_look)
    _exclude.append(_body.get_rid())
    _orbit.position = Vector3(SPAWN.x, 20.0, SPAWN.y)
    _hud.show_status("1024 × 1024 test arazisi hazırlanıyor…")
    _fixture = FIXTURE.new()
    var status: Error = _fixture.start(WORLD_CELLS)
    if status != OK:
        _fixture = null
        _fail("Test arazisi oluşturulamadı", status)

func _process(_delta: float) -> void:
    if _fixture != null:
        var result: Dictionary = _fixture.take_result()
        if result["error"] == ERR_BUSY:
            return
        _fixture = null
        _fixture_dir = result.get("directory", "")
        if _leaving:
            _return_to_menu()
        elif result["error"] == OK:
            _open_terrain()
        else:
            _fail("Test arazisi oluşturulamadı", result["error"])
        return
    if _preview == null or _failed or _leaving or _app_paused:
        return
    var focus := _body.global_position if _spawned else Vector3(SPAWN.x, 0.0, SPAWN.y)
    var pump_start := Time.get_ticks_usec()
    _preview.set_stream_center(focus)
    var stream: Dictionary = _preview.pump_stream()
    _pump_us = Time.get_ticks_usec() - pump_start
    _pending = stream.get("pending_tiles", 0)
    if stream["error"] != OK:
        _fail("Arazi akışı durdu", stream["error"])
        return
    if not _playing:
        _initial_tiles_ready = stream["resident_tiles"] > 0 and stream["pending_tiles"] == 0
        if Time.get_ticks_msec() - _stream_started > STREAM_TIMEOUT_MS:
            _fail("Arazi zamanında yüklenemedi", ERR_TIMEOUT)
        return
    if _notice_until > 0 and Time.get_ticks_msec() >= _notice_until:
        _notice_until = 0
        _hud.show_status("")
    if _window_focused and not _dialog_open:
        _sample_frame()
        if _comparison != null:
            _advance_comparison()

func _open_terrain() -> void:
    _preview = PREVIEW.new()
    _preview.region_index_format = 1 # TFM2
    _preview.sampling_strategy = 4 # F priority worker
    _preview.geometry_job_limit = GEOMETRY_JOBS
    _preview.max_visible_tiles = TILE_LIMIT
    _preview.view_distance = VIEW_DISTANCE
    _preview.enable_support_retention = true
    add_child(_preview)
    var status: Error = _preview.start_preview(_fixture_dir, PAGE_LIMIT, IO_JOBS)
    if status != OK:
        _fail("Test arazisi açılamadı", status)
        return
    # Stream around the player, including while the camera orbits.
    _preview.set_process(false)
    _extent = _preview.world_extent()
    var lease: Dictionary = _preview.support_state()
    _support_session = lease["session"]
    _support_revision = lease["revision"]
    _stream_started = Time.get_ticks_msec()
    _hud.show_status("İlk arazi parçaları yükleniyor…")

func _physics_process(delta: float) -> void:
    if _preview == null or _failed or _leaving or not _window_focused or _app_paused or _dialog_open:
        return
    if not _spawned:
        _try_spawn()
        return
    var began := Time.get_ticks_usec()
    var start := _body.global_position
    var from := Vector2(start.x, start.z)
    var stick: Vector2 = _hud.movement() if _comparison == null else _comparison.direction(from, MOVE_SPEED * delta)
    var heading := Basis(Vector3.UP, _yaw) * Vector3(stick.x, 0.0, stick.y)
    var margin := Vector2.ONE * (SUPPORT_RADIUS + 0.15)
    var target := (from + Vector2(heading.x, heading.z) * MOVE_SPEED * delta).clamp(margin, _extent - margin)
    var horizontal := (target - from) / delta
    if not target.is_equal_approx(from):
        var step: Dictionary = _preview.inspect_support_step(from, target, SUPPORT_RADIUS, _support_session, _support_revision, _exclude)
        if not step["ready"]:
            horizontal = Vector2.ZERO
            _waiting_steps += 1
    _body.velocity = Vector3(horizontal.x, _body.velocity.y - GRAVITY * delta, horizontal.y)
    _body.move_and_slide()
    var actual := Vector2(_body.global_position.x, _body.global_position.z)
    if not _claim_support(actual) and not actual.is_equal_approx(from):
        # Keep the last verified location if the actual slide cannot be leased.
        _body.global_position = start
        _body.velocity = Vector3.ZERO
        actual = from
        _waiting_steps += 1
    _orbit.global_position = _body.global_position + Vector3.UP * 0.85
    _orbit.rotation.y = _yaw
    _arm.rotation.x = _pitch
    _controller_us += Time.get_ticks_usec() - began
    _physics_steps += 1
    if _playing:
        _distance += from.distance_to(actual)
        _airborne_steps += int(not _body.is_on_floor())
    elif _initial_tiles_ready and _body.is_on_floor():
        _playing = true
        _hud.show_status("")
        _hud.set_controls_enabled(true)
        _reset_measurement()

func _try_spawn() -> void:
    if not _preview.has_collision_at(Vector3(SPAWN.x, 0.0, SPAWN.y)):
        return
    var query := PhysicsRayQueryParameters3D.create(
        Vector3(SPAWN.x, 128.0, SPAWN.y), Vector3(SPAWN.x, -128.0, SPAWN.y), 1, _exclude
    )
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty() or not _preview.is_ancestor_of(hit["collider"]) or not _claim_support(SPAWN):
        return
    var shape: CapsuleShape3D = $Player/Shape.shape
    _body.global_position = hit["position"] + Vector3.UP * (shape.height * 0.5 + 0.04)
    _body.show()
    _spawned = true

func _claim_support(point: Vector2) -> bool:
    var lease: Dictionary = _preview.update_support(point, SUPPORT_RADIUS, _support_session, _support_revision, _exclude)
    if lease["error"] != OK:
        return false
    _support_revision = lease["revision"]
    return true

func _look(drag: Vector2) -> void:
    if _comparison != null:
        return
    _yaw = wrapf(_yaw - drag.x * LOOK_SPEED, -PI, PI)
    _pitch = clampf(_pitch - drag.y * LOOK_SPEED, deg_to_rad(-75.0), deg_to_rad(8.0))

func _reset_measurement() -> void:
    _cost = FRAME_COST.new()
    _controller_us = 0
    _physics_steps = 0
    _last_frame_usec = 0
    _elapsed_usec = 0
    _frames = 0
    _window_usec = 0
    _window_frames = 0
    _frame_times = HISTOGRAM.new()
    _distance = 0.0
    _waiting_steps = 0
    _airborne_steps = 0
    _hud.show_metrics(0, 0.0, 0.0, 0.0)

func _sample_frame() -> void:
    var now := Time.get_ticks_usec()
    var elapsed := now - _last_frame_usec
    var has_previous := _last_frame_usec > 0
    _last_frame_usec = now
    if has_previous and elapsed > 0:
        _cost.frame(elapsed, _pump_us, _controller_us, _physics_steps, _pending)
        if _render_timing:
            _cost.sample_renderer(get_viewport().get_viewport_rid(), now)
    _controller_us = 0
    _physics_steps = 0
    if not has_previous or elapsed <= 0:
        return
    _frames += 1
    _elapsed_usec += elapsed
    _window_frames += 1
    _window_usec += elapsed
    _frame_times.add(float(elapsed) / 1000.0)
    if _window_usec >= 333333:
        var duration := float(_elapsed_usec) / 1000000.0
        _hud.show_metrics(
            roundi(float(_window_frames) * 1000000.0 / float(_window_usec)),
            float(_frames) / duration, duration, _frame_times.report()["p95_upper_ms"]
        )
        _window_frames = 0
        _window_usec = 0

func _resize_target() -> void:
    var vp := get_viewport()
    # canvas_items stretches logical coordinates into the letterboxed render
    # target. ViewportTexture.get_size() also applies the stretch in Godot 4.7.
    var content_pixels: Rect2 = vp.get_stretch_transform() * vp.get_visible_rect()
    _render_target = Vector2i(content_pixels.size.round())
    if _comparison != null:
        _stop_comparison(false)
    vp.scaling_3d_scale = _balanced_scale()

func _balanced_scale() -> float:
    return minf(_original_scale, 540.0 / maxf(1.0, _render_target.y))

func _toggle_comparison() -> void:
    if _comparison != null:
        _stop_comparison(false)
        return
    if not _playing or _dialog_open or _leaving:
        return
    if is_equal_approx(_balanced_scale(), 1.0):
        _show_notice("Bu ekranda 3B görüntü zaten 540p veya altında.")
        return
    _comparison = COMPARISON.new(Vector2(_body.position.x, _body.position.z), _extent)
    _yaw = 0.0
    _pitch = deg_to_rad(-24.0)
    _render_timing = DisplayServer.get_name() != "headless"
    if _render_timing:
        RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
    _begin_arm()

func _begin_arm() -> void:
    var native: bool = COMPARISON.SCALES[_comparison.arm] == "native"
    get_viewport().scaling_3d_scale = 1.0 if native else _balanced_scale()
    _hud.comparison_caption(_comparison.label())
    _reset_measurement()

func _advance_comparison() -> void:
    match _comparison.phase:
        "settle":
            if _elapsed_usec >= 1000000:
                _comparison.phase = "idle" if _comparison.arm > 0 else "walk"
                _reset_measurement()
                _hud.comparison_caption(_comparison.label())
        "idle":
            if _elapsed_usec >= 2500000:
                _comparison.idle = _interval_report()
                _comparison.phase = "walk"
                _reset_measurement()
                _hud.comparison_caption(_comparison.label())
        "walk":
            if _elapsed_usec > 45000000:
                _stop_comparison(false)
                _show_notice("Rota zamanında tamamlanamadı.")
            elif _comparison.lap_done:
                if _comparison.arm > 0:
                    var scale_3d := get_viewport().scaling_3d_scale
                    var target := (Vector2(_render_target) * scale_3d).round()
                    _comparison.runs.append({"arm": COMPARISON.SCALES[_comparison.arm],
                        "scale": scale_3d, "target_3d_pixels": [int(target.x), int(target.y)],
                        "idle": _comparison.idle, "walk": _interval_report()})
                _comparison.next_arm()
                if _comparison.arm == COMPARISON.SCALES.size():
                    _stop_comparison(true)
                else:
                    _begin_arm()

func _stop_comparison(completed: bool) -> void:
    if completed:
        _comparison_runs = _comparison.runs
    _comparison = null
    if _render_timing:
        RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
    _render_timing = false
    get_viewport().scaling_3d_scale = _balanced_scale()
    _hud.comparison_caption("")
    _hud.has_comparison = not _comparison_runs.is_empty()
    _reset_measurement()
    if completed:
        var native := _paired_fps("native")
        var reduced := _paired_fps("540p")
        _show_notice("Yürüyüş ortalaması\nDoğal %.1f FPS  ·  540p %.1f FPS\nFPS JSON kaydet" % [native, reduced])

func _paired_fps(arm: String) -> float:
    var seconds := 0.0
    var frames := 0
    for run in _comparison_runs:
        if run["arm"] == arm:
            seconds += float(run["walk"]["seconds"])
            frames += int(run["walk"]["frame_intervals_ms"]["count"])
    return float(frames) / seconds if seconds > 0.0 else 0.0

func _interval_report() -> Dictionary:
    var duration := float(_elapsed_usec) / 1000000.0
    return {"seconds": duration, "average_fps": float(_frames) / duration if duration > 0.0 else 0.0,
        "frame_intervals_ms": _frame_times.report(), "player_distance_m": _distance,
        "streaming_wait_steps": _waiting_steps, "airborne_steps": _airborne_steps, "cost": _cost.report()}

func measurement() -> Dictionary:
    var pixels := get_viewport().get_visible_rect().size
    var screen_pixels := get_window().size
    var refresh_hz := DisplayServer.screen_get_refresh_rate()
    var inventory: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://suite.json"))
    var report := _interval_report()
    report.merge({
        "schema": "TF_FREE_WORLD_2",
        "build_commit": inventory.get("build_commit") if inventory is Dictionary else null,
        "terrain_tree": inventory.get("terrain_tree") if inventory is Dictionary else null,
        "recorded_utc": Time.get_datetime_string_from_system(true),
        "os": OS.get_name(),
        "device_model": OS.get_model_name(),
        "godot": Engine.get_version_info().get("string", ""),
        "display": DisplayServer.get_name(),
        "renderer": RenderingServer.get_current_rendering_method(),
        "adapter": RenderingServer.get_video_adapter_name(),
        "viewport": [pixels.x, pixels.y],
        "window_pixels": [screen_pixels.x, screen_pixels.y],
        "vsync_mode": DisplayServer.window_get_vsync_mode(),
        "physics_hz": Engine.physics_ticks_per_second,
        "terrain_cells": [WORLD_CELLS.x, WORLD_CELLS.y],
        "format": "TFM2",
        "sampling_strategy": "F",
        "page_limit": PAGE_LIMIT,
        "geometry_jobs": GEOMETRY_JOBS,
        "tile_limit": TILE_LIMIT,
        "view_distance": VIEW_DISTANCE,
        "shadows": false,
        "render_target_pixels": [_render_target.x, _render_target.y],
        "scale_3d": get_viewport().scaling_3d_scale,
        "target_3d_height_px": roundi(_render_target.y * get_viewport().scaling_3d_scale),
        "editor_build": OS.has_feature("editor"), "debugger_active": EngineDebugger.is_active(),
        "fps_limit": Engine.max_fps, "display_refresh_hz": refresh_hz if is_finite(refresh_hz) and refresh_hz > 0.0 else null,
        "comparison_walk_fps": {"native": _paired_fps("native"), "540p": _paired_fps("540p")} if not _comparison_runs.is_empty() else {},
        "comparison": _comparison_runs,
        "notes": "Frame intervals exclude initial load. Pump and controller timings are wall times within the interval. Delayed viewport CPU/GPU samples are available during comparison only. Unsupported or zero-only timers are null."
    })
    return report

func _export_report() -> void:
    if _dialog_open or _comparison != null or (_elapsed_usec < 1000000 and _comparison_runs.is_empty()):
        return
    var payload := JSON.stringify(measurement(), "  ")
    var filename := "TerraForge_Dunya_FPS_%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
    var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
    if not downloads.is_empty() and _write_report(downloads.path_join(filename), payload):
        _show_notice("FPS raporu İndirilenler'e kaydedildi.")
        return
    _dialog_open = true
    _interrupt_input()
    var result := DisplayServer.file_dialog_show(
        "FPS raporunu kaydet", downloads, filename, false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
        PackedStringArray(["*.json ; JSON raporu"]),
        func(ok: bool, paths: PackedStringArray, _filter: int):
            _dialog_open = false
            if ok and not paths.is_empty():
                _show_notice("FPS raporu kaydedildi." if _write_report(paths[0], payload) else "FPS raporu yazılamadı.")
    )
    if result != OK:
        _dialog_open = false
        var local_path := "user://".path_join(filename)
        _show_notice("FPS raporu kaydedildi.\n" + ProjectSettings.globalize_path(local_path) if _write_report(local_path, payload) else "FPS raporu yazılamadı.")

func _write_report(path: String, payload: String) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(payload)
    file.flush()
    var result := file.get_error()
    file.close()
    return result == OK

func _show_notice(message: String) -> void:
    _hud.show_status(message)
    _notice_until = Time.get_ticks_msec() + 4500

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED:
            _app_paused = true
            _interrupt_input()
        NOTIFICATION_APPLICATION_RESUMED:
            _app_paused = false
        NOTIFICATION_WM_WINDOW_FOCUS_OUT:
            _window_focused = false
            _interrupt_input()
        NOTIFICATION_WM_WINDOW_FOCUS_IN:
            _window_focused = true

func _interrupt_input() -> void:
    if _comparison != null:
        _stop_comparison(false)
    _last_frame_usec = 0
    _window_usec = 0
    _window_frames = 0
    if is_node_ready():
        _hud.clear_input()

func _fail(message: String, error: Error) -> void:
    _failed = true
    _hud.set_controls_enabled(false)
    _hud.show_status("%s.\n%s" % [message, error_string(error)])

func _leave() -> void:
    if _leaving:
        return
    _leaving = true
    _hud.set_controls_enabled(false)
    if _fixture != null:
        _fixture.request_cancel()
        _hud.show_status("Menüye dönülüyor…")
    else:
        _return_to_menu()

func _return_to_menu() -> void:
    if exit_requested.get_connections().is_empty():
        get_tree().change_scene_to_file("res://main.tscn")
    else:
        exit_requested.emit()

func _exit_tree() -> void:
    get_viewport().scaling_3d_scale = _original_scale
    if _render_timing:
        RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
    if _fixture != null:
        _fixture.request_cancel()
        var result: Dictionary = _fixture.take_result()
        _fixture_dir = result.get("directory", "")
        _fixture.close()
    if is_instance_valid(_preview):
        _preview.stop_preview()
    if _fixture_dir.begins_with(FIXTURE.PREFIX):
        _remove_fixture()

func _remove_fixture() -> void:
    # Only the unique, flat directory published by this scene's builder.
    var parent := DirAccess.open("user://")
    var name := _fixture_dir.get_file()
    if parent == null or parent.is_link(name):
        return
    var directory := DirAccess.open(_fixture_dir)
    if directory == null:
        return
    for file in directory.get_files():
        if not directory.is_link(file):
            directory.remove(file)
    parent.remove(name)
