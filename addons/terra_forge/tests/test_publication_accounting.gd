extends SceneTree
const A=preload("res://addons/terra_forge/core/publication_accounting.gd")
const MICRO=preload("res://addons/terra_forge/core/publication_micro_profile.gd")
const PUMP=preload("res://addons/terra_forge/core/pump_micro_profile.gd")
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
    var micro=MICRO.new()
    for i in range(20):
        micro.record({"key":[i,0],"lod":0,"new_tile":true,"frame":i,"physics_tick":i,"stages_us":{"root_attach":i*1000,"mesh_assign":100}},i*1000+200,OK,116052)
    micro.record({"key":[0,0],"lod":0,"new_tile":true,"frame":0,"physics_tick":0,"stages_us":{"validate":50}},100,ERR_INVALID_DATA,0)
    var mr: Dictionary=micro.report()
    if mr["success"]!=20 or mr["failed"]!=1 or mr["invalid_samples"]!=0 or mr["slow_events"].size()!=8 or mr["slow_events"][0]["total_us"]!=19200 or mr["slow_events"][7]["total_us"]!=12200 or mr["residual_ms"]["max_ms"]!=0.1:
        _fail("micro synthetic bounded events",null,null)
        return
    var pm=PUMP.new()
    var synthetic:Dictionary={"frame":1,"physics_tick":1,"builds_before":0,"pending_before":2,"jobs_before":0,"stages_us":{"io_accept":200,"sync_and_eviction":9000,"pending_build_submit":100},"stops":["build_outer_time"]}
    for i in range(12):
        pm.record(synthetic,10000+i,OK,1,9200)
    var pr:Dictionary=pm.report()
    if pr["invalid_samples"]!=0 or pr["total_ms"]["count"]!=12 or pr["slow_events"].size()!=8 or pr["slow_events"][0]["total_us"]!=10011 or pr["outer_stops"]["build_outer_time"]!=12 or pr["pre_budget_ms"]["mean_ms"]<9.19:
        _fail("pump synthetic attribution",null,null)
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
            p.observe_publication_micro=true
            p.observe_pump_micro=true
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
            var live_micro: Dictionary=p.publication_micro_profile()
            if live_micro["success"]!=5 or live_micro["failed"]!=1 or live_micro["invalid_samples"]!=0 or live_micro["total_ms"]["count"]!=6 or live_micro["stage_ms"]["root_attach"]["count"]!=4 or live_micro["stage_ms"]["mesh_assign"]["count"]!=5 or live_micro["stage_ms"]["validate"]["count"]!=6:
                _fail("micro live stage conservation "+str(live_micro),p,b)
                return
            print("PUBLICATION_MICRO_CASE ",JSON.stringify({"format":format+1,"mode":mode,"micro":live_micro}))
            var pump_report:Dictionary=p.pump_micro_profile()
            var pump_count:int=int(pump_report["total_ms"]["count"])
            if pump_count<=0 or pump_count!=s["pumps"] or pump_report["invalid_samples"]!=0 or pump_report["errors"]!=0 or pump_report["stage_ms"]["io_accept"]["count"]!=pump_count or pump_report["stage_ms"]["pending_build_submit"]["count"]!=pump_count or pump_report["pre_budget_ms"]["count"]!=pump_count:
                _fail("pump stage conservation "+str(pump_report),p,b)
                return
            print("PUMP_MICRO_CASE ",JSON.stringify({"format":format+1,"mode":mode,"pump":pump_report}))
            p.set_stream_center(Vector3(16,20,16))
            p._sync_tiles()
            if p.stats()["publication"]["resident"]["meshes"]!=0:
                _fail("eviction accounting",p,b)
                return
            p.stop_preview()
            if not p.stats()["publication"].is_empty():
                _fail("close reset",p,b)
                return
            if not p.publication_micro_profile().is_empty():
                _fail("micro stop reset",p,b)
                return
            if not p.pump_micro_profile().is_empty():
                _fail("pump stop reset",p,b)
                return
            p.observe_pump_micro=false
            p.observe_publication_micro=false
            p.observe_publication=false
            if p.start_preview(folder,16,4)!=OK or not p.stats()["publication"].is_empty() or not p.publication_micro_profile().is_empty() or not p.pump_micro_profile().is_empty():
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
        if not _calibrate_micro(folder,format):
            _fail("fixed-work micro calibration",null,b)
            return
        b.close()
    print("PASS: publication source bytes and resource counts, LOD replacement/eviction, invalid geometry last-good, synthetic overshoot, 6 observed streaming traces")
    quit(0)

