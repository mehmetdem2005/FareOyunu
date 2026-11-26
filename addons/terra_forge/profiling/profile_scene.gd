extends Node3D
## Isolated opt-in diagnostic scene. Open and run this scene, never the game.
const PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const HIST = preload("res://addons/terra_forge/core/profile_histogram.gd")
const V2 = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const INDEX = preload("res://addons/terra_forge/core/region_index_v2.gd")
const BUILDER = preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
@export_range(5.0, 1800.0, 1.0) var duration_seconds: float = 20.0
@export_range(9, 64, 1) var page_limit: int = 16
@export_range(1, 8, 1) var job_limit: int = 4
var _preview
var _camera: Camera3D
var _path: LineEdit
var _label: Label
var _buttons: Array[Button] = []
@export_range(1, 16, 1) var shard_limit: int = 4
@export var use_tile_read_view: bool = false
const COMPARISON_ORDER := [0, 3, 3, 0]
var _comparison_step := -1
var _previous_strategy := -1
var _previous_choice := 0
var _sampling_choice: OptionButton
var _budget_toggle: CheckButton
var _publication_micro_toggle: CheckButton
var _pump_micro_toggle: CheckButton
const FRAME_EVENT_LIMIT: int=8
var _slow_frame_intervals: Array[Dictionary]=[]
var _previous_process_frame: int=-1
var _hybrid_choice: OptionButton
var _comparison_kind: String=""
var _comparison_candidate: int=0
var _previous_hybrid_preset: int=0
@export var hybrid_scalar_sampling: bool=false
@export var hybrid_topology_cache: bool=false
@export var hybrid_cropped_halo: bool=false
@export var enforce_publication_budget: bool=false
@export var observe_publication_micro: bool=false
@export var observe_pump_micro: bool=false
@export_range(4096,1048576,4096) var publication_byte_target: int=131072
@export_range(100,8000,100) var publication_time_target_us: int=1000
@export_enum("Legacy flag:-1", "A direct:0", "B tile view:1", "C dense buffer:2", "E geometry worker:3", "F priority worker:4", "G scalar priority worker:5", "H cached topology worker:6", "I hybrid experimental:7") var sampling_strategy: int = -1
var _format: OptionButton
var _fixture_size: OptionButton
var _estimate: Label
var _generated: Dictionary = {}
var _generating_recipe: String = ""
var _run_format: String = ""
var _run_recipe: String = ""
var _run_settings: Dictionary = {}
var _shard_peak: int = 0
var _shard_bytes_peak: int = 0
var _gap_start: int = -1
var _startup_missing_frames := 0
var _movement_gap_max_us := 0
var _movement_gap_count := 0
var _gap_max_us: int = 0
var _mesh_hist
var _last_mesh_builds: int = 0
var _cancel_button: Button
var _fixture = null
var _running: bool = false
var _started: int = 0
var _opened: int = 0
var _previous_frame: int = 0
var _next_memory_sample: int = 0
var _first_collision: Variant = null
var _open_ms: float = 0.0
var _frame_hist
var _over_30fps_budget := 0
var _over_50ms := 0
var _late_streak := 0
var _longest_late_streak := 0
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
    _path.placeholder_text = "Read-only world (user:// or res://)"
    _path.custom_minimum_size.x = 280.0
    ui.add_child(_path)
    _format = OptionButton.new()
    _format.add_item("TFM1", 0)
    _format.add_item("TFM2", 1)
    ui.add_child(_format)
    _fixture_size = OptionButton.new()
    ui.add_child(_fixture_size)
    _estimate = Label.new()
    _estimate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _estimate.custom_minimum_size.x = 280.0
    ui.add_child(_estimate)
    _format.item_selected.connect(func(_index): _refresh_sizes())
    _fixture_size.item_selected.connect(func(_index): _refresh_estimate())
    _refresh_sizes()
    _sampling_choice = OptionButton.new()
    _sampling_choice.add_item("A direct (baseline)", 0)
    _sampling_choice.add_item("B tile view (experimental)", 1)
    _sampling_choice.add_item("C dense (experimental)", 2)
    _sampling_choice.add_item("E geometry worker (experimental)", 3)
    _sampling_choice.add_item("F priority worker (experimental)", 4)
    _sampling_choice.add_item("G scalar priority worker (experimental)", 5)
    _sampling_choice.add_item("H cached topology worker (experimental)", 6)
    _sampling_choice.add_item("I hybrid (experimental)", 7)

    _sampling_choice.select(clampi((1 if use_tile_read_view else 0) if sampling_strategy == -1 else sampling_strategy, 0, 7))
    _sampling_choice.item_selected.connect(func(index): sampling_strategy = _sampling_choice.get_item_id(index))
    ui.add_child(_sampling_choice)
    _hybrid_choice=OptionButton.new()
    for backend in ["F","G","H"]:
        _hybrid_choice.add_item("I "+backend+" / full halo")
        _hybrid_choice.add_item("I "+backend+" / cropped halo")
    _hybrid_choice.select(_hybrid_preset())
    _hybrid_choice.item_selected.connect(_apply_hybrid_preset)
    ui.add_child(_hybrid_choice)
    _budget_toggle=CheckButton.new()
    _budget_toggle.text="Publication budget (experimental)"
    _budget_toggle.button_pressed=enforce_publication_budget
    _budget_toggle.toggled.connect(func(enabled): enforce_publication_budget=enabled)
    ui.add_child(_budget_toggle)
    _publication_micro_toggle=CheckButton.new()
    _publication_micro_toggle.text="Publication micro (diagnostic)"
    _publication_micro_toggle.button_pressed=observe_publication_micro
    _publication_micro_toggle.toggled.connect(func(enabled): observe_publication_micro=enabled)
    ui.add_child(_publication_micro_toggle)
    _pump_micro_toggle=CheckButton.new()
    _pump_micro_toggle.text="Pump micro (diagnostic)"
    _pump_micro_toggle.button_pressed=observe_pump_micro
    _pump_micro_toggle.toggled.connect(func(enabled): observe_pump_micro=enabled)
    ui.add_child(_pump_micro_toggle)
    _button(ui, "Create isolated sample", _make_fixture)
    _cancel_button = Button.new()
    _cancel_button.text = "Cancel fixture generation"
    _cancel_button.custom_minimum_size.y = 42.0
    _cancel_button.disabled = true
    _cancel_button.pressed.connect(func():
        if _fixture != null:
            _fixture.request_cancel()
    )
    ui.add_child(_cancel_button)
    _button(ui, "Run strict full verification", func(): _begin(false))
    _button(ui, "Run lazy on-demand", func(): _begin(true))
    _button(ui, "Compare A / E (lazy)", _compare_strategies)
    _button(ui, "Compare I-F / selected I (ABBA)", _compare_hybrid)
    _button(ui, "Copy JSON report to clipboard", _copy_report)
    _button(ui, "Save / show JSON report", _save_report)
    _label = Label.new()
    _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label.custom_minimum_size.x = 280.0
    _label.text = "Select format and sample, or enter an existing world folder."
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
    _fixture_size.disabled = busy
    _format.disabled = busy
    _sampling_choice.disabled = busy
    _hybrid_choice.disabled = busy
    _budget_toggle.disabled = busy
    _publication_micro_toggle.disabled = busy
    _pump_micro_toggle.disabled = busy

