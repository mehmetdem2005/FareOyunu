extends Node3D

const PREVIEW = preload("res://isolation_preview.gd")
const PATCH := preload("res://patch.gd")
const FIXTURE = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const ORIGIN := Vector3(500.0, 0.0, 500.0)
const ARMS := ["empty", "frozen_still", "frozen_move", "live", "stats", "half_scale",
    "unshaded", "mesh_only", "hidden_mesh", "receipt", "baked_patch", "gpu_patch"]
const TOP := 8

@onready var status: Label = $Overlay/Panel/Controls/Status
@onready var start: Button = $Overlay/Panel/Controls/Start
@onready var save: Button = $Overlay/Panel/Controls/Save
var builder
var directory := ""
var patch: PATCH
var preview: PREVIEW
var plan: Array = []
var index := 0
var phase := "idle"
var arm := ""
var duration := 10.0
var auto_verify := false
var renderer := false
var interrupted := false
var initial_scale := 1.0
var open_ms := 0.0
var sample_start_unix := 0.0
var began := 0
var last := 0
var gpu_next := 0
var terminal_path := ""
var export_open := false
var doc := {}
var setup := {}
var counts_before := Vector3i.ZERO
var samples := PackedFloat64Array()
var pump := PackedFloat64Array()
var pub := PackedFloat64Array()
var sync := PackedFloat64Array()
var detail := PackedFloat64Array()
var gpu := PackedFloat64Array()
var render_cpu := PackedFloat64Array()
var worst: Array[Dictionary] = []
# Previous process invocation's work belongs to the interval ending now.
var previous_cost := Vector4.ZERO

func _ready() -> void:
    initial_scale = get_viewport().scaling_3d_scale
    renderer = DisplayServer.get_name() != "headless"
    start.pressed.connect(_start)
    save.pressed.connect(_save)
    get_viewport().size_changed.connect(_invalidate)
    auto_verify = OS.get_cmdline_user_args().has("--verify-isolation")
    if auto_verify:
        duration = 4.0
        call_deferred("_start")

func _start() -> void:
    if phase != "idle" or export_open:
        return
    interrupted = false
    terminal_path = ""
    start.hide()
    save.hide()
    status.text = "TFM2 test arazisi hazırlanıyor…"
    plan = ARMS.duplicate()
    var reverse := ARMS.duplicate()
    reverse.reverse()
    plan.append_array(reverse)
    index = 0
    doc = {"schema": "TF_ISOLATION_1", "build": JSON.parse_string(FileAccess.get_file_as_string("res://build.json")),
        "device": OS.get_model_name(), "os": OS.get_name(), "os_version": OS.get_version(),
        "godot": Engine.get_version_info()["string"], "adapter": RenderingServer.get_video_adapter_name(),
        "renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(),
        "editor": OS.has_feature("editor"), "debug": OS.is_debug_build(), "debugger": EngineDebugger.is_active(),
        "physics_hz": Engine.physics_ticks_per_second, "window_px": [get_window().size.x, get_window().size.y],
        "vsync": DisplayServer.window_get_vsync_mode(), "fps_limit": Engine.max_fps,
        "started_utc": Time.get_datetime_string_from_system(true), "arm_seconds": duration,
        "plan": plan.duplicate(), "runs": [], "state": "running",
        "fixture_cells": [1024,1024], "sampling_strategy": "F", "page_limit": 32, "geometry_jobs": 2}
    builder = FIXTURE.new()
    phase = "fixture"
    var err: Error = builder.start(Vector2i(1024, 1024))
    if err != OK:
        _finish(error_string(err))

func _invalidate() -> void:
    if phase in ["settle", "settle_end", "warm", "sample", "prepare"]:
        interrupted = true

func _notification(what: int) -> void:
    if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
        _invalidate()

func _process(_delta: float) -> void:
    if interrupted and phase != "idle":
        _finish("Pencere veya uygulama odağı değişti")
        return
    if phase == "fixture":
        var result: Dictionary = builder.take_result()
        if result["error"] == ERR_BUSY:
            return
        builder = null
        if result["error"] != OK:
            _finish(error_string(result["error"]))
            return
        directory = result["directory"]
        phase = "prepare"
    elif phase == "settle_end":
        _process_settle_end()
    elif phase == "prepare":
        _prepare()
    elif phase in ["settle", "warm", "sample"]:
        _frame()

