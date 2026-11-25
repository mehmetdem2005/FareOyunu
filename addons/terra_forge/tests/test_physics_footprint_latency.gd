extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const FOOT=preload("res://addons/terra_forge/core/collision_footprint.gd")
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
            var points: Array[Vector2]=[Vector2(100,100),Vector2(512,512),Vector2(100,420),Vector2(320,320)]
            for point in points:
                var plan: Dictionary=FOOT.plan(point,point,0.25,p.world_extent(),32.0)
                if not plan["ready"]:
                    _fail("plan")
                    return
                p.set_stream_center(Vector3(point.x,0,point.y))
                var started: int=Time.get_ticks_usec()
                var attach_tick: int=-1
                var attach_us: int=-1
                var ready_tick: int=-1
                var ready_us: int=-1
                var reasons: Dictionary={}
                var confirmed: Dictionary={}
                for tick in range(300):
                    await physics_frame
                    if p.pump_stream()["error"]!=OK:
                        _fail("pump")
                        return
                    var all_attached: bool=true
                    for key in plan["tiles"]:
                        var tile: Dictionary=p._tiles.get(key,{})
                        if tile.is_empty() or tile["lod"]!=0 or not tile["collision"].shape is HeightMapShape3D:
                            all_attached=false
                    if all_attached and attach_tick<0:
                        attach_tick=tick
                        attach_us=Time.get_ticks_usec()-started
                    confirmed=p.inspect_collision_footprint(point,point,0.25)
                    if confirmed["ready"]:
                        if attach_tick<0 or confirmed["tiles"]!=plan["tiles"] or confirmed["ray_count"]!=plan["tiles"].size():
                            _fail("guard readiness accounting")
                            return
                        ready_tick=tick
                        ready_us=Time.get_ticks_usec()-started
                        break
                    var reason: String=confirmed["reason"]
                    reasons[reason]=int(reasons.get(reason,0))+1
                if attach_tick<0 or ready_tick<attach_tick or ready_us<attach_us:
                    _fail("readiness timeout "+str(reasons))
                    return
                var stats: Dictionary=p.stats()
                if int(stats["source"]["resident"])>cache or int(stats["source"]["shard_resident"])>1:
                    _fail("bounds")
                    return
                print("F4_FOOTPRINT_READY ",JSON.stringify({"format":format+1,"cache":cache,"point":str(point),"tiles":plan["tiles"].size(),"attach_tick":attach_tick,"guard_tick":ready_tick,"attach_us":attach_us,"guard_us":ready_us,"gap_ticks":ready_tick-attach_tick,"gap_us":ready_us-attach_us,"ray_count":confirmed["ray_count"],"wait_reasons":reasons,"note":"Production guard verifies one center ray per footprint tile, not continuous capsule sweep."}))
            p.stop_preview()
            await physics_frame
            if p.inspect_collision_footprint(Vector2(320,320),Vector2(320,320),0.25)["ready"]:
                _fail("stop guard")
                return
            p.free()
            p=null
        b.close()
        b=null
    print("PASS: F4 16 sampled footprint readiness traces, one/four tile guards, bounded IO and stop")
    quit(0)

func _fail(msg: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("F4 footprint: "+msg)
    quit(1)