func _refresh_sizes() -> void:
    var previous: int = _fixture_size.get_selected_id() if _fixture_size.item_count > 0 else 256
    _fixture_size.clear()
    var sizes: Array[int] = [256, 512, 1024, 2048]
    if _format.get_selected_id() == 1:
        sizes.append_array([4096, 8192])
    for size in sizes:
        _fixture_size.add_item("%dx%d cells" % [size, size], size)
    var index: int = sizes.find(previous)
    _fixture_size.select(index if index >= 0 else 0)
    _refresh_estimate()

func _refresh_estimate() -> void:
    var size: int = _fixture_size.get_selected_id()
    var dims: Vector2i = Vector2i(size, size)
    var v2: bool = _format.get_selected_id() == 1
    var plan: Dictionary = V2.preflight(dims) if v2 else BUILDER.preflight(dims)
    if plan.get("error", FAILED) != OK:
        _estimate.text = "Unsupported size"
        return
    var logical: int = int(plan["logical_upper_bytes"])
    var reserve: int = logical + (int(plan["pages"]) + int(plan.get("shards", 0))) * 8192 + 16 * 1024 * 1024
    _estimate.text = "%d pages | <= %.1f MiB logical\nFree-space gate %.1f MiB (estimate)" % [plan["pages"], float(logical) / 1048576.0, float(reserve) / 1048576.0]

