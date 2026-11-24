extends SceneTree
## Scratch-only faults: damaged destination halo is not needed by OLD.
## Real capsule physics and streaming continue throughout failure/recovery.
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const FOOT=preload("res://addons/terra_forge/core/collision_footprint.gd")
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
const REGIONS=preload("res://addons/terra_forge/core/region_store.gd")
const RADIUS: float=0.25
const HEIGHT: float=0.6
const GRAVITY: float=20.0
const OLD: Vector2i=Vector2i(15,15)
const NEW: Vector2i=Vector2i(16,15)
const DAMAGED: Vector2i=Vector2i(17,15)
var _p
var _builder
var _body: CharacterBody3D

func _initialize() -> void:
    call_deferred("_run")

func _format() -> int:
    return 0

func _run() -> void:
    var format: int=_format()
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
        for corrupt in [false,true]:
            var report: Dictionary=await _case(made["directory"],format,mode,corrupt)
            if report.get("error",FAILED)!=OK:
                _fail(str([format,mode,corrupt])+" "+str(report))
                return
            print("MOTION_FAULT_TRACE ",JSON.stringify({"format":format+1,"mode":mode,"corrupt":corrupt,"metrics":report}))
    _builder.close()
    _builder=null
    print("PASS: damaged destination fail-closed, actual support preserved, no same-generation retry, verified recovery")
    quit(0)

func _write_bytes(path: String,bytes: PackedByteArray) -> bool:
    var f: FileAccess=FileAccess.open(path,FileAccess.WRITE)
    if f==null:
        return false
    f.store_buffer(bytes)
    f.flush()
    var result: Error=f.get_error()
    f.close()
    return result==OK

