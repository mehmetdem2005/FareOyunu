extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const S=preload("res://addons/terra_forge/core/verified_staged_resource_candidate.gd")
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
        var old_mesh: Mesh=tile["visual"].mesh
        var old_shape: Shape3D=tile["collision"].shape
        var s=S.new()
        p._desired_tiles=after.duplicate()
        if s.begin(p,KEY,0)!=OK:
            _fail("begin")
            return
        p._desired_tiles=before.duplicate()
        if s.prepare_shape()!=ERR_UNAVAILABLE or s.report()["slots"]!=0:
            _fail("signature rejection")
            return
        p._desired_tiles=after.duplicate()
        if s.begin(p,KEY,0)!=OK or s.prepare_shape()!=OK or p._reader.set_generation(1)!=OK:
            _fail("epoch setup")
            return
        if s.commit()!=ERR_UNAVAILABLE or s.report()["slots"]!=0 or tile["visual"].mesh!=old_mesh or tile["collision"].shape!=old_shape:
            _fail("epoch rejection")
            return
        await physics_frame
        if _heights()!=initial or not EQ._load(p,G.required_pages(p._reader,KEY.x,KEY.y,0)):
            _fail("old ray or reload")
            return
        if s.begin(p,KEY,0)!=OK or s.prepare_shape()!=OK:
            _fail("verified stage")
            return
        await physics_frame
        if _heights()!=initial or s.commit()!=OK:
            _fail("old ray / commit")
            return
        await physics_frame
        await physics_frame
        var staged: PackedFloat32Array=_heights()
        if staged.size()!=9 or staged==initial or tile["collision"].shape.map_data!=z["collision_heights"]:
            _fail("changed ray or shape")
            return
        # Compare against ordinary production publication of exact same
        # verified revision. This is a physics-height oracle, not timing.
        if p._publish_geometry(KEY,0,z,Time.get_ticks_usec())!=OK:
            _fail("reference publish")
            return
        await physics_frame
        await physics_frame
        var direct: PackedFloat32Array=_heights()
        if direct!=staged or s.report()["slots"]!=0:
            _fail("exact ray height parity")
            return
        if s.begin(p,KEY,0)!=OK or s.prepare_shape()!=OK:
            _fail("stop setup")
            return
        p.stop_preview()
        if s.commit()!=ERR_UNAVAILABLE or s.report()["slots"]!=0:
            _fail("stopped source rejection")
            return
        print("E2_VERIFIED_REVISION ",JSON.stringify({"format":format+1,"rays":9,"changed":staged!=initial,"exact_ray_parity":direct==staged,"signature_rejected":true,"epoch_rejected":true,"stop_rejected":true,"note":"Verified reader generation, target references and desired signature. Isolated resource swap, no worker integration or frame timing."}))
        p.free()
        p=null
        b.close()
        b=null
    print("PASS: E2 verified source revision, actual changed seam rays equal direct publication, signature/epoch/stop rejection")
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
    push_error("E2 verified: "+reason)
    quit(1)