## Isolate observation costs without conflating worker IO or different
## amounts of completed geometry. Keep ordinary accounting on in all arms.
## This is a Linux/off-tree wall-time diagnostic, not a device threshold.
func _calibrate_micro(folder: String,format: int) -> bool:
    var reference: Dictionary={}
    var orders: Array=[[0,1,3,2],[2,3,1,0],[3,0,2,1]]
    for block in range(orders.size()):
        for flags in orders[block]:
            var measured: Dictionary=_calibration_trial(folder,format,int(flags))
            if measured.get("error",FAILED)!=OK:
                return false
            var signature: Dictionary=measured["signature"]
            if reference.is_empty():
                reference=signature
            elif reference!=signature:
                return false
            measured.erase("signature")
            measured["format"]=format+1
            measured["block"]=block
            measured["flags"]=flags
            print("MICRO_OVERHEAD_FIXED ",JSON.stringify(measured))
    return true

func _calibration_trial(folder: String,format: int,flags: int) -> Dictionary:
    var p=P.new()
    p.region_index_format=format
    p.sampling_strategy=0
    p.observe_publication=true
    p.observe_publication_micro=(flags&1)!=0
    p.observe_pump_micro=(flags&2)!=0
    p.max_visible_tiles=1
    p.tile_updates_per_frame=1
    p.max_tile_work_ms=8.0
    if p.start_preview(folder,16,4)!=OK:
        return _calibration_close(p,{"error":FAILED})
    var key:=Vector2i(15,15)
    p._desired_tiles={key:0}
    p._pending_tiles={key:true}
    if not _settle(p):
        return _calibration_close(p,{"error":FAILED})
    var generated: Dictionary=G.generate(p._reader,key.x,key.y,0,p._desired_tiles)
    if generated.get("error",FAILED)!=OK:
        return _calibration_close(p,{"error":FAILED})
    var first: Dictionary=p.stats()["publication"]
    var pub_before: int=0
    var pump_before: int=0
    if flags&1:
        pub_before=int(p.publication_micro_profile()["success"])
    if flags&2:
        pump_before=int(p.pump_micro_profile()["total_ms"]["count"])
    var pub_us: Array[int]=[]
    var idle_us: Array[int]=[]
    # Same precomputed owned arrays in every arm; no asynchronous work
    # inside these timed calls. Include the profiler's final record cost.
    for i in range(32):
        p._publication.begin_pump(1)
        var started: int=Time.get_ticks_usec()
        var status: Error=p._publish_geometry(key,0,generated,started)
        pub_us.append(Time.get_ticks_usec()-started)
        p._publication.end_pump(p._publication_resident())
        if status!=OK:
            return _calibration_close(p,{"error":FAILED})
    for i in range(64):
        p._last_sync_msec=Time.get_ticks_msec()
        var started: int=Time.get_ticks_usec()
        var result: Dictionary=p.pump_stream()
        idle_us.append(Time.get_ticks_usec()-started)
        if result.get("error",FAILED)!=OK or not p._pending_tiles.is_empty():
            return _calibration_close(p,{"error":FAILED})
    var last: Dictionary=p.stats()["publication"]
    if int(last["publication_count"])-int(first["publication_count"])!=32 or int(last["pumps"])-int(first["pumps"])!=96 or last["resident"]!=first["resident"]:
        return _calibration_close(p,{"error":FAILED})
    if flags&1:
        var pub: Dictionary=p.publication_micro_profile()
        if int(pub["success"])-pub_before!=32 or pub["invalid_samples"]!=0:
            return _calibration_close(p,{"error":FAILED})
    elif not p.publication_micro_profile().is_empty():
        return _calibration_close(p,{"error":FAILED})
    if flags&2:
        var pump: Dictionary=p.pump_micro_profile()
        if int(pump["total_ms"]["count"])-pump_before!=64 or pump["invalid_samples"]!=0:
            return _calibration_close(p,{"error":FAILED})
    elif not p.pump_micro_profile().is_empty():
        return _calibration_close(p,{"error":FAILED})
    var tile: Dictionary=p._tiles[key]
    var mesh: Mesh=tile["visual"].mesh
    var shape: HeightMapShape3D=tile["collision"].shape
    if shape==null:
        return _calibration_close(p,{"error":FAILED})
    var signature: Dictionary={"arrays":mesh.surface_get_arrays(0),"heights":shape.map_data,"width":shape.map_width,"depth":shape.map_depth}
    return _calibration_close(p,{"error":OK,"publications":32,"idle_pumps":64,"publication_us":pub_us,"idle_pump_us":idle_us,"signature":signature,"note":"Off-tree fixed work; no GPU, Android or worker overhead inference."})

func _calibration_close(p,result: Dictionary) -> Dictionary:
    p.stop_preview()
    p.free()
    return result

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
