@tool
extends RefCounted
## Fixed positions and pump counts, real asynchronous I/O and mesh/shape.
## Not a rendered frame benchmark; scheduler completion can vary.
const PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const HIST = preload("res://addons/terra_forge/core/profile_histogram.gd")
const PROFILE = preload("res://addons/terra_forge/profiling/profile_scene.gd")
const ROUTE_ID = "fixed_576_v1"
const STEPS: int = 144
const WAIT_MS: int = 2

static func focus_at(step: int) -> Vector3:
    if step < 24:
        return Vector3(480,20,480)
    if step < 72:
        return Vector3(480+float(step-24)*1.5,20,480+float(step-24)*1.5)
    if step < 96:
        return Vector3(550-float(step-72)*20.0,20,550-float(step-72)*20.0)
    if step < 120:
        return Vector3(16,20,16)
    return Vector3(528,20,528)

static func _close(p,result: Dictionary) -> Dictionary:
    p.stop_preview()
    p.free()
    return result

static func run(directory: String, format: int, mode: int, cache: int) -> Dictionary:
    if format not in [0,1] or mode not in [0,1,2] or cache not in [9,16]:
        return {"error": ERR_INVALID_PARAMETER}
    var p = PREVIEW.new()
    p.region_index_format = format
    p.sampling_strategy = mode
    p.resident_shard_limit = 2
    p.view_distance = 96.0
    p.high_detail_distance = 40.0
    p.medium_detail_distance = 80.0
    p.max_visible_tiles = 8
    p.tile_updates_per_frame = 1
    p.max_tile_work_ms = 8.0
    var baseline: Variant = PROFILE._rss()
    var peak: Variant = baseline
    var status: Error = p.start_preview(directory,cache,4)
    if status != OK:
        return _close(p,{"error":status,"stage":"open"})
    if p.world_extent()!=Vector2(576,576):
        return _close(p,{"error":ERR_INVALID_PARAMETER,"stage":"extent"})
    p.enable_io_profile()
    var pumps = HIST.new()
    var intervals = HIST.new()
    var previous: int = 0
    var missing: int = 0
    var gap: int = 0
    var gap_max: int = 0
    var page_peak: int = 0
    var tile_peak: int = 0
    var job_peak: int = 0
    var shard_peak: int = 0
    var vertex_peak: int = 0
    var begin: int = Time.get_ticks_usec()
    for step in range(STEPS):
        var now: int = Time.get_ticks_usec()
        if previous > 0:
            intervals.add(float(now-previous)/1000.0)
        previous = now
        var focus: Vector3 = focus_at(step)
        p.set_stream_center(focus)
        # Force the same synchronization opportunity each step, avoiding
        # 220ms wall-clock sync cadence differences between strategies.
        p._last_sync_msec = -100000
        var start: int = Time.get_ticks_usec()
        var progress: Dictionary = p.pump_stream()
        pumps.add(float(Time.get_ticks_usec()-start)/1000.0)
        var s: Dictionary = p.stats()
        var src: Dictionary = s["source"]
        var jobs: int = int(src["outstanding"])+int(src["inflight"])+int(src["finished"])
        if progress["error"]!=OK or src["resident"]>cache or src["resident_float_bytes"]>cache*4096 or jobs>4 or s["tiles"]>8 or s["pending_tiles"]>8 or src["shard_resident"]>2 or src["tile_view_active_pages"]!=0 or s["dense_payload_peak_bytes"]>4900:
            return _close(p,{"error":ERR_BUG,"stage":"budget or IO","step":step,"stats":s})
        page_peak=maxi(page_peak,src["resident"])
        tile_peak=maxi(tile_peak,s["tiles"])
        job_peak=maxi(job_peak,jobs)
        shard_peak=maxi(shard_peak,src["shard_resident"])
        vertex_peak=maxi(vertex_peak,s["vertices"])
        if p.has_collision_at(focus):
            gap=0
        else:
            missing+=1
            gap+=1
            gap_max=maxi(gap_max,gap)
        if step%12==0:
            var rss: Variant=PROFILE._rss()
            if rss!=null:
                peak=rss if peak==null else maxi(int(peak),int(rss))
        OS.delay_msec(WAIT_MS)
    var elapsed: float=float(Time.get_ticks_usec()-begin)/1000.0
    var s: Dictionary=p.stats()
    var src: Dictionary=s["source"]
    var last: Vector3=focus_at(STEPS-1)
    # Recovery gate is outside the fixed measured trace.
    var settled: bool=p.has_collision_at(last)
    for attempt in range(2400):
        if settled:
            break
        p.pump_stream()
        settled=p.has_collision_at(last)
        OS.delay_msec(1)
    if not settled or s["camera_cancellations"]<2 or s["mesh_builds"]<1 or s["writable"] or p.save_data()!=ERR_UNAVAILABLE:
        return _close(p,{"error":ERR_BUG,"stage":"recovery","stats":s})
    var report: Dictionary={
        "error":OK,"route":ROUTE_ID,"steps":STEPS,"sleep_ms":WAIT_MS,"format":"TFM"+str(format+1),"strategy":mode,"page_cap":cache,"job_cap":4,"tile_cap":8,"shard_cap":2 if format==1 else 0,
        "elapsed_ms":elapsed,"pump_ms":pumps.report(),"pump_interval_ms":intervals.report(),"missing_shape_steps":missing,"longest_missing_shape_steps":gap_max,
        "rss_baseline_bytes":baseline,"rss_peak_sampled_bytes":peak,"page_peak":page_peak,"page_payload_peak_bytes":page_peak*4096,"tile_peak":tile_peak,"job_peak":job_peak,"shard_peak":shard_peak,"vertex_peak":vertex_peak,
        "mesh_builds":s["mesh_builds"],"camera_cancellations":s["camera_cancellations"],"waiting_tile_frames":s["waiting_tile_frames"],"dense_payload_peak_bytes":s["dense_payload_peak_bytes"],
        "accepted_page_reads":src["disk_reads"],"unique_accepted_pages":src["pages_verified_on_demand"],"accepted_page_reloads":maxi(0,src["disk_reads"]-src["pages_verified_on_demand"]),"request_cache_hits":src["cache_hits"],"evictions":src["evictions"],"stale_discarded":src["stale_discarded"],"submitted":src["submitted"],"worker_errors":src["worker_errors"],"lru_touches":src["lru_touches"],"direct_reads":src["direct_height_reads"],"view_reads":src["tile_view_reads"],
        "recovery_ok":settled
    }
    return _close(p,report)
