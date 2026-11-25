extends SceneTree
## P1.5.8b2 sustained bidirectional movement. Same route, fixed/adaptive
## forecasts, explicit stationary hold, missing-sample expiry, remote camera.
## No teleport of actual capsule inside measured trace.
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const FOOT=preload("res://addons/terra_forge/core/collision_footprint.gd")
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
const RADIUS: float=0.25
const HEIGHT: float=0.6
const SPEED: float=24.0
const GRAVITY: float=20.0
const TICKS: int=480
const ORIGIN: Vector2i=Vector2i(14,15)
var _p
var _builder
var _body: CharacterBody3D

func _initialize() -> void:
    call_deferred("_run")

func _format() -> int:
    return 0

func _mode() -> int:
    return 0

func _fixture_cells() -> Vector2i:
    return Vector2i(576,576)

func _route_offset() -> Vector2i:
    return Vector2i.ZERO

func _cache_sizes() -> Array[int]:
    return [9,16]

func _run() -> void:
    var format: int=_format()
    _builder=V1.new() if format==0 else V2.new()
    var err: Error=_builder.start(_fixture_cells(),true) if format==0 else _builder.start(_fixture_cells())
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
    for cache in _cache_sizes():
        var order: Array[bool]=[false,true]
        if cache==16:
            order.reverse()
        for adaptive in order:
            var outcome: Dictionary=await _case(made["directory"],format,_mode(),cache,adaptive)
            if outcome.get("error",FAILED)!=OK:
                _fail(str([format,_mode(),cache,adaptive])+" "+str(outcome))
                return
            var label: String = "ROUNDTRIP_TRACE " if _route_offset()==Vector2i.ZERO else "LARGE_WORLD_TRACE "
            print(label,JSON.stringify({"format":format+1,"mode":_mode(),"cache":cache,"adaptive":adaptive,"world_cells":str(_fixture_cells()),"offset":str(_route_offset()),"metrics":outcome}))
    _builder.close()
    _builder=null
    print("PASS: sustained multi-seam roundtrip, reversal, expiry and verified relocation lifecycle")
    quit(0)

