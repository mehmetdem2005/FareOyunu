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
    var fixture_deadline: int = Time.get_ticks_msec() + 30000
    while p._fixture != null and Time.get_ticks_msec() < fixture_deadline:
        await process_frame
        OS.delay_msec(2)
    if p._fixture != null or p._path.text.is_empty():
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
    var legacy_path: String = p._path.text
    p._format.select(1)
    p._refresh_sizes()
    if p._fixture_size.item_count != 6 or p._fixture_size.get_item_id(5) != 8192:
        _fail("Missing large V2 choices", p)
        return
    p._make_fixture()
    fixture_deadline = Time.get_ticks_msec() + 30000
    while p._fixture != null and Time.get_ticks_msec() < fixture_deadline:
        await process_frame
        OS.delay_msec(2)
    if p._fixture != null or p._path.text == legacy_path:
        _fail("V2 fixture failed", p)
        return
    var v2_manifest: String = p._path.text.path_join("manifest.tfm2")
    var v2_sha: String = FileAccess.get_sha256(v2_manifest)
    if v2_sha.is_empty():
        _fail("V2 root missing", p)
        return
    for z in range(9):
        for x in range(9):
            var name: String = "r_%05d_%05d.tfr" % [x,z]
            if FileAccess.get_sha256(legacy_path.path_join(name)) != FileAccess.get_sha256(p._path.text.path_join(name)):
                _fail("Matched fixture TFR1 bytes differ", p)
                return
    for lazy in [false,true]:
        p._begin(lazy)
        var deadline: int = Time.get_ticks_msec() + 15000
        while p._running and Time.get_ticks_msec() < deadline:
            await process_frame
            OS.delay_msec(2)
        var report: Dictionary = p._reports[-1]
        if p._running or report["error"] != OK or report["index_format"] != "TFM2" or report["fixture_recipe_session_hint"] != p._reports[0]["fixture_recipe_session_hint"] or report["root_index_bytes"] <= 0 or report["shard_resident_peak"] < 1 or report["shard_resident_peak"] > p.shard_limit or report["first_focus_collision_ms_from_open_start"] == null or report["longest_sampled_collision_shape_gap_ms"] == null:
            _fail("V2 profile report " + str(report), p)
            return
    if p.report_document()["schema"] != "TF_PROFILE_3" or p._reports.size() != 4 or FileAccess.get_sha256(v2_manifest) != v2_sha:
        _fail("V2 profile identity or report", p)
        return
    p._save_report()
    if not p._label.text.begins_with("Saved:"):
        _fail("JSON report export failed", p)
        return
    p.free()
    print("PASS: matched TFM1/TFM2 81 byte-identical pages, four strict/lazy profile runs, shard metrics, collision coverage, bounded histograms, immutable manifests and JSON")
    quit(0)
