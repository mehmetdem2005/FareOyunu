extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const W=preload("res://addons/terra_forge/tests/fixtures/shadow_cache_worker.gd")
const MODEL=preload("res://addons/terra_forge/tests/fixtures/discard_cache_shadow.gd")
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")

func _initialize() -> void:
    var m=MODEL.new(100)
    m.offer("a",60,12,0)
    m.offer("b",60,15,0)
    if m.lookup("a",1) or not m.lookup("b",1) or m.lookup("b",1):
        _fail(null,"shadow eviction/one transfer")
        return
    var check: Dictionary=m.report()
    if check["evictions"]!=1 or check["hypothetical_hits"]!=1 or check["cross_epoch_hits"]!=1 or check["modeled_resident_bytes"]!=0 or check["prior_discarded_build_wall_us"]!=15:
        _fail(null,"shadow accounting")
        return
    m.offer("a",60,4,1)
    m.offer("a",40,6,2)
    if m.report()["modeled_resident_bytes"]!=40 or m.lookup("a_changed_neighbor",2) or not m.lookup("a",2):
        _fail(null,"shadow exact identity")
        return
    for format in [0,1]:
        var b: Variant=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail(b,"fixture start")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail(b,"fixture")
            return
        for mode in [4,6]:
            for cache in [9,16]:
                for trial in range(2):
                    var result: Dictionary=_trace(made["directory"],format,mode,cache,trial)
                    if result.get("error",FAILED)!=OK:
                        _fail(b,"trace "+str(result))
                        return
                    print("DISCARD_CACHE_SHADOW ",JSON.stringify(result))
        b.close()
    print("PASS: bounded discarded-result metadata shadow, exact identity model, 16 real streaming traces; no cached output delivered")
    quit(0)

func _trace(folder: String,format: int,mode: int,cache: int,trial: int) -> Dictionary:
    var p=P.new()
    p.region_index_format=format
    p.sampling_strategy=mode
    p.geometry_job_limit=2
    p.resident_shard_limit=2
    p.view_distance=96.0
    p.high_detail_distance=40.0
    p.medium_detail_distance=80.0
    p.max_visible_tiles=8
    p.tile_updates_per_frame=1
    p.max_tile_work_ms=8.0
    if p.start_preview(folder,cache,4)!=OK:
        return _close(p,{"error":FAILED,"stage":"open"})
    # Replace the unpumped worker only in this fixture. No production hook.
    if p._geometry_worker.stats()["slots"]!=0 or not p._geometry_jobs.is_empty():
        return _close(p,{"error":ERR_BUG,"stage":"initial ownership"})
    p._geometry_worker.close()
    var worker=W.new()
    p._geometry_worker=worker
    if worker.start(p._reader,2,mode==6,mode==6)!=OK:
        return _close(p,{"error":FAILED,"stage":"shadow open"})
    worker.configure_shadow()
    var missing: int=0
    var start: int=Time.get_ticks_usec()
    # Two complete routes include reversals and return to previous regions.
    for step in range(288):
        var target: int=start+step*8000
        var remaining: int=target-Time.get_ticks_usec()
        if remaining>0:
            OS.delay_usec(remaining)
        var focus: Vector3=TRACE.focus_at(step%144)
        p.set_stream_center(focus)
        p._last_sync_msec=-100000
        var progress: Dictionary=p.pump_stream()
        var s: Dictionary=p.stats()
        if progress["error"]!=OK or s["source"]["resident"]>cache or s["source"]["tile_view_active_pages"]!=0 or s["geometry_reservations"]>2 or s["geometry_worker"]["slots"]>2:
            return _close(p,{"error":ERR_BUG,"stage":"bounds","step":step})
        if not p.has_collision_at(focus):
            missing+=1
    # Shadow snapshot first: a worker can finish/discard between reads;
    # later worker totals are monotonic, and no new submit occurs here.
    var model: Dictionary=worker.shadow_report()
    var stats: Dictionary=worker.stats()
    if stats["submitted"]!=stats["delivered"]+stats["dropped"]+stats["slots"] or stats["discard_accounting"]["classified"]!=stats["dropped"] or model["ready_offers"]>stats["dropped"]:
        return _close(p,{"error":ERR_BUG,"stage":"ownership"})
    for item in model["models"]:
        if item["lookups"]!=stats["submitted"] or item["offers"]!=model["ready_offers"] or item["modeled_peak_bytes"]>item["budget_bytes"] or item["hypothetical_hits"]>item["offers"] or item["cross_epoch_hits"]>item["hypothetical_hits"] or item["entries"]>64:
            return _close(p,{"error":ERR_BUG,"stage":"model bounds","model":item})
    var settled: bool=p.has_collision_at(TRACE.focus_at(143))
    for attempt in range(2400):
        if settled:
            break
        p.pump_stream()
        settled=p.has_collision_at(TRACE.focus_at(143))
        OS.delay_msec(1)
    if not settled:
        return _close(p,{"error":ERR_BUG,"stage":"recovery"})
    return _close(p,{"error":OK,"format":format+1,"backend":mode,"cache":cache,"trial":trial,"steps":288,"missing_shape_steps":missing,"worker":stats,"shadow":model})

func _close(p,result: Dictionary) -> Dictionary:
    p.stop_preview()
    p.free()
    return result

func _fail(b,msg: String) -> void:
    if b!=null:
        b.close()
    push_error("Discard shadow: "+msg)
    quit(1)
