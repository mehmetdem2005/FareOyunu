extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/tests/fixtures/g1_candidate_preview.gd")
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
var p
var b

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for format in [0,1]:
        b=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture")
            return
        var arms: Array[bool]=[false,true]
        if format==1:
            arms.reverse()
        var reference: Array=[]
        for candidate in arms:
            p=P.new()
            p.use_candidate=candidate
            p.region_index_format=format
            p.sampling_strategy=5
            p.geometry_job_limit=2
            p.max_visible_tiles=8
            p.high_detail_distance=40.0
            p.medium_detail_distance=80.0
            p.view_distance=96.0
            p.max_tile_work_ms=8.0
            p.tile_updates_per_frame=2
            root.add_child(p)
            if p.start_preview(made["directory"],16,4)!=OK:
                _fail("open")
                return
            p.set_process(false)
            var snapshots: Array=[]
            var pumps=HIST.new()
            var peak_slots: int=0
            var rays: int=0
            # Same position sequence and exact settled visible output; no
            # manual desired edits, synthetic hits, or forced epoch resets.
            for focus in [Vector2(480,480),Vector2(496,480),Vector2(512,480),Vector2(512,496),Vector2(512,512),Vector2(496,512),Vector2(480,512),Vector2(480,496),Vector2(480,480),Vector2(16,16),Vector2(528,528)]:
                p.set_stream_center(Vector3(focus.x,20,focus.y))
                var settled: bool=false
                for attempt in range(240):
                    await physics_frame
                    var t: int=Time.get_ticks_usec()
                    var progress: Dictionary=p.pump_stream()
                    pumps.add(float(Time.get_ticks_usec()-t)/1000.0)
                    var st: Dictionary=p.stats()
                    peak_slots=maxi(peak_slots,st["geometry_worker"]["slots"])
                    if progress["error"]!=OK or st["source"]["resident"]>16 or st["tiles"]>8 or peak_slots>2:
                        _fail("stream bounds")
                        return
                    if p._pending_tiles.is_empty() and p._geometry_jobs.is_empty() and p._tiles.size()==p._desired_tiles.size() and not p._tiles.is_empty():
                        settled=true
                        break
                if not settled:
                    _fail("settle")
                    return
                await physics_frame
                await physics_frame
                var fp: Dictionary={}
                for key in p._desired_tiles:
                    var tile: Dictionary=p._tiles[key]
                    var mesh: Mesh=tile["visual"].mesh
                    var shape: Shape3D=tile["collision"].shape
                    if mesh==null or tile["lod"]!=p._desired_tiles[key] or (shape is HeightMapShape3D)!=(tile["lod"]==0):
                        _fail("resource parity")
                        return
                    var h=HashingContext.new()
                    h.start(HashingContext.HASH_SHA256)
                    h.update(var_to_bytes([mesh.surface_get_arrays(0),shape.map_data if shape is HeightMapShape3D else PackedFloat32Array()]))
                    fp[str(key)]=h.finish().hex_encode()
                var heights: Array[float]=[]
                for offset in [Vector2(0.25,0.5),Vector2(-0.25,0.5),Vector2(0.5,-0.25)]:
                    var q: Vector2=focus+offset
                    var ray=PhysicsRayQueryParameters3D.create(Vector3(q.x,128,q.y),Vector3(q.x,-128,q.y))
                    var hit: Dictionary=p.get_world_3d().direct_space_state.intersect_ray(ray)
                    if hit.is_empty() or not p.is_ancestor_of(hit["collider"]):
                        _fail("missing actual ray")
                        return
                    heights.append(hit["position"].y)
                    rays+=1
                snapshots.append({"fingerprints":fp,"heights":heights})
            if reference.is_empty():
                reference=snapshots
            elif reference!=snapshots:
                _fail("matched route mesh/physics parity")
                return
            var s: Dictionary=p.stats()
            var observed: Dictionary=p._geometry_worker.delivered_cache_report() if candidate else {}
            if candidate and (observed["delivered"]!=s["geometry_worker"]["delivered"] or observed["peak_retained_bytes"]>262144 or observed["max_metadata_keys"]>20 or observed["retain_fail_max"]!=0):
                _fail("cache bounds")
                return
            print("G1_LIVE_PREVIEW ",JSON.stringify({"format":format+1,"candidate":candidate,"settled_positions":snapshots.size(),"rays":rays,"worker":s["geometry_worker"],"cache":observed,"mesh_builds":s["mesh_builds"],"disk_reads":s["source"]["disk_reads"],"worker_ms":s["geometry_worker_ms"],"pump_ms":pumps.report(),"peak_slots":peak_slots,"note":"Real preview worker and natural desired changes; settled positions not fixed wall duration, delivered hits only; raw retained bound not transient RSS/GPU"}))
            p.stop_preview()
            await physics_frame
            await physics_frame
            var empty_ray=PhysicsRayQueryParameters3D.create(Vector3(528,128,528),Vector3(528,-128,528))
            if not p.get_world_3d().direct_space_state.intersect_ray(empty_ray).is_empty():
                _fail("stop ray")
                return
            p.free()
            p=null
        b.close()
        b=null
    print("PASS: G1 real preview worker, natural camera route, equal settled meshes and actual rays, bounded delivery and stop")
    quit(0)

func _fail(reason: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("G1 live preview: "+reason)
    quit(1)
