extends SceneTree
## Paired equal-work resource publication experiment; no production changes.
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const C=preload("res://addons/terra_forge/core/mesh_buffer_coalesce_candidate.gd")
class Source extends RefCounted:
    var cells: Vector2i=Vector2i(128,128)
    var spacing: float=1.0
    func is_open() -> bool:
        return true
    func get_height(x: int,z: int) -> Dictionary:
        return {"error":OK,"height":4.0*sin(float(x)*0.19)+3.0*cos(float(z)*0.23)+0.002*float(x*z)}
var source=Source.new()
var visual: MeshInstance3D
var collision: CollisionShape3D
const KEY=Vector2i(1,1)

func _initialize() -> void:
    call_deferred("_run")

func _mesh(data: Dictionary) -> ArrayMesh:
    var mesh=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data["arrays"],[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
    return mesh

func _shape(data: Dictionary,lod: int) -> HeightMapShape3D:
    if lod!=0:
        return null
    var shape=HeightMapShape3D.new()
    shape.map_width=data["width"]
    shape.map_depth=data["width"]
    shape.map_data=data["collision_heights"]
    return shape

func _case(lod: int,reverse: bool,patch: bool) -> Dictionary:
    var before: Dictionary={KEY:lod,KEY+Vector2i.LEFT:lod}
    var after: Dictionary={KEY:lod}
    if lod<2:
        after[KEY+Vector2i.LEFT]=2
    if reverse:
        var swap: Dictionary=before
        before=after
        after=swap
    var base: Dictionary=G.generate(source,KEY.x,KEY.y,lod,before)
    if base["error"]!=OK:
        return {"error":FAILED,"stage":"base"}
    var old: ArrayMesh=_mesh(base)
    visual.mesh=old
    collision.shape=_shape(base,lod)
    var began: int=Time.get_ticks_usec()
    var target: Dictionary=G.generate(source,KEY.x,KEY.y,lod,after)
    var geometry_us: int=Time.get_ticks_usec()-began
    if target["error"]!=OK:
        return {"error":FAILED,"stage":"target"}
    var pack_begin: int=Time.get_ticks_usec()
    var fresh: ArrayMesh=_mesh(target)
    var pack_us: int=Time.get_ticks_usec()-pack_begin
    var plan_us: int=0
    var update_us: int=0
    var calls: int=0
    var bytes: int=0
    var fallback: bool=false
    if patch:
        var t: int=Time.get_ticks_usec()
        var a: Dictionary=RenderingServer.mesh_get_surface(old.get_rid(),0)
        var b: Dictionary=RenderingServer.mesh_get_surface(fresh.get_rid(),0)
        if a.get("format")!=b.get("format") or a.get("index_data")!=b.get("index_data"):
            return {"error":FAILED,"stage":"topology"}
        var plan: Dictionary=C.plan(a["vertex_data"],b["vertex_data"],a.get("attribute_data",PackedByteArray()),b.get("attribute_data",PackedByteArray()))
        plan_us=Time.get_ticks_usec()-t
        if plan["error"]!=OK:
            fallback=true
            visual.mesh=fresh
        else:
            t=Time.get_ticks_usec()
            for span in plan["vertex"]:
                old.surface_update_vertex_region(0,span.x,b["vertex_data"].slice(span.x,span.y))
            for span in plan["attribute"]:
                old.surface_update_attribute_region(0,span.x,b["attribute_data"].slice(span.x,span.y))
            # Reset to current target bounds, never accumulate historical boxes.
            old.custom_aabb=fresh.get_aabb().grow(0.0001)
            visual.mesh=old
            update_us=Time.get_ticks_usec()-t
            calls=plan["calls"]
            bytes=plan["bytes"]
    else:
        visual.mesh=fresh
    var shape_begin: int=Time.get_ticks_usec()
    collision.shape=_shape(target,lod)
    var shape_us: int=Time.get_ticks_usec()-shape_begin
    var total_us: int=Time.get_ticks_usec()-began
    # Verification outside timed region, including exact rendered buffer and shape data.
    var actual: Dictionary=RenderingServer.mesh_get_surface(visual.mesh.get_rid(),0)
    var expected: Dictionary=RenderingServer.mesh_get_surface(fresh.get_rid(),0)
    if actual.get("vertex_data")!=expected.get("vertex_data") or actual.get("attribute_data")!=expected.get("attribute_data") or actual.get("index_data")!=expected.get("index_data"):
        return {"error":FAILED,"stage":"resource parity"}
    if lod==0 and (collision.shape==null or collision.shape.map_data!=target["collision_heights"]):
        return {"error":FAILED,"stage":"shape parity"}
    if lod!=0 and collision.shape!=null:
        return {"error":FAILED,"stage":"shape release"}
    if patch and not fallback and not old.custom_aabb.encloses(fresh.get_aabb()):
        return {"error":FAILED,"stage":"bounds"}
    visual.mesh=null
    collision.shape=null
    return {"error":OK,"total_us":total_us,"geometry_us":geometry_us,"pack_us":pack_us,"plan_readback_us":plan_us,"update_bounds_us":update_us,"shape_us":shape_us,"calls":calls,"bytes":bytes,"fallback":fallback}

func _run() -> void:
    var method: String=RenderingServer.get_current_rendering_method()
    var expected: String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--require-renderer="):
            expected=arg.get_slice("=",1)
    if DisplayServer.get_name().to_lower()=="headless":
        if not expected.is_empty():
            _fail("required renderer absent")
            return
        print("PASS: E4 cost diagnostic headless guard only")
        quit(0)
        return
    if not expected.is_empty() and method!=expected:
        _fail("renderer fallback")
        return
    visual=MeshInstance3D.new()
    collision=CollisionShape3D.new()
    root.add_child(visual)
    var body=StaticBody3D.new()
    root.add_child(body)
    body.add_child(collision)
    for lod in [0,1,2]:
        var sums: Dictionary={}
        for arm in ["full","patch"]:
            sums[arm]={"total_us":0,"geometry_us":0,"pack_us":0,"plan_readback_us":0,"update_bounds_us":0,"shape_us":0,"calls":0,"bytes":0,"fallbacks":0,"samples":0}
        for round_id in range(4):
            for reverse in [false,true]:
                var order: Array[bool]=[false,true,true,false]
                if round_id%2!=0:
                    order.assign([true,false,false,true])
                for patch in order:
                    var result: Dictionary=_case(lod,reverse,patch)
                    if result["error"]!=OK:
                        _fail(str([lod,reverse,patch,result]))
                        return
                    var arm: String="patch" if patch else "full"
                    for key in ["total_us","geometry_us","pack_us","plan_readback_us","update_bounds_us","shape_us","calls","bytes"]:
                        sums[arm][key]+=result[key]
                    sums[arm]["fallbacks"]+=int(result["fallback"])
                    sums[arm]["samples"]+=1
                    await process_frame
        print("E4_COMPLETE_COST ",JSON.stringify({"method":method,"lod":lod,"full":sums["full"],"patch":sums["patch"],"note":"Same target generation, scratch engine packing, readback/plan, updates/bounds, mesh and shape assignment; verification and resource release outside timing. CPU submission wall time, not GPU completion, transient memory or phone FPS."}))
    visual.free()
    body.free()
    print("PASS: E4 paired complete CPU resource publication and exact buffer/shape parity")
    quit(0)

func _fail(reason: String) -> void:
    push_error("E4 cost: "+reason)
    quit(1)
