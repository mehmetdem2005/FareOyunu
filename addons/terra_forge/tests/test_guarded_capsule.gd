extends SceneTree
## P1.5.7d: isolated diagnostic, not a runtime movement controller.
## Verified current footprint + prospective footprint; deny horizontal movement
## while the destination is cold. Explicit test staging is NOT predictive streaming.
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const RADIUS: float=0.25
const HEIGHT: float=0.6
const GRAVITY: float=20.0
var _p
var _builder
var _body: CharacterBody3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for format in [0,1]:
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
            _p=P.new()
            _p.region_index_format=format
            _p.sampling_strategy=mode
            _p.max_visible_tiles=1
            _p.high_detail_distance=64.0
            _p.medium_detail_distance=80.0
            _p.view_distance=96.0
            _p.max_tile_work_ms=8.0
            root.add_child(_p)
            if _p.start_preview(made["directory"],16,4)!=OK:
                _fail("open")
                return
            _p.set_process(false)
            _p.set_stream_center(Vector3(496,0,496))
            if not await _settle(Vector2i(15,15),1):
                _fail("cold origin settle")
                return
            var outcome: Dictionary=await _exercise(12.0 if mode==0 else 24.0)
            if outcome.get("error",FAILED)!=OK:
                _fail(str(outcome))
                return
            print("GUARDED_CASE ",JSON.stringify({"format":format+1,"mode":mode,"outcome":outcome}))
            _body.free()
            _body=null
            _p.stop_preview()
            _p.free()
            _p=null
        _builder.close()
        _builder=null
    print("PASS: diagnostic capsule horizontal denial on cold destination, explicit staged recovery, real seam traversal")
    quit(0)

func _exercise(speed: float) -> Dictionary:
    await physics_frame
    var start=Vector3(510,0,500)
    var ground: Dictionary=_ground(start)
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
    _body.position=Vector3(start.x,float(ground["position"].y)+HEIGHT*0.5+0.05,start.z)
    root.add_child(_body)
    var dt: float=1.0/float(Engine.physics_ticks_per_second)
    for tick in range(20):
        await physics_frame
        _body.velocity=Vector3(0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
    if not _body.is_on_floor():
        return {"error":FAILED,"stage":"spawn floor"}
    var denied: int=0
    var first_denial_x: float=0.0
    var peak_rays: int=0
    for tick in range(40):
        await physics_frame
        var point: Vector3=_body.global_position
        var from=Vector2(point.x,point.z)
        var to: Vector2=from+Vector2(speed*dt,0)
        var exclude: Array[RID]=[_body.get_rid()]
        var current: Dictionary=_p.inspect_collision_footprint(from,from,RADIUS,exclude)
        if not current["ready"] or not _body.is_on_floor():
            return {"error":FAILED,"stage":"current support","detail":current}
        var next: Dictionary=_p.inspect_collision_footprint(from,to,RADIUS,exclude)
        peak_rays=maxi(peak_rays,int(current.get("ray_count",0))+int(next.get("ray_count",0)))
        if not next["ready"]:
            if next["reason"]!="missing_lod0":
                return {"error":FAILED,"stage":"unexpected denial","detail":next}
            if denied==0:
                first_denial_x=point.x
            denied+=1
        _body.velocity=Vector3(speed if next["ready"] else 0.0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
        if not _body.is_on_floor() or not _valid_ground(_ground(_body.global_position)) or _body.global_position.x+RADIUS>512.02:
            return {"error":FAILED,"stage":"cold boundary support","x":_body.global_position.x}
        if denied>=6:
            break
    if denied<6 or absf(_body.global_position.x-first_denial_x)>0.05:
        return {"error":FAILED,"stage":"denial drift","denied":denied}
    # Explicit pause in the diagnostic harness only. No controller guarantee
    # while current LOD changes; production pin/eviction semantics remain open.
    _p.max_visible_tiles=4
    _p.set_stream_center(Vector3(512,0,512))
    if not await _settle(Vector2i(15,15),4):
        return {"error":FAILED,"stage":"destination settle"}
    var resume_x: float=_body.global_position.x
    for tick in range(30):
        await physics_frame
        var point: Vector3=_body.global_position
        var from=Vector2(point.x,point.z)
        var to: Vector2=from+Vector2(speed*dt,0)
        var exclude: Array[RID]=[_body.get_rid()]
        var current: Dictionary=_p.inspect_collision_footprint(from,from,RADIUS,exclude)
        var next: Dictionary=_p.inspect_collision_footprint(from,to,RADIUS,exclude)
        if not current["ready"] or not next["ready"]:
            return {"error":FAILED,"stage":"resume readiness","current":current,"next":next}
        peak_rays=maxi(peak_rays,int(current.get("ray_count",0))+int(next.get("ray_count",0)))
        _body.velocity=Vector3(speed,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
        if not _body.is_on_floor() or not _valid_ground(_ground(_body.global_position)):
            return {"error":FAILED,"stage":"resume ground"}
    var finish_x: float=_body.global_position.x
    return {"error":OK if finish_x>512.0 and finish_x-resume_x>=speed*dt*30*0.8 else FAILED,"denied_ticks":denied,"first_denial_x":first_denial_x,"resume_x":resume_x,"finish_x":finish_x,"speed":speed,"peak_readiness_rays_per_tick":peak_rays,"staging_pauses_motion":true}

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
    push_error("Guarded capsule: "+msg)
    quit(1)
