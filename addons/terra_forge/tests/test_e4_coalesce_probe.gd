extends SceneTree
const C=preload("res://addons/terra_forge/core/mesh_buffer_patch_plan.gd")
const CO=preload("res://addons/terra_forge/core/mesh_buffer_coalesce_candidate.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
class Source extends RefCounted:
    var cells: Vector2i=Vector2i(128,128)
    var spacing: float=1.0
    func is_open() -> bool:
        return true
    func get_height(x: int,z: int) -> Dictionary:
        return {"error":OK,"height":4.0*sin(float(x)*0.19)+3.0*cos(float(z)*0.23)+0.002*float(x*z)}

func _initialize() -> void:
    var expected_method: String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--require-renderer="):
            expected_method=arg.get_slice("=",1)
    var actual_method: String=RenderingServer.get_current_rendering_method()
    var actual_driver: String=RenderingServer.get_current_rendering_driver_name()
    print("E4_RENDERER ",JSON.stringify({"display":DisplayServer.get_name(),"method":actual_method,"driver":actual_driver,"expected":expected_method,"adapter":RenderingServer.get_video_adapter_name()}))
    if not expected_method.is_empty() and (DisplayServer.get_name().to_lower()=="headless" or actual_method!=expected_method):
        _fail("required renderer unavailable or fallback")
        return
    var cases: int=0
    var rejected: int=0
    for n in [0,16,64,256,4096]:
        for step in [4,20,80]:
            var a=PackedByteArray()
            a.resize(n)
            var b: PackedByteArray=a.duplicate()
            for i in range(0,n,step):
                b[i]=17
            var p: Dictionary=C.plan(a,b)
            if p["error"]==ERR_UNAVAILABLE:
                rejected+=1
            elif p["error"]!=OK or C.reconstruct(a,b,p["ranges"])!=b or p["bytes"]>n:
                _fail("pure plan")
                return
            cases+=1
    if C.plan(PackedByteArray([1]),PackedByteArray([1]))["error"]!=ERR_INVALID_PARAMETER or rejected==0:
        _fail("negative control")
        return
    var empty=PackedByteArray()
    var zeros=PackedByteArray()
    zeros.resize(128)
    var sparse: PackedByteArray=zeros.duplicate()
    sparse[0]=1
    sparse[8]=1
    sparse[40]=1
    var known: Dictionary=CO.plan(zeros,sparse,empty,empty,2)
    if known.get("error",FAILED)!=OK or known["bytes"]!=16 or known["calls"]!=2 or C.reconstruct(zeros,sparse,known["vertex"])!=sparse:
        _fail("minimum gap control")
        return
    var dense: PackedByteArray=zeros.duplicate()
    dense.fill(1)
    if CO.plan(zeros,dense,empty,empty)["error"]!=ERR_UNAVAILABLE or CO.plan(zeros,sparse,zeros,sparse,1)["error"]!=ERR_UNAVAILABLE or CO.plan(zeros,sparse,empty,empty,33)["error"]!=ERR_INVALID_PARAMETER:
        _fail("combined cap negative controls")
        return
    var source=Source.new()
    var raw_available: int=0
    var raw_verified: int=0
    var raw_unsupported: int=0
    var dummy_noop: int=0
    var display: String=DisplayServer.get_name()
    var fallback: int=0
    var uploaded_bytes: int=0
    var full_bytes: int=0
    var calls: int=0
    var changed_verified: int=0
    var bound_checks: int=0
    var stale_bounds: int=0
    var key=Vector2i(1,1)
    for lod in [0,1,2]:
        var before: Dictionary={key:lod,key+Vector2i.LEFT:lod}
        var after: Dictionary={key:lod}
        if lod<2:
            after[key+Vector2i.LEFT]=2
        var a: Dictionary=G.generate(source,key.x,key.y,lod,before)
        var b: Dictionary=G.generate(source,key.x,key.y,lod,after)
        if a["error"]!=OK or b["error"]!=OK:
            _fail("geometry")
            return
        var old=ArrayMesh.new()
        var target=ArrayMesh.new()
        old.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a["arrays"],[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
        target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,b["arrays"],[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
        var x: Dictionary=RenderingServer.mesh_get_surface(old.get_rid(),0)
        var y: Dictionary=RenderingServer.mesh_get_surface(target.get_rid(),0)
        # Headless dummy backend may expose no raw packed bytes. Record a
        # capability gap, never silently pass as an actual GPU update.
        if not x.has("vertex_data") or not y.has("vertex_data") or x["vertex_data"].is_empty() or y["vertex_data"].is_empty():
            raw_unsupported+=1
            print("E4_FALLBACK ",JSON.stringify({"lod":lod,"reason":"no_raw_bytes"}))
            continue
        raw_available+=1
        if x.get("format")!=y.get("format") or x.get("index_data")!=y.get("index_data") or x.get("vertex_count")!=y.get("vertex_count"):
            fallback+=1
            print("E4_FALLBACK ",JSON.stringify({"lod":lod,"reason":"format_or_topology"}))
            continue
        var old_v: Dictionary=C.plan(x["vertex_data"],y["vertex_data"])
        var old_a: Dictionary=C.plan(x.get("attribute_data",PackedByteArray()),y.get("attribute_data",PackedByteArray()))
        var old_calls: int=-1
        var old_bytes: int=-1
        if old_v["error"]==OK and old_a["error"]==OK:
            old_calls=old_v["ranges"].size()+old_a["ranges"].size()
            old_bytes=old_v["bytes"]+old_a["bytes"]
        var began: int=Time.get_ticks_usec()
        var plan: Dictionary=CO.plan(x["vertex_data"],y["vertex_data"],x.get("attribute_data",PackedByteArray()),y.get("attribute_data",PackedByteArray()))
        var elapsed: int=Time.get_ticks_usec()-began
        print("E4_COALESCE_PAIR ",JSON.stringify({"lod":lod,"display":display,"method":actual_method,"old_accepted":old_calls>=0 and old_calls<=C.MAX_RUNS,"old_calls":old_calls,"old_bytes":old_bytes,"candidate_accepted":plan["error"]==OK,"candidate_calls":plan.get("calls",-1),"candidate_bytes":plan.get("bytes",-1),"initial_calls":plan.get("initial_calls",-1),"full_bytes":y["vertex_data"].size()+y.get("attribute_data",PackedByteArray()).size(),"plan_us":elapsed,"reason":plan.get("reason","ok")}))
        if plan["error"]!=OK:
            fallback+=1
            continue
        var vp: Dictionary={"ranges":plan["vertex"],"bytes":0}
        var ap: Dictionary={"ranges":plan["attribute"],"bytes":0}
        for span in vp["ranges"]:
            vp["bytes"]+=span.y-span.x
        for span in ap["ranges"]:
            ap["bytes"]+=span.y-span.x
        if C.reconstruct(x["vertex_data"],y["vertex_data"],vp["ranges"])!=y["vertex_data"] or C.reconstruct(x.get("attribute_data",PackedByteArray()),y.get("attribute_data",PackedByteArray()),ap["ranges"])!=y.get("attribute_data",PackedByteArray()) or vp["ranges"].size()+ap["ranges"].size()>C.MAX_RUNS or vp["bytes"]+ap["bytes"]!=plan["bytes"]:
            _fail("combined plan parity/caps")
            return
        for span in vp["ranges"]:
            old.surface_update_vertex_region(0,span.x,y["vertex_data"].slice(span.x,span.y))
        for span in ap["ranges"]:
            old.surface_update_attribute_region(0,span.x,y["attribute_data"].slice(span.x,span.y))
        # Detached scratch mesh only. No collision or published resource.
        var actual: Dictionary=RenderingServer.mesh_get_surface(old.get_rid(),0)
        if actual.get("vertex_data")!=y["vertex_data"] or actual.get("attribute_data",PackedByteArray())!=y.get("attribute_data",PackedByteArray()) or actual.get("index_data")!=y.get("index_data"):
            # Dummy backend stores original packed bytes but region update
            # methods are no-ops (Godot dummy/storage/mesh_storage.h).
            # Accept only exact unchanged data in explicitly headless mode;
            # a partially changed or real renderer mismatch remains failure.
            if display.to_lower()=="headless" and actual.get("vertex_data")==x["vertex_data"] and actual.get("attribute_data",PackedByteArray())==x.get("attribute_data",PackedByteArray()) and actual.get("index_data")==x.get("index_data"):
                dummy_noop+=1
                print("E4_BACKEND_NOOP ",JSON.stringify({"lod":lod,"display":display,"planned_bytes":vp["bytes"]+ap["bytes"],"planned_calls":vp["ranges"].size()+ap["ranges"].size(),"vertex_changed":x["vertex_data"]!=y["vertex_data"],"attribute_changed":x.get("attribute_data",PackedByteArray())!=y.get("attribute_data",PackedByteArray())}))
                continue
            _fail("raw renderer readback mismatch "+display+" lod="+str(lod))
            return
        print("E4_COALESCE_VERIFIED ",JSON.stringify({"lod":lod,"method":actual_method,"bytes":plan["bytes"],"calls":plan["calls"]}))
        raw_verified+=1
        if vp["bytes"]+ap["bytes"]>0:
            changed_verified+=1
        var target_box: AABB=target.get_aabb()
        var previous_box: AABB=old.get_aabb()
        var covers: bool=previous_box.grow(0.0001).encloses(target_box)
        bound_checks+=1
        if not covers:
            stale_bounds+=1
        # Explicit conservative custom bounds; getter checks configured bounds,
        # not proof of visibility or actual renderer culling.
        old.custom_aabb=previous_box.merge(target_box).grow(0.0001)
        if not old.custom_aabb.encloses(target_box):
            _fail("custom bounds coverage")
            return
        print("E4_BOUNDS ",JSON.stringify({"lod":lod,"old_covers_target":covers,"custom_covers_target":true,"actual_culling_verified":false}))
        uploaded_bytes+=vp["bytes"]+ap["bytes"]
        full_bytes+=y["vertex_data"].size()+y.get("attribute_data",PackedByteArray()).size()
        calls+=vp["ranges"].size()+ap["ranges"].size()
    print("E4_MESH_BUFFER_PROBE ",JSON.stringify({"pure_cases":cases,"pure_cap_rejections":rejected,"raw_available":raw_available,"raw_verified":raw_verified,"raw_unsupported":raw_unsupported,"dummy_noop":dummy_noop,"display":display,"fallback":fallback,"planned_uploaded_bytes":uploaded_bytes,"full_buffer_bytes":full_bytes,"calls":calls,"changed_verified":changed_verified,"bound_checks":bound_checks,"stale_bounds":stale_bounds,"note":"Scratch renderer readback only if backend supports it. No live culling/AABB, collision, GPU timings, Mobile device or allocation claim."}))
    if not expected_method.is_empty() and changed_verified==0:
        _fail("no changed renderer readback verified")
        return
    print("PASS: E4 bounded aligned buffer plan and conditional detached renderer capability probe; headless no-op is unsupported, not verified update")
    quit(0)

func _fail(reason: String) -> void:
    push_error("E4 mesh buffer: "+reason)
    quit(1)
