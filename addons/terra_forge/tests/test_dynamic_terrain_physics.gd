extends SceneTree
## In-tree CharacterBody3D capsule crossing a fully resident four-tile seam,
## followed by actual ray coverage during a fixed streaming route.
## This is a diagnostic fixture, NOT player controller or collision fallback.
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")
const RADIUS: float=0.25
const HEIGHT: float=0.6
const WALK_TICKS: int=120
const GRAVITY: float=20.0
var _p
var _builder
var _body: CharacterBody3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    print("DYNAMIC_ENV ",JSON.stringify({"godot":Engine.get_version_info().get("string",""),"physics_engine_setting":ProjectSettings.get_setting("physics/3d/physics_engine","default"),"ticks_per_second":Engine.physics_ticks_per_second,"capsule_radius":RADIUS,"capsule_height":HEIGHT,"walk_ticks":WALK_TICKS,"notes":"warm actual CharacterBody3D, then separate moving direct-space ray trace; no player safety fallback, headless Linux spacing1"}))
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
        var folder: String=made["directory"]
        for mode in [0,5]:
            _p=P.new()
            _p.region_index_format=format
            _p.sampling_strategy=mode
            _p.max_visible_tiles=4
            _p.high_detail_distance=64.0
            _p.medium_detail_distance=80.0
            _p.view_distance=96.0
            _p.max_tile_work_ms=8.0
            _p.tile_updates_per_frame=2
            root.add_child(_p)
            if _p.start_preview(folder,16,4)!=OK:
                _fail("open")
                return
            _p.set_process(false)
            _p.set_stream_center(Vector3(512,0,512))
            if not await _settle(Vector2i(15,15),4):
                _fail("warm settle")
                return
            var slow: Dictionary=await _walk(12.0,Vector3(500,0,500))
            var fast: Dictionary=await _walk(24.0,Vector3(488,0,488))
            if slow.get("error",FAILED)!=OK or fast.get("error",FAILED)!=OK:
                _fail("warm capsule "+str(slow)+" "+str(fast))
                return
            _p.stop_preview()
            _p.max_visible_tiles=8
            _p.high_detail_distance=40.0
            _p.tile_updates_per_frame=1
            if _p.start_preview(folder,16,4)!=OK:
                _fail("trace reopen")
                return
            _p.set_process(false)
            var moving: Dictionary=await _trace()
            if moving.get("error",FAILED)!=OK:
                _fail("moving ray trace "+str(moving))
                return
            print("DYNAMIC_CASE ",JSON.stringify({"format":format+1,"mode":mode,"slow_walk":slow,"fast_walk":fast,"moving_rays":moving}))
            _p.stop_preview()
            _p.free()
            _p=null
        _builder.close()
        _builder=null
    print("PASS: warm capsule slow/fast diagonal seam traversal, actual moving physics ray coverage and recovery")
    quit(0)

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

