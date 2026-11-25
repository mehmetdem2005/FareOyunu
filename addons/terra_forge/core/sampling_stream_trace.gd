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

static func run(directory: String, format: int, mode: int, cache: int, geometry_cap: int=2, cadence_us: int=0, observe_publication: bool=false, publication_options: Dictionary={}) -> Dictionary:
    if format not in [0,1] or mode not in [0,1,2,3,4,5,6,7] or cache not in [9,16] or geometry_cap not in [1,2,4] or cadence_us not in [0,4000,8000]:
        return {"error": ERR_INVALID_PARAMETER}
    var p = PREVIEW.new()
    p.region_index_format = format
    p.sampling_strategy = mode
    p.hybrid_scalar_sampling=bool(publication_options.get("scalar",false))
    p.hybrid_topology_cache=bool(publication_options.get("topology",false))
    p.hybrid_cropped_halo=bool(publication_options.get("crop",false))
    p.hybrid_cooperative_cancel=bool(publication_options.get("cancel",false))
    p.enable_camera_worker_cropped_halo=bool(publication_options.get("camera_crop",false))
    p.observe_publication=observe_publication
    p.enforce_publication_budget=bool(publication_options.get("enabled",false))
    p.publication_byte_target=int(publication_options.get("bytes",131072))
    p.publication_time_target_us=int(publication_options.get("time_us",1000))
    p.geometry_job_limit = geometry_cap
    p.resident_shard_limit = 2
    p.view_distance = 96.0
    p.high_detail_distance = 40.0
    p.medium_detail_distance = 80.0
    p.max_visible_tiles = 8
    p.tile_updates_per_frame = int(publication_options.get("updates",1))
    if p.tile_updates_per_frame not in [1,2,3]:
        return _close(p,{"error":ERR_INVALID_PARAMETER,"stage":"updates"})
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
    var first_shape_step: int = -1
    var geometry_peak: int = 0
    var gap: int = 0
    var gap_max: int = 0
    var page_peak: int = 0
    var tile_peak: int = 0
    var job_peak: int = 0
    var shard_peak: int = 0
    var vertex_peak: int = 0
    var deadline_misses: int=0
    var max_late_us: int=0
    var begin: int = Time.get_ticks_usec()
    for step in range(STEPS):
        if cadence_us>0:
            var target: int=begin+step*cadence_us
            var remaining: int=target-Time.get_ticks_usec()
            if remaining>0:
                OS.delay_usec(remaining)
            var late: int=maxi(0,Time.get_ticks_usec()-target)
            max_late_us=maxi(max_late_us,late)
            if late>=cadence_us:
                deadline_misses+=1
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
        var worker: Dictionary=s["geometry_worker"]
        if mode>=3:
            if worker["slots"]>geometry_cap or s["geometry_reservations"]>geometry_cap or s["geometry_publish_peak_per_pump"]>p.tile_updates_per_frame:
                return _close(p,{"error":ERR_BUG,"stage":"geometry cap","step":step,"stats":s})
            geometry_peak=maxi(geometry_peak,int(worker["slots"]))
        page_peak=maxi(page_peak,src["resident"])
        tile_peak=maxi(tile_peak,s["tiles"])
        job_peak=maxi(job_peak,jobs)
        shard_peak=maxi(shard_peak,src["shard_resident"])
        vertex_peak=maxi(vertex_peak,s["vertices"])
        if p.has_collision_at(focus):
            if first_shape_step<0:
                first_shape_step=step
            gap=0
        else:
            missing+=1
            gap+=1
            gap_max=maxi(gap_max,gap)
        if step%12==0:
            var rss: Variant=PROFILE._rss()
            if rss!=null:
                peak=rss if peak==null else maxi(int(peak),int(rss))
        if cadence_us==0:
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
        "cadence_target_us":cadence_us,"deadline_misses":deadline_misses,"max_late_us":max_late_us,"elapsed_ms":elapsed,"pump_ms":pumps.report(),"pump_interval_ms":intervals.report(),"missing_shape_steps":missing,"longest_missing_shape_steps":gap_max,
        "rss_baseline_bytes":baseline,"rss_peak_sampled_bytes":peak,"page_peak":page_peak,"page_payload_peak_bytes":page_peak*4096,"tile_peak":tile_peak,"job_peak":job_peak,"shard_peak":shard_peak,"vertex_peak":vertex_peak,
        "mesh_builds":s["mesh_builds"],"camera_cancellations":s["camera_cancellations"],"waiting_tile_frames":s["waiting_tile_frames"],"dense_payload_peak_bytes":s["dense_payload_peak_bytes"],
        "accepted_page_reads":src["disk_reads"],"unique_accepted_pages":src["pages_verified_on_demand"],"accepted_page_reloads":maxi(0,src["disk_reads"]-src["pages_verified_on_demand"]),"request_cache_hits":src["cache_hits"],"evictions":src["evictions"],"stale_discarded":src["stale_discarded"],"submitted":src["submitted"],"worker_errors":src["worker_errors"],"lru_touches":src["lru_touches"],"direct_reads":src["direct_height_reads"],"view_reads":src["tile_view_reads"],
        "geometry_cap":geometry_cap if mode>=3 else 0,"geometry_peak":geometry_peak,"first_shape_step":first_shape_step,"geometry_worker":s["geometry_worker"],
        "geometry_copy_ms":s["geometry_copy_ms"],"geometry_queue_ms":s["geometry_queue_ms"],"geometry_worker_ms":s["geometry_worker_ms"],"geometry_delivery_ms":s["geometry_delivery_ms"],"geometry_publish_ms":s["geometry_publish_ms"],
        "publication":s.get("publication",{}),"publication_options":publication_options.duplicate(),
        "camera_crop":s["camera_worker_cropped_halo_active"],"camera_cropped_submissions":s["camera_worker_cropped_submissions"],
        "recovery_ok":settled
    }
    return _close(p,report)
