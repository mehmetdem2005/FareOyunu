extends SceneTree
## Controlled stationary actor, same camera trace and caps for baseline/retention.
## No production controller or prediction. Actual physics continues every tick.
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
const RADIUS: float=0.25
const HEIGHT: float=0.6
const GRAVITY: float=20.0
const TICKS: int=120
var _p
var _builder
var _body: CharacterBody3D
var _pool_limit: int=0

func _initialize() -> void:
    call_deferred("_run")

func _formats() -> Array[int]:
    return [0,1]

func _run() -> void:
    for format in _formats():
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
        for mode in [7]:
            # Equal cap within pair; alternating order reduces warm-cache bias.
            for cap in [4,8]:
                var paired: Dictionary={}
                var order: Array[bool]=[false,true]
                if cap!=4:
                    order.reverse()
                for held in order:
                    _pool_limit=cap if held else 0
                    var result: Dictionary=await _case(made["directory"],format,mode,cap,true)
                    if result.get("error",FAILED)!=OK:
                        _fail("format/mode/cap/held "+str([format,mode,cap,held])+" "+str(result))
                        return
                    paired[str(held)]=result
                    print("POOL_SUPPORT_TRACE ",JSON.stringify({"format":format+1,"mode":mode,"cap":cap,"pool_limit":_pool_limit,"metrics":result}))
                if paired["false"]["missing_rays"]!=0 or paired["false"]["airborne_ticks"]!=0 or paired["true"]["missing_rays"]!=0 or paired["true"]["airborne_ticks"]!=0 or paired["true"]["pool"]["peak"]>cap:
                    _fail("coverage comparison "+str(paired))
                    return
        _builder.close()
        _builder=null
    print("PASS: actual retained support with pool off/on, fixed caps, lease invalidation and bounded resources")
    quit(0)

