extends SceneTree
const SCENE=preload("res://addons/terra_forge/profiling/profile_scene.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("M1: "+message)
    quit(1)
func _run() -> void:
    if DisplayServer.get_name().to_lower()=="headless":
        _fail("requires non-headless renderer")
        return
    var p=SCENE.instantiate()
    root.add_child(p)
    p._run_settings={"publication_micro":true,"pump_micro":true}
    for i in range(12):
        p._record_slow_frame_interval(i,i+1,40000+i*1000)
    p._record_slow_frame_interval(99,100,33333)
    p._record_slow_frame_interval(100,100,999999)
    var check: Dictionary=p._frame_micro_report({"slow_events":[{"frame":11,"total_us":10000},{"frame":12,"total_us":20000}]},{"slow_events":[{"frame":11,"total_us":30000}]})
    var rows: Array=check["intervals"]
    if rows.size()!=8 or rows[0]["start_frame"]!=11 or rows[-1]["start_frame"]!=4 or rows[0]["publication_events"].size()!=1 or rows[0]["pump_events"].size()!=1 or not rows[1]["publication_events"].is_empty():
        _fail("bounded exact frame join")
        return
    p._reset_frame_samples()
    if not p._slow_frame_intervals.is_empty():
        _fail("reset")
        return
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
    var fingerprint: String=FileAccess.get_sha256(manifest)
    if fingerprint.is_empty():
        _fail("manifest")
        return
    p.sampling_strategy=4
    p.duration_seconds=5.0
    var snapshot: String=""
    for enabled in [false,true,true,false]:
        p.observe_publication_micro=enabled
        p.observe_pump_micro=enabled
        p._begin(true)
        deadline=Time.get_ticks_msec()+30000
        while p._running and Time.get_ticks_msec()<deadline:
            await process_frame
        if p._running or p._reports.is_empty():
            _fail("profile timeout")
            return
        var r: Dictionary=p._reports[-1]
        if snapshot.is_empty():
            snapshot=str(r["snapshot_id"])
        if r["error"]!=OK or str(r["snapshot_id"])!=snapshot or snapshot.is_empty() or r["mesh_builds"]<1 or r["frame_interval_ms"]["count"]<1 or r["settings"]["publication_micro"]!=enabled or r["settings"]["pump_micro"]!=enabled:
            _fail("invalid profile evidence")
            return
        var pub: Dictionary=r["publication_micro"]
        var pump: Dictionary=r["pump_micro"]
        var join: Dictionary=r["frame_micro_join"]
        if enabled:
            if pub.get("success",0)!=r["mesh_builds"] or pub.get("invalid_samples",-1)!=0 or pump.get("invalid_samples",-1)!=0 or pump.get("total_ms",{}).get("count",0)<1 or join.get("intervals",[]).size()>8 or join.get("schema","")!="TF_FRAME_MICRO_JOIN_1":
                _fail("missing or inconsistent diagnostic samples")
                return
            for row in join["intervals"]:
                for kind in ["publication_events","pump_events"]:
                    for event in row[kind]:
                        if event["frame"]!=row["start_frame"]:
                            _fail("wrong frame join")
                            return
        elif not pub.is_empty() or not pump.is_empty() or not join.is_empty():
            _fail("observer leakage into control")
            return
        print("M1_PROFILE ",JSON.stringify({"enabled":enabled,"renderer":RenderingServer.get_current_rendering_method(),"frame":r["frame_interval_ms"],"builds":r["mesh_builds"],"reads":r["disk_reads"],"publication_micro":pub,"pump_micro":pump,"frame_micro_join":join}))
    if FileAccess.get_sha256(manifest)!=fingerprint:
        _fail("source changed")
        return
    p.free()
    print("PASS: M1 rendered observer ABBA and exact bounded frame correlation")
    quit(0)
