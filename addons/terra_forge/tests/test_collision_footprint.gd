extends SceneTree
const F=preload("res://addons/terra_forge/core/collision_footprint.gd")
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
var _p
var _b

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for edge in range(4):
        for old_level in [-1,0,1,2]:
            for new_level in [-1,0,1,2]:
                var old_edges := [0,0,0,0]
                var new_edges := [0,0,0,0]
                old_edges[edge] = old_level
                new_edges[edge] = new_level
                var safe: bool = old_level == new_level or (old_level <= 0 and new_level <= 0)
                if P._same_lod0_height_edges(old_edges,new_edges) != safe:
                    _fail("LOD0 edge classification")
                    return
    var extent=Vector2(576,576)
    var one: Dictionary=F.plan(Vector2(500,500),Vector2(501,501),0.25,extent,32)
    var four: Dictionary=F.plan(Vector2(511.8,511.8),Vector2(512.2,512.2),0.25,extent,32)
    var touch: Dictionary=F.plan(Vector2(512.25,500),Vector2(513,500),0.25,extent,32)
    if not one["ready"] or one["tiles"]!=[Vector2i(15,15)] or not four["ready"] or four["tiles"].size()!=4 or touch["tiles"].size()!=2 or F.plan(Vector2(1,1),Vector2(570,570),0.25,extent,32)["reason"]!="footprint_cap" or F.plan(Vector2(0.25,5),Vector2(1,5),0.25,extent,32)["reason"]!="outside_world" or F.plan(Vector2(NAN,0),Vector2.ONE,0.25,extent,32)["reason"]!="invalid_input":
        _fail("pure conservative plan")
        return
    for format in [0,1]:
        _b=V1.new() if format==0 else V2.new()
        var err: Error=_b.start(Vector2i(576,576),true) if format==0 else _b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=_b.take_result()
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
            _p.position=Vector3(13,7,-19)
            _p.rotation.y=0.37
            root.add_child(_p)
            if _p.start_preview(made["directory"],16,4)!=OK:
                _fail("open")
                return
            _p.set_process(false)
            _p.set_stream_center(_p.to_global(Vector3(496,0,496)))
            await physics_frame
            var cold: Dictionary=_p.inspect_collision_footprint(Vector2(500,500),Vector2(501,501),0.25)
            if cold["ready"] or not await _settle(1):
                _fail("cold rejection/settle")
                return
            var inside: Dictionary=_p.inspect_collision_footprint(Vector2(500,500),Vector2(501,501),0.25)
            var denied: Dictionary=_p.inspect_collision_footprint(Vector2(511.8,511.8),Vector2(512.2,512.2),0.25)
            if not inside["ready"] or inside["ray_count"]!=1 or denied["ready"] or denied["reason"]!="missing_lod0":
                _fail("cold boundary rejected "+str(denied)+" inside "+str(inside))
                return
            # Explicitly stream destination. The query itself did not mutate.
            _p.max_visible_tiles=4
            _p.set_stream_center(_p.to_global(Vector3(512,0,512)))
            if not await _settle(4):
                _fail("destination settle")
                return
            var allowed: Dictionary=_p.inspect_collision_footprint(Vector2(511.8,511.8),Vector2(512.2,512.2),0.25)
            if not allowed["ready"] or allowed["ray_count"]!=4:
                _fail("four actual physics confirmations "+str(allowed))
                return
            var key=Vector2i(15,15)
            _p._pending_tiles[key]=true
            var pending: Dictionary=_p.inspect_collision_footprint(Vector2(500,500),Vector2(501,501),0.25)
            _p._pending_tiles.erase(key)
            if pending["ready"] or pending["reason"]!="unsettled":
                _fail("pending must deny")
                return
            # Metadata remains attached but actual query cannot hit excluded body.
            var body: StaticBody3D=_p._tiles[key]["collision"].get_parent()
            var exclude: Array[RID]=[body.get_rid()]
            var absent: Dictionary=_p.inspect_collision_footprint(Vector2(500,500),Vector2(501,501),0.25,exclude)
            if absent["ready"] or absent["reason"]!="physics_unconfirmed" or absent["ray_count"]!=1:
                _fail("actual physics confirmation required")
                return
            var outside: Dictionary=_p.inspect_collision_footprint(Vector2(0.1,5),Vector2(1,5),0.25)
            if outside["ready"] or outside["reason"]!="outside_world":
                _fail("outside denial")
                return
            _p.stop_preview()
            if _p.inspect_collision_footprint(Vector2(500,500),Vector2(501,501),0.25)["ready"]:
                _fail("stopped")
                return
            print("FOOTPRINT_CASE ",JSON.stringify({"format":format+1,"mode":mode,"cold_reason":cold["reason"],"boundary_reason":denied["reason"],"confirmed_tiles":allowed["ray_count"],"pending_reason":pending["reason"],"excluded_reason":absent["reason"],"stopped_denied":true}))
            _p.free()
            _p=null
        _b.close()
        _b=null
    print("PASS: bounded conservative footprint, actual physics confirmations, cold/pending/excluded/outside/stop denial")
    quit(0)

func _settle(count: int) -> bool:
    for attempt in range(240):
        await physics_frame
        _p.pump_stream()
        if _p._tiles.size()==count and _p._pending_tiles.is_empty() and _p._geometry_jobs.is_empty():
            await physics_frame
            await physics_frame
            return true
    return false

func _fail(msg: String) -> void:
    if _p!=null:
        _p.stop_preview()
        _p.free()
    if _b!=null:
        _b.close()
    push_error("Collision footprint: "+msg)
    quit(1)
