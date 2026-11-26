extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const C=preload("res://addons/terra_forge/core/seam_patch_candidate.gd")
const A=preload("res://addons/terra_forge/core/publication_accounting.gd")
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
        for lod in [0,1,2]:
            if not EQ._load(p,G.required_pages(p._reader,KEY.x,KEY.y,lod)):
                _fail("load")
                return
            var signatures: Array[Dictionary]=[{KEY:lod,KEY+Vector2i.LEFT:lod},{KEY:lod}]
            if lod<2:
                signatures[1][KEY+Vector2i.LEFT]=2
            for reverse in [false,true]:
                var before: Dictionary=signatures[1 if reverse else 0]
                var after: Dictionary=signatures[0 if reverse else 1]
                var base: Dictionary=G.generate(p._reader,KEY.x,KEY.y,lod,before)
                var t: int=Time.get_ticks_usec()
                var full: Dictionary=G.generate(p._reader,KEY.x,KEY.y,lod,after)
                var full_us: int=Time.get_ticks_usec()-t
                if base["error"]!=OK or full["error"]!=OK:
                    _fail("geometry")
                    return
                var control: Dictionary=C.patch(p._reader,KEY,lod,before,after,base)
                if control.get("error",FAILED)!=OK or control["arrays"]!=full["arrays"] or control["collision_heights"]!=full["collision_heights"]:
                    _fail("raw positive control")
                    return
                p._desired_tiles=before.duplicate()
                if p._publish_geometry(KEY,lod,base,Time.get_ticks_usec())!=OK:
                    _fail("base publish")
                    return
                var tile: Dictionary=p._tiles[KEY]
                var mesh: Mesh=tile["visual"].mesh
                var shape: HeightMapShape3D=tile["collision"].shape as HeightMapShape3D
                t=Time.get_ticks_usec()
                var readback: Array=mesh.surface_get_arrays(0)
                var heights: PackedFloat32Array=shape.map_data if shape!=null else PackedFloat32Array()
                var old: Dictionary={"error":OK,"arrays":readback,"collision_heights":heights,"width":base["width"],"vertex_count":base["vertex_count"]}
                var read_us: int=Time.get_ticks_usec()-t
                if readback.size()!=Mesh.ARRAY_MAX:
                    _fail("readback shape")
                    return
                var raw_equal: Dictionary=_channels(base["arrays"],readback)
                var collision_equal: bool=heights==base["collision_heights"]
                var valid: bool=A.describe(old,lod)["error"]==OK
                var patched: Dictionary={"error":ERR_INVALID_DATA}
                var patch_us: int=0
                var target_equal: Dictionary={}
                var repacked_equal: bool=false
                var repacked_available: bool=false
                var patch_collision_equal: bool=false
                var target_exact: bool=false
                if valid:
                    t=Time.get_ticks_usec()
                    patched=C.patch(p._reader,KEY,lod,before,after,old)
                    patch_us=Time.get_ticks_usec()-t
                    if patched.get("error",FAILED)==OK:
                        target_equal=_channels(full["arrays"],patched["arrays"])
                        target_exact=patched["arrays"]==full["arrays"]
                        patch_collision_equal=patched["collision_heights"]==full["collision_heights"]
                        var candidate=ArrayMesh.new()
                        var target=ArrayMesh.new()
                        candidate.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,patched["arrays"])
                        target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,full["arrays"])
                        var x: Dictionary=RenderingServer.mesh_get_surface(candidate.get_rid(),0)
                        var y: Dictionary=RenderingServer.mesh_get_surface(target.get_rid(),0)
                        repacked_available=x.has("vertex_data") and y.has("vertex_data") and not x["vertex_data"].is_empty() and not y["vertex_data"].is_empty()
                        if repacked_available:
                            repacked_equal=x.get("format")==y.get("format") and x["vertex_data"]==y["vertex_data"] and x.get("attribute_data")==y.get("attribute_data") and x.get("index_data")==y.get("index_data")
                if tile["visual"].mesh!=mesh or tile["collision"].shape!=shape or mesh.surface_get_arrays(0)!=readback or (shape!=null and shape.map_data!=heights):
                    _fail("live resource mutation")
                    return
                print("G2_RESOURCE_READBACK ",JSON.stringify({"format":format+1,"lod":lod,"reverse":reverse,"raw_channels_equal":raw_equal,"raw_exact":base["arrays"]==readback,"collision_base_equal":collision_equal,"canonical_shape_valid":valid,"patch_error":patched.get("error",FAILED),"target_channels_equal":target_equal,"target_raw_exact":target_exact,"target_collision_exact":patch_collision_equal,"repacked_available":repacked_available,"repacked_equal":repacked_equal,"full_us":full_us,"readback_us":read_us,"patch_us":patch_us,"readback_plus_patch_us":read_us+patch_us,"raw_allowance_bytes":A.expected(lod)["total_bytes"],"note":"Existing published resources read back in diagnostic only; exact raw control required, no runtime cache or authority promotion; sampled timing excludes repack and publication, not GPU."}))
        p.stop_preview()
        p.free()
        p=null
        b.close()
        b=null
    print("PASS: G2 raw positive controls and readback eligibility diagnostics; no live resource mutation")
    quit(0)

func _channels(a: Array,b: Array) -> Dictionary:
    return {"vertices":a[Mesh.ARRAY_VERTEX]==b[Mesh.ARRAY_VERTEX],"normals":a[Mesh.ARRAY_NORMAL]==b[Mesh.ARRAY_NORMAL],"colors":a[Mesh.ARRAY_COLOR]==b[Mesh.ARRAY_COLOR],"uv":a[Mesh.ARRAY_TEX_UV]==b[Mesh.ARRAY_TEX_UV],"indices":a[Mesh.ARRAY_INDEX]==b[Mesh.ARRAY_INDEX]}

func _fail(reason: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("G2 readback: "+reason)
    quit(1)
