extends "res://addons/terra_forge/tests/test_support_transfer.gd"
## I1: actual terrain mesh pixels at physical capsule checkpoints.
## Existing geometry only, unshaded diagnostic material, software renderer.
var _camera: Camera3D
const ROUTE_TICKS: int=720
const GOALS: Array[float]=[536.0,500.0,552.0,510.0]

func _run() -> void:
    var expected: String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--require-renderer="):
            expected=arg.get_slice("=",1)
    if DisplayServer.get_name().to_lower()=="headless" or expected.is_empty() or RenderingServer.get_current_rendering_method()!=expected:
        _fail("I1 required non-headless renderer absent or fallback")
        return
    _camera=Camera3D.new()
    _camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    _camera.size=4.0
    root.add_child(_camera)
    _camera.make_current()
    for format in [0,1]:
        _builder=V1.new() if format==0 else V2.new()
        var err: Error=_builder.start(Vector2i(576,576),true) if format==0 else _builder.start(Vector2i(576,576))
        if err!=OK:
            _fail("I1 fixture")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=_builder.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("I1 fixture result")
            return
        for arm in [4,5,6]:
            var result: Dictionary=await _route(made["directory"],format,arm)
            if result.get("error",FAILED)!=OK:
                _fail("I1 "+str([format,arm,result]))
                return
            print("I1_RENDERED_TERRAIN ",JSON.stringify({"renderer":expected,"format":format+1,"arm":arm,"mode":4 if arm==4 else 7,"metrics":result}))
        _builder.close()
        _builder=null
    _camera.free()
    _camera=null
    print("PASS: I1 rendered terrain support checkpoints and post-stop ghost rejection")
    quit(0)

