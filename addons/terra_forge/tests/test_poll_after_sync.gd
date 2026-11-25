extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
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
        for i in range(15000):
            made=b.take_result()
            if made.get("error",FAILED)!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture")
            return
        var order: Array[bool]=[false,true,true,false]
        if format==1:
            order.reverse()
        for late in order:
            p=P.new()
            p.region_index_format=format
            p.sampling_strategy=7
            p.hybrid_poll_after_sync=late
            p.max_visible_tiles=4
            p.high_detail_distance=64.0
            p.medium_detail_distance=80.0
            p.view_distance=96.0
            p.observe_pump_micro=true
            root.add_child(p)
            if p.start_preview(made["directory"],16,4)!=OK:
                _fail("open")
                return
            p.set_process(false)
            p.hybrid_poll_after_sync=not late
            p.enable_io_profile()
            if p._reader.request_page(Vector2i(16,16))!=OK:
                _fail("old page request")
                return
            var deadline: int=Time.get_ticks_msec()+5000
            while p._reader.stats()["finished"]!=1 and Time.get_ticks_msec()<deadline:
                OS.delay_msec(1)
            if p._reader.stats()["finished"]!=1:
                _fail("old page ready")
                return
            p.set_stream_center(Vector3(100,0,100))
            if p.pump_stream()["error"]!=OK:
                _fail("first pump")
                return
            var first: Dictionary=p._reader.stats()
            if first["accepted_results"]!=(0 if late else 1) or first["cancelled_finished"]!=(1 if late else 0):
                _fail("old ready disposition "+str(first))
                return
            var hist=HIST.new()
            var settled: int=-1
            for tick in range(240):
                await physics_frame
                var start: int=Time.get_ticks_usec()
                var pumped: Dictionary=p.pump_stream()
                hist.add(float(Time.get_ticks_usec()-start)/1000.0)
                if pumped["error"]!=OK:
                    _fail("pump")
                    return
                if p._tiles.size()==4 and p._pending_tiles.is_empty() and p._geometry_jobs.is_empty():
                    settled=tick
                    break
            if settled<0:
                _fail("settle")
                return
            await physics_frame
            await physics_frame
            var hit: Dictionary=p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(100,128,100),Vector3(100,-128,100)))
            if hit.is_empty() or not p.is_ancestor_of(hit["collider"]) or absf(hit["position"].y-V2.sample(100,100))>0.002:
                _fail("actual focus height")
                return
            var s: Dictionary=p._reader.stats()
            var micro: Dictionary=p.pump_micro_profile()
            if micro["invalid_samples"]!=0 or micro["stage_ms"]["io_accept"]["count"]!=settled+2 or s["resident"]>16:
                _fail("poll count or bounds")
                return
            print("F1_POLL_ORDER ",JSON.stringify({"format":format+1,"after_sync":late,"first_accepted":first["accepted_results"],"first_cancelled_finished":first["cancelled_finished"],"settle_ticks":settled+1,"accepted":s["accepted_results"],"submitted":s["submitted"],"resident":s["resident"],"pump_ms":hist.report(),"io":p.pipeline_profile(),"actual_ray":true}))
            p.stop_preview()
            if p._poll_after_sync_active:
                _fail("stop reset")
                return
            p.free()
            p=null
        b.close()
        b=null
    print("PASS: one bounded poll per pump, session-pinned camera sync order, controlled old-ready cancellation, actual new-focus ray")
    quit(0)

func _fail(msg: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("F1 poll order: "+msg)
    quit(1)