func _make_fixture() -> void:
    if _running or _fixture != null:
        return
    var size: int = _fixture_size.get_selected_id()
    var dims: Vector2i = Vector2i(size, size)
    var v2: bool = _format.get_selected_id() == 1
    _generating_recipe = INDEX.sha(V2.descriptor(dims)).hex_encode()
    _fixture = V2.new() if v2 else BUILDER.new()
    var err: Error = _fixture.start(dims) if v2 else _fixture.start(dims, true)
    if err != OK:
        _fixture = null
        _label.text = "Fixture refused: " + error_string(err)
        return
    _set_busy(true)
    _cancel_button.disabled = false
    _label.text = "Generating isolated sample..."

func _poll_fixture() -> void:
    var progress: Dictionary = _fixture.progress()
    if not bool(progress["done"]):
        _label.text = "%s %d/%d" % [progress["phase"], progress["completed"], progress["total"]]
        return
    var result: Dictionary = _fixture.take_result()
    _fixture = null
    _set_busy(false)
    _cancel_button.disabled = true
    if int(result["error"]) != OK:
        _label.text = "Fixture stopped: " + error_string(int(result["error"]))
        if int(result.get("cleanup_error", OK)) != OK:
            _label.text += " | staging retained: " + str(result["remaining_staging"])
        return
    _path.text = str(result["directory"])
    if _generated.size() >= 8:
        _generated.erase(_generated.keys()[0])
    _generated[_path.text] = {"recipe": _generating_recipe, "format": _format.get_item_text(_format.selected)}
    _label.text = "Sample ready (%.1f s). Select strict or lazy." % (float(result["generation_ms"]) / 1000.0)

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

# Explicit diagnostic policy only. No implicit per-device selection or
# benchmark at gameplay startup. Same halo is held across the ABBA pair.
func _hybrid_preset() -> int:
    if hybrid_topology_cache and not hybrid_scalar_sampling:
        return -1
    return (4 if hybrid_topology_cache else (2 if hybrid_scalar_sampling else 0))+(1 if hybrid_cropped_halo else 0)

func _apply_hybrid_preset(index: int) -> void:
    if index<0 or index>5:
        return
    hybrid_scalar_sampling=index>=2
    hybrid_topology_cache=index>=4
    hybrid_cropped_halo=(index & 1)==1
    _hybrid_choice.select(index)

func _compare_hybrid() -> void:
    if _running or _fixture!=null or _comparison_step>=0:
        return
    if _path.text.strip_edges().is_empty():
        _label.text="Create an isolated sample first."
        return
    var candidate: int=_hybrid_preset()
    if candidate<2:
        _label.text="Select I-G or I-H for comparison."
        return
    _previous_strategy=sampling_strategy
    _previous_choice=_sampling_choice.selected
    _previous_hybrid_preset=candidate
    _comparison_candidate=candidate
    _comparison_kind="I_F_vs_candidate_same_halo_ABBA"
    _comparison_step=0
    _begin_comparison_step()

func _compare_strategies() -> void:
    if _running or _fixture != null or _comparison_step >= 0:
        return
    if _path.text.strip_edges().is_empty():
        _label.text = "Create an isolated sample first."
        return
    _previous_strategy = sampling_strategy
    _previous_choice = _sampling_choice.selected
    _comparison_kind="A_E_ABBA"
    _comparison_step = 0
    _begin_comparison_step()

