extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const S=preload("res://addons/terra_forge/core/verified_seam_revision_candidate.gd")
const R=preload("res://addons/terra_forge/core/async_region_source.gd")
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
        var other=R.new()
        var opened: Error=other.open(made["directory"],16,4,false) if format==0 else other.open_v2(made["directory"],16,4,false)
        if opened!=OK or s.begin(p._reader,KEY,0,before)!=OK:
            other.close()
            _fail("identity setup")
            return
        var wrong: Dictionary=s.patch(other,after)
        other.close()
        if wrong["error"]!=ERR_UNAVAILABLE or s.retained_bytes()!=0:
            _fail("wrong reader")
            return
        if s.begin(p._reader,KEY,0,before)!=OK or p._reader.set_generation(1)!=OK or s.patch(p._reader,after)["error"]!=ERR_UNAVAILABLE:
            _fail("epoch rejection")
            return
        if not EQ._load(p,G.required_pages(p._reader,KEY.x,KEY.y,0)):
            _fail("verified pages")
            return
        var base_started: int=Time.get_ticks_usec()
        if s.begin(p._reader,KEY,0,before)!=OK:
            _fail("verified base")
            return
        var base_us: int=Time.get_ticks_usec()-base_started
        var held: int=s.retained_bytes()
        var t: int=Time.get_ticks_usec()
        var patched: Dictionary=s.patch(p._reader,after)
        var patch_us: int=Time.get_ticks_usec()-t
        t=Time.get_ticks_usec()
        var full: Dictionary=G.generate(p._reader,KEY.x,KEY.y,0,after)
        var full_us: int=Time.get_ticks_usec()-t
        if patched.get("error",FAILED)!=OK or full.get("error",FAILED)!=OK or patched["arrays"]!=full["arrays"] or patched["collision_heights"]!=full["collision_heights"] or s.retained_bytes()!=0 or held>131072 or patched["changed_vertices"]<=0:
            _fail("verified patch parity")
            return
        if tile["visual"].mesh!=old_mesh or tile["collision"].shape!=old_shape or _heights()!=initial:
            _fail("old resources changed")
            return
        p._desired_tiles=after.duplicate()
        if p._publish_geometry(KEY,0,patched,Time.get_ticks_usec())!=OK:
            _fail("patch publish")
            return
        await physics_frame
        await physics_frame
        var actual: PackedFloat32Array=_heights()
        var mesh_arrays: Array=tile["visual"].mesh.surface_get_arrays(0)
        if actual.size()!=9 or actual==initial or tile["collision"].shape.map_data!=full["collision_heights"]:
            _fail("changed physical ray")
            return
        if p._publish_geometry(KEY,0,full,Time.get_ticks_usec())!=OK:
            _fail("full publish")
            return
        await physics_frame
        await physics_frame
        if _heights()!=actual or tile["visual"].mesh.surface_get_arrays(0)!=mesh_arrays:
            _fail("actual physics/resource parity")
            return
        if s.begin(p._reader,KEY,0,after)!=OK:
            _fail("stop setup")
            return
        var reader=p._reader
        p.stop_preview()
        if s.patch(reader,before)["error"]!=ERR_UNAVAILABLE or s.retained_bytes()!=0:
            _fail("closed reader")
            return
        print("G2_VERIFIED_PHYSICS ",JSON.stringify({"format":format+1,"rays":9,"changed_vertices":patched["changed_vertices"],"sampled_edges":patched["sampled_edges"],"normals":patched["updated_normals"],"full_us":full_us,"patch_us":patch_us,"base_us":base_us,"base_plus_patch_us":base_us+patch_us,"retained_raw_bytes":held,"wrong_reader_rejected":true,"epoch_rejected":true,"stop_rejected":true,"note":"Single-use internally generated verified base, patch_us excludes base generation; base_plus_patch_us includes it; ordinary full resource publication, no runtime cache or FPS claim"}))
        p.free()
        p=null
        b.close()
        b=null
    print("PASS: G2 verified source patch arrays and actual physics heights equal full rebuild; wrong reader/epoch/close rejected")
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
    push_error("G2 verified: "+reason)
    quit(1)