func _case(directory: String,format: int,mode: int,cache: int,adaptive: bool,diagnostics: bool=false) -> Dictionary:
    var offset: Vector2i = _route_offset()
    var delta: Vector2 = Vector2(offset)
    var delta3: Vector3 = Vector3(offset.x,0,offset.y)
    var origin: Vector2i = ORIGIN + offset / 32
    var goal_x: float = 536.0 + delta.x
    var return_x: float = 470.0 + delta.x
    _p=P.new()
    _p.region_index_format=format
    _p.sampling_strategy=mode
    _p.enable_support_retention=true
    _p.enable_motion_prefetch=true
    _p.enable_adaptive_motion_horizon=adaptive
    _p.observe_geometry_latency=diagnostics
    _p.observe_capacity_wait=diagnostics
    _p.max_visible_tiles=4
    _p.high_detail_distance=64.0
    _p.medium_detail_distance=80.0
    _p.view_distance=96.0
    _p.max_tile_work_ms=8.0
    root.add_child(_p)
    if _p.start_preview(directory,cache,4)!=OK:
        return {"error":FAILED,"stage":"open"}
    _p.set_process(false)
    _p.set_stream_center(Vector3(480,0,512)+delta3)
    if not await _settle(origin,4):
        return {"error":FAILED,"stage":"warm origin"}
    await physics_frame
    var start=Vector2(478,500)+delta
    var state: Dictionary=_p.support_state()
    var session: int=state["session"]
    var claim: Dictionary=_p.update_support(start,RADIUS,session,state["revision"])
    if claim.get("error",FAILED)!=OK:
        return {"error":FAILED,"stage":"origin claim","detail":claim}
    var revision: int=claim["revision"]
    _p.set_stream_center(Vector3(100,0,100)+delta3)
    if not await _settle(origin,4) or _p._tiles.has(origin+Vector2i.RIGHT):
        return {"error":FAILED,"stage":"cold setup"}
    await physics_frame
    var ground: Dictionary=_ground(Vector3(start.x,0,start.y))
    if not _valid_ground(ground):
        return {"error":FAILED,"stage":"spawn"}
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
    var phase: int=0
    var outbound_tick: int=-1
    var reverse_tick: int=-1
    var return_tick: int=-1
    var denied: int=0
    var stall: int=0
    var longest_stall: int=0
    var transfers: int=0
    var peak_rays: int=0
    var total_rays: int=0
    var max_drift: float=0.0
    var actual_velocity=Vector2.ZERO
    var visited: Dictionary={}
    var pump_hist=HIST.new()
    var guard_hist=HIST.new()
    var sample_hist=HIST.new()
    var initial: Dictionary=_p.stats()
    var initial_capacity: Dictionary=_p.capacity_wait_profile()
    var initial_latency: Dictionary=_p.geometry_latency_profile()
    if diagnostics and (initial_capacity.is_empty() or initial_latency.is_empty()):
        return {"error":FAILED,"stage":"diagnostics not enabled"}
    if not diagnostics and (not initial_capacity.is_empty() or not initial_latency.is_empty()):
        return {"error":FAILED,"stage":"default diagnostic leak"}
    var reasons: Dictionary={}
    var denial_states: Dictionary={}
    var denial_tiles: Dictionary={}
    var peak_pages: int=0
    var peak_tiles: int=0
    var peak_jobs: int=0
    var peak_shards: int=0
    for tick in range(TICKS):
        await physics_frame
        var before: Vector3=_body.global_position
        var from=Vector2(before.x,before.z)
        if phase==0 and from.x>=goal_x-0.02:
            phase=1
            outbound_tick=tick
        if phase==1 and tick-outbound_tick>=20:
            phase=2
            reverse_tick=tick
        if phase==2 and from.x<=return_x+0.02:
            phase=3
            return_tick=tick
        if tick==100 or tick==340:
            _p.set_stream_center(Vector3(96,0,420)+delta3)
        elif tick==220:
            _p.set_stream_center(Vector3(100,0,100)+delta3)
        var command: float=0.0
        if phase==0:
            command=minf(SPEED,maxf(0.0,(goal_x-from.x)/dt))
        elif phase==2:
            command=-minf(SPEED,maxf(0.0,(from.x-return_x)/dt))
        var intent=Vector2(command,0)
        var began: int=Time.get_ticks_usec()
        # One sample on each moving/hold tick. During final stationary
        # phase cease submissions to exercise expiry of the session hint.
        if phase!=3 or tick==return_tick:
            var status: Error=_p.sample_motion_prefetch(from,actual_velocity,intent,RADIUS,session,revision)
            if status!=OK:
                return {"error":FAILED,"stage":"sample","tick":tick,"status":status}
            sample_hist.add(float(Time.get_ticks_usec()-began)/1000.0)
            if tick==0:
                if _p.sample_motion_prefetch(from,actual_velocity,intent,RADIUS,session,revision)!=ERR_BUSY:
                    return {"error":FAILED,"stage":"duplicate sample"}
        began=Time.get_ticks_usec()
        var admission: Dictionary=_p.inspect_support_step(from,from+intent*dt,RADIUS,session,revision,exclude)
        guard_hist.add(float(Time.get_ticks_usec()-began)/1000.0)
        var admitted: bool=absf(command)>0.0 and admission["ready"]
        var rays: int=int(admission.get("ray_count",0))
        if absf(command)>0.0 and not admitted:
            denied+=1
            stall+=1
            longest_stall=maxi(longest_stall,stall)
            var reason: String=admission["reason"]
            reasons[reason]=int(reasons.get(reason,0))+1
            # Snapshot the first rejected tile before moving or pumping.
            var rejected: Vector2i = admission["tile"]
            var held: bool = _p._support_keys.has(rejected)
            var tile: Dictionary = _p._tiles.get(rejected, {})
            var stage: String = reason
            if _p._blocked_tiles.has(rejected):
                stage = "blocked"
            elif _p._geometry_jobs.has(rejected):
                stage = "worker_outstanding"
            elif _p._pending_tiles.has(rejected):
                var missing := 0
                for page in _p.GEOMETRY.required_pages(_p._reader, rejected.x, rejected.y, 0, _p._tile_halo(rejected, 0)):
                    if _p._reader.page_status(page) != OK:
                        missing += 1
                stage = "pending_pages" if missing > 0 else "pending_resident"
            var shape_ready: bool = not tile.is_empty() and tile["collision"].shape is HeightMapShape3D
            var description := "%s/lod%d/shape%s/%s" % ["held" if held else "destination", int(tile.get("lod",-1)), str(shape_ready), stage]
            denial_states[description] = int(denial_states.get(description,0)) + 1
            var location := "%s/%s" % [str(rejected), "held" if held else "destination"]
            denial_tiles[location] = int(denial_tiles.get(location,0)) + 1
            if reason!="missing_lod0" and reason!="unsettled" and reason!="physics_unconfirmed":
                return {"error":FAILED,"stage":"unexpected denial","tick":tick,"detail":admission}
        else:
            stall=0
        _body.velocity=Vector3(command if admitted else 0.0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
        var after: Vector3=_body.global_position
        var actual=Vector2(after.x,after.z)
        actual_velocity=(actual-from)/dt
        if not _body.is_on_floor() or not _valid_ground(_ground(after)):
            return {"error":FAILED,"stage":"physical ground loss","tick":tick,"position":str(after)}
        if not admitted:
            max_drift=maxf(max_drift,actual.distance_to(from))
        var plan: Dictionary=FOOT.plan(actual,actual,RADIUS,_p.world_extent(),32.0)
        if not plan["ready"]:
            return {"error":FAILED,"stage":"actual footprint","tick":tick}
        if plan["tiles"]!=_p.support_state()["tiles"]:
            var moved: Dictionary=_p.update_support(actual,RADIUS,session,revision,exclude)
            if not admitted or moved.get("error",FAILED)!=OK or moved["revision"]!=revision+1:
                return {"error":FAILED,"stage":"transfer","tick":tick,"detail":moved}
            revision=moved["revision"]
            transfers+=1
            rays+=int(moved["ray_count"])
        for key in plan["tiles"]:
            visited[key]=true
        total_rays+=rays
        peak_rays=maxi(peak_rays,rays)
        began=Time.get_ticks_usec()
        var pumped: Dictionary=_p.pump_stream()
        pump_hist.add(float(Time.get_ticks_usec()-began)/1000.0)
        if pumped["error"]!=OK:
            return {"error":FAILED,"stage":"pump","tick":tick,"detail":pumped}
        var stats: Dictionary=_p.stats()
        peak_pages=maxi(peak_pages,int(stats["source"]["resident"]))
        peak_tiles=maxi(peak_tiles,int(stats["tiles"]))
        peak_jobs=maxi(peak_jobs,int(stats["geometry_reservations"]))
        peak_shards=maxi(peak_shards,int(stats["source"]["shard_resident"]))
        if int(stats["source"]["shard_resident"])>int(stats["source"]["shard_limit"]):
            return {"error":FAILED,"stage":"shard cache bound","tick":tick}
        if peak_pages>cache or peak_tiles>4 or peak_jobs>2 or stats["motion_prefetch"]["selected"].size()>2 or int(stats["motion_prefetch"]["pending_latency_samples"])>2:
            return {"error":FAILED,"stage":"resource bounds","tick":tick}
        if _p.support_state()["tiles"]!=plan["tiles"]:
            return {"error":FAILED,"stage":"lease mismatch","tick":tick}
        for key in plan["tiles"]:
            if not _p._tiles.has(key) or _p._desired_tiles.get(key,-1)!=0:
                return {"error":FAILED,"stage":"support eviction","tick":tick}
    var final: Dictionary=_p.stats()
    var capacity_report: Dictionary=_p.capacity_wait_profile()
    var latency_report: Dictionary=_p.geometry_latency_profile()
    if diagnostics:
        if int(capacity_report["observations"])-int(initial_capacity["observations"])!=TICKS or int(capacity_report["peak_active"])>4 or int(capacity_report["active"])!=0 or int(capacity_report["epoch"])!=int(final["source"]["generation"]):
            return {"error":FAILED,"stage":"capacity integration","detail":capacity_report}
        var ownership: Dictionary=latency_report["ownership"]
        var delivered_count: int=0
        for category in ["critical","optional"]:
            var group: Dictionary=latency_report[category]
            var count: int=int(group["queue_ms"]["count"])
            if int(group["build_ms"]["count"])!=count or int(group["delivery_ms"]["count"])!=count or int(group["stage_sum_ms"]["count"])!=count or int(group["delivered_errors"])!=0:
                return {"error":FAILED,"stage":"latency accounting","category":category,"detail":group}
            delivered_count+=count
        if delivered_count!=int(ownership["delivered"]) or int(ownership["submitted"])!=int(ownership["delivered"])+int(ownership["dropped"])+int(ownership["owned"]) or int(ownership["owned"])!=0 or int(latency_report["critical"]["queue_ms"]["count"])<=0:
            return {"error":FAILED,"stage":"ownership integration","detail":latency_report}
    var motion: Dictionary=final["motion_prefetch"]
    var report: Dictionary={"error":OK,"ticks":TICKS,"outbound_tick":outbound_tick,"reverse_tick":reverse_tick,"return_tick":return_tick,"finish_x":_body.global_position.x,"transfers":transfers,"visited_tiles":visited.size(),"denied_ticks":denied,"longest_stall_ticks":longest_stall,"denial_states":denial_states,"denial_tiles":denial_tiles,"denial_reasons":reasons,"missing_rays":0,"airborne_ticks":0,"max_denied_drift":max_drift,"peak_rays":peak_rays,"total_rays":total_rays,"peak_pages":peak_pages,"peak_tiles":peak_tiles,"peak_jobs":peak_jobs,"disk_reads":int(final["source"]["disk_reads"])-int(initial["source"]["disk_reads"]),"stale_discarded":int(final["source"]["stale_discarded"])-int(initial["source"]["stale_discarded"]),"builds":int(final["mesh_builds"])-int(initial["mesh_builds"]),"pump_ms":pump_hist.report(),"guard_ms":guard_hist.report(),"sample_ms":sample_hist.report(),"motion":motion}
    report["peak_shards"]=peak_shards
    report["shard_loads"]=int(final["source"]["shard_loads"])-int(initial["source"]["shard_loads"])
    if outbound_tick<0 or reverse_tick<=outbound_tick or return_tick<=reverse_tick or return_tick>TICKS-10 or visited.size()!=3 or transfers!=8 or max_drift>0.05 or absf(_body.global_position.x-return_x)>0.05 or not motion["keys"].is_empty() or int(motion["expirations"])<1 or (adaptive and int(motion["latency"]["samples"])<2):
        report["error"]=FAILED
        report["stage"]="roundtrip evidence"
        return report
    if diagnostics:
        report["capacity_wait"]=capacity_report
        report["geometry_latency"]=latency_report
        report["measured_gate_observations"]=int(capacity_report["observations"])-int(initial_capacity["observations"])
        report["delivered_delta"]=int(latency_report["ownership"]["delivered"])-int(initial_latency["ownership"]["delivered"])
    # Separate unmeasured lifecycle test: sample near old boundary, then
    # deliberately reassign support to distant VERIFIED terrain. No physics
    # guarantee is implied for arbitrary teleports. No pump before claim.
    _body.free()
    _body=null
    _p.max_visible_tiles=8
    _p.set_stream_center(Vector3(480,0,512)+delta3)
    if not await _settle(origin,8):
        return {"error":FAILED,"stage":"relocation warm"}
    await physics_frame
    var near=Vector2(478,500)+delta
    if _p.sample_motion_prefetch(near,Vector2.ZERO,Vector2(24,0),RADIUS,session,revision)!=OK:
        return {"error":FAILED,"stage":"relocation sample"}
    var prior: Dictionary=_p.motion_prefetch_state()
    if prior["keys"].is_empty():
        return {"error":FAILED,"stage":"relocation hint"}
    var far=Vector2(500,530)+delta
    var relocated: Dictionary=_p.update_support(far,RADIUS,session,revision)
    if relocated.get("error",FAILED)!=OK or not _p.motion_prefetch_state()["keys"].is_empty() or int(_p.motion_prefetch_state()["relocations"])!=1:
        return {"error":FAILED,"stage":"relocation revoke","detail":relocated}
    var next_revision: int=relocated["revision"]
    if _p.sample_motion_prefetch(near,Vector2.ZERO,Vector2(24,0),RADIUS,session,revision)!=ERR_INVALID_PARAMETER or _p.release_support(session,next_revision)!=OK:
        return {"error":FAILED,"stage":"stale or release"}
    _p.stop_preview()
    if not _p.capacity_wait_profile().is_empty() or not _p.geometry_latency_profile().is_empty():
        return {"error":FAILED,"stage":"diagnostics stop reset"}
    if _p.motion_prefetch_state()["active"] or not _p.motion_prefetch_state()["keys"].is_empty():
        return {"error":FAILED,"stage":"stop reset"}
    _p.free()
    _p=null
    report["relocation_verified"]=true
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
    push_error("Motion roundtrip: "+msg)
    quit(1)