func _begin_comparison_step() -> void:
    if _comparison_kind=="I_F_vs_candidate_same_halo_ABBA":
        sampling_strategy=7
        var preset: int=(_comparison_candidate & 1) if _comparison_step==0 or _comparison_step==3 else _comparison_candidate
        _apply_hybrid_preset(preset)
    else:
        sampling_strategy=COMPARISON_ORDER[_comparison_step]
    _sampling_choice.select(_sampling_choice.get_item_index(sampling_strategy))
    _begin(true)

func _begin(lazy: bool) -> void:
    if _running or _fixture != null or _path.text.strip_edges().is_empty():
        return
    _set_busy(true)
    _mode = "on_demand" if lazy else "strict"
    _run_path = _path.text.strip_edges()
    _run_format = _format.get_item_text(_format.selected)
    var generated: Dictionary = _generated.get(_run_path, {})
    _run_recipe = str(generated.get("recipe", "")) if generated.get("format", "") == _run_format else ""
    _run_seconds = duration_seconds
    _reset_frame_samples()
    _pump_hist = HIST.new()
    _mesh_hist = HIST.new()
    _last_mesh_builds = 0
    _shard_peak = 0
    _shard_bytes_peak = 0
    _gap_start = -1
    _startup_missing_frames = 0
    _movement_gap_max_us = 0
    _movement_gap_count = 0
    _gap_max_us = 0
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
    _preview.region_index_format = _format.get_selected_id()
    _preview.resident_shard_limit = shard_limit
    _preview.use_tile_read_view = use_tile_read_view
    _preview.sampling_strategy = sampling_strategy
    _preview.hybrid_scalar_sampling=sampling_strategy==7 and hybrid_scalar_sampling
    _preview.hybrid_topology_cache=sampling_strategy==7 and hybrid_topology_cache
    _preview.hybrid_cropped_halo=sampling_strategy==7 and hybrid_cropped_halo
    _preview.observe_publication = true
    _preview.observe_publication_micro = observe_publication_micro
    _preview.observe_pump_micro = observe_pump_micro
    _preview.enforce_publication_budget=enforce_publication_budget
    _preview.publication_byte_target=publication_byte_target
    _preview.publication_time_target_us=publication_time_target_us
    _run_settings = {"page_limit": page_limit, "job_limit": job_limit, "shard_limit": shard_limit if _run_format == "TFM2" else 0, "view_distance": _preview.view_distance, "high_detail_distance": _preview.high_detail_distance, "medium_detail_distance": _preview.medium_detail_distance, "max_visible_tiles": _preview.max_visible_tiles, "tile_updates_per_frame": _preview.tile_updates_per_frame, "max_tile_work_ms": _preview.max_tile_work_ms, "viewport": [get_viewport().size.x, get_viewport().size.y]}
    _run_settings["use_tile_read_view"] = use_tile_read_view
    _run_settings["sampling_strategy"] = _preview.resolved_sampling_strategy()
    _run_settings["effective_sampling_strategy"] = (6 if hybrid_topology_cache else (5 if hybrid_scalar_sampling else 4)) if sampling_strategy==7 else _preview.resolved_sampling_strategy()
    _run_settings["hybrid_scalar_sampling"]=_preview.hybrid_scalar_sampling
    _run_settings["hybrid_topology_cache"]=_preview.hybrid_topology_cache
    _run_settings["hybrid_cropped_halo"]=_preview.hybrid_cropped_halo
    _run_settings["publication_micro"]=observe_publication_micro
    _run_settings["pump_micro"]=observe_pump_micro
    _run_settings["publication_budget"]=enforce_publication_budget
    _run_settings["publication_byte_target"]=publication_byte_target
    _run_settings["publication_time_target_us"]=publication_time_target_us
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
    _label.text = _run_format + " " + _mode + " running..."

