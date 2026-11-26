extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const S=preload("res://addons/terra_forge/core/staged_resource_candidate.gd")
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
        for attempt in range(15000):
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture")
            return
        p=P.new()
        p.region_index_format=format
        p.max_visible_tiles=4
        root.add_child(p)
        if p.start_preview(made["directory"],16,4)!=OK:
            _fail("open")
            return
        p.set_process(false)
        var key=Vector2i(15,15)
        var desired: Dictionary={key:0}
        if not EQ._load(p,G.required_pages(p._reader,key.x,key.y,0)):
            _fail("load")
            return
        var before: Dictionary=G.generate(p._reader,key.x,key.y,0,desired)
        desired[key+Vector2i.LEFT]=2
        var after: Dictionary=G.generate(p._reader,key.x,key.y,0,desired)
        if before.get("error",FAILED)!=OK or after.get("error",FAILED)!=OK:
            _fail("geometry")
            return
        p._desired_tiles={key:0}
        if p._publish_geometry(key,0,before,Time.get_ticks_usec())!=OK:
            _fail("initial publish")
            return
        var tile: Dictionary=p._tiles[key]
        var visual: MeshInstance3D=tile["visual"]
        var collision: CollisionShape3D=tile["collision"]
        await physics_frame
        await physics_frame
        var old_mesh: Mesh=visual.mesh
        var old_shape: Shape3D=collision.shape
        var point=Vector3(480.5,0,495.5)
        var initial: Dictionary=_ray(point)
        if initial.is_empty():
            _fail("initial ray")
            return
        var stage=S.new()
        var mesh_us: int=0
        var shape_us: int=0
        var commit_us: int=0
        var single_us: int=0
        var single_peak: int=0
        var staged_peak: int=0
        for i in range(12):
            var identity: String=str(i)
            var t: int=Time.get_ticks_usec()
            var direct=ArrayMesh.new()
            direct.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,after["arrays"])
            var ds=HeightMapShape3D.new()
            ds.map_width=after["width"]
            ds.map_depth=after["width"]
            ds.map_data=after["collision_heights"]
            var elapsed: int=Time.get_ticks_usec()-t
            single_us+=elapsed
            single_peak=maxi(single_peak,elapsed)
            t=Time.get_ticks_usec()
            var status: Error=stage.stage_mesh(identity,after,0)
            elapsed=Time.get_ticks_usec()-t
            mesh_us+=elapsed
            staged_peak=maxi(staged_peak,elapsed)
            if status!=OK or stage.stage_mesh(identity,after,0)!=ERR_BUSY or stage.report()["source_payload"]>131072 or visual.mesh!=old_mesh or collision.shape!=old_shape:
                _fail("stage mesh")
                return
            await physics_frame
            if _ray(point).is_empty() or stage.commit(identity,visual,collision,old_mesh,old_shape)!=ERR_UNAVAILABLE:
                _fail("partial visibility")
                return
            t=Time.get_ticks_usec()
            status=stage.stage_shape(identity)
            elapsed=Time.get_ticks_usec()-t
            shape_us+=elapsed
            staged_peak=maxi(staged_peak,elapsed)
            if status!=OK or stage.commit("stale",visual,collision,old_mesh,old_shape)!=ERR_UNAVAILABLE or visual.mesh!=old_mesh or collision.shape!=old_shape:
                _fail("stage shape or stale")
                return
            await physics_frame
            if i%3==0:
                stage.cancel()
                if stage.report()["slots"]!=0 or visual.mesh!=old_mesh or collision.shape!=old_shape or _ray(point).is_empty():
                    _fail("cancel")
                    return
                continue
            t=Time.get_ticks_usec()
            status=stage.commit(identity,visual,collision,old_mesh,old_shape)
            elapsed=Time.get_ticks_usec()-t
            commit_us+=elapsed
            staged_peak=maxi(staged_peak,elapsed)
            if status!=OK or visual.mesh.surface_get_arrays(0)!=direct.surface_get_arrays(0) or collision.shape.map_data!=ds.map_data:
                _fail("commit parity")
                return
            old_mesh=visual.mesh
            old_shape=collision.shape
            await physics_frame
            await physics_frame
            if _ray(point).is_empty() or stage.report()["slots"]!=0:
                _fail("committed ray")
                return
        print("E2_STAGED_RESOURCE ",JSON.stringify({"format":format+1,"cases":12,"commits":8,"cancels":4,"direct_prepare_us":single_us,"direct_prepare_peak_us":single_peak,"staged_mesh_us":mesh_us,"staged_shape_us":shape_us,"commit_us":commit_us,"staged_peak_us":staged_peak,"note":"Isolated staged resource preparation, direct prep excludes assignment; actual ray presence only, not exact changed-height ray parity or full pump/VRAM"}))
        p.stop_preview()
        p.free()
        p=null
        b.close()
        b=null
    print("PASS: E2 one-slot staged mesh/shape, old ray retained, stale reject, cancel and matched resource commit")
    quit(0)

func _ray(point: Vector3) -> Dictionary:
    var query=PhysicsRayQueryParameters3D.create(point+Vector3.UP*128.0,point-Vector3.UP*128.0)
    return p.get_world_3d().direct_space_state.intersect_ray(query)

func _fail(msg: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("E2 staged: "+msg)
    quit(1)
