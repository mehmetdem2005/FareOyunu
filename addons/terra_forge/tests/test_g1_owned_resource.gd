extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const D=preload("res://addons/terra_forge/core/tile_dense_buffer.gd")
const L=preload("res://addons/terra_forge/core/lod_policy.gd")
const C=preload("res://addons/terra_forge/core/normal_edge_candidate.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
var p
var builder

func _initialize() -> void:
    call_deferred("_run")

func _mesh(result: Dictionary) -> ArrayMesh:
    var mesh=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result["arrays"])
    return mesh

func _run() -> void:
    for format in [0,1]:
        builder=V1.new() if format==0 else V2.new()
        var err: Error=builder.start(Vector2i(576,576),true) if format==0 else builder.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=builder.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture")
            return
        p=P.new()
        p.region_index_format=format
        if p.start_preview(made["directory"],16,4)!=OK:
            _fail("open")
            return
        var session: String=p._reader.stats()["snapshot_id"]
        var counts: Dictionary={"cases":0,"full_us":0,"patch_us":0,"full_mesh_us":0,"patch_mesh_us":0,"copy_us":0,"full_normals":0,"patch_normals":0,"zero_work":0,"shape_reused":0}
        for key in [Vector2i(5,5),Vector2i(15,15)]:
            for lod in range(3):
                var pages: Array[Vector2i]=G.required_pages(p._reader,key.x,key.y,lod)
                if not EQ._load(p,pages):
                    _fail("warm")
                    return
                var start: int=Time.get_ticks_usec()
                var acquired: Dictionary=p._reader.acquire_tile_view(pages)
                if acquired["error"]!=OK:
                    _fail("lease")
                    return
                var copied: Dictionary=D.build(acquired["view"],key.x,key.y,L.sample_stride(lod))
                if p._reader.release_tile_view(acquired["view"])!=OK or copied["error"]!=OK:
                    _fail("copy")
                    return
                counts["copy_us"]+=Time.get_ticks_usec()-start
                var source=copied["buffer"]
                var before: Dictionary={key:lod}
                for dir in C.DIRS:
                    before[key+dir]=lod
                var base: Dictionary=G.generate_owned_dense_scalar(source,key.x,key.y,lod,before)
                if base["error"]!=OK:
                    _fail("base")
                    return
                var base_bytes: PackedByteArray=var_to_bytes(base)
                var source_bytes: PackedByteArray=var_to_bytes(source._values)
                var old_shape: HeightMapShape3D
                if lod==0:
                    old_shape=HeightMapShape3D.new()
                    old_shape.map_width=base["width"]
                    old_shape.map_depth=base["width"]
                    old_shape.map_data=base["collision_heights"]
                var variants: Array[Dictionary]=[before.duplicate()]
                for dir in C.DIRS:
                    var changed: Dictionary=before.duplicate()
                    changed.erase(key+dir)
                    variants.append(changed)
                var both: Dictionary=before.duplicate()
                both.erase(key+Vector2i.LEFT)
                both.erase(key+Vector2i.UP)
                variants.append(both)
                variants.append({key:lod})
                for i in range(variants.size()):
                    var after: Dictionary=variants[i]
                    var full: Dictionary
                    var patched: Dictionary
                    for patch_first in ([false,true] if i%2==0 else [true,false]):
                        start=Time.get_ticks_usec()
                        if patch_first:
                            patched=C.patch(source,key,lod,before,after,base)
                            counts["patch_us"]+=Time.get_ticks_usec()-start
                        else:
                            full=G.generate_owned_dense_scalar(source,key.x,key.y,lod,after)
                            counts["full_us"]+=Time.get_ticks_usec()-start
                    if full.get("error",FAILED)!=OK or patched.get("error",FAILED)!=OK or full["arrays"]!=patched["arrays"] or full["collision_heights"]!=patched["collision_heights"] or var_to_bytes(base)!=base_bytes or var_to_bytes(source._values)!=source_bytes:
                        _fail("owned buffer parity")
                        return
                    var a: ArrayMesh
                    var b: ArrayMesh
                    for patch_first in ([false,true] if i%2==0 else [true,false]):
                        start=Time.get_ticks_usec()
                        if patch_first:
                            b=_mesh(patched)
                            counts["patch_mesh_us"]+=Time.get_ticks_usec()-start
                        else:
                            a=_mesh(full)
                            counts["full_mesh_us"]+=Time.get_ticks_usec()-start
                    if a.surface_get_arrays(0)!=b.surface_get_arrays(0):
                        _fail("mesh resource parity")
                        return
                    if lod==0:
                        if old_shape.map_data!=patched["collision_heights"] or old_shape.map_data!=full["collision_heights"]:
                            _fail("shape data reuse")
                            return
                        counts["shape_reused"]+=1
                    counts["cases"]+=1
                    counts["full_normals"]+=base["width"]*base["width"]
                    counts["patch_normals"]+=patched["updated_normals"]
                    counts["zero_work"]+=int(patched["updated_normals"]==0)
        if p._reader.stats()["snapshot_id"]!=session or p._reader.stats()["tile_view_active_pages"]!=0 or counts["cases"]!=42:
            _fail("session or lease")
            return
        print("G1_OWNED_RESOURCE ",JSON.stringify({"format":format+1,"counts":counts,"note":"Warm same-snapshot owned dense buffer, headless ArrayMesh construction; no GPU/render, no runtime cache or physics publication"}))
        p.stop_preview()
        p.free()
        p=null
        builder.close()
        builder=null
    print("PASS: G1 verified TFM1/TFM2 owned dense scalar and mesh resource parity, 84 variants, no mutation")
    quit(0)

func _fail(msg: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if builder!=null:
        builder.close()
    push_error("G1 owned resource: "+msg)
    quit(1)
