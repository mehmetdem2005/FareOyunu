extends Node3D
## Isolated opt-in diagnostic scene. Open and run this scene, never the game.
const PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const HIST = preload("res://addons/terra_forge/core/profile_histogram.gd")
const HEIGHT = preload("res://addons/terra_forge/core/height_store.gd")
const EXPORT = preload("res://addons/terra_forge/core/region_export.gd")
@export_range(5.0, 1800.0, 1.0) var duration_seconds: float = 20.0
@export_range(9, 64, 1) var page_limit: int = 16
@export_range(1, 8, 1) var job_limit: int = 4
var _preview
var _camera: Camera3D
var _path: LineEdit
var _label: Label
var _buttons: Array[Button] = []
var _running: bool = false
var _started: int = 0
var _opened: int = 0
var _previous_frame: int = 0
var _next_memory_sample: int = 0
var _first_collision: Variant = null
var _open_ms: float = 0.0
var _frame_hist
var _pump_hist
var _rss_baseline: Variant = null
var _rss_peak: Variant = null
var _static_peak: Variant = null
var _page_peak: int = 0
var _tile_peak: int = 0
var _vertex_peak: int = 0
var _coverage_frames: int = 0
var _missing_frames: int = 0
var _mode: String = ""
var _reports: Array[Dictionary] = []
var _run_path: String = ""
var _extent: Vector2 = Vector2.ZERO
var _run_seconds: float = 0.0

func _ready() -> void:
    _camera = Camera3D.new()
    _camera.current = true
    _camera.far = 2000.0
    add_child(_camera)
    var light: DirectionalLight3D = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
    add_child(light)
    var layer: CanvasLayer = CanvasLayer.new()
    add_child(layer)
    var panel: PanelContainer = PanelContainer.new()
    panel.position = Vector2(8, 8)
    layer.add_child(panel)
    var ui: VBoxContainer = VBoxContainer.new()
    panel.add_child(ui)
    _path = LineEdit.new()
    _path.placeholder_text = "TFM1 folder (user:// or res://)"
    _path.custom_minimum_size.x = 280.0
    ui.add_child(_path)
    _button(ui, "Create isolated 256x256 sample", _make_fixture)
    _button(ui, "Run strict full verification", func(): _begin(false))
    _button(ui, "Run lazy on-demand", func(): _begin(true))
    _button(ui, "Save / show JSON report", _save_report)
    _label = Label.new()
    _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label.custom_minimum_size.x = 280.0
    _label.text = "Choose sample or existing read-only TFM1 folder."
    ui.add_child(_label)

func _button(parent: VBoxContainer, title: String, action: Callable) -> void:
    var button: Button = Button.new()
    button.text = title
    button.custom_minimum_size.y = 42.0
    parent.add_child(button)
    button.pressed.connect(action)
    _buttons.append(button)

func _set_busy(busy: bool) -> void:
    for button in _buttons:
        button.disabled = busy
    _path.editable = not busy

func _make_fixture() -> void:
    if _running:
        return
    # Explicit user action; never write to a chosen real world directory.
    var prefix: String = "user://tf_profile_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec())
    var source = HEIGHT.new()
    source.initialize(Vector2i(256, 256), 1.0)
    for z in range(257):
        for x in range(257):
            source.heights[source.index_of(x, z)] = 8.0 + 3.0 * sin(float(x) * 0.04) + 4.0 * cos(float(z) * 0.035)
    var err: Error = source.save_file(prefix + ".tfh")
    if err == OK:
        err = int(EXPORT.export_file(prefix + ".tfh", prefix + "_world", 4).get("error", ERR_FILE_CORRUPT))
    if err != OK:
        _label.text = "Fixture failed: " + error_string(err)
        return
    _path.text = prefix + "_world"
    _label.text = "Sample ready. Select strict or lazy."

# Linux/Android process resident memory, NOT system free RAM or Godot static memory.
# Missing or restricted procfs stays null; only read once per 500 ms.
static func parse_rss(text: String) -> Variant:
    for line in text.split("\n"):
        if line.begins_with("VmRSS:"):
            var fields: PackedStringArray = line.substr(6).strip_edges().replace("\t", " ").split(" ", false)
            if fields.size() == 2 and fields[0].is_valid_int() and fields[1] == "kB" and int(fields[0]) >= 0:
                return int(fields[0]) * 1024
    return null

