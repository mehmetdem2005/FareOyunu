extends "res://addons/terra_forge/tests/test_support_transfer.gd"
## H3: matched route, one worker, bounded outstanding slots 1/2/4.
## Queue reservation bytes are not measured RSS or GPU memory.
const ROUTE_TICKS: int=720
const GOALS: Array[float]=[536.0,500.0,552.0,510.0]

func _run() -> void:
    for format in _formats():
        _builder=V1.new() if format==0 else V2.new()
        var err: Error=_builder.start(Vector2i(576,576),true) if format==0 else _builder.start(Vector2i(576,576))
        if err!=OK:
            _fail("H3 fixture")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=_builder.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("H3 fixture result")
            return
        var order: Array[int]=[1,2,4]
        if format==1:
            order.reverse()
        for cap in order:
            var result: Dictionary=await _route(made["directory"],format,cap)
            if result.get("error",FAILED)!=OK:
                _fail("H3 "+str([format,cap,result]))
                return
            print("H3_CAPACITY_TRACE ",JSON.stringify({"format":format+1,"cap":cap,"metrics":result}))
        _builder.close()
        _builder=null
    print("PASS: H3 fixed capacity matrix, matched route, bounded ownership and shutdown")
    quit(0)

func _route(directory: String,format: int,cap: int) -> Dictionary:
    _p=P.new()
    _p.region_index_format=format
    _p.sampling_strategy=5
    _p.geometry_job_limit=cap
    _p.enable_support_retention=true
    _p.enable_motion_prefetch=true
    _p.enable_adaptive_motion_horizon=true
    _p.enable_adaptive_view_budget=true
    _p.enable_adaptive_work_budget=true
    _p.max_visible_tiles=12
    _p.high_detail_distance=32.0
    _p.medium_detail_distance=80.0
    _p.view_distance=160.0
    _p.max_tile_work_ms=8.0
    _p.tile_updates_per_frame=3
    root.add_child(_p)
    if _p.start_preview(directory,16,4)!=OK:
        return {"error":FAILED,"stage":"open"}
    _p.set_process(false)
    _p.set_stream_center(Vector3(512,0,512))
    if not await _settle(OLD,12):
        return {"error":FAILED,"stage":"warm"}
    await physics_frame
    var state: Dictionary=_p.support_state()
    var session: int=state["session"]
    var start=Vector2(510,500)
    var claim: Dictionary=_p.update_support(start,RADIUS,session,state["revision"])
    if claim.get("error",FAILED)!=OK:
        return {"error":FAILED,"stage":"initial lease"}
    var revision: int=claim["revision"]
    var initial_revision: int=revision
    _p.set_stream_center(Vector3(100,0,100))
    if not await _settle(OLD,12):
        return {"error":FAILED,"stage":"remote warm"}
    await physics_frame
    var ground: Dictionary=_ground(Vector3(start.x,0,start.y))
    if not _valid_ground(ground):
        return {"error":FAILED,"stage":"spawn ray"}
    _body=CharacterBody3D.new()
    _body.floor_snap_length=0.5
    _body.floor_max_angle=deg_to_rad(45.0)
    _body.floor_constant_speed=true
    var capsule=CapsuleShape3D.new()
    capsule.radius=RADIUS
    capsule.height=HEIGHT
    var shape=CollisionShape3D.new()
    shape.shape=capsule
    _body.add_child(shape)
    _body.position=Vector3(start.x,float(ground["position"].y)+HEIGHT*0.5+0.05,start.y)
    root.add_child(_body)
    var dt: float=1.0/float(Engine.physics_ticks_per_second)
    var exclude: Array[RID]=[_body.get_rid()]
    for i in range(20):
        await physics_frame
        _body.velocity=Vector3(0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
    if not _body.is_on_floor():
        return {"error":FAILED,"stage":"settled floor"}
    var leg: int=0
    var goal_ticks: Array[int]=[]
    var denied: int=0
    var shifts: int=0
    var peak_tiles: int=0
    var peak_pages: int=0
    var peak_jobs: int=0
    var actual_velocity=Vector2.ZERO
    var traversed: float=0.0
    var pump_hist=HIST.new()
    var peak_reserved: int=0
    var peak_pending: int=0
    var peak_finished: int=0
    var last_tier: int=0
    var transitions: int=0
    for tick in range(ROUTE_TICKS):
        await physics_frame
        # Sample gap while the real physics body remains supported.
        var gap: bool=tick>=300 and tick<312
        if not gap:
            var pressure: float=55.0 if int(tick/120)%2==0 else 20.0
            if _p.sample_view_pressure(pressure)!=OK:
                return {"error":FAILED,"stage":"pressure","tick":tick}
        if tick%60==0:
            var anchor=Vector3(100,0,100) if int(tick/60)%2==0 else Vector3(220,0,100)
            _p.set_stream_center(anchor)
            shifts+=1
        var before: Vector3=_body.global_position
        var from=Vector2(before.x,before.z)
        var command: float=0.0
        if leg<GOALS.size() and not gap:
            command=clampf((GOALS[leg]-from.x)/dt,-24.0,24.0)
        var intent=Vector2(command,0)
        if _p.sample_motion_prefetch(from,actual_velocity,intent,RADIUS,session,revision)!=OK:
            return {"error":FAILED,"stage":"motion sample","tick":tick}
        var admission: Dictionary=_p.inspect_support_step(from,from+intent*dt,RADIUS,session,revision,exclude)
        var admitted: bool=admission["ready"] and absf(command)>0.001
        if absf(command)>0.001 and not admitted:
            denied+=1
            if admission["reason"] not in ["missing_lod0","unsettled","physics_unconfirmed"]:
                return {"error":FAILED,"stage":"admission","tick":tick,"detail":admission}
        _body.velocity=Vector3(command if admitted else 0.0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
        var after: Vector3=_body.global_position
        var actual=Vector2(after.x,after.z)
        actual_velocity=(actual-from)/dt
        traversed+=absf(actual.x-from.x)
        if not _body.is_on_floor() or not _valid_ground(_ground(after)):
            return {"error":FAILED,"stage":"ground","tick":tick,"position":str(after)}
        if not admitted and actual.distance_to(from)>0.05:
            return {"error":FAILED,"stage":"denied drift","tick":tick}
        var plan: Dictionary=FOOT.plan(actual,actual,RADIUS,_p.world_extent(),32.0)
        if not plan["ready"]:
            return {"error":FAILED,"stage":"footprint"}
        if plan["tiles"]!=_p.support_state()["tiles"]:
            var transfer: Dictionary=_p.update_support(actual,RADIUS,session,revision,exclude)
            if not admitted or transfer.get("error",FAILED)!=OK or transfer["revision"]!=revision+1:
                return {"error":FAILED,"stage":"transfer","tick":tick,"detail":transfer}
            revision=transfer["revision"]
        if leg<GOALS.size() and absf(actual.x-GOALS[leg])<0.02:
            goal_ticks.append(tick)
            leg+=1
        if not gap:
            var started: int=Time.get_ticks_usec()
            var pumped: Dictionary=_p.pump_stream()
            pump_hist.add(float(Time.get_ticks_usec()-started)/1000.0)
            if pumped["error"]!=OK:
                return {"error":FAILED,"stage":"pump","tick":tick}
        var stats: Dictionary=_p.stats()
        peak_tiles=maxi(peak_tiles,int(stats["tiles"]))
        peak_pages=maxi(peak_pages,int(stats["source"]["resident"]))
        peak_jobs=maxi(peak_jobs,int(stats["geometry_reservations"]))
        var ws: Dictionary=stats["geometry_worker"]
        peak_reserved=maxi(peak_reserved,int(ws["reserved_payload_bytes"]))
        peak_pending=maxi(peak_pending,int(ws["pending"]))
        peak_finished=maxi(peak_finished,int(ws["finished"]))
        if int(ws["cap"])!=cap or int(ws["slots"])>cap or int(ws["inflight"])>1 or int(ws["reserved_payload_bytes"])>int(ws["payload_cap_bytes"]) or int(ws["submitted"])!=int(ws["delivered"])+int(ws["dropped"])+int(ws["slots"]):
            return {"error":FAILED,"stage":"worker ownership","tick":tick,"worker":ws}
        if peak_tiles>12 or peak_pages>16 or peak_jobs>cap:
            return {"error":FAILED,"stage":"cap","tick":tick}
        var held: Dictionary=_p.support_state()
        if held["tiles"]!=plan["tiles"] or held["revision"]!=revision:
            return {"error":FAILED,"stage":"lease","tick":tick}
        for key in held["tiles"]:
            if not _p._tiles.has(key) or _p._desired_tiles.get(key,-1)!=0:
                return {"error":FAILED,"stage":"evicted support","tick":tick}
        var view: Dictionary=_p.adaptive_view_state()
        var work: Dictionary=_p.adaptive_work_state()
        var motion: Dictionary=_p.motion_prefetch_state()
        var tier: int=view["controller"]["tier"]
        var horizon: float=motion["latency"]["horizon_seconds"]
        if absi(tier-last_tier)>1 or work["controller"]["tier"]!=tier or horizon<0.125 or horizon>0.5 or motion["selected"].size()>2:
            return {"error":FAILED,"stage":"controller","tick":tick}
        if tier!=last_tier:
            transitions+=1
            last_tier=tier
    if leg!=GOALS.size() or revision-initial_revision<8 or transitions<4 or absf(_body.global_position.x-510.0)>0.05:
        return {"error":FAILED,"stage":"route evidence","goals":goal_ticks,"revisions":revision-initial_revision,"transitions":transitions,"finish":_body.global_position.x}
    var report: Dictionary={"error":OK,"ticks":ROUTE_TICKS,"goals":goal_ticks,"travel_x":traversed,"support_revisions":revision-initial_revision,"denied_ticks":denied,"missing_rays":0,"airborne_ticks":0,"camera_shifts":shifts,"tier_transitions":transitions,"peak_tiles":peak_tiles,"peak_pages":peak_pages,"peak_jobs":peak_jobs,"simulated_sample_gap_ticks":12,"note":"No actual app pause/background, no phone FPS claim."}
    var final_stats: Dictionary=_p.stats()
    var worker=_p._geometry_worker
    report["worker_final"]=final_stats["geometry_worker"]
    report["mesh_builds"]=final_stats["mesh_builds"]
    report["source_reads"]=final_stats["source"].get("disk_reads",-1)
    report["peak_reserved_payload_bytes"]=peak_reserved
    report["peak_pending"]=peak_pending
    report["peak_finished"]=peak_finished
    report["pump_ms"]=pump_hist.report()
    report["note"]="One worker; slot allowance is not RSS, wall timing is headless CPU, equal route not necessarily equal optional work."
    _body.free()
    _body=null
    _p.stop_preview()
    var closed: Dictionary=worker.stats()
    var stopped: Dictionary=_p.stats()
    if closed["open"] or closed["slots"]!=0 or closed["reserved_payload_bytes"]!=0 or stopped["active"] or stopped["tiles"]!=0 or stopped["geometry_reservations"]!=0:
        return {"error":FAILED,"stage":"shutdown","worker":closed}
    report["shutdown_clean"]=true
    _p.free()
    _p=null
    return report
