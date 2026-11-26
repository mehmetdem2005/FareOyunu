extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const S=preload("res://addons/terra_forge/core/staged_resource_candidate.gd")
const PROFILE=preload("res://addons/terra_forge/profiling/profile_scene.gd")
const A=preload("res://addons/terra_forge/core/publication_accounting.gd")
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
var p
var b
const KEY=Vector2i(15,15)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for format in [0,1]:
        b=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),false) if format==0 else b.start(Vector2i(576,576),true)
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
        if not EQ._load(p,G.required_pages(p._reader,KEY.x,KEY.y,0)):
            _fail("load")
            return
        var before: Dictionary={KEY:0}
        var after: Dictionary={KEY:0,KEY+Vector2i.LEFT:2}
        var a: Dictionary=G.generate(p._reader,KEY.x,KEY.y,0,before)
        var z: Dictionary=G.generate(p._reader,KEY.x,KEY.y,0,after)
        if a["error"]!=OK or z["error"]!=OK or a["collision_heights"]==z["collision_heights"]:
            _fail("changed seam fixture format "+str(format+1))
            return
        p._desired_tiles=before.duplicate()
        if p._publish_geometry(KEY,0,a,Time.get_ticks_usec())!=OK:
            _fail("base publish")
            return
        await physics_frame
        await physics_frame
        var initial: PackedFloat32Array=_heights()
        if initial.size()!=9:
            _fail("initial rays")
            return
        var tile: Dictionary=p._tiles[KEY]
        var visual: MeshInstance3D=tile["visual"]
        var collision: CollisionShape3D=tile["collision"]
        var arms: Array[bool]=[false,true,true,false]
        if format==1:
            arms.reverse()
        var reference: Array=[]
        for staged in arms:
            # Reset the actual same starting revision outside measurement.
            p._desired_tiles=before.duplicate()
            if p._publish_geometry(KEY,0,a,Time.get_ticks_usec())!=OK:
                _fail("reset")
                return
            await physics_frame
            await physics_frame
            var slices=HIST.new()
            var total_us: int=0
            var max_transition_ticks: int=0
            var snapshots: Array=[]
            var rss_start: Variant=PROFILE._rss()
            var rss_peak: Variant=rss_start
            var max_raw: int=0
            for i in range(12):
                var next: Dictionary=z if i%2==0 else a
                p._desired_tiles=after.duplicate() if i%2==0 else before.duplicate()
                var token: String=str(i)
                var prior: PackedFloat32Array=_heights()
                if prior.size()!=9:
                    _fail("prior ray")
                    return
                var tick: int=Engine.get_physics_frames()
                var elapsed: int=0
                var t: int=Time.get_ticks_usec()
                if staged:
                    var stage=S.new()
                    var old_mesh: Mesh=visual.mesh
                    var old_shape: Shape3D=collision.shape
                    var status: Error=stage.stage_mesh(token,next,0)
                    elapsed=Time.get_ticks_usec()-t
                    slices.add(float(elapsed)/1000.0)
                    total_us+=elapsed
                    if status!=OK:
                        _fail("mesh stage")
                        return
                    max_raw=maxi(max_raw,stage.report()["source_payload"])
                    var rss: Variant=PROFILE._rss()
                    if rss!=null:
                        rss_peak=rss if rss_peak==null else maxi(rss_peak,rss)
                    await physics_frame
                    if _heights()!=prior:
                        _fail("mesh stage changed ray")
                        return
                    t=Time.get_ticks_usec()
                    status=stage.stage_shape(token)
                    elapsed=Time.get_ticks_usec()-t
                    slices.add(float(elapsed)/1000.0)
                    total_us+=elapsed
                    if status!=OK:
                        _fail("shape stage")
                        return
                    rss=PROFILE._rss()
                    if rss!=null:
                        rss_peak=rss if rss_peak==null else maxi(rss_peak,rss)
                    await physics_frame
                    if _heights()!=prior:
                        _fail("shape stage changed ray")
                        return
                    t=Time.get_ticks_usec()
                    status=stage.commit(token,visual,collision,old_mesh,old_shape)
                    elapsed=Time.get_ticks_usec()-t
                    slices.add(float(elapsed)/1000.0)
                    total_us+=elapsed
                    if status!=OK or stage.report()["slots"]!=0:
                        _fail("staged commit")
                        return
                else:
                    var mesh=ArrayMesh.new()
                    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,next["arrays"])
                    var shape=HeightMapShape3D.new()
                    shape.map_width=next["width"]
                    shape.map_depth=next["width"]
                    shape.map_data=next["collision_heights"]
                    visual.mesh=mesh
                    collision.shape=shape
                    elapsed=Time.get_ticks_usec()-t
                    slices.add(float(elapsed)/1000.0)
                    total_us+=elapsed
                    var rss: Variant=PROFILE._rss()
                    if rss!=null:
                        rss_peak=rss if rss_peak==null else maxi(rss_peak,rss)
                await physics_frame
                await physics_frame
                max_transition_ticks=maxi(max_transition_ticks,Engine.get_physics_frames()-tick)
                var actual: PackedFloat32Array=_heights()
                if actual.size()!=9 or actual==prior or collision.shape.map_data!=next["collision_heights"]:
                    _fail("changed ray")
                    return
                var h=HashingContext.new()
                h.start(HashingContext.HASH_SHA256)
                h.update(var_to_bytes([visual.mesh.surface_get_arrays(0),actual]))
                snapshots.append(h.finish().hex_encode())
            if reference.is_empty():
                reference=snapshots
            elif reference!=snapshots:
                _fail("paired resource and ray parity")
                return
            print("E2_PAIRED_PUBLICATION ",JSON.stringify({"format":format+1,"staged":staged,"revisions":12,"total_us":total_us,"slices":slices.report(),"max_transition_ticks":max_transition_ticks,"rss_start":rss_start,"rss_peak_sampled":rss_peak,"staged_source_allowance":max_raw,"note":"Matched complete resource create+assignment only, excludes preview bookkeeping and authority regeneration; sampled process RSS not transient allocation bound or GPU timing. ABBA per format."}))
        p.stop_preview()
        p.free()
        p=null
        b.close()
        b=null
    print("PASS: E2 ABBA paired complete resource create/assign, exact changed ray parity, sampled process RSS and latency")
    quit(0)

func _heights() -> PackedFloat32Array:
    var out=PackedFloat32Array()
    for x in [480.125,480.25,480.5]:
        for z in [492.5,493.0,493.5]:
            var ray=PhysicsRayQueryParameters3D.create(Vector3(x,128,z),Vector3(x,-128,z))
            var hit: Dictionary=p.get_world_3d().direct_space_state.intersect_ray(ray)
            if hit.is_empty() or not p.is_ancestor_of(hit["collider"]):
                return PackedFloat32Array()
            out.append(hit["position"].y)
    return out

func _fail(reason: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("E2 paired: "+reason)
    quit(1)
