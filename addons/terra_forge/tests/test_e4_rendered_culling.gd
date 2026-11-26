extends SceneTree
## Rendered synthetic terrain quad: old bounds outside camera, target inside.
## Tests actual pixels, not only AABB getters or packed readback.
const C=preload("res://addons/terra_forge/core/mesh_buffer_patch_plan.gd")
var viewport: SubViewport
var visual: MeshInstance3D

func _initialize() -> void:
    call_deferred("_run")

func _mesh(x: float) -> ArrayMesh:
    var arrays: Array=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(x-1,0,-1),Vector3(x+1,0,-1),Vector3(x+1,0,1),Vector3(x-1,0,1)])
    arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
    var mesh=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
    return mesh

func _mask() -> PackedByteArray:
    # Multiple completed frames allow render/culling state to settle.
    for i in range(3):
        await process_frame
        await RenderingServer.frame_post_draw
    var img: Image=viewport.get_texture().get_image()
    var mask=PackedByteArray()
    if img==null or img.get_width()!=128 or img.get_height()!=128:
        return mask
    mask.resize(128*128)
    for y in range(128):
        for x in range(128):
            var color: Color=img.get_pixel(x,y)
            mask[y*128+x]=1 if color.r>0.65 and color.b>0.65 and color.g<0.35 else 0
    return mask

func _count(mask: PackedByteArray) -> int:
    var n: int=0
    for v in mask:
        n+=v
    return n

func _run() -> void:
    var expected: String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--require-renderer="):
            expected=arg.get_slice("=",1)
    var method: String=RenderingServer.get_current_rendering_method()
    var display: String=DisplayServer.get_name()
    if display.to_lower()=="headless":
        if not expected.is_empty():
            _fail("required renderer absent")
            return
        print("E4_CULLING_UNSUPPORTED headless: no rendered pixels")
        print("PASS: E4 culling capability guard only; actual rendering required separately")
        quit(0)
        return
    if not expected.is_empty() and method!=expected:
        _fail("renderer fallback")
        return
    viewport=SubViewport.new()
    viewport.size=Vector2i(128,128)
    viewport.own_world_3d=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    viewport.msaa_3d=Viewport.MSAA_DISABLED
    root.add_child(viewport)
    var camera=Camera3D.new()
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=4.0
    viewport.add_child(camera)
    camera.position=Vector3(0,8,0)
    camera.look_at(Vector3.ZERO,Vector3.FORWARD)
    camera.make_current()
    visual=MeshInstance3D.new()
    var mat=StandardMaterial3D.new()
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mat.albedo_color=Color(1,0,1,1)
    visual.material_override=mat
    viewport.add_child(visual)
    var old: ArrayMesh=_mesh(12.0)
    var target: ArrayMesh=_mesh(0.0)
    var original: AABB=old.get_aabb()
    var desired: AABB=target.get_aabb()
    if original.grow(0.01).encloses(desired):
        _fail("fixture bounds not distinct")
        return
    visual.mesh=old
    var outside: PackedByteArray=await _mask()
    visual.mesh=target
    var reference: PackedByteArray=await _mask()
    if outside.size()!=16384 or reference.size()!=16384 or _count(outside)!=0 or _count(reference)<100:
        _fail("camera positive/negative control: "+str([_count(outside),_count(reference)]))
        return
    visual.mesh=old
    var before: Dictionary=RenderingServer.mesh_get_surface(old.get_rid(),0)
    var after: Dictionary=RenderingServer.mesh_get_surface(target.get_rid(),0)
    var plan: Dictionary=C.plan(before["vertex_data"],after["vertex_data"])
    if plan["error"]!=OK or plan["bytes"]<=0 or before.get("index_data")!=after.get("index_data") or before.get("format")!=after.get("format"):
        _fail("packed vertex plan")
        return
    for span in plan["ranges"]:
        old.surface_update_vertex_region(0,span.x,after["vertex_data"].slice(span.x,span.y))
    var actual: Dictionary=RenderingServer.mesh_get_surface(old.get_rid(),0)
    if actual.get("vertex_data")!=after.get("vertex_data") or actual.get("index_data")!=after.get("index_data"):
        _fail("packed readback mismatch")
        return
    # Observe the renderer's behavior before the conservative bounds fix.
    var stale: PackedByteArray=await _mask()
    old.custom_aabb=original.merge(desired).grow(0.01)
    var corrected: PackedByteArray=await _mask()
    if corrected.size()!=16384 or corrected!=reference:
        _fail("corrected rendered mask differs from fresh reference: "+str([_count(corrected),_count(reference)]))
        return
    # Move camera to the old footprint. New geometry must not appear there,
    # even though the conservative bounding box overlaps the view.
    camera.position=Vector3(12,8,0)
    camera.look_at(Vector3(12,0,0),Vector3.FORWARD)
    var away: PackedByteArray=await _mask()
    if away.size()!=16384 or _count(away)!=0:
        _fail("ghost pixels after camera relocation")
        return
    print("E4_RENDERED_CULLING ",JSON.stringify({"method":method,"display":display,"adapter":RenderingServer.get_video_adapter_name(),"old_outside_pixels":_count(outside),"target_pixels":_count(reference),"before_bounds_fix_pixels":_count(stale),"after_bounds_fix_pixels":_count(corrected),"relocated_camera_pixels":_count(away),"mask_equal":corrected==reference,"calls":plan["ranges"].size(),"bytes":plan["bytes"],"note":"Synthetic horizontal quad, actual software rendered pixels; no terrain route, phone GPU, physics or FPS claim."}))
    viewport.free()
    viewport=null
    print("PASS: E4 rendered camera visibility and conservative bounds on synthetic quad")
    quit(0)

func _fail(reason: String) -> void:
    if is_instance_valid(viewport):
        viewport.free()
    push_error("E4 culling: "+reason)
    quit(1)