func _walk(speed: float,start: Vector3) -> Dictionary:
    await physics_frame
    var ground: Dictionary=_ground(start)
    if not _valid_ground(ground):
        return {"error":ERR_INVALID_DATA,"stage":"spawn ground"}
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
        _body.free()
        _body=null
        return {"error":ERR_INVALID_DATA,"stage":"spawn floor"}
    var initial: Vector3=_body.global_position
    var airborne: int=0
    var longest_airborne: int=0
    var gap: int=0
    var missed_rays: int=0
    var max_penetration: float=0.0
    var max_clearance: float=0.0
    var crossed_x: bool=false
    var crossed_z: bool=false
    var direction: Vector3=Vector3(1,0,1).normalized()
    for tick in range(WALK_TICKS):
        await physics_frame
        _body.velocity=Vector3(direction.x*speed,_body.velocity.y-GRAVITY*dt,direction.z*speed)
        _body.move_and_slide()
        var point: Vector3=_body.global_position
        crossed_x=crossed_x or point.x>512.0
        crossed_z=crossed_z or point.z>512.0
        if _body.is_on_floor():
            gap=0
        else:
            airborne+=1
            gap+=1
            longest_airborne=maxi(longest_airborne,gap)
        var hit: Dictionary=_ground(point)
        if not _valid_ground(hit):
            missed_rays+=1
        else:
            var clearance: float=point.y-HEIGHT*0.5-float(hit["position"].y)
            max_penetration=maxf(max_penetration,-clearance)
            max_clearance=maxf(max_clearance,clearance)
    var finish: Vector3=_body.global_position
    var distance: float=Vector2(finish.x-initial.x,finish.z-initial.z).length()
    var grounded: bool=_body.is_on_floor()
    _body.free()
    _body=null
    var ok: bool=crossed_x and crossed_z and grounded and missed_rays==0 and max_penetration<=0.12 and longest_airborne<=6 and distance>=speed*WALK_TICKS*dt*0.8
    return {"error":OK if ok else ERR_INVALID_DATA,"speed_world_units_per_second":speed,"ticks":WALK_TICKS,"distance":distance,"crossed_x":crossed_x,"crossed_z":crossed_z,"airborne_ticks":airborne,"longest_airborne_ticks":longest_airborne,"missed_ground_rays":missed_rays,"max_bottom_below_ray_height":max_penetration,"max_bottom_above_ray_height":max_clearance,"end_grounded":grounded,"finish":[finish.x,finish.y,finish.z]}

func _trace() -> Dictionary:
    var missing: int=0
    var metadata_missing: int=0
    var attached_no_hit: int=0
    var hit_without_attached: int=0
    var max_gap: int=0
    var gap: int=0
    var first_hit: int=-1
    var peak: int=0
    var begin: int=Time.get_ticks_usec()
    for step in range(144):
        await physics_frame
        var focus: Vector3=TRACE.focus_at(step)
        _p.set_stream_center(focus)
        _p._last_sync_msec=-100000
        # Query before pump so physics state can have synced prior changes.
        var attached: bool=_p.has_collision_at(focus)
        var hit: Dictionary=_ground(focus)
        var actual: bool=_valid_ground(hit)
        if not hit.is_empty() and not actual:
            return {"error":ERR_INVALID_DATA,"stage":"unexpected collider","step":step}
        if not attached:
            metadata_missing+=1
        if attached and not actual:
            attached_no_hit+=1
        if actual and not attached:
            hit_without_attached+=1
        if actual:
            if first_hit<0:
                first_hit=step
            gap=0
        else:
            missing+=1
            gap+=1
            max_gap=maxi(max_gap,gap)
        var status: Dictionary=_p.pump_stream()
        if status["error"]!=OK:
            return {"error":status["error"],"stage":"pump","step":step}
        var s: Dictionary=_p.stats()
        if s["source"]["resident"]>16 or s["tiles"]>8 or s["geometry_reservations"]>2 or s["source"]["tile_view_active_pages"]!=0:
            return {"error":ERR_BUG,"stage":"caps","step":step}
        peak=maxi(peak,int(s["tiles"]))
    var elapsed: int=Time.get_ticks_usec()-begin
    var builds: int=_p.stats()["mesh_builds"]
    var recovered: bool=false
    var recovery_ticks: int=0
    for attempt in range(240):
        await physics_frame
        recovery_ticks=attempt+1
        if _valid_ground(_ground(TRACE.focus_at(143))):
            recovered=true
            break
        _p.pump_stream()
    return {"error":OK if recovered and first_hit>=0 and builds>0 else ERR_INVALID_DATA,"steps":144,"missing_actual_ray_steps":missing,"missing_attached_shape_steps":metadata_missing,"attached_without_hit":attached_no_hit,"hit_without_attached":hit_without_attached,"longest_actual_gap_ticks":max_gap,"first_hit_step":first_hit,"recovered":recovered,"recovery_ticks":recovery_ticks,"mesh_builds":builds,"peak_tiles":peak,"wall_elapsed_us":elapsed}

func _fail(msg: String) -> void:
    if is_instance_valid(_body):
        _body.free()
    if _p!=null:
        _p.stop_preview()
        _p.free()
    if _builder!=null:
        _builder.close()
    push_error("Dynamic terrain physics: "+msg)
    quit(1)