static func _rss() -> Variant:
    if OS.get_name() not in ["Linux", "Android"]:
        return null
    var f: FileAccess = FileAccess.open("/proc/self/status", FileAccess.READ)
    if f == null:
        return null
    # procfs often reports a zero length, so use line reads rather than get_as_text.
    for i in range(128):
        var line: String = f.get_line()
        if line.begins_with("VmRSS:"):
            f.close()
            return parse_rss(line)
        if f.eof_reached():
            break
    f.close()
    return null

func _memory() -> void:
    var rss: Variant = _rss()
    if rss != null:
        _rss_peak = rss if _rss_peak == null else maxi(int(_rss_peak), int(rss))
    var stat: float = Performance.get_monitor(Performance.MEMORY_STATIC)
    if stat > 0:
        _static_peak = int(stat) if _static_peak == null else maxi(int(_static_peak), int(stat))

func _begin(lazy: bool) -> void:
    if _running or _path.text.strip_edges().is_empty():
        return
    _set_busy(true)
    _mode = "on_demand" if lazy else "strict"
    _run_path = _path.text.strip_edges()
    _run_seconds = duration_seconds
    _frame_hist = HIST.new()
    _pump_hist = HIST.new()
    _first_collision = null
    _extent = Vector2.ZERO
    _rss_baseline = _rss()
    _rss_peak = _rss_baseline
    _static_peak = null
    _page_peak = 0
    _tile_peak = 0
    _vertex_peak = 0
    _coverage_frames = 0
    _missing_frames = 0
    _preview = PREVIEW.new()
    _preview.verify_pages_on_demand = lazy
    add_child(_preview)
    _started = Time.get_ticks_usec()
    var status: Error = _preview.start_preview(_run_path, page_limit, job_limit)
    _opened = Time.get_ticks_usec()
    _open_ms = float(_opened - _started) / 1000.0
    # Disable autonomous pumping: exactly one timed pump per actual scene frame.
    _preview.set_process(false)
    if status != OK:
        _finish(status)
        return
    _preview.enable_io_profile()
    _extent = _preview.world_extent()
    _previous_frame = 0
    _next_memory_sample = 0
    _running = true
    _label.text = _mode + " running..."

func _process(_delta: float) -> void:
    if not _running:
        return
    var now: int = Time.get_ticks_usec()
    var elapsed: float = float(now - _opened) / 1000000.0
    if _previous_frame > 0:
        _frame_hist.add(float(now - _previous_frame) / 1000.0)
    _previous_frame = now
    # Identical route for both modes; fixed initial focus for two seconds.
    var t: float = clampf((elapsed - 2.0) / maxf(1.0, _run_seconds - 2.0), 0.0, 1.0)
    var focus: Vector3 = Vector3(_extent.x * lerpf(0.15, 0.85, t), 0.0, _extent.y * (0.5 - 0.35 * cos(t * TAU)))
    _camera.position = focus + Vector3(0.0, 36.0, 24.0)
    _camera.look_at(focus, Vector3.UP)
    _preview.set_stream_center(focus)
    var tick: int = Time.get_ticks_usec()
    var progress: Dictionary = _preview.pump_stream()
    _pump_hist.add(float(Time.get_ticks_usec() - tick) / 1000.0)
    var s: Dictionary = _preview.stats()
    var src: Dictionary = s.get("source", {})
    _page_peak = maxi(_page_peak, int(src.get("resident", 0)))
    _tile_peak = maxi(_tile_peak, int(s.get("tiles", 0)))
    _vertex_peak = maxi(_vertex_peak, int(s.get("vertices", 0)))
    _coverage_frames += 1
    if _preview.has_collision_at(focus):
        if _first_collision == null:
            _first_collision = float(Time.get_ticks_usec() - _started) / 1000.0
    else:
        _missing_frames += 1
    if now >= _next_memory_sample:
        _memory()
        _next_memory_sample = now + 500000
        _label.text = "%s %.1f/%.1fs | tiles %d | pages %d" % [_mode, elapsed, _run_seconds, int(s.get("tiles", 0)), int(src.get("resident", 0))]
    if int(progress.get("error", ERR_FILE_CORRUPT)) != OK:
        _finish(int(progress["error"]))
    elif elapsed >= _run_seconds:
        _finish(OK)