func _prepare() -> void:
    arm = plan[index]
    get_viewport().scaling_3d_scale = 0.5 if arm == "half_scale" else 1.0
    status.text = "%d / %d   ·   %s" % [index + 1, plan.size(), arm]
    _camera(0.0)
    open_ms = 0.0
    if arm in ["baked_patch", "gpu_patch"]:
        var opened := Time.get_ticks_usec()
        patch = PATCH.new()
        add_child(patch)
        var err := patch.construct(arm == "gpu_patch")
        open_ms = (Time.get_ticks_usec() - opened) / 1000.0
        if err != OK:
            _finish(error_string(err))
            return
    elif arm != "empty":
        preview = PREVIEW.new()
        preview.region_index_format = 1
        preview.sampling_strategy = 4
        preview.geometry_job_limit = 2
        if arm in ["mesh_only", "hidden_mesh"]:
            preview.sink = "mesh"
        elif arm == "receipt":
            preview.sink = "receipt"
        preview.visible = arm not in ["receipt", "hidden_mesh"]
        add_child(preview)
        var opened := Time.get_ticks_usec()
        var err := preview.start_preview(directory, 32, 4)
        open_ms = (Time.get_ticks_usec() - opened) / 1000.0
        if err != OK:
            _finish(error_string(err))
            return
        preview.set_process(false)
        preview.set_stream_center(ORIGIN)
        if arm == "unshaded":
            preview._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if renderer:
        RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
    setup = {}
    phase = "settle"
    _reset_window()

func _reset_window() -> void:
    samples.clear()
    pump.clear()
    pub.clear()
    sync.clear()
    detail.clear()
    gpu.clear()
    render_cpu.clear()
    worst.clear()
    previous_cost = Vector4.ZERO
    began = Time.get_ticks_usec()
    last = 0
    gpu_next = began + 250000
    counts_before = _counts()

func _counts() -> Vector3i:
    return Vector3i(preview.delivered, preview.visuals, preview.shapes) if preview != null else Vector3i.ZERO

func _camera(travel: float) -> void:
    var point := ORIGIN + Vector3(travel, 0.0, 0.0)
    var ground := Vector3(point.x, 15.0, point.z)
    $Camera.position = ground + Vector3(0, 12, 14)
    $Camera.look_at(ground, Vector3.UP)

func _frame() -> void:
    var now := Time.get_ticks_usec()
    var elapsed := (now - began) / 1000000.0
    if last > 0:
        _record(now, (now - last) / 1000.0)
    last = now
    if phase == "sample" and elapsed >= duration:
        _end_arm()
        return
    if phase == "warm" and elapsed >= 1.0:
        print("TF_ISOLATION_ARM ", index + 1, " ", arm)
        sample_start_unix = Time.get_unix_time_from_system()
        phase = "sample"
        _reset_window()
        return
    if phase == "settle" and elapsed > 90.0:
        _finish("İlk arazi parçaları yüklenemedi")
        return
    # The camera poses are a function of wall time, independent of frame count.
    var travel := 0.0
    if phase == "sample" and arm != "frozen_still":
        travel = 24.0 * (1.0 - cos(TAU * minf(1.0, elapsed / duration))) * 0.5
    _camera(travel)
    var step := {"error": OK, "resident_tiles": 0, "pending_tiles": 0}
    previous_cost = Vector4.ZERO
    if preview != null and (phase == "settle" or arm not in ["frozen_still", "frozen_move"]):
        preview.set_stream_center(ORIGIN + Vector3(travel, 0, 0))
        preview.sync_us = 0
        preview.publish_us = 0
        var tick := Time.get_ticks_usec()
        step = preview.pump_stream()
        previous_cost.x = (Time.get_ticks_usec() - tick) / 1000.0
        previous_cost.y = preview.publish_us / 1000.0
        previous_cost.z = preview.sync_us / 1000.0
        if arm == "stats":
            tick = Time.get_ticks_usec()
            preview.stats()
            previous_cost.w = (Time.get_ticks_usec() - tick) / 1000.0
    if step["error"] != OK:
        _finish(error_string(step["error"]))
        return
    if phase == "settle" and (preview == null or (step["resident_tiles"] == preview.max_visible_tiles and step["pending_tiles"] == 0)):
        # Include the last publication in the setup frame before switching.
        phase = "settle_end"

func _process_settle_end() -> void:
    var now := Time.get_ticks_usec()
    _record(now, (now - last) / 1000.0)
    setup = _summary()
    setup["open_ms"] = open_ms
    phase = "warm"
    _reset_window()

func _record(now: int, frame_ms: float) -> void:
    samples.append(frame_ms)
    pump.append(previous_cost.x)
    pub.append(previous_cost.y)
    sync.append(previous_cost.z)
    detail.append(previous_cost.w)
    if worst.size() < TOP or frame_ms > float(worst.back()["frame_ms"]):
        worst.append({"frame_ms": frame_ms, "pump_ms": previous_cost.x, "publish_ms": previous_cost.y,
            "sync_and_eviction_ms": previous_cost.z, "stats_ms": previous_cost.w})
        worst.sort_custom(func(a,b): return a["frame_ms"] > b["frame_ms"])
        if worst.size() > TOP:
            worst.pop_back()
    if renderer and now >= gpu_next:
        gpu_next = now + 250000
        var rid := get_viewport().get_viewport_rid()
        var g := RenderingServer.viewport_get_measured_render_time_gpu(rid)
        var c := RenderingServer.viewport_get_measured_render_time_cpu(rid)
        if g > 0 and is_finite(g):
            gpu.append(g)
        if c > 0 and is_finite(c):
            render_cpu.append(c)

