extends SceneTree
const HIST = preload("res://addons/terra_forge/core/profile_histogram.gd")
const SCENE = preload("res://addons/terra_forge/profiling/profile_scene.tscn")
const PROFILE = preload("res://addons/terra_forge/profiling/profile_scene.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String, node: Node = null) -> void:
    if node != null:
        node.free()
    push_error("TerraForge profile: " + message)
    quit(1)

func _run() -> void:
    var h = HIST.new()
    if h.report()["p95_upper_ms"] != null:
        _fail("Empty histogram invented a percentile")
        return
    for i in range(95):
        h.add(2.0)
    for i in range(4):
        h.add(40.0)
    h.add(6000.0)
    h.add(-1.0)
    var hist: Dictionary = h.report()
    if hist["count"] != 100 or hist["p95_upper_ms"] != 2.0 or hist["p99_upper_ms"] != 40.0 or hist["overflow"] != 1 or hist["max_ms"] != 6000.0:
        _fail("Histogram rank/bounds/overflow incorrect")
        return
    if PROFILE.parse_rss("VmRSS:\t 123 kB") != 125952 or PROFILE.parse_rss("VmRSS: broken") != null:
        _fail("RSS parser invented unsupported memory")
        return
    var p = SCENE.instantiate()
    root.add_child(p)
    p._make_fixture()
    if p._path.text.is_empty():
        _fail("Could not prepare isolated fixture", p)
        return
    var manifest: String = p._path.text + "/manifest.tfm"
    var before: String = FileAccess.get_sha256(manifest)
    if before.is_empty():
        _fail("Missing fixture manifest", p)
        return
    p.duration_seconds = 2.5
    for lazy in [false, true]:
        p._begin(lazy)
        var deadline: int = Time.get_ticks_msec() + 15000
        while p._running and Time.get_ticks_msec() < deadline:
            await process_frame
            OS.delay_msec(2)
        if p._running or p._reports.is_empty():
            _fail("Profile timed out", p)
            return
        var r: Dictionary = p._reports[-1]
        if r["error"] != OK or r["first_focus_collision_ms_from_open_start"] == null or int(r["resident_pages_peak"]) > p.page_limit or int(r["frame_interval_ms"]["count"]) < 1 or int(r["accepted_worker_io_ms"].get("count", 0)) < 1:
            _fail("Missing genuine collision/frame/worker sample: " + str(r), p)
            return
        if r["mode"] != ("on_demand" if lazy else "strict"):
            _fail("Wrong verification mode in report", p)
            return
    if p.report_document()["runs"].size() != 2 or FileAccess.get_sha256(manifest) != before:
        _fail("Missing comparison or modified source manifest", p)
        return
    p._save_report()
    if not p._label.text.begins_with("Saved:"):
        _fail("JSON report export failed", p)
        return
    p.free()
    print("PASS: bounded histograms, nullable RSS, isolated strict/lazy scene, first focus collision, worker IO, JSON and immutable manifest")
    quit(0)
