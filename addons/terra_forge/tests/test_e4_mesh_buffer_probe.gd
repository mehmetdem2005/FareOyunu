extends SceneTree
const C=preload("res://addons/terra_forge/core/mesh_buffer_patch_plan.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
class Source extends RefCounted:
    var cells: Vector2i=Vector2i(128,128)
    var spacing: float=1.0
    func is_open() -> bool:
        return true
    func get_height(x: int,z: int) -> Dictionary:
        return {"error":OK,"height":4.0*sin(float(x)*0.19)+3.0*cos(float(z)*0.23)+0.002*float(x*z)}

func _initialize() -> void:
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
            continue
        raw_available+=1
        if x.get("format")!=y.get("format") or x.get("index_data")!=y.get("index_data") or x.get("vertex_count")!=y.get("vertex_count"):
            fallback+=1
            continue
        var vp: Dictionary=C.plan(x["vertex_data"],y["vertex_data"])
        var ap: Dictionary=C.plan(x.get("attribute_data",PackedByteArray()),y.get("attribute_data",PackedByteArray()))
        if vp["error"]!=OK or ap["error"]!=OK:
            fallback+=1
            continue
        if C.reconstruct(x["vertex_data"],y["vertex_data"],vp["ranges"])!=y["vertex_data"] or C.reconstruct(x.get("attribute_data",PackedByteArray()),y.get("attribute_data",PackedByteArray()),ap["ranges"])!=y.get("attribute_data",PackedByteArray()):
            _fail("packed plan parity")
            return
        if vp["ranges"].size()+ap["ranges"].size()>C.MAX_RUNS:
            fallback+=1
            continue
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
        raw_verified+=1
        uploaded_bytes+=vp["bytes"]+ap["bytes"]
        full_bytes+=y["vertex_data"].size()+y.get("attribute_data",PackedByteArray()).size()
        calls+=vp["ranges"].size()+ap["ranges"].size()
    print("E4_MESH_BUFFER_PROBE ",JSON.stringify({"pure_cases":cases,"pure_cap_rejections":rejected,"raw_available":raw_available,"raw_verified":raw_verified,"raw_unsupported":raw_unsupported,"dummy_noop":dummy_noop,"display":display,"fallback":fallback,"planned_uploaded_bytes":uploaded_bytes,"full_buffer_bytes":full_bytes,"calls":calls,"note":"Scratch renderer readback only if backend supports it. No live culling/AABB, collision, GPU timings, Mobile device or allocation claim."}))
    print("PASS: E4 bounded aligned buffer plan and conditional detached renderer capability probe; headless no-op is unsupported, not verified update")
    quit(0)

func _fail(reason: String) -> void:
    push_error("E4 mesh buffer: "+reason)
    quit(1)