func _route(directory: String,format: int,arm: int,job_cap: int=2) -> Dictionary:
    _p=P.new()
    _p.region_index_format=format
    _p.sampling_strategy=4 if arm==4 else 7
    _p.hybrid_scalar_sampling=arm!=4
    _p.hybrid_topology_cache=arm==6
    _p.hybrid_cropped_halo=arm!=4
    _p.geometry_job_limit=job_cap
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
    var material: StandardMaterial3D=_p._material
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo=false
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    material.albedo_color=Color(1,0,1,1)
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
    var checkpoints: Array[Dictionary]=[]
    var initial: Dictionary=await _pixels(_body.global_position)
    if initial.get("center_magenta",-1)!=256:
        return {"error":FAILED,"stage":"initial rendered support","pixels":initial}
    checkpoints.append(initial)
    var denied: int=0
    var denied_streak: int=0
    var longest_denied_streak: int=0
    var anchor_missing: int=0
    var anchor_missing_streak: int=0
    var anchor_longest_streak: int=0
    var anchor_samples: int=0
    var physical_samples: int=0
    var stream_anchor=Vector3(100,0,100)
    var shifts: int=0
    var peak_tiles: int=0
    var peak_pages: int=0
    var peak_jobs: int=0
    var actual_velocity=Vector2.ZERO
    var traversed: float=0.0
    var pump_hist=HIST.new()
    var peak_payload: int=0
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
            stream_anchor=Vector3(100,0,100) if int(tick/60)%2==0 else Vector3(220,0,100)
            _p.set_stream_center(stream_anchor)
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
            denied_streak+=1
            longest_denied_streak=maxi(longest_denied_streak,denied_streak)
            if admission["reason"] not in ["missing_lod0","unsettled","physics_unconfirmed"]:
                return {"error":FAILED,"stage":"admission","tick":tick,"detail":admission}
        else:
            denied_streak=0
        _body.velocity=Vector3(command if admitted else 0.0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
        var after: Vector3=_body.global_position
        var actual=Vector2(after.x,after.z)
        actual_velocity=(actual-from)/dt
        traversed+=absf(actual.x-from.x)
        if not _body.is_on_floor() or not _valid_ground(_ground(after)):
            return {"error":FAILED,"stage":"ground","tick":tick,"position":str(after)}
        physical_samples+=1
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
            var pixels: Dictionary=await _pixels(after)
            if pixels.get("center_magenta",-1)!=256:
                return {"error":FAILED,"stage":"rendered support","tick":tick,"pixels":pixels}
            checkpoints.append(pixels)
        if not gap:
            var stamp: int=Time.get_ticks_usec()
            var pumped: Dictionary=_p.pump_stream()
            pump_hist.add(float(Time.get_ticks_usec()-stamp)/1000.0)
            if pumped["error"]!=OK:
                return {"error":FAILED,"stage":"pump","tick":tick}
        # The remote stream anchor is deliberately not the physical actor.
        # Attachment is not a physics ray or actual camera pixel.
        anchor_samples+=1
        if not _p.has_collision_at(stream_anchor):
            anchor_missing+=1
            anchor_missing_streak+=1
            anchor_longest_streak=maxi(anchor_longest_streak,anchor_missing_streak)
        else:
            anchor_missing_streak=0
        var stats: Dictionary=_p.stats()
        peak_tiles=maxi(peak_tiles,int(stats["tiles"]))
        peak_pages=maxi(peak_pages,int(stats["source"]["resident"]))
        peak_jobs=maxi(peak_jobs,int(stats["geometry_reservations"]))
        var ws: Dictionary=stats["geometry_worker"]
        peak_payload=maxi(peak_payload,int(ws["reserved_payload_bytes"]))
        if ws["cap"]!=job_cap or ws["slots"]>job_cap or ws["inflight"]>1 or ws["reserved_payload_bytes"]>ws["payload_cap_bytes"] or int(ws["submitted"])!=int(ws["delivered"])+int(ws["dropped"])+int(ws["slots"]):
            return {"error":FAILED,"stage":"worker ownership","tick":tick}
        if peak_tiles>12 or peak_pages>16 or peak_jobs>job_cap:
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
    report["physical_contact_samples"]=physical_samples
    report["remote_anchor_attachment_samples"]=anchor_samples
    report["remote_anchor_missing_shape_samples"]=anchor_missing
    report["remote_anchor_longest_missing_ticks"]=anchor_longest_streak
    report["longest_denied_ticks"]=longest_denied_streak
    report["source_reads"]=final_stats["source"].get("disk_reads",0)
    report["mesh_builds"]=final_stats.get("mesh_builds",0)
    report["hybrid_topology_cache"]=arm==6
    report["job_cap"]=job_cap
    report["pump_ms"]=pump_hist.report()
    report["peak_reserved_payload_bytes"]=peak_payload
    report["worker_final"]=final_stats["geometry_worker"]
    report["worker_ms"]=final_stats["geometry_worker_ms"]
    report["queue_ms"]=final_stats["geometry_queue_ms"]
    report["delivery_ms"]=final_stats["geometry_delivery_ms"]
    if physical_samples!=ROUTE_TICKS or anchor_samples!=ROUTE_TICKS or anchor_missing>anchor_samples or anchor_longest_streak>anchor_missing or longest_denied_streak>denied:
        return {"error":FAILED,"stage":"sample accounting"}
    _body.free()
    _body=null
    _p.stop_preview()
    var ghost: Dictionary=await _pixels(Vector3(510,0,500))
    if ghost.get("total_magenta",-1)!=0:
        return {"error":FAILED,"stage":"ghost after stop","pixels":ghost}
    report["checkpoints"]=checkpoints
    report["post_stop_pixels"]=ghost
    report["note"]="Actual software-rendered terrain, diagnostic material, five physical checkpoints; remote anchor attachment distinct from actual actor floor and ray; extra draw waits, no matched timing or Android lifecycle/FPS claim."
    _p.free()
    _p=null
    return report

func _pixels(point: Vector3) -> Dictionary:
    _camera.position=Vector3(point.x,128,point.z)
    _camera.look_at(Vector3(point.x,0,point.z),Vector3.FORWARD)
    for i in range(3):
        await process_frame
        await RenderingServer.frame_post_draw
    var img: Image=root.get_texture().get_image()
    if img==null or img.get_width()<16 or img.get_height()<16:
        return {"error":FAILED}
    var cx: int=int(img.get_width()/2)
    var cy: int=int(img.get_height()/2)
    var center: int=0
    var total: int=0
    for y in range(img.get_height()):
        for x in range(img.get_width()):
            var c: Color=img.get_pixel(x,y)
            if c.r>0.65 and c.b>0.65 and c.g<0.35:
                total+=1
                if x>=cx-8 and x<cx+8 and y>=cy-8 and y<cy+8:
                    center+=1
    return {"center_magenta":center,"total_magenta":total,"width":img.get_width(),"height":img.get_height(),"x":point.x,"z":point.z}
