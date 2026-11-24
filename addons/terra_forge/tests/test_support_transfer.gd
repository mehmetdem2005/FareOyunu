extends SceneTree
## P1.5.7e3: continuous physics while a cold seam loads, then live support
## transfer and camera departure. No pause in the measured 150-tick trace.
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const FOOT=preload("res://addons/terra_forge/core/collision_footprint.gd")
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
const RADIUS: float=0.25
const HEIGHT: float=0.6
const GRAVITY: float=20.0
const TICKS: int=150
const OLD: Vector2i=Vector2i(15,15)
const NEW: Vector2i=Vector2i(16,15)
var _p
var _builder
var _body: CharacterBody3D

func _initialize() -> void:
    call_deferred("_run")

func _formats() -> Array[int]:
    return [0]

func _run() -> void:
    for format in _formats():
        _builder=V1.new() if format==0 else V2.new()
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
            for cap in [4,8]:
                for speed in [12.0,24.0]:
                    var result: Dictionary=await _case(made["directory"],format,mode,cap,speed)
                    if result.get("error",FAILED)!=OK:
                        _fail(str([format,mode,cap,speed])+" "+str(result))
                        return
                    print("TRANSFER_TRACE ",JSON.stringify({"format":format+1,"mode":mode,"cap":cap,"speed":speed,"metrics":result}))
        _builder.close()
        _builder=null
    print("PASS: continuous physics cold seam admission and verified live support transfer, fixed cap and camera departure")
    quit(0)