func _case(directory: String,format: int,mode: int,corrupt: bool) -> Dictionary:
    var path: String=directory.path_join("r_%05d_%05d.tfr" % [DAMAGED.x,DAMAGED.y])
    var original: PackedByteArray=FileAccess.get_file_as_bytes(path)
    var digest: String=FileAccess.get_sha256(path)
    if original.size()!=REGIONS.FILE_BYTES or digest.is_empty():
        return {"error":FAILED,"stage":"fixture bytes"}
    _p=P.new()
    _p.region_index_format=format
    _p.sampling_strategy=mode
    _p.enable_support_retention=true
    _p.enable_motion_prefetch=true
    _p.enable_adaptive_motion_horizon=true
    _p.max_visible_tiles=4
    _p.high_detail_distance=64.0
    _p.medium_detail_distance=80.0
    _p.view_distance=96.0
    _p.max_tile_work_ms=8.0
    root.add_child(_p)
    if _p.start_preview(directory,9,4)!=OK:
        return {"error":FAILED,"stage":"open"}
    _p.set_process(false)
    _p.set_stream_center(Vector3(512,0,512))
    if not await _settle(OLD,4):
        return {"error":FAILED,"stage":"warm"}
    await physics_frame
    var state: Dictionary=_p.support_state()
    var session: int=state["session"]
    var claim: Dictionary=_p.update_support(Vector2(510,500),RADIUS,session,state["revision"])
    if claim.get("error",FAILED)!=OK or claim["tiles"]!=[OLD]:
        return {"error":FAILED,"stage":"claim","detail":claim}
    var revision: int=claim["revision"]
    _p.set_stream_center(Vector3(100,0,100))
    if not await _settle(OLD,4) or _p._tiles.has(NEW):
        return {"error":FAILED,"stage":"cold setup"}
    if _p._reader.release_outside(Vector2i.ZERO,Vector2i.ZERO)!=OK or _p._reader.page_status(DAMAGED)!=ERR_BUSY:
        return {"error":FAILED,"stage":"force cold page"}
    if corrupt:
        var altered: PackedByteArray=original.duplicate()
        altered[REGIONS.HEADER_BYTES+11]=altered[REGIONS.HEADER_BYTES+11]^1
        if not _write_bytes(path,altered):
            return {"error":FAILED,"stage":"corrupt scratch"}
    elif DirAccess.remove_absolute(ProjectSettings.globalize_path(path))!=OK:
        return {"error":FAILED,"stage":"remove scratch"}
    var expected: Error=ERR_FILE_CORRUPT if corrupt else ERR_FILE_NOT_FOUND
    await physics_frame
    var start=Vector3(510,0,500)
    var ground: Dictionary=_ground(start)
    if not _valid_ground(ground):
        return {"error":FAILED,"stage":"spawn"}
    var original_body: int=ground["collider"].get_instance_id()
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
    var exclude: Array[RID]=[_body.get_rid()]
    for tick in range(20):
        await physics_frame
        _body.velocity=Vector3(0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
    if not _body.is_on_floor():
        return {"error":FAILED,"stage":"initial floor"}
    var actual_velocity=Vector2.ZERO
    var fault_tick: int=-1
    var repair_tick: int=-1
    var reset_tick: int=-1
    var first_blocked: int=-1
    var first_resume: int=-1
    var terminal_denials: int=0
    var failed_before: int=int(_p.stats()["source"]["worker_errors"])
    var generation: int=int(_p.stats()["source"]["generation"])
    var generation_errors: int=-1
    var held_ticks: int=0
    var transfers: int=0
    var peak_pages: int=0
    var peak_tiles: int=0
    var peak_jobs: int=0
    var pump_hist=HIST.new()
    for tick in range(180):
        await physics_frame
        var before: Vector3=_body.global_position
        var from=Vector2(before.x,before.z)
        if tick==60:
            if fault_tick<0 or first_blocked<0 or int(_p.stats()["source"]["worker_errors"])-failed_before!=1 or not _write_bytes(path,original) or FileAccess.get_sha256(path)!=digest:
                return {"error":FAILED,"stage":"fault/repair evidence","tick":tick}
            repair_tick=tick
            generation_errors=int(_p.stats()["source"]["worker_errors"])
        if tick==90:
            if _p._reader.page_status(DAMAGED)!=expected or int(_p.stats()["source"]["worker_errors"])!=generation_errors:
                return {"error":FAILED,"stage":"terminal retry without generation"}
            # Explicit camera generation transition; not automatic repair.
            _p.set_stream_center(Vector3(100,0,420))
            reset_tick=tick
        var speed: float=24.0 if from.x<524.0-0.02 else 0.0
        var intent=Vector2(minf(speed,maxf(0.0,(524.0-from.x)/dt)),0)
        var sample: Error=_p.sample_motion_prefetch(from,actual_velocity,intent,RADIUS,session,revision)
        if sample!=OK:
            return {"error":FAILED,"stage":"sample","tick":tick,"status":sample}
        var admission: Dictionary=_p.inspect_support_step(from,from+intent*dt,RADIUS,session,revision,exclude)
        if admission["reason"]=="terrain_blocked":
            if admission.get("tile_error",OK)!=expected or admission.get("tile")!=NEW:
                return {"error":FAILED,"stage":"terminal reason","tick":tick,"detail":admission}
            if first_blocked<0:
                first_blocked=tick
            terminal_denials+=1
        var admitted: bool=intent.x>0.0 and admission["ready"]
        if tick>=91 and first_blocked>=0 and admitted and first_resume<0:
            first_resume=tick
        _body.velocity=Vector3(intent.x if admitted else 0.0,_body.velocity.y-GRAVITY*dt,0)
        _body.move_and_slide()
        var after: Vector3=_body.global_position
        var actual=Vector2(after.x,after.z)
        actual_velocity=(actual-from)/dt
        var hit: Dictionary=_ground(after)
        if not _body.is_on_floor() or not _valid_ground(hit):
            return {"error":FAILED,"stage":"physical ground loss","tick":tick}
        if tick<90:
            held_ticks+=1
            if actual.x>=512.0 or hit["collider"].get_instance_id()!=original_body or _p.support_state()["tiles"]!=[OLD]:
                return {"error":FAILED,"stage":"premature crossing or old support lost","tick":tick}
        var footprint: Dictionary=FOOT.plan(actual,actual,RADIUS,_p.world_extent(),32.0)
        if not footprint["ready"]:
            return {"error":FAILED,"stage":"footprint","tick":tick}
        if footprint["tiles"]!=_p.support_state()["tiles"]:
            var moved: Dictionary=_p.update_support(actual,RADIUS,session,revision,exclude)
            if not admitted or moved.get("error",FAILED)!=OK or moved["revision"]!=revision+1:
                return {"error":FAILED,"stage":"verified transfer","tick":tick,"detail":moved}
            revision=moved["revision"]
            transfers+=1
        var began: int=Time.get_ticks_usec()
        var pumped: Dictionary=_p.pump_stream()
        pump_hist.add(float(Time.get_ticks_usec()-began)/1000.0)
        if pumped["error"]!=OK and pumped["error"]!=expected:
            return {"error":FAILED,"stage":"unexpected pump error","tick":tick,"detail":pumped}
        var stats: Dictionary=_p.stats()
        peak_pages=maxi(peak_pages,int(stats["source"]["resident"]))
        peak_tiles=maxi(peak_tiles,int(stats["tiles"]))
        peak_jobs=maxi(peak_jobs,int(stats["geometry_reservations"]))
        if peak_pages>9 or peak_tiles>4 or peak_jobs>2 or int(stats["motion_prefetch"]["pending_latency_samples"])>2:
            return {"error":FAILED,"stage":"bounds","tick":tick}
        for key in footprint["tiles"]:
            if not _p._tiles.has(key) or _p._desired_tiles.get(key,-1)!=0:
                return {"error":FAILED,"stage":"support eviction","tick":tick}
        if tick<90 and _p._blocked_tiles.has(NEW):
            if _p._tiles.has(NEW) or _p._reader.get_height(544,480).has("height") or int(stats["source"]["generation"])!=generation:
                return {"error":FAILED,"stage":"fabricated data/early generation","tick":tick}
            if fault_tick<0:
                fault_tick=tick
            if int(stats["motion_prefetch"]["failed_latency_samples"])!=1 or int(stats["motion_prefetch"]["latency"]["samples"])!=0:
                return {"error":FAILED,"stage":"failure counted as latency","tick":tick}
    var final: Dictionary=_p.stats()
    var motion: Dictionary=final["motion_prefetch"]
    var report: Dictionary={"error":OK,"ticks":180,"fault_tick":fault_tick,"repair_tick":repair_tick,"reset_tick":reset_tick,"first_blocked_tick":first_blocked,"first_resume_tick":first_resume,"terminal_denials":terminal_denials,"held_ticks":held_ticks,"transfers":transfers,"finish_x":_body.global_position.x,"worker_errors_delta":int(final["source"]["worker_errors"])-failed_before,"generation_delta":int(final["source"]["generation"])-generation,"peak_pages":peak_pages,"peak_tiles":peak_tiles,"peak_jobs":peak_jobs,"missing_rays":0,"airborne_ticks":0,"motion":motion,"pump_ms":pump_hist.report()}
    if fault_tick<0 or repair_tick!=60 or reset_tick!=90 or first_resume<91 or terminal_denials<30 or transfers!=2 or absf(_body.global_position.x-524.0)>0.05 or _p.support_state()["tiles"]!=[NEW] or final["last_error"]!=OK or report["worker_errors_delta"]!=1 or report["generation_delta"]!=1 or int(motion["failed_latency_samples"])!=1 or int(motion["latency"]["samples"])<1 or int(motion["pending_latency_samples"])!=0 or FileAccess.get_sha256(path)!=digest:
        report["error"]=FAILED
        report["stage"]="recovery evidence"
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
    push_error("Motion fault recovery: "+msg)
    quit(1)