func _process(_delta: float) -> void:
    if _fixture != null:
        _poll_fixture()
        return
    if not _running:
        return
    var now: int = Time.get_ticks_usec()
    var elapsed: float = float(now - _opened) / 1000000.0
    if _previous_frame > 0:
        _record_frame_interval(now - _previous_frame)
        if bool(_run_settings.get("publication_micro",false)) or bool(_run_settings.get("pump_micro",false)):
            _record_slow_frame_interval(_previous_process_frame,Engine.get_process_frames(),now-_previous_frame)
    _previous_frame = now
    _previous_process_frame=Engine.get_process_frames()
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
    _shard_peak = maxi(_shard_peak, int(src.get("shard_resident", 0)))
    _shard_bytes_peak = maxi(_shard_bytes_peak, int(src.get("shard_resident_bytes", 0)))
    var builds: int = int(s.get("mesh_builds", 0))
    if builds > _last_mesh_builds:
        _mesh_hist.add(float(s.get("last_build_ms", 0.0)))
        _last_mesh_builds = builds
    _coverage_frames += 1
    if _preview.has_collision_at(focus):
        if _gap_start >= 0:
            if _first_collision != null:
                _movement_gap_max_us = maxi(_movement_gap_max_us, now - _gap_start)
            _gap_max_us = maxi(_gap_max_us, now - _gap_start)
            _gap_start = -1
        if _first_collision == null:
            _first_collision = float(Time.get_ticks_usec() - _started) / 1000.0
    else:
        _missing_frames += 1
        if _first_collision == null:
            _startup_missing_frames += 1
        elif _gap_start < 0:
            _movement_gap_count += 1
        if _gap_start < 0:
            _gap_start = now
    if now >= _next_memory_sample:
        _memory()
        _next_memory_sample = now + 500000
        _label.text = "%s %.1f/%.1fs | tiles %d | pages %d" % [_mode, elapsed, _run_seconds, int(s.get("tiles", 0)), int(src.get("resident", 0))]
    if int(progress.get("error", ERR_FILE_CORRUPT)) != OK:
        _finish(int(progress["error"]))
    elif elapsed >= _run_seconds:
        _finish(OK)

func _reset_frame_samples() -> void:
    _slow_frame_intervals.clear()
    _previous_process_frame=-1
    _frame_hist = HIST.new()
    _over_30fps_budget = 0
    _over_50ms = 0
    _late_streak = 0
    _longest_late_streak = 0

func _record_frame_interval(interval_us: int) -> void:
    _frame_hist.add(float(interval_us) / 1000.0)
    if interval_us * 30 > 1000000:
        _over_30fps_budget += 1
        _late_streak += 1
        _longest_late_streak = maxi(_longest_late_streak, _late_streak)
    else:
        _late_streak = 0
    if interval_us > 50000:
        _over_50ms += 1

# Bounded wall intervals keyed to the process invocation at the start.
func _record_slow_frame_interval(start_frame: int,end_frame: int,elapsed_us: int) -> void:
    if start_frame<0 or end_frame<=start_frame or elapsed_us*30<=1000000:
        return
    if _slow_frame_intervals.size()>=FRAME_EVENT_LIMIT and elapsed_us<=int(_slow_frame_intervals.back()["elapsed_us"]):
        return
    var i: int=0
    while i<_slow_frame_intervals.size() and int(_slow_frame_intervals[i]["elapsed_us"])>=elapsed_us:
        i+=1
    _slow_frame_intervals.insert(i,{"start_frame":start_frame,"observed_frame":end_frame,"elapsed_us":elapsed_us})
    if _slow_frame_intervals.size()>FRAME_EVENT_LIMIT:
        _slow_frame_intervals.pop_back()

