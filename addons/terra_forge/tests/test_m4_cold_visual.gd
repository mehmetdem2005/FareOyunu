extends SceneTree
## Fresh process per arm. Diagnostic-only, no runtime node pool or shader claim.
const SCENE=preload("res://addons/terra_forge/profiling/profile_scene.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("M4: "+message)
    quit(1)
func _run() -> void:
    var arm: String=""
    var renderer: String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--arm="):
            arm=arg.get_slice("=",1)
        if arg.begins_with("--require-renderer="):
            renderer=arg.get_slice("=",1)
    if arm not in ["cold","prewarm"] or renderer.is_empty() or DisplayServer.get_name().to_lower()=="headless" or RenderingServer.get_current_rendering_method()!=renderer:
        _fail("invalid arm or renderer fallback")
        return
    var p=SCENE.instantiate()
    root.add_child(p)
    p._format.select(1)
    p._refresh_sizes()
    p._fixture_size.select(p._fixture_size.get_item_index(512))
    p._make_fixture()
    var deadline: int=Time.get_ticks_msec()+60000
    while p._fixture!=null and Time.get_ticks_msec()<deadline:
        await process_frame
        OS.delay_msec(2)
    if p._fixture!=null or p._path.text.is_empty():
        _fail("fixture")
        return
    var manifest: String=p._path.text.path_join("manifest.tfm2")
    var hash: String=FileAccess.get_sha256(manifest)
    if hash.is_empty():
        _fail("manifest")
        return
    p.sampling_strategy=4
    p.duration_seconds=5.0
    p.observe_publication_micro=true
    p.observe_pump_micro=true
    var setup: Dictionary={}
    var start: int=Time.get_ticks_usec()
    var static_before: float=Performance.get_monitor(Performance.MEMORY_STATIC)
    if arm=="prewarm":
        # Create the class and assign an ordinary material, but do not create
        # mesh geometry or keep an extra live node. No shader/draw warmup claim.
        var stamp: int=Time.get_ticks_usec()
        var visual=MeshInstance3D.new()
        setup["allocate_us"]=Time.get_ticks_usec()-stamp
        stamp=Time.get_ticks_usec()
        var material=StandardMaterial3D.new()
        visual.material_override=material
        setup["material_us"]=Time.get_ticks_usec()-stamp
        stamp=Time.get_ticks_usec()
        root.add_child(visual)
        setup["attach_us"]=Time.get_ticks_usec()-stamp
        stamp=Time.get_ticks_usec()
        visual.free()
        material=null
        setup["free_us"]=Time.get_ticks_usec()-stamp
    var setup_us: int=Time.get_ticks_usec()-start
    p._begin(true)
    deadline=Time.get_ticks_msec()+30000
    while p._running and Time.get_ticks_msec()<deadline:
        await process_frame
    if p._running or p._reports.is_empty():
        _fail("profile timeout")
        return
    var r: Dictionary=p._reports[-1]
    if r["error"]!=OK or r["mesh_builds"]<1 or r["snapshot_id"]=="" or r["first_focus_collision_ms_from_open_start"]==null or r["resident_pages_peak"]>p.page_limit or FileAccess.get_sha256(manifest)!=hash:
        _fail("missing evidence or source changed")
        return
    var micro: Dictionary=r["publication_micro"]
    if micro.get("invalid_samples",-1)!=0 or micro.get("success",0)!=r["mesh_builds"] or micro.get("stage_ms",{}).get("visual_allocate",{}).get("count",0)<1:
        _fail("micro stage evidence")
        return
    var total_us: int=Time.get_ticks_usec()-start
    print("M4_COLD_VISUAL ",JSON.stringify({"renderer":renderer,"arm":arm,"setup":setup,"setup_us":setup_us,"total_setup_through_profile_us":total_us,"static_before_bytes":static_before if static_before>0 else null,"static_peak_bytes":r["godot_static_peak_sampled_bytes"],"rss_peak_bytes":r["rss_peak_sampled_bytes"],"snapshot":r["snapshot_id"],"manifest":hash,"frame":r["frame_interval_ms"],"open_ms":r["open_ms"],"first_focus_shape_ms":r["first_focus_collision_ms_from_open_start"],"shutdown_ms":r["shutdown_ms"],"builds":r["mesh_builds"],"reads":r["disk_reads"],"coverage":r["focus_frames"],"missing_shape":r["focus_frames_without_collision_shape"],"visual_allocate":micro["stage_ms"]["visual_allocate"],"publication":micro["total_ms"],"pump":r["pump_micro"]["total_ms"],"joined":r["frame_micro_join"],"notes":"Fresh process each arm; persistent OS/driver caches not flushed; fixed time, potentially unequal work; setup counted; diagnostic empty visual only, no pool or shader warmup, not GPU time."}))
    p.free()
    print("PASS: M4 cold visual allocation probe")
    quit(0)