func _case(directory: String,format: int,mode: int,cap: int,speed: float,predictive: bool=false,paired_single_seam: bool=false,adaptive: bool=false,cache_pages: int=16,work_trial: int=-1) -> Dictionary:
    _p=P.new()
    _p.region_index_format=format
    _p.sampling_strategy=mode
    _p.enable_support_retention=true
    _p.enable_motion_prefetch=predictive
    _p.enable_adaptive_motion_horizon=adaptive
    _p.max_visible_tiles=cap
    _p.high_detail_distance=64.0
    _p.medium_detail_distance=80.0
    _p.view_distance=96.0
    _p.max_tile_work_ms=8.0
    if work_trial>=0:
        _p.enable_adaptive_view_budget=true
        _p.enable_adaptive_work_budget=work_trial==1
        _p.high_detail_distance=32.0
        _p.view_distance=160.0
        _p.tile_updates_per_frame=3
    root.add_child(_p)
    if _p.start_preview(directory,cache_pages,4)!=OK:
        return {"error":FAILED,"stage":"open"}
    _p.set_process(false)
    _p.set_stream_center(Vector3(512,0,512))
    if not await _settle(OLD,cap):
        return {"error":FAILED,"stage":"warm origin"}
    await physics_frame
    var state: Dictionary=_p.support_state()
    var session: int=state["session"]
    var revision: int=state["revision"]
    var start=Vector2(510,500)
    var claim: Dictionary=_p.update_support(start,RADIUS,session,revision)
    if claim.get("error",FAILED)!=OK or claim["tiles"]!=[OLD]:
        return {"error":FAILED,"stage":"claim origin","detail":claim}
    revision=claim["revision"]
    _p.set_stream_center(Vector3(100,0,100))
    if not await _settle(OLD,cap) or _p._tiles.has(NEW):
        return {"error":FAILED,"stage":"cold setup"}
    await physics_frame
    var ground: Dictionary=_ground(Vector3(start.x,0,start.y))
    if not _valid_ground(ground):
        return {"error":FAILED,"stage":"spawn ray"}
    _body=CharacterBody3D.new()
    _body.floor_snap_length=0.5
    _body.floor_max_angle=deg_to_rad(45.0)
    _body.floor_constant_speed=true
    var shape=CapsuleShape3D.new()
    shape.radius=RADIUS
    shape.height=HEIGHT
    var collision=CollisionShape3D.new()
    collision.shape=shape
    _body.add_child(collision)
    _body.position=Vector3(start.x,float(ground["position"].y)+HEIGHT*0.5+0.05,start.y)
    root.add_child(_body)
    var dt: float=1.0/float(Engine.physics_ticks_per_second)
    var exclude: Array[RID]=[_body.get_rid()]
    for tick in range(20):
        await physics_frame
        _body.velocity=Vector3(0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
    if not _body.is_on_floor():
        return {"error":FAILED,"stage":"settled floor"}
    await physics_frame
    var position=Vector2(_body.global_position.x,_body.global_position.z)
    var stale: Dictionary=_p.inspect_support_step(position,position,RADIUS,session,revision-1,exclude)
    var mismatch: Dictionary=_p.inspect_support_step(Vector2(500,540),Vector2(500,540),RADIUS,session,revision,exclude)
    var large: Dictionary=_p.inspect_support_step(position,Vector2(575,570),RADIUS,session,revision,exclude)
    if stale["reason"]!="stale_lease" or mismatch["reason"]!="lease_footprint_mismatch" or large["reason"]!="support_cap":
        return {"error":FAILED,"stage":"admission guards","detail":[stale,mismatch,large]}
    var denied: int=0
    var cold_denied: int=0
    var resumed: int=-1
    var longest_stall: int=0
    var stall: int=0
    var both_tick: int=-1
    var new_tick: int=-1
    var old_evicted_tick: int=-1
    var max_tiles: int=0
    var max_pages: int=0
    var max_jobs: int=0
    var peak_rays: int=0
    var total_rays: int=0
    var max_denied_drift: float=0.0
    var guard_hist=HIST.new()
    var claim_hist=HIST.new()
    var pump_hist=HIST.new()
    var reasons: Dictionary={}
    var previous_revision: int=revision
    var actual_velocity: Vector2=Vector2.ZERO
    var initial_io: Dictionary=_p.stats()["source"]
    var peak_forecast: int=0
    var admitted_ticks: int=0
    var demanded_ticks: int=0
    var goal_x: float=536.0
    var goal_tick: int=-1
    for tick in range(TICKS):
        await physics_frame
        if work_trial>=0:
            # Both paired paths see the same deterministic pressure input;
            # only the optional work governor differs.
            if _p.sample_view_pressure(55.0 if tick<96 else 20.0)!=OK:
                return {"error":FAILED,"stage":"work pressure"}
        var before: Vector3=_body.global_position
        var from=Vector2(before.x,before.z)
        # Fixed schedule, independent of IO completion. At 96 stop walking
        # and move the camera away; keep simulating gravity until tick 150.
        if tick==24:
            _p.set_stream_center(Vector3(512,0,512))
        if tick==96:
            _p.set_stream_center(Vector3(100,0,100))
        # Paired comparison explicitly ends at a shared waypoint before the
        # second seam (x544). Do not let faster admission silently change
        # the topology of this single-seam experiment. e3 remains untouched.
        var walking: bool=tick<96 and (not paired_single_seam or from.x<goal_x-0.02)
        var commanded: float=speed if walking else 0.0
        if paired_single_seam and walking:
            commanded=minf(commanded,maxf(0.0,(goal_x-from.x)/dt))
        if walking:
            demanded_ticks+=1
        var intent=Vector2(commanded,0)
        if predictive and _p.sample_motion_prefetch(from,actual_velocity,intent,RADIUS,session,revision)!=OK:
            return {"error":FAILED,"stage":"motion sample","tick":tick}
        var requested: Vector2=from+intent*dt
        var began: int=Time.get_ticks_usec()
        var admission: Dictionary=_p.inspect_support_step(from,requested,RADIUS,session,revision,exclude)
        guard_hist.add(float(Time.get_ticks_usec()-began)/1000.0)
        var rays: int=int(admission.get("ray_count",0))
        var admitted: bool=walking and admission["ready"]
        if walking and not admitted:
            denied+=1
            stall+=1
            longest_stall=maxi(longest_stall,stall)
            var reason: String=admission["reason"]
            reasons[reason]=int(reasons.get(reason,0))+1
            if tick<24:
                cold_denied+=1
            if reason!="missing_lod0" and reason!="unsettled" and reason!="physics_unconfirmed":
                return {"error":FAILED,"stage":"unexpected denial","tick":tick,"detail":admission}
        elif admitted:
            if stall>0 and resumed<0:
                resumed=tick
            stall=0
        if admitted:
            admitted_ticks+=1
        _body.velocity=Vector3(commanded if admitted else 0.0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
        var after: Vector3=_body.global_position
        var actual=Vector2(after.x,after.z)
        actual_velocity=(actual-from)/dt
        if paired_single_seam and actual.x>=goal_x-0.02 and goal_tick<0:
            goal_tick=tick
        var hit: Dictionary=_ground(after)
        if not _body.is_on_floor() or not _valid_ground(hit):
            return {"error":FAILED,"stage":"actual ground loss","tick":tick,"admission":admission,"position":str(after)}
        if not admitted:
            max_denied_drift=maxf(max_denied_drift,actual.distance_to(from))
        var plan: Dictionary=FOOT.plan(actual,actual,RADIUS,_p.world_extent(),32.0)
        if not plan["ready"]:
            return {"error":FAILED,"stage":"actual footprint","tick":tick}
        var held: Dictionary=_p.support_state()
        if plan["tiles"]!=held["tiles"]:
            # No pump between the verified admission, movement and transfer.
            # If actual motion diverges, fail; never release on predicted XZ.
            began=Time.get_ticks_usec()
            var transfer: Dictionary=_p.update_support(actual,RADIUS,session,revision,exclude)
            claim_hist.add(float(Time.get_ticks_usec()-began)/1000.0)
            rays+=int(transfer.get("ray_count",0))
            if not admitted or transfer.get("error",FAILED)!=OK or transfer["revision"]!=revision+1:
                return {"error":FAILED,"stage":"live transfer","tick":tick,"detail":transfer}
            revision=transfer["revision"]
            if transfer["tiles"]==[OLD,NEW] and both_tick<0:
                both_tick=tick
            if transfer["tiles"]==[NEW] and new_tick<0:
                new_tick=tick
        total_rays+=rays
        peak_rays=maxi(peak_rays,rays)
        began=Time.get_ticks_usec()
        var pumped: Dictionary=_p.pump_stream()
        pump_hist.add(float(Time.get_ticks_usec()-began)/1000.0)
        if pumped["error"]!=OK:
            return {"error":FAILED,"stage":"pump","tick":tick,"detail":pumped}
        var stats: Dictionary=_p.stats()
        peak_forecast=maxi(peak_forecast,stats["motion_prefetch"]["selected"].size())
        if peak_forecast>2 or int(stats["motion_prefetch"]["pending_latency_samples"])>2:
            return {"error":FAILED,"stage":"forecast cap"}
        max_tiles=maxi(max_tiles,int(stats["tiles"]))
        max_pages=maxi(max_pages,int(stats["source"]["resident"]))
        max_jobs=maxi(max_jobs,int(stats["geometry_reservations"]))
        if max_tiles>cap or max_pages>cache_pages or max_jobs>2:
            return {"error":FAILED,"stage":"resource caps","tick":tick}
        var post_pump: Dictionary=_p.support_state()
        if post_pump["tiles"]!=plan["tiles"]:
            return {"error":FAILED,"stage":"actual footprint lease mismatch after pump","tick":tick}
        for key in post_pump["tiles"]:
            if not _p._tiles.has(key) or _p._desired_tiles.get(key,-1)!=0:
                return {"error":FAILED,"stage":"evicted current lease","tick":tick}
        if not _p._tiles.has(OLD):
            if post_pump["tiles"].has(OLD) or new_tick<0:
                return {"error":FAILED,"stage":"premature origin eviction","tick":tick,"held":post_pump["tiles"]}
            if old_evicted_tick<0:
                old_evicted_tick=tick
    var finish: Vector3=_body.global_position
    var report: Dictionary={"error":OK,"ticks":TICKS,"cold_denied":cold_denied,"denied_ticks":denied,"longest_stall_ticks":longest_stall,"first_resume_tick":resumed,"both_tiles_tick":both_tick,"new_only_tick":new_tick,"old_evicted_tick":old_evicted_tick,"revisions":revision-previous_revision,"finish_x":finish.x,"max_denied_drift":max_denied_drift,"missing_rays":0,"airborne_ticks":0,"total_readiness_rays":total_rays,"peak_readiness_rays":peak_rays,"max_tiles":max_tiles,"max_pages":max_pages,"max_jobs":max_jobs,"denial_reasons":reasons,"guard_ms":guard_hist.report(),"transfer_ms":claim_hist.report(),"pump_ms":pump_hist.report(),"support":_p.support_state()}
    var final_io: Dictionary=_p.stats()["source"]
    report["motion_prefetch"]=_p.motion_prefetch_state()
    report["peak_forecast"]=peak_forecast
    report["adaptive"]=adaptive
    report["cache_pages"]=cache_pages
    if work_trial>=0:
        report["work_trial"]=work_trial
        report["adaptive_work"]=_p.adaptive_work_state()
        report["adaptive_view"]=_p.adaptive_view_state()
        if work_trial==1:
            var work: Dictionary=report["adaptive_work"]["controller"]
            if int(work["restricted_pumps"])<=0 or int(work["critical_attempts"])<=0 or int(work["optional_attempts"])<=0 or int(work["restricted_peak_optional"])>2 or int(work["tier2_peak_optional"])>1:
                return {"error":FAILED,"stage":"adaptive work evidence","detail":report}
    if adaptive:
        var latency: Dictionary=_p.motion_prefetch_state()["latency"]
        if int(latency["samples"])<1 or float(latency["horizon_seconds"])<0.125 or float(latency["horizon_seconds"])>0.5 or int(_p.motion_prefetch_state()["pending_latency_samples"])!=0:
            return {"error":FAILED,"stage":"adaptive latency evidence","detail":report}
    report["disk_reads_delta"]=int(final_io["disk_reads"])-int(initial_io["disk_reads"])
    report["stale_discarded_delta"]=int(final_io["stale_discarded"])-int(initial_io["stale_discarded"])
    report["mesh_builds"]=_p.stats()["mesh_builds"]
    report["demanded_ticks"]=demanded_ticks
    report["admitted_ticks"]=admitted_ticks
    report["paired_single_seam"]=paired_single_seam
    report["goal_tick"]=goal_tick
    report["goal_x"]=goal_x if paired_single_seam else null
    # Predictive path may eliminate all stalls; baseline remains strict.
    if predictive and (peak_forecast==0 or not _p.motion_prefetch_state()["keys"].is_empty()):
        return {"error":FAILED,"stage":"forecast not used or stationary not cleared","detail":report}
    # The invariant is causal, not a camera timestamp: OLD may disappear
    # immediately AFTER the actual footprint transfers to NEW. Baseline
    # still has the original camera-only eviction time assertion.
    var eviction_valid: bool=old_evicted_tick>=new_tick and new_tick>=0 and not _p._tiles.has(OLD)
    if not predictive:
        eviction_valid=eviction_valid and old_evicted_tick>=96
    if (not predictive and (cold_denied<6 or resumed<24)) or both_tick<0 or new_tick<=both_tick or new_tick>=96 or not eviction_valid or revision-previous_revision!=2 or max_denied_drift>0.05 or finish.x<=512.5 or _p.support_state()["tiles"]!=[NEW] or (paired_single_seam and finish.x>goal_x+0.05) or admitted_ticks+denied!=demanded_ticks:
        report["error"]=FAILED
        report["stage"]="transfer evidence"
        return report
    _body.free()
    _body=null
    _p.stop_preview()
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
    push_error("Support transfer: "+msg)
    quit(1)