func _frame_micro_report(publication: Dictionary,pump: Dictionary) -> Dictionary:
    if not bool(_run_settings.get("publication_micro",false)) and not bool(_run_settings.get("pump_micro",false)):
        return {}
    var joined: Array[Dictionary]=[]
    for interval in _slow_frame_intervals:
        var item: Dictionary=interval.duplicate()
        for source in ["publication","pump"]:
            var events: Array=[]
            var report: Dictionary=publication if source=="publication" else pump
            for event in report.get("slow_events",[]):
                if int(event.get("frame",-1))==int(interval["start_frame"]):
                    events.append(event.duplicate(true))
            item[source+"_events"]=events
        joined.append(item)
    return {"schema":"TF_FRAME_MICRO_JOIN_1","limit":FRAME_EVENT_LIMIT,"intervals":joined,"notes":"Wall-clock intervals include scheduling/render waits. Exact start process-frame match only; absent event may be below threshold or outside independent top-eight retention. No causal or GPU attribution."}

func _finish(status: Error) -> void:
    _running = false
    _memory()
    var s: Dictionary = _preview.stats()
    var src: Dictionary = s.get("source", {})
    var io: Dictionary = _preview.io_profile()
    var pipeline: Dictionary = _preview.pipeline_profile()
    var micro: Dictionary = _preview.publication_micro_profile()
    var pump_micro: Dictionary = _preview.pump_micro_profile()
    var end: int = Time.get_ticks_usec()
    if _gap_start >= 0:
        if _first_collision != null:
            _movement_gap_max_us = maxi(_movement_gap_max_us, end - _gap_start)
        _gap_max_us = maxi(_gap_max_us, end - _gap_start)
    var rss_end: Variant = _rss()
    _preview.stop_preview()
    var shutdown_ms: float = float(Time.get_ticks_usec() - end) / 1000.0
    _preview.free()
    _preview = null
    var report: Dictionary = {
        "mode": _mode, "world": _run_path, "error": int(status),
        "index_format": _run_format, "fixture_recipe_session_hint": _run_recipe if not _run_recipe.is_empty() else null,
        "snapshot_id": src.get("snapshot_id", "") if _run_format == "TFM2" else null,
        "route": "normalized_sine_v1", "settings": _run_settings,
        "root_index_bytes": src.get("root_index_bytes", 0),
        "dense_payload_peak_bytes": s.get("dense_payload_peak_bytes", 0),
        "publication": s.get("publication", {}),
        "publication_micro": micro,
        "pump_micro": pump_micro,
        "frame_micro_join": _frame_micro_report(micro,pump_micro),
        "geometry_worker": s.get("geometry_worker", {}),
        "geometry_copy_ms": s.get("geometry_copy_ms", {}), "geometry_queue_ms": s.get("geometry_queue_ms", {}),
        "geometry_worker_ms": s.get("geometry_worker_ms", {}), "geometry_delivery_ms": s.get("geometry_delivery_ms", {}),
        "geometry_publish_ms": s.get("geometry_publish_ms", {}), "geometry_publish_peak_per_pump": s.get("geometry_publish_peak_per_pump", 0),
        "accepted_page_reloads": maxi(0, int(src.get("disk_reads", 0)) - int(src.get("pages_verified_on_demand", 0))),
        "direct_height_reads": src.get("direct_height_reads", 0), "lru_touches": src.get("lru_touches", 0),
        "tile_view_acquires": src.get("tile_view_acquires", 0), "tile_view_reads": src.get("tile_view_reads", 0),
        "tile_view_page_touches": src.get("tile_view_page_touches", 0), "tile_view_peak_pages": src.get("tile_view_peak_pages", 0),
        "shard_resident_peak": _shard_peak, "shard_resident_bytes_peak": _shard_bytes_peak,
        "shard_hits": src.get("shard_hits", 0), "shard_misses": src.get("shard_misses", 0),
        "shard_loads": src.get("shard_loads", 0), "shard_evictions": src.get("shard_evictions", 0),
        "verification_bitmap_bytes": src.get("verification_bitmap_bytes", 0), "terminal_error_bytes": src.get("terminal_error_bytes", 0),
        "mesh_build_pump_sample_ms": _mesh_hist.report(), "mesh_builds": s.get("mesh_builds", 0),
        "startup_frames_without_shape": _startup_missing_frames,
        "post_ready_frames_without_shape": _missing_frames - _startup_missing_frames,
        "post_ready_shape_gap_count": _movement_gap_count,
        "longest_post_ready_shape_gap_ms": float(_movement_gap_max_us) / 1000.0 if _first_collision != null else null,
        "longest_sampled_collision_shape_gap_ms": float(_gap_max_us) / 1000.0 if _coverage_frames > 0 else null,
        "rss_end_before_shutdown_bytes": rss_end,
        "requested_seconds": _run_seconds, "actual_stream_seconds": float(end - _opened) / 1000000.0,
        "page_limit": page_limit, "job_limit": job_limit, "open_ms": _open_ms,
        "manifest_verify_ms": src.get("open_verify_ms", null),
        "first_focus_collision_ms_from_open_start": _first_collision,
        "frame_intervals_over_30fps_budget": _over_30fps_budget,
        "frame_intervals_over_50ms": _over_50ms,
        "longest_consecutive_over_30fps_budget": _longest_late_streak,
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
    if _comparison_step >= 0:
        report["comparison_step"] = _comparison_step + 1
        report["comparison_kind"]=_comparison_kind
    _reports.append(report)
    _set_busy(false)
    _label.text = "%s: %s | open %.2f ms | collision %s ms\nSave JSON for complete report." % [_mode, error_string(status), _open_ms, str(_first_collision)]

    if _comparison_step >= 0:
        _comparison_step += 1
        if status == OK and _comparison_step < COMPARISON_ORDER.size():
            _begin_comparison_step()
        else:
            _comparison_step = -1
            sampling_strategy = _previous_strategy
            _sampling_choice.select(_previous_choice)
            var hybrid_comparison: bool=_comparison_kind=="I_F_vs_candidate_same_halo_ABBA"
            if hybrid_comparison:
                _apply_hybrid_preset(_previous_hybrid_preset)
            _comparison_kind=""
            if status == OK:
                _label.text = ("I comparison complete. Copy JSON report." if hybrid_comparison else "A / E comparison complete. Copy JSON report.")

func report_document() -> Dictionary:
    return {
        "schema": "TF_PROFILE_3", "os": OS.get_name(), "os_version": OS.get_version(),
        "device_model": OS.get_model_name(), "godot": Engine.get_version_info().get("string", ""),
        "display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
        "headless": DisplayServer.get_name() == "headless",
        "notes": "Frame intervals include scheduler/render waits; not GPU timings. RSS is sampled process-wide; static memory is separate. Worker IO includes accepted success/failure results only, excludes strict scan and canceled jobs. Pipeline splits queue wait, worker service and result delivery; counts include canceled jobs separately. First focus collision means shape attached, not a raycast. No OS cache flush; repeat in opposite order. Fixture generation excluded. Session recipe is a hint, not verification of external edits. Compare identical extent, settings and route; normalized route speed varies with world size. Shard counters include canceled work. Mesh sample is cumulative pump-to-last-build, not pure mesh CPU or GPU. Collision gap is sampled shape coverage, not physics raycast. Strict scan blocks the opening call.",
        "runs": _reports.duplicate(true)
    }

func _report_json() -> String:
    return JSON.stringify(report_document(), "  ")

func _copy_report() -> void:
    if _running or _reports.is_empty():
        _label.text = "Finish at least one profile run before copying."
        return
    DisplayServer.clipboard_set(_report_json())
    _label.text = "JSON copied. Paste it into your ChatGPT message."

func _save_report() -> void:
    if _running or _reports.is_empty():
        return
    var report_text: String = _report_json()
    var path: String = "user://tf_profile_report_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec()) + ".json"
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        _label.text = "Could not save report."
        return
    file.store_string(report_text)
    file.flush()
    var result: Error = file.get_error()
    file.close()
    _label.text = "Saved: " + ProjectSettings.globalize_path(path) if result == OK else "Report write failed."
    if result == OK and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
        DisplayServer.clipboard_set(report_text)
        _label.text += "\nJSON copied."

func _exit_tree() -> void:
    if _fixture != null:
        _fixture.close()
        _fixture = null
    if is_instance_valid(_preview):
        _preview.stop_preview()
