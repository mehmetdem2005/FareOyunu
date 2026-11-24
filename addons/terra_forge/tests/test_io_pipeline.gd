extends SceneTree
const ASYNC = preload("res://addons/terra_forge/core/async_region_source.gd")
const HEIGHT = preload("res://addons/terra_forge/core/height_store.gd")
const EXPORT = preload("res://addons/terra_forge/core/region_export.gd")

func _initialize() -> void:
    var prefix: String = "user://tf_io_pipeline_" + str(Time.get_ticks_usec())
    var h = HEIGHT.new()
    h.initialize(Vector2i(128, 128), 1.0)
    if h.save_file(prefix + ".tfh") != OK or EXPORT.export_file(prefix + ".tfh", prefix + "_world", 4).get("error", ERR_FILE_CORRUPT) != OK:
        _fail("fixture", null)
        return
    var src = ASYNC.new()
    if src.open(prefix + "_world", 9, 3, false) != OK:
        _fail("open", src)
        return
    src.collect_io_profile = true
    # Burst cancellation repeatedly, without relying on worker scheduling.
    for epoch in range(1, 1001):
        for x in range(3):
            src.request_page(Vector2i(x, epoch % 5))
        if src.set_generation(epoch) != OK or not _conserved(src.stats()):
            _fail("epoch accounting or bounded admission", src)
            return
    var target: Vector2i = Vector2i(4, 4)
    var deadline: int = Time.get_ticks_msec() + 5000
    while src.page_status(target) == ERR_BUSY and Time.get_ticks_msec() < deadline:
        src.request_page(target)
        src.poll_results(3)
        OS.delay_msec(1)
    if src.page_status(target) != OK:
        _fail("new generation starved", src)
        return
    var stats: Dictionary = src.stats()
    if not _conserved(stats) or int(stats["cancelled_pending"]) + int(stats["cancelled_finished"]) + int(stats["cancelled_inflight"]) < 1:
        _fail("cancelled requests invisible", src)
        return
    var profile: Dictionary = src.pipeline_profile()
    for key in ["queue_wait_ms", "worker_service_ms", "delivery_wait_ms", "request_to_accept_ms"]:
        if int(profile[key]["count"]) != int(stats["accepted_results"]) or float(profile[key]["max_ms"]) < 0.0:
            _fail("latency stage missing", src)
            return
    if float(profile["request_to_accept_ms"]["mean_ms"]) < float(profile["worker_service_ms"]["mean_ms"]):
        _fail("end-to-end latency shorter than service", src)
        return
    if int(stats["wake_posts"]) > int(stats["submitted"]) or int(stats["wake_cycles"]) > int(stats["wake_posts"]):
        _fail("unbalanced wake ownership", src)
        return
    src.close()
    if src.open(prefix + "_world", 9, 1, false) != OK:
        _fail("reopen", src)
        return
    stats = src.stats()
    if int(stats["submitted"]) != 0 or int(stats["wake_posts"]) != 0 or int(stats["wake_cycles"]) != 0 or src.pipeline_profile()["queue_wait_ms"]["count"] != 0:
        _fail("stale wake/counters after reopen", src)
        return
    src.close()
    print("PASS: binary worker wake, 1000 camera epochs, bounded conservation, stage latency, close/reopen reset")
    quit(0)

func _conserved(s: Dictionary) -> bool:
    var outstanding: int = int(s["outstanding"]) + int(s["inflight"]) + int(s["finished"])
    var accounted: int = outstanding + int(s["accepted_results"]) + int(s["cancelled_pending"]) + int(s["cancelled_finished"]) + int(s["cancelled_inflight"])
    return outstanding <= int(s["max_jobs"]) and accounted == int(s["submitted"])

func _fail(msg: String, src) -> void:
    if src != null:
        src.close()
    push_error("TerraForge IO pipeline: " + msg)
    quit(1)
