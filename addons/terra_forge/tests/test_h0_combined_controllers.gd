extends SceneTree
## Deterministic pressure input, real Godot streaming and stationary physics.
## No artificial frame time is reported as actual device performance.
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const POLICY=preload("res://addons/terra_forge/core/adaptive_view_budget.gd")
const LOD=preload("res://addons/terra_forge/core/lod_policy.gd")
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
const OLD: Vector2i=Vector2i(15,15)
const NEXT: Vector2i=Vector2i(16,15)
const RADIUS: float=0.25
const CAP: int=12
var _p
var _builder
var _body: CharacterBody3D

func _initialize() -> void:
    call_deferred("_run")

func _format() -> int:
    return 0

func _run() -> void:
    var checks: int=0
    for fps in [30,60]:
        var policy=POLICY.new()
        if policy.configure(fps)!=OK or policy.configure(25)==OK or policy.observe(NAN)==OK or policy.observe(0.0)==OK or policy.samples!=0:
            _fail("invalid inputs")
            return
        var target: float=1000.0/float(fps)
        for i in range(120):
            policy.observe(target*(1.05 if i%2==0 else 0.95))
        if policy.tier!=0 or policy.transitions!=0:
            _fail("near-target oscillation")
            return
        for i in range(120):
            policy.observe(target*1.8)
        if policy.tier!=2 or policy.transitions!=2 or policy.far_limit(9)!=3:
            _fail("overload/cooldown")
            return
        for i in range(150):
            policy.observe(target*0.5)
        if policy.tier!=0 or policy.transitions!=4:
            _fail("recovery")
            return
        for i in range(120):
            policy.observe(target*1.8)
        if not policy.set_auto(false) or policy.tier!=0:
            _fail("override")
            return
        var samples: int=policy.samples
        for i in range(100):
            policy.observe(target*1.8)
        if policy.tier!=0 or policy.samples!=samples or policy.far_limit(9)!=9:
            _fail("manual persistence")
            return
        policy.set_auto(true)
        if not policy.auto or policy.mean_ms!=0.0:
            _fail("resume auto")
            return
        checks+=1
    if checks!=2:
        _fail("policy preset coverage")
        return
    var format: int=_format()
    if format==0:
        _builder=V1.new()
    else:
        _builder=V2.new()
    var err: Error=_builder.start(Vector2i(576,576),true) if format==0 else _builder.start(Vector2i(576,576))
    if err!=OK:
        _fail("fixture start")
        return
    var made: Dictionary={}
    for attempt in range(15000):
        made=_builder.take_result()
        if made["error"]!=ERR_BUSY:
            break
        OS.delay_msec(2)
    if made.get("error",FAILED)!=OK:
        _fail("fixture")
        return
    for mode in [0,5]:
        var outcome: Dictionary=await _case(made["directory"],format,mode)
        if outcome.get("error",FAILED)!=OK:
            _fail(str([format,mode])+" "+str(outcome))
            return
        print("H0_COMBINED_CONTROLLER_TRACE ",JSON.stringify({"format":format+1,"mode":mode,"metrics":outcome}))
    _builder.close()
    _builder=null
    print("PASS: H0 shared view/work tier and bounded adaptive motion with actual support and manual override")
    quit(0)

