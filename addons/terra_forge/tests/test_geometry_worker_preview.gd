extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const PREVIEW=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const W=preload("res://addons/terra_forge/core/geometry_worker.gd")

func _initialize() -> void:
    for format in [0,1]:
        var b: Variant=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start",null,b)
            return
        var made: Dictionary={}
        var deadline: int=Time.get_ticks_msec()+30000
        while Time.get_ticks_msec()<deadline:
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture",null,b)
            return
        var folder: String=made["directory"]
        var p=PREVIEW.new()
        p.region_index_format=format
        p.sampling_strategy=3
        p.geometry_job_limit=2
        p.max_visible_tiles=6
        p.view_distance=96.0
        p.high_detail_distance=40.0
        p.medium_detail_distance=80.0
        p.max_tile_work_ms=8.0
        p.tile_updates_per_frame=1
        if p.start_preview(folder,16,4)!=OK:
            _fail("open",p,b)
            return
        var key=Vector2i(15,15)
        p.set_stream_center(Vector3(496,20,496))
        if not _settle(p,key):
            _fail("initial settle",p,b)
            return
        if not _parity(p,key):
            _fail("initial mesh/shape parity",p,b)
            return
        # Force same-epoch signature change after enqueue, before publish.
        var desired: Dictionary=p._desired_tiles.duplicate()
        var neighbor=key+Vector2i.RIGHT
        if not desired.has(neighbor):
            _fail("neighbor fixture",p,b)
            return
        p._pending_tiles[key]=true
        if not _load(p,G.required_pages(p._reader,key.x,key.y,int(desired[key]))):
            _fail("load rebuild",p,b)
            return
        # Drain old reservations first, then enqueue one explicit request.
        p._pending_tiles={key:true}
        for step in range(2400):
            p._publish_worker_results(Time.get_ticks_usec())
            if p._geometry_worker.stats()["slots"]==0:
                break
            OS.delay_msec(1)
        p._pending_tiles[key]=true
        var old_mesh: Mesh=p._tiles[key]["visual"].mesh
        var request: Dictionary=p._geometry_worker.submit(p._reader,key,int(desired[key]),desired)
        if request["error"]!=OK:
            _fail("enqueue stale",p,b)
            return
        p._geometry_jobs[key]=request["id"]
        p._desired_tiles[neighbor]=(int(desired[neighbor])+1)%3
        var stale_before: int=p._geometry_worker.stats()["dropped"]
        for step in range(2400):
            p._publish_worker_results(Time.get_ticks_usec())
            if p._geometry_worker.stats()["slots"]==0:
                break
            OS.delay_msec(1)
        if p._tiles[key]["visual"].mesh!=old_mesh or p._geometry_worker.stats()["dropped"]<=stale_before or p._geometry_jobs.has(key) or not p._pending_tiles.has(key):
            _fail("same epoch stale publish",p,b)
            return
        p._desired_tiles=desired
        p._pending_tiles[key]=true
        if not _settle(p,key) or not _parity(p,key):
            _fail("rebuild recovery",p,b)
            return
        # Start another request, then move far before publication.
        if not _load(p,G.required_pages(p._reader,key.x,key.y,int(p._desired_tiles[key]))):
            _fail("jump load",p,b)
            return
        p._pending_tiles[key]=true
        request=p._geometry_worker.submit(p._reader,key,int(p._desired_tiles[key]),p._desired_tiles)
        if request["error"]!=OK:
            _fail("jump submit",p,b)
            return
        p._geometry_jobs[key]=request["id"]
        p.set_stream_center(Vector3(16,20,16))
        if not _settle(p,Vector2i.ZERO) or p._tiles.has(key) or not _parity(p,Vector2i.ZERO):
            _fail("jump recovery",p,b)
            return
        var origin=Vector2i.ZERO
        old_mesh=p._tiles[origin]["visual"].mesh
        var old_shape: Shape3D=p._tiles[origin]["collision"].shape
        # Cold missing page OR shard, only disposable fixture damaged.
        var path: String=folder.path_join("r_00000_00000.tfr" if format==0 else "s_00000_00000.tfs")
        var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
        # TFM2 shard cache must be cold: cap1 and remote shard load before
        # returning to origin, or use a cold page failure here. Dedicated
        # shard failure test below uses a fresh preview.
        if format==1:
            path=folder.path_join("r_00000_00000.tfr")
            bytes=FileAccess.get_file_as_bytes(path)
        if p._reader.release_outside(Vector2i(18,18),Vector2i(18,18))!=OK or DirAccess.remove_absolute(path)!=OK:
            _fail("cold missing setup",p,b)
            return
        p._pending_tiles[origin]=true
        for step in range(2400):
            p.pump_stream()
            if p._blocked_tiles.has(origin):
                break
            OS.delay_msec(1)
        if not p._blocked_tiles.has(origin) or p._tiles[origin]["visual"].mesh!=old_mesh or p._tiles[origin]["collision"].shape!=old_shape:
            _fail("last good retention",p,b)
            return
        p.set_stream_center(Vector3(528,20,528))
        if not _settle(p,Vector2i(16,16)):
            _fail("healthy remote recovery",p,b)
            return
        var s: Dictionary=p.stats()
        print("WORKER_PREVIEW ",JSON.stringify({"format":format,"worker":s["geometry_worker"],"builds":s["mesh_builds"],"copy":s["geometry_copy_ms"],"queue":s["geometry_queue_ms"],"build":s["geometry_worker_ms"],"delivery":s["geometry_delivery_ms"],"publish":s["geometry_publish_ms"],"publish_peak":s["geometry_publish_peak_per_pump"]}))
        p.stop_preview()
        if p._geometry_worker!=null or not p._geometry_jobs.is_empty() or p._reader!=null or not p._tiles.is_empty():
            _fail("close",p,b)
            return
        p.free()
        if format==1:
            # New reader, cold shard missing. Origin absent, remote healthy.
            var shard: String=folder.path_join("s_00000_00000.tfs")
            if DirAccess.remove_absolute(shard)!=OK:
                _fail("shard setup",null,b)
                return
            p=PREVIEW.new()
            p.region_index_format=1
            p.sampling_strategy=3
            p.max_visible_tiles=1
            p.high_detail_distance=180.0
            if p.start_preview(folder,9,4)!=OK:
                _fail("lazy shard open",p,b)
                return
            p.set_stream_center(Vector3(16,20,16))
            for step in range(2400):
                p.pump_stream()
                if p._blocked_tiles.has(Vector2i.ZERO):
                    break
                OS.delay_msec(1)
            if not p._blocked_tiles.has(Vector2i.ZERO) or p._tiles.has(Vector2i.ZERO):
                _fail("cold shard fail closed",p,b)
                return
            p.set_stream_center(Vector3(560,20,560))
            if not _settle(p,Vector2i(17,17)):
                _fail("shard independent recovery",p,b)
                return
            p.stop_preview()
            p.free()
        b.close()
    print("PASS: opt-in geometry worker live ArrayMesh/shape, bounded reservations and publication, stale signature/epoch rejection, missing page last-good, cold shard fail closed")
    quit(0)