func _finish(status: Error) -> void:
    _running = false
    _memory()
    var s: Dictionary = _preview.stats()
    var src: Dictionary = s.get("source", {})
    var io: Dictionary = _preview.io_profile()
    var pipeline: Dictionary = _preview.pipeline_profile()
    var end: int = Time.get_ticks_usec()
    _preview.stop_preview()
    var shutdown_ms: float = float(Time.get_ticks_usec() - end) / 1000.0
    _preview.free()
    _preview = null
    var report: Dictionary = {
        "mode": _mode, "world": _run_path, "error": int(status),
        "requested_seconds": _run_seconds, "actual_stream_seconds": float(end - _opened) / 1000000.0,
        "page_limit": page_limit, "job_limit": job_limit, "open_ms": _open_ms,
        "manifest_verify_ms": src.get("open_verify_ms", null),
        "first_focus_collision_ms_from_open_start": _first_collision,
        "shutdown_ms": shutdown_ms, "frame_interval_ms": _frame_hist.report(),
        "main_thread_pump_ms": _pump_hist.report(), "accepted_worker_io_ms": io,
        "io_pipeline": pipeline,
        "io_submitted": src.get("submitted", 0), "io_accepted": src.get("accepted_results", 0),
        "io_cancelled_pending": src.get("cancelled_pending", 0), "io_cancelled_finished": src.get("cancelled_finished", 0),
        "io_cancelled_inflight": src.get("cancelled_inflight", 0), "io_pending_at_stop": int(src.get("outstanding", 0)) + int(src.get("inflight", 0)) + int(src.get("finished", 0)),
        "worker_wake_posts": src.get("wake_posts", 0), "worker_wake_cycles": src.get("wake_cycles", 0),
        "rss_baseline_bytes": _rss_baseline, "rss_peak_sampled_bytes": _rss_peak,
        "godot_static_peak_sampled_bytes": _static_peak,
        "resident_pages_peak": _page_peak, "resident_tiles_peak": _tile_peak,
        "vertices_peak": _vertex_peak, "focus_frames": _coverage_frames,
        "focus_frames_without_collision_shape": _missing_frames,
        "pages_verified": src.get("pages_verified_on_demand", 0),
        "manifest_pages": src.get("manifest_entries", 0),
        "disk_reads": src.get("disk_reads", 0), "worker_errors": src.get("worker_errors", 0),
        "cache_evictions": src.get("evictions", 0),
        "blocked_tiles_final": s.get("blocked_tiles", 0),
        "world_extent": [_extent.x, _extent.y]
    }
    # Keep reports bounded for long phone sessions.
    if _reports.size() >= 8:
        _reports.pop_front()
    _reports.append(report)
    _set_busy(false)
    _label.text = "%s: %s | open %.2f ms | collision %s ms\nSave JSON for complete report." % [_mode, error_string(status), _open_ms, str(_first_collision)]

func report_document() -> Dictionary:
    return {
        "schema": "TF_PROFILE_2", "os": OS.get_name(), "os_version": OS.get_version(),
        "device_model": OS.get_model_name(), "godot": Engine.get_version_info().get("string", ""),
        "display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
        "headless": DisplayServer.get_name() == "headless",
        "notes": "Frame intervals include scheduler/render waits; not GPU timings. RSS is sampled process-wide; static memory is separate. Worker IO includes accepted success/failure results only, excludes strict scan and canceled jobs. Pipeline splits queue wait, worker service and result delivery; counts include canceled jobs separately. First focus collision means shape attached, not a raycast. No OS cache flush; repeat in opposite order. Fixture generation excluded.",
        "runs": _reports.duplicate(true)
    }

func _save_report() -> void:
    if _running or _reports.is_empty():
        return
    var path: String = "user://tf_profile_report_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec()) + ".json"
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        _label.text = "Could not save report."
        return
    file.store_string(JSON.stringify(report_document(), "  "))
    file.flush()
    var result: Error = file.get_error()
    file.close()
    _label.text = "Saved: " + ProjectSettings.globalize_path(path) if result == OK else "Report write failed."

func _exit_tree() -> void:
    if is_instance_valid(_preview):
        _preview.stop_preview()