func _case(directory: String,format: int,mode: int,target_fps: int=30,simulate_gap: bool=false) -> Dictionary:
    _p=P.new()
    _p.region_index_format=format
    _p.sampling_strategy=mode
    _p.enable_support_retention=true
    _p.enable_motion_prefetch=true
    _p.enable_adaptive_view_budget=true
    _p.enable_adaptive_work_budget=true
    _p.enable_adaptive_motion_horizon=true
    _p.adaptive_target_fps=target_fps
    _p.max_visible_tiles=CAP
    _p.high_detail_distance=32.0
    _p.medium_detail_distance=80.0
    _p.view_distance=160.0
    _p.max_tile_work_ms=8.0
    root.add_child(_p)
    if _p.start_preview(directory,16,4)!=OK:
        return {"error":FAILED,"stage":"open"}
    _p.set_process(false)
    _p.set_stream_center(Vector3(512,0,512))
    if not await _settle(OLD,CAP):
        return {"error":FAILED,"stage":"warm origin"}
    await physics_frame
    var state: Dictionary=_p.support_state()
    var session: int=state["session"]
    var point=Vector2(510,500)
    var claim: Dictionary=_p.update_support(point,RADIUS,session,state["revision"])
    if claim.get("error",FAILED)!=OK or claim["tiles"]!=[OLD]:
        return {"error":FAILED,"stage":"claim"}
    var revision: int=claim["revision"]
    _p.set_stream_center(Vector3(100,0,100))
    if not await _settle(OLD,CAP):
        return {"error":FAILED,"stage":"warm remote"}
    await physics_frame
    var ground: Dictionary=_ground(Vector3(point.x,0,point.y))
    if not _valid_ground(ground):
        return {"error":FAILED,"stage":"spawn"}
    var body_id: int=ground["collider"].get_instance_id()
    _body=CharacterBody3D.new()
    _body.floor_snap_length=0.5
    var shape=CapsuleShape3D.new()
    shape.radius=RADIUS
    shape.height=0.6
    var collision=CollisionShape3D.new()
    collision.shape=shape
    _body.add_child(collision)
    _body.position=Vector3(point.x,float(ground["position"].y)+0.35,point.y)
    root.add_child(_body)
    var dt: float=1.0/float(Engine.physics_ticks_per_second)
    for tick in range(20):
        await physics_frame
        _body.velocity=Vector3(0,_body.velocity.y-20.0*dt,0)
        _body.move_and_slide()
    if not _body.is_on_floor():
        return {"error":FAILED,"stage":"settled floor"}
    var points: Array[Dictionary]=[]
    var peak_tiles: int=0
    var peak_pages: int=0
    var peak_jobs: int=0
    var hist=HIST.new()
    var baseline_far: int=-1
    var baseline_near: Array[Vector2i]=[]
    var prior_tier: int=0
    var transitions: int=0
    var skipped_samples: int=0
    var peak_ground_delta: float=0.0
    var reference_height: float=ground["position"].y
    for tick in range(340):
        await physics_frame
        if tick==260 and _p.set_adaptive_view_auto(false)!=OK:
            return {"error":FAILED,"stage":"manual disable"}
        if tick==320 and _p.set_adaptive_view_auto(true)!=OK:
            return {"error":FAILED,"stage":"manual resume"}
        var frame_ms: float=33.333
        if (tick>=40 and tick<140) or (tick>=260 and tick<320):
            frame_ms=55.0
        elif tick>=140 and tick<260:
            frame_ms=20.0
        frame_ms*=30.0/float(target_fps)
        # Skip only pressure observation, keep real physics and streaming.
        # Never pretend this is Android pause/resume.
        if simulate_gap and tick>=145 and tick<157:
            skipped_samples+=1
        elif _p.sample_view_pressure(frame_ms)!=OK:
            return {"error":FAILED,"stage":"pressure sample"}
        if tick in [50,170,280]:
            var prior: Dictionary=_p.adaptive_view_state()
            for invalid in [-1.0,0.0,NAN,1001.0]:
                if _p.sample_view_pressure(invalid)!=ERR_INVALID_PARAMETER or _p.adaptive_view_state()!=prior:
                    return {"error":FAILED,"stage":"invalid pressure changes controller","tick":tick}
        var before: Vector3=_body.global_position
        # Persistent intent on a stationary test body deliberately keeps
        # a critical ahead tile active across all quality tiers.
        if _p.sample_motion_prefetch(Vector2(before.x,before.z),Vector2.ZERO,Vector2(24,0),RADIUS,session,revision)!=OK:
            return {"error":FAILED,"stage":"motion sample","tick":tick}
        _body.velocity=Vector3(0,_body.velocity.y-20.0*dt,0)
        _body.move_and_slide()
        var hit: Dictionary=_ground(_body.global_position)
        if not _body.is_on_floor() or not _valid_ground(hit) or hit["collider"].get_instance_id()!=body_id:
            return {"error":FAILED,"stage":"physical ground","tick":tick}
        peak_ground_delta=maxf(peak_ground_delta,absf(float(hit["position"].y)-reference_height))
        if peak_ground_delta>0.0001:
            return {"error":FAILED,"stage":"stationary ground height changed","tick":tick,"delta":peak_ground_delta}
        var began: int=Time.get_ticks_usec()
        var result: Dictionary=_p.pump_stream()
        hist.add(float(Time.get_ticks_usec()-began)/1000.0)
        if result["error"]!=OK:
            return {"error":FAILED,"stage":"pump","detail":result}
        var stats: Dictionary=_p.stats()
        var view: Dictionary=stats["adaptive_view"]
        var tier: int=view["controller"]["tier"]
        var work: Dictionary=_p.adaptive_work_state()
        var motion: Dictionary=_p.motion_prefetch_state()
        if view["controller"]["target_fps"]!=target_fps or not work["active"] or work["controller"]["tier"]!=tier or not motion["active"] or not motion["adaptive"]:
            return {"error":FAILED,"stage":"shared tier or motion controller","tick":tick}
        var horizon: float=motion["latency"]["horizon_seconds"]
        if not is_finite(horizon) or horizon<0.125 or horizon>0.5 or work["controller"]["tier2_peak_optional"]>1 or work["controller"]["restricted_peak_optional"]>2:
            return {"error":FAILED,"stage":"controller bounds","tick":tick}
        if tier!=prior_tier:
            transitions+=1
            prior_tier=tier
        peak_tiles=maxi(peak_tiles,int(stats["tiles"]))
        peak_pages=maxi(peak_pages,int(stats["source"]["resident"]))
        peak_jobs=maxi(peak_jobs,int(stats["geometry_reservations"]))
        if peak_tiles>CAP or peak_pages>16 or peak_jobs>2 or _p.max_visible_tiles!=CAP or _p._desired_tiles.get(OLD,-1)!=0 or _p._desired_tiles.get(NEXT,-1)!=0 or not _p._tiles.has(OLD) or _p.support_state()["revision"]!=revision:
            return {"error":FAILED,"stage":"critical keys or resource caps","tick":tick}
        var far: int=0
        var near: Array[Vector2i]=[]
        for key in _p._desired_tiles:
            if int(_p._desired_tiles[key])>0:
                far+=1
            else:
                near.append(key)
        if tick==39:
            baseline_far=far
            baseline_near=near.duplicate()
        if tick>=39:
            for key in baseline_near:
                if not near.has(key):
                    return {"error":FAILED,"stage":"near candidate lost","tick":tick}
        if tick in [39,139,259,319,339]:
            points.append({"tick":tick,"tier":tier,"far":far,"near":near.size(),"tiles":stats["tiles"],"pending":stats["pending_tiles"],"controller":view["controller"],"work":work["controller"],"motion_horizon":horizon})
        if tick==139 and (tier!=2 or baseline_far<4 or far>=baseline_far or view["far_admitted_candidates"]>ceili(float(view["far_candidates"])/4.0)):
            return {"error":FAILED,"stage":"actual far reduction","detail":points}
        if tick in [259,319,339] and (tier!=0 or far!=baseline_far):
            return {"error":FAILED,"stage":"restored far view","detail":points}
    var report: Dictionary={"error":OK,"ticks":340,"checkpoints":points,"transitions":transitions,"peak_tiles":peak_tiles,"peak_pages":peak_pages,"peak_jobs":peak_jobs,"missing_rays":0,"airborne_ticks":0,"pump_ms":hist.report(),"final":_p.adaptive_view_state(),"work":_p.adaptive_work_state(),"motion":_p.motion_prefetch_state(),"note":"Injected frame pressure, real stationary support; no FPS or equal-work performance claim"}
    report["target_fps"]=target_fps
    report["skipped_pressure_samples"]=skipped_samples
    report["peak_ground_height_delta"]=peak_ground_delta
    report["source_reads"]=_p.stats()["source"]["disk_reads"]
    report["mesh_builds"]=_p.stats()["mesh_builds"]
    if transitions!=4 or _p.adaptive_view_state()["controller"]["transitions"]!=4 or skipped_samples!=(12 if simulate_gap else 0):
        return {"error":FAILED,"stage":"transition evidence","detail":report}
    _body.free()
    _body=null
    _p.stop_preview()
    if _p.adaptive_view_state()["active"] or _p.adaptive_work_state()["active"] or _p.motion_prefetch_state()["active"] or _p.sample_view_pressure(30.0)!=ERR_UNCONFIGURED:
        return {"error":FAILED,"stage":"stop reset"}
    _p.free()
    _p=null
    return report

func _settle(key: Vector2i,count: int) -> bool:
    for attempt in range(240):
        await physics_frame
        _p.pump_stream()
        if _p._tiles.size()==count and _p._pending_tiles.is_empty() and _p._geometry_jobs.is_empty() and _p._tiles.has(key):
            await physics_frame
            await physics_frame
            return true
    return false

func _ground(point: Vector3) -> Dictionary:
    var query=PhysicsRayQueryParameters3D.create(Vector3(point.x,128,point.z),Vector3(point.x,-128,point.z))
    query.collide_with_areas=false
    if is_instance_valid(_body):
        query.exclude=[_body.get_rid()]
    return _p.get_world_3d().direct_space_state.intersect_ray(query)

func _valid_ground(hit: Dictionary) -> bool:
    return not hit.is_empty() and hit.get("collider") is StaticBody3D and _p.is_ancestor_of(hit["collider"]) and is_finite(hit["position"].y) and hit["normal"].y>0.0





func _fail(msg: String) -> void:
    if is_instance_valid(_body):
        _body.free()
    if _p!=null:
        _p.stop_preview()
        _p.free()
    if _builder!=null:
        _builder.close()
    push_error("H0 combined controllers: "+msg)
    quit(1)