func _distribution(values: PackedFloat64Array) -> Variant:
    if values.is_empty():
        return null
    var ordered := values.duplicate()
    ordered.sort()
    var total := 0.0
    for x in ordered:
        total += x
    return {"count": ordered.size(), "mean": total / ordered.size(), "p95": ordered[ceili(0.95 * ordered.size()) - 1],
        "p99": ordered[ceili(0.99 * ordered.size()) - 1], "max": ordered[-1]}

func _summary() -> Dictionary:
    var late16 := 0
    var late33 := 0
    var late50 := 0
    for ms in samples:
        late16 += int(ms > 1000.0 / 60.0)
        late33 += int(ms > 1000.0 / 30.0)
        late50 += int(ms > 50.0)
    var frame: Variant = _distribution(samples)
    var output := _counts() - counts_before
    return {"frame_ms": frame, "fps": 1000.0 / frame["mean"] if frame != null else null,
        "over_16_67": late16, "over_33_33": late33, "over_50": late50,
        "pump_ms": _distribution(pump), "publish_ms": _distribution(pub),
        "sync_and_eviction_ms": _distribution(sync), "stats_ms": _distribution(detail),
        "viewport_gpu_ms": _distribution(gpu), "viewport_cpu_ms": _distribution(render_cpu),
        "delivered": output.x, "mesh_uploads": output.y, "height_shapes_assigned": output.z,
        "slowest_frames": worst.duplicate(true)}

func _end_arm() -> void:
    var result := _summary()
    result["arm"] = arm
    result["sequence"] = index + 1
    result["start_unix_seconds"] = sample_start_unix
    result["setup"] = setup
    var size_px: Vector2 = (get_viewport().get_stretch_transform() * get_viewport().get_visible_rect()).size
    var target := (size_px * get_viewport().scaling_3d_scale).round()
    result["target_3d_px"] = [int(target.x), int(target.y)]
    if patch != null:
        result["static_patch"] = {"chunks": patch.get_child_count(), "cells_per_side": PATCH.TILE * PATCH.SIDE,
            "triangles": PATCH.SIDE * PATCH.SIDE * PATCH.TILE * PATCH.TILE * 2, "collision": false}
    if preview != null:
        var snapshot := preview.stats()
        result["resident_tiles_end"] = snapshot["tiles"]
        result["vertices_end"] = snapshot["vertices"]
        result["pending_end"] = snapshot["pending_tiles"]
        result["effective_strategy"] = snapshot["effective_sampling_strategy"]
    doc["runs"].append(result)
    _close_preview()
    index += 1
    if index == plan.size():
        _finish("")
    else:
        phase = "prepare"

func _close_preview() -> void:
    if patch != null:
        patch.free()
        patch = null
    if preview != null:
        preview.free()
        preview = null

func _finish(reason: String) -> void:
    phase = "idle"
    _close_preview()
    if renderer:
        RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
    get_viewport().scaling_3d_scale = initial_scale
    _cleanup()
    doc["state"] = "complete" if reason.is_empty() else "interrupted"
    doc["reason"] = reason
    terminal_path = "user://TerraForge_Isolation_" + Time.get_datetime_string_from_system().replace(":", "-") + "_" + str(Time.get_ticks_usec()) + ".json"
    var saved := _write(terminal_path)
    status.text = "Ölçüm tamamlandı · %d koşul" % doc["runs"].size() if reason.is_empty() else reason
    if not saved:
        status.text += " · İç kayıt yazılamadı"
    save.disabled = false
    save.show()
    start.show()
    if auto_verify:
        print("ISOLATION_RESULT ", doc["state"], " ", ProjectSettings.globalize_path(terminal_path))
        get_tree().quit(0 if reason.is_empty() and saved else 1)

func _write(path: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(doc, "  "))
    f.flush()
    return f.get_error() == OK

func _save() -> void:
    if export_open or terminal_path.is_empty():
        return
    var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
    var name_only := terminal_path.get_file()
    if not downloads.is_empty() and _write(downloads.path_join(name_only)):
        status.text = "JSON İndirilenler'e kaydedildi."
        return
    export_open = true
    var err := DisplayServer.file_dialog_show("Ölçümü kaydet", downloads, name_only, false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
        PackedStringArray(["*.json ; JSON"]), func(ok: bool, paths: PackedStringArray, _i: int):
            export_open = false
            if ok and not paths.is_empty():
                status.text = "JSON kaydedildi." if _write(paths[0]) else "JSON yazılamadı.")
    if err != OK:
        export_open = false
        status.text = ProjectSettings.globalize_path(terminal_path)

func _cleanup() -> void:
    if builder != null:
        builder.request_cancel()
        var result: Dictionary = builder.take_result()
        directory = result.get("directory", "")
        builder.close()
        builder = null
    if directory.begins_with(FIXTURE.PREFIX):
        var dir := DirAccess.open(directory)
        if dir != null:
            for file in dir.get_files():
                if not dir.is_link(file):
                    dir.remove(file)
            DirAccess.remove_absolute(directory)
    directory = ""

func _exit_tree() -> void:
    _cleanup()