func _case(directory: String,format: int,mode: int,cap: int,held: bool) -> Dictionary:
    _p=P.new()
    _p.region_index_format=format
    _p.sampling_strategy=mode
    _p.hybrid_idle_pool_limit=_pool_limit
    _p.enable_support_retention=held
    _p.max_visible_tiles=cap
    _p.high_detail_distance=64.0
    _p.medium_detail_distance=80.0
    _p.view_distance=96.0
    _p.max_tile_work_ms=8.0
    _p.observe_publication=true
    root.add_child(_p)
    if _p.start_preview(directory,16,4)!=OK:
        return {"error":FAILED,"stage":"open"}
    _p.set_process(false)
    _p.set_stream_center(Vector3(512,0,512))
    if not await _settle(Vector2i(15,15),cap):
        return {"error":FAILED,"stage":"warm"}
    var initial_state: Dictionary=_p.support_state()
    var session: int=initial_state["session"]
    var revision: int=initial_state["revision"]
    await physics_frame
    if held:
        # Four-way footprint at a shard intersection. Invalid cap and stale
        # release must not alter the previously accepted lease.
        var four: Dictionary=_p.update_support(Vector2(512,512),RADIUS,session,revision)
        if four.get("error",FAILED)!=OK or four["tiles"].size()!=4:
            return {"error":FAILED,"stage":"four claim","detail":four}
        revision=four["revision"]
        _p.max_visible_tiles=3
        if _p.max_visible_tiles!=cap or _p.release_support(session,revision-1)==OK:
            return {"error":FAILED,"stage":"cap/stale release"}
        var denied: Dictionary=_p.update_support(Vector2(50,50),RADIUS,session,revision)
        if denied.get("error",OK)==OK or _p.support_state()["tiles"]!=four["tiles"]:
            return {"error":FAILED,"stage":"atomic failure","detail":denied}
        var single: Dictionary=_p.update_support(Vector2(500,500),RADIUS,session,revision)
        if single.get("error",FAILED)!=OK or single["tiles"]!=[Vector2i(15,15)]:
            return {"error":FAILED,"stage":"single transfer","detail":single}
        revision=single["revision"]
        var unchanged: Dictionary=_p.update_support(Vector2(500,500),RADIUS,session,revision)
        if unchanged.get("error",FAILED)!=OK or unchanged["revision"]!=revision:
            return {"error":FAILED,"stage":"unchanged lease"}
    var start=Vector3(500,0,500)
    var ground: Dictionary=_ground(start)
    if not _valid_ground(ground):
        return {"error":FAILED,"stage":"spawn ray"}
    var expected_body: int=ground["collider"].get_instance_id()
    _body=CharacterBody3D.new()
    _body.floor_snap_length=0.5
    _body.floor_max_angle=deg_to_rad(45.0)
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
        return {"error":FAILED,"stage":"settled body"}
    var origin: Vector3=_body.global_position
    var pump_hist=HIST.new()
    var missing: int=0
    var airborne: int=0
    var current_gap: int=0
    var longest_gap: int=0
    var max_tiles: int=0
    var max_pages: int=0
    var max_jobs: int=0
    var changed_body: int=0
    var pending_support_ticks: int=0
    var max_drift: float=0.0
    var trace: Array[Vector3]=[Vector3(100,0,100),Vector3(420,0,420),Vector3(32,0,480),Vector3(512,0,512),Vector3(100,0,100)]
    for tick in range(TICKS):
        await physics_frame
        var hit: Dictionary=_ground(start)
        if not _valid_ground(hit):
            missing+=1
            current_gap+=1
            longest_gap=maxi(longest_gap,current_gap)
        else:
            current_gap=0
            if hit["collider"].get_instance_id()!=expected_body:
                changed_body+=1
        _body.velocity=Vector3(0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
        if not _body.is_on_floor():
            airborne+=1
        max_drift=maxf(max_drift,Vector2(_body.global_position.x-origin.x,_body.global_position.z-origin.z).length())
        if held and _p._pending_tiles.has(Vector2i(15,15)):
            pending_support_ticks+=1
        _p.set_stream_center(trace[floori(float(tick)/24.0)])
        var begin: int=Time.get_ticks_usec()
        var pumped: Dictionary=_p.pump_stream()
        pump_hist.add(float(Time.get_ticks_usec()-begin)/1000.0)
        if pumped["error"]!=OK:
            return {"error":FAILED,"stage":"pump","detail":pumped}
        var stats: Dictionary=_p.stats()
        max_tiles=maxi(max_tiles,int(stats["tiles"]))
        max_pages=maxi(max_pages,int(stats["source"]["resident"]))
        max_jobs=maxi(max_jobs,int(stats["geometry_reservations"]))
        if max_tiles>cap or max_pages>16 or max_jobs>2 or (held and (not _p._tiles.has(Vector2i(15,15)) or _p._desired_tiles.get(Vector2i(15,15),-1)!=0)):
            return {"error":FAILED,"stage":"caps or retention"}
    var state: Dictionary=_p.support_state()
    var stats: Dictionary=_p.stats()
    var result: Dictionary={"error":OK,"ticks":TICKS,"missing_rays":missing,"longest_gap_ticks":longest_gap,"airborne_ticks":airborne,"changed_support_body":changed_body,"max_horizontal_drift":max_drift,"max_tiles":max_tiles,"max_pages":max_pages,"max_geometry_reservations":max_jobs,"pending_support_ticks":pending_support_ticks,"mesh_builds":stats["mesh_builds"],"camera_cancellations":stats["camera_cancellations"],"pump_ms":pump_hist.report(),"support":state,"pool":stats["idle_pool"]}
    if held:
        if changed_body!=0 or max_drift>0.1 or state["cap_rejections"]!=1 or _p.release_support(session,revision)!=OK:
            return {"error":FAILED,"stage":"release or support continuity","detail":result}
        await physics_frame
        _p.pump_stream()
        if _p._tiles.has(Vector2i(15,15)) or not _p.support_state()["tiles"].is_empty():
            return {"error":FAILED,"stage":"release eviction"}
    _body.free()
    _body=null
    _p.stop_preview()
    if _p.support_state()["active"] or not _p.support_state()["tiles"].is_empty() or _p.stats()["idle_pool"]["idle"]!=0:
        return {"error":FAILED,"stage":"stop revoke"}
    if held:
        if _p.start_preview(directory,16,4)!=OK:
            return {"error":FAILED,"stage":"reopen"}
        _p.set_process(false)
        await physics_frame
        var stale: Dictionary=_p.update_support(Vector2(500,500),RADIUS,session,revision)
        if stale.get("reason","")!="stale_lease":
            return {"error":FAILED,"stage":"reopen token","detail":stale}
    _p.free()
    _p=null
    return result

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
    push_error("Support retention: "+msg)
    quit(1)
