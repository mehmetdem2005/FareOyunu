extends SceneTree
## Actual PhysicsDirectSpaceState3D rays on in-tree streamed tiles.
## No manual physics server synchronization or shape-only success proxy.
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const EPS: float=0.002
var _p
var _builder
var _rays: int=0
var _mesh_mismatch: int=0
var _max_error: float=0.0
var _max_mesh_delta: float=0.0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    print("PHYSICS_ENV ",JSON.stringify({"godot":Engine.get_version_info().get("string",""),"physics_engine_setting":ProjectSettings.get_setting("physics/3d/physics_engine","default"),"ticks_per_second":Engine.physics_ticks_per_second,"notes":"in-tree direct-space rays after physics frames; synthetic spacing1, translated and yaw-rotated preview, not Android"}))
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
            _rays=0
            _mesh_mismatch=0
            _max_error=0.0
            _max_mesh_delta=0.0
            _p=P.new()
            _p.region_index_format=format
            _p.sampling_strategy=mode
            _p.max_visible_tiles=4
            _p.high_detail_distance=64.0
            _p.medium_detail_distance=80.0
            _p.view_distance=96.0
            _p.max_tile_work_ms=8.0
            _p.tile_updates_per_frame=2
            _p.position=Vector3(13,7,-19)
            _p.rotation.y=0.37
            root.add_child(_p)
            if _p.start_preview(folder,16,4)!=OK:
                _fail("open")
                return
            _p.set_process(false)
            var focus=Vector3(512,0,512)
            _p.set_stream_center(_p.to_global(focus))
            if not await _settle(Vector2i(15,15),4):
                _fail("initial settle")
                return
            # Probe both sides of the shard boundary, exact vertices,
            # cell interiors and the seam crossing. All four tiles LOD0.
            for x in [480.25,495.0,511.75,512.0,512.25,527.0,543.75]:
                for z in [480.25,495.0,511.75,512.0,512.25,527.0,543.75]:
                    if not _probe(Vector2(x,z)):
                        _fail("ray parity "+str(Vector2(x,z)))
                        return
            # Noncoplanar cells where the diagonal ridge crosses a unit
            # square: detect actual mesh vs physics diagonal differences.
            for x in range(485,540):
                var z: int=1023-x
                for offset in [Vector2(0.2,0.3),Vector2(0.7,0.8)]:
                    if not _probe(Vector2(x,z)+offset):
                        _fail("nonplanar ray")
                        return
            var initial_rays: int=_rays
            # No phantom collision at an unstreamed distant position.
            if not _ray(Vector2(16,16)).is_empty():
                _fail("unstreamed collision")
                return
            _p.set_stream_center(_p.to_global(Vector3(16,0,16)))
            if not await _settle(Vector2i.ZERO,4) or not _probe(Vector2(16.25,16.5)) or not _ray(Vector2(512,512)).is_empty():
                _fail("teleport/eviction")
                return
            var origin=Vector2i.ZERO
            var old_shape: Shape3D=_p._tiles[origin]["collision"].shape
            var old_mesh: Mesh=_p._tiles[origin]["visual"].mesh
            # Scratch fixture only: retain last verified collision on IO failure.
            var path: String=folder.path_join("r_00000_00000.tfr")
            var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
            if bytes.is_empty() or _p._reader.release_outside(Vector2i(18,18),Vector2i(18,18))!=OK or DirAccess.remove_absolute(path)!=OK:
                _fail("failure setup")
                return
            _p._pending_tiles[origin]=true
            for attempt in range(240):
                await physics_frame
                _p.pump_stream()
                if _p._blocked_tiles.has(origin):
                    break
            var retained: bool=_p._blocked_tiles.has(origin) and _p._tiles[origin]["collision"].shape==old_shape and _p._tiles[origin]["visual"].mesh==old_mesh
            await physics_frame
            await physics_frame
            retained=retained and _probe(Vector2(16.25,16.5))
            # Restore disposable file even on a failed retention assertion.
            var f=FileAccess.open(path,FileAccess.WRITE)
            if f==null:
                _fail("restore")
                return
            f.store_buffer(bytes)
            f.close()
            if not retained:
                _fail("last-good actual ray")
                return
            _p.set_stream_center(_p.to_global(Vector3(528,0,528)))
            if not await _settle(Vector2i(16,16),4) or not _probe(Vector2(528.25,528.5)):
                _fail("healthy remote recovery")
                return
            # Stop removes actual physics bodies, not just dictionaries.
            _p.stop_preview()
            await physics_frame
            await physics_frame
            if not _ray(Vector2(528.25,528.5)).is_empty():
                _fail("collision after stop")
                return
            print("PHYSICS_CASE ",JSON.stringify({"format":format+1,"mode":mode,"rays_verified":_rays,"initial_rays":initial_rays,"max_error_to_either_diagonal":_max_error,"mesh_diagonal_mismatch_count":_mesh_mismatch,"max_mesh_height_delta":_max_mesh_delta,"teleport_eviction":true,"last_good_ray":true,"stop_no_hit":true}))
            _p.free()
            _p=null
        _builder.close()
        _builder=null
    print("PASS: actual in-tree physics rays, translated/rotated terrain, seam and fractional heights, teleport eviction, last-good and stop")
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

func _ray(local: Vector2) -> Dictionary:
    var start: Vector3=_p.to_global(Vector3(local.x,128,local.y))
    var end: Vector3=_p.to_global(Vector3(local.x,-128,local.y))
    var query=PhysicsRayQueryParameters3D.create(start,end)
    query.collide_with_areas=false
    return _p.get_world_3d().direct_space_state.intersect_ray(query)

func _probe(point: Vector2) -> bool:
    var hit: Dictionary=_ray(point)
    if hit.is_empty() or not hit.get("collider") is StaticBody3D or not _p.is_ancestor_of(hit["collider"]):
        return false
    var local: Vector3=_p.to_local(hit["position"])
    if Vector2(local.x,local.z).distance_to(point)>EPS or hit["normal"].y<=0.0:
        return false
    var x: int=floori(point.x)
    var z: int=floori(point.y)
    var u: float=point.x-x
    var v: float=point.y-z
    var a: float=V2.sample(x,z)
    var b: float=V2.sample(x+1,z)
    var c: float=V2.sample(x,z+1)
    var d: float=V2.sample(x+1,z+1)
    # Mesh uses b-c diagonal. Some physics backends use a-d.
    # Verify against either actual triangulation, report mesh mismatch
    # explicitly rather than treating it as proven visual parity.
    var mesh_y: float=a+(b-a)*u+(c-a)*v if u+v<=1.0 else d+(c-d)*(1.0-u)+(b-d)*(1.0-v)
    var other_y: float=a+(b-a)*u+(d-b)*v if u>=v else a+(d-c)*u+(c-a)*v
    var error: float=minf(absf(local.y-mesh_y),absf(local.y-other_y))
    var delta: float=absf(local.y-mesh_y)
    _max_error=maxf(_max_error,error)
    _max_mesh_delta=maxf(_max_mesh_delta,delta)
    if delta>EPS:
        _mesh_mismatch+=1
    _rays+=1
    return error<=EPS

func _fail(msg: String) -> void:
    if _p!=null:
        _p.stop_preview()
        _p.free()
    if _builder!=null:
        _builder.close()
    push_error("Physics raycast: "+msg+" rays="+str(_rays)+" max_error="+str(_max_error))
    quit(1)
