extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
var p
var b

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for format in [0,1]:
        b=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start")
            return
        var made: Dictionary={}
        for i in range(15000):
            made=b.take_result()
            if made.get("error",FAILED)!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture")
            return
        for cache in [9,16]:
            p=P.new()
            p.region_index_format=format
            p.sampling_strategy=7
            p.max_visible_tiles=4
            p.high_detail_distance=64.0
            p.medium_detail_distance=80.0
            p.view_distance=96.0
            p.resident_shard_limit=1
            root.add_child(p)
            if p.start_preview(made["directory"],cache,1)!=OK:
                _fail("open")
                return
            p.set_process(false)
            var points: Array[Vector2i]=[Vector2i(100,100),Vector2i(528,528),Vector2i(100,420),Vector2i(528,496)]
            for point in points:
                var key=Vector2i(point.x/32,point.y/32)
                var pos=Vector3(point.x,0,point.y)
                if not _ray(pos).is_empty():
                    _fail("cold target already has collision")
                    return
                p.set_stream_center(pos)
                var begin: int=Time.get_ticks_usec()
                var attach_tick: int=-1
                var ray_tick: int=-1
                var attach_us: int=-1
                var ray_us: int=-1
                var checks: int=0
                for tick in range(300):
                    await physics_frame
                    if p.pump_stream()["error"]!=OK:
                        _fail("pump")
                        return
                    if attach_tick<0 and p.has_collision_at(pos):
                        attach_tick=tick
                        attach_us=Time.get_ticks_usec()-begin
                    var hit: Dictionary=_ray(pos)
                    checks+=1
                    if not hit.is_empty():
                        if not p.is_ancestor_of(hit["collider"]) or absf(hit["position"].y-V2.sample(point.x,point.y))>0.002:
                            _fail("actual ray identity/height")
                            return
                        if attach_tick>=0:
                            ray_tick=tick
                            ray_us=Time.get_ticks_usec()-begin
                            break
                if attach_tick<0 or ray_tick<attach_tick or ray_us<attach_us:
                    _fail("readiness timeout")
                    return
                var stats: Dictionary=p.stats()
                if int(stats["source"]["resident"])>cache or int(stats["source"]["shard_resident"])>1 or not p._tiles.has(key):
                    _fail("bounds")
                    return
                print("PHYSICS_READY_LATENCY ",JSON.stringify({"format":format+1,"cache":cache,"point":str(point),"attach_tick":attach_tick,"ray_tick":ray_tick,"attach_us":attach_us,"ray_us":ray_us,"gap_us":ray_us-attach_us,"gap_ticks":ray_tick-attach_tick,"ray_checks":checks,"note":"first observed center ray, not full footprint readiness; wall time includes scheduling"}))
            p.stop_preview()
            await physics_frame
            await physics_frame
            for point in points:
                if not _ray(Vector3(point.x,0,point.y)).is_empty():
                    _fail("stop ghost")
                    return
            p.free()
            p=null
        b.close()
        b=null
    print("PASS: request-to-attachment versus first actual ray, 16 cold targets, two formats and caps, stop ghost isolation")
    quit(0)

func _ray(point: Vector3) -> Dictionary:
    return p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*128,point-Vector3.UP*128))

func _fail(msg: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("Physics readiness: "+msg)
    quit(1)