func _settle(p,key: Vector2i) -> bool:
    for step in range(3000):
        p.pump_stream()
        var s: Dictionary=p.stats()
        var w: Dictionary=s["geometry_worker"]
        if w["slots"]>2 or s["geometry_reservations"]>2 or s["geometry_publish_peak_per_pump"]>1 or s["source"]["resident"]>16 or s["source"]["tile_view_active_pages"]!=0:
            return false
        if p._tiles.has(key) and not p._pending_tiles.has(key) and p._tiles[key]["collision"].shape is HeightMapShape3D and p._geometry_jobs.is_empty() and w["slots"]==0 and (p._pending_tiles.is_empty() or p._pending_tiles.size()==p._blocked_tiles.size()):
            return true
        OS.delay_msec(1)
    return false

func _parity(p,key: Vector2i) -> bool:
    var lod: int=p._tiles[key]["lod"]
    if not _load(p,G.required_pages(p._reader,key.x,key.y,lod)):
        return false
    var expected: Dictionary=G.generate(p._reader,key.x,key.y,lod,p._desired_tiles)
    if expected["error"]!=OK:
        return false
    var actual: Array=p._tiles[key]["visual"].mesh.surface_get_arrays(0)
    # ArrayMesh normal compression may differ; exact canonical vertices and
    # indices plus collision, normal direction checked within engine tolerance.
    if actual[Mesh.ARRAY_VERTEX]!=expected["arrays"][Mesh.ARRAY_VERTEX] or actual[Mesh.ARRAY_INDEX]!=expected["arrays"][Mesh.ARRAY_INDEX]:
        return false
    for i in range(actual[Mesh.ARRAY_NORMAL].size()):
        if actual[Mesh.ARRAY_NORMAL][i].dot(expected["arrays"][Mesh.ARRAY_NORMAL][i])<0.999:
            return false
    return p._tiles[key]["collision"].shape.map_data==expected["collision_heights"]

func _load(p,keys: Array[Vector2i]) -> bool:
    for step in range(4000):
        p._reader.poll_results(4)
        p._reader.prioritize_resident(keys)
        var ready: bool=true
        for k in keys:
            var state: Error=p._reader.page_status(k)
            if state==ERR_BUSY:
                ready=false
                p._reader.request_page(k)
            elif state!=OK:
                return false
        if ready:
            return true
        OS.delay_msec(1)
    return false

func _fail(msg: String,p,b) -> void:
    if p!=null:
        print("FAIL_STATS ",p.stats())
        p.stop_preview()
        p.free()
    b.close()
    push_error("Worker preview: "+msg)
    quit(1)
