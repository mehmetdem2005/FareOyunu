extends SceneTree
const A=preload("res://addons/terra_forge/core/publication_accounting.gd")
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")

func _initialize() -> void:
    print("PUBLICATION_ENV ",JSON.stringify({"cpu":OS.get_processor_name(),"os":OS.get_name(),"godot":Engine.get_version_info().get("string",""),"notes":"CPU-side source array allowance and main-thread resource creation; no GPU/physics frame measurement"}))
    var zero: Dictionary={"vertices":0,"triangles":0,"mesh_bytes":0,"shape_bytes":0,"total_bytes":0,"meshes":0,"shapes":0}
    var a=A.new()
    var expected: Dictionary=A.expected(0)
    if expected["total_bytes"]!=116052 or A.expected(1)["total_bytes"]!=29264 or A.expected(2)["total_bytes"]!=8016 or A.expected(-1)["error"]==OK or A.describe({},0)["error"]==OK:
        _fail("formula",null,null)
        return
    a.begin_pump(1)
    a.record(0,expected,600,200,900)
    a.record(0,expected,200,100,400)
    a.end_pump(zero)
    a.begin_pump(1)
    a.end_pump(zero)
    var report: Dictionary=a.report(zero)
    if report["publication_count"]!=2 or report["over_byte_pumps"]!=1 or report["over_time_pumps"]!=1 or report["over_count_pumps"]!=1 or report["max_byte_excess"]!=101032 or report["max_time_excess_us"]!=300 or report["pumps"]!=2 or report["active_pumps"]!=1 or report["gpu_time_ms"]!=null or report["gpu_resident_bytes"]!=null:
        _fail("synthetic overshoot",null,null)
        return
    for format in [0,1]:
        var b: Variant=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start",null,b)
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture",null,b)
            return
        var folder: String=made["directory"]
        for mode in [0,2,5]:
            var p=P.new()
            p.region_index_format=format
            p.sampling_strategy=mode
            p.observe_publication=true
            p.max_visible_tiles=4
            p.tile_updates_per_frame=2
            p.max_tile_work_ms=8.0
            if p.start_preview(folder,16,4)!=OK:
                _fail("preview start",p,b)
                return
            # Fixed mixed LOD set; prevent periodic camera sync in this test.
            var key=Vector2i(15,15)
            var desired: Dictionary={key:0,Vector2i(16,15):1,Vector2i(15,16):2,Vector2i(16,16):0}
            p._desired_tiles=desired.duplicate()
            p._pending_tiles.clear()
            for k in desired:
                p._pending_tiles[k]=true
            if not _settle(p) or not _verify(p):
                _fail("initial accounting and resources",p,b)
                return
            var s: Dictionary=p.stats()["publication"]
            if s["publication_count"]!=4 or s["lod_counts"]!=[2,1,1] or s["total_source_bytes"]!=269384 or s["resident"]["triangles"]!=4736 or s["resident"]["meshes"]!=4 or s["resident"]["shapes"]!=2:
                _fail("initial totals "+str(s),p,b)
                return
            # Rebuild a tile at new LOD, verify no stale shape/count.
            p._desired_tiles[key]=2
            p._pending_tiles[key]=true
            if not _settle(p) or not _verify(p):
                _fail("replacement accounting",p,b)
                return
            s=p.stats()["publication"]
            if s["publication_count"]!=5 or s["resident"]["shapes"]!=1 or s["resident"]["total_bytes"]!=161348:
                _fail("replacement totals "+str(s),p,b)
                return
            # Deliberately malformed geometry must not replace last-good.
            var old: Mesh=p._tiles[key]["visual"].mesh
            var count: int=s["publication_count"]
            if p._publish_geometry(key,2,{"error":OK,"arrays":[]},Time.get_ticks_usec())!=ERR_INVALID_DATA or p._tiles[key]["visual"].mesh!=old or p.stats()["publication"]["publication_count"]!=count:
                _fail("invalid publication counted/replaced",p,b)
                return
            p.set_stream_center(Vector3(16,20,16))
            p._sync_tiles()
            if p.stats()["publication"]["resident"]["meshes"]!=0:
                _fail("eviction accounting",p,b)
                return
            p.stop_preview()
            if not p.stats()["publication"].is_empty():
                _fail("close reset",p,b)
                return
            p.observe_publication=false
            if p.start_preview(folder,16,4)!=OK or not p.stats()["publication"].is_empty():
                _fail("disabled reopen",p,b)
                return
            p.stop_preview()
            p.free()
            var measured: Dictionary=TRACE.run(folder,format,mode,16,2,8000,true)
            if measured["error"]!=OK:
                _fail("trace "+str(measured),null,b)
                return
            var m: Dictionary=measured["publication"]
            if m["publication_count"]!=measured["mesh_builds"] or m["pumps"]!=144 or m["peak_pump_count"]>1 or m["over_count_pumps"]!=0 or m["gpu_time_ms"]!=null:
                _fail("trace conservation",null,b)
                return
            print("PUBLICATION_CASE ",JSON.stringify(measured))
        b.close()
    print("PASS: publication source bytes and resource counts, LOD replacement/eviction, invalid geometry last-good, synthetic overshoot, 6 observed streaming traces")
    quit(0)

func _settle(p) -> bool:
    for step in range(4000):
        p._last_sync_msec=Time.get_ticks_msec()
        var status: Dictionary=p.pump_stream()
        if status["error"]!=OK:
            return false
        if p._pending_tiles.is_empty() and p._geometry_jobs.is_empty():
            return true
        OS.delay_msec(1)
    return false

func _verify(p) -> bool:
    var s: Dictionary=p.stats()["publication"]
    var total: int=0
    var triangles: int=0
    var shapes: int=0
    var vertices: int=0
    for key in p._tiles:
        var tile: Dictionary=p._tiles[key]
        var mesh: Mesh=tile["visual"].mesh
        var shape: Shape3D=tile["collision"].shape
        var arrays: Array=mesh.surface_get_arrays(0)
        var n: int=arrays[Mesh.ARRAY_VERTEX].size()
        var tri: int=arrays[Mesh.ARRAY_INDEX].size()/3
        var bytes: int=n*80+tri*12
        if shape is HeightMapShape3D:
            shapes+=1
            bytes+=shape.map_data.size()*4
        vertices+=n
        triangles+=tri
        total+=bytes
    return s["resident"]["total_bytes"]==total and s["resident"]["triangles"]==triangles and s["resident"]["vertices"]==vertices and s["resident"]["meshes"]==p._tiles.size() and s["resident"]["shapes"]==shapes and s["publication_count"]==p.stats()["mesh_builds"] and s["mesh_main_ms"]["count"]==s["publication_count"]

func _fail(msg: String,p,b) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("Publication accounting: "+msg)
    quit(1)
