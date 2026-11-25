@tool
extends RefCounted
## Equal completed-work comparison: 4 fixed mixed-LOD tiles, 8 rebuilds.
## Preload all 16 halo pages; no streaming sync or IO during timed batches.
## Real resource creation, but off-tree and no rendered frames.
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const H=preload("res://addons/terra_forge/core/profile_histogram.gd")
const BATCHES: int=8
const DESIRED: Dictionary={Vector2i(15,15):0,Vector2i(16,15):1,Vector2i(15,16):2,Vector2i(16,16):0}

static func _close(p,result: Dictionary) -> Dictionary:
    p.stop_preview()
    p.free()
    return result

static func _load(p,keys: Array[Vector2i]) -> bool:
    for attempt in range(4000):
        p._reader.poll_results(4)
        p._reader.prioritize_resident(keys)
        var ready: bool=true
        for key in keys:
            var status: Error=p._reader.page_status(key)
            if status==ERR_BUSY:
                ready=false
                p._reader.request_page(key)
            elif status!=OK:
                return false
        if ready:
            return true
        OS.delay_msec(1)
    return false

static func _fingerprints(p) -> Dictionary:
    var result: Dictionary={}
    for key in DESIRED:
        if not p._tiles.has(key):
            return {}
        var tile: Dictionary=p._tiles[key]
        var mesh: Mesh=tile["visual"].mesh
        var shape: Shape3D=tile["collision"].shape
        if mesh==null or tile["lod"]!=DESIRED[key]:
            return {}
        if (DESIRED[key]==0)!=(shape is HeightMapShape3D):
            return {}
        var arrays: Array=mesh.surface_get_arrays(0)
        var bytes: PackedByteArray=var_to_bytes([arrays,shape.map_data if shape is HeightMapShape3D else PackedFloat32Array()])
        var hash=HashingContext.new()
        hash.start(HashingContext.HASH_SHA256)
        hash.update(bytes)
        result[str(key)]=hash.finish().hex_encode()
    return result

static func run(directory: String,format: int,mode: int,cap: int,publication_options: Dictionary={},scalar_crop: bool=false,camera_crop: bool=false,hybrid_policy: Dictionary={}) -> Dictionary:
    if mode not in [2,3,4,5,6,7] or cap not in [1,2,4] or format not in [0,1] or (scalar_crop and mode not in [5,6]) or (camera_crop and mode not in [3,4]):
        return {"error":ERR_INVALID_PARAMETER}
    var p=P.new()
    p.region_index_format=format
    p.sampling_strategy=mode
    p.hybrid_scalar_sampling=bool(hybrid_policy.get("scalar",false))
    p.hybrid_topology_cache=bool(hybrid_policy.get("topology",false))
    p.hybrid_cropped_halo=bool(hybrid_policy.get("crop",false))
    p.hybrid_cooperative_cancel=bool(hybrid_policy.get("cancel",false))
    p.enable_scalar_worker_cropped_halo=scalar_crop
    p.enable_camera_worker_cropped_halo=camera_crop
    p.geometry_job_limit=cap
    p.tile_updates_per_frame=int(publication_options.get("updates",2))
    p.observe_publication=not publication_options.is_empty()
    p.enforce_publication_budget=bool(publication_options.get("enabled",false))
    p.publication_byte_target=int(publication_options.get("bytes",131072))
    p.publication_time_target_us=int(publication_options.get("time_us",1000))
    if p.tile_updates_per_frame not in [1,2,3]:
        return _close(p,{"error":ERR_INVALID_PARAMETER,"stage":"updates"})
    p.max_tile_work_ms=8.0
    if p.start_preview(directory,16,4)!=OK:
        return _close(p,{"error":FAILED,"stage":"open"})
    p._desired_tiles=DESIRED.duplicate()
    p._pending_tiles.clear()
    var pages: Array[Vector2i]=[]
    for key in DESIRED:
        for page in G.required_pages(p._reader,key.x,key.y,DESIRED[key]):
            if not pages.has(page):
                pages.append(page)
    if pages.size()!=16 or not _load(p,pages):
        return _close(p,{"error":FAILED,"stage":"warm pages","pages":pages.size()})
    var main=H.new()
    var batch_wall=H.new()
    var total_main_us: int=0
    var total_wall_us: int=0
    var pump_count: int=0
    var reference: Dictionary={}
    var before: Dictionary=p._reader.stats()
    for batch in range(BATCHES+1):
        p._pending_tiles.clear()
        for key in DESIRED:
            p._pending_tiles[key]=true
        var begin: int=Time.get_ticks_usec()
        var batch_main: int=0
        for step in range(3000):
            var started: int=Time.get_ticks_usec()
            if not publication_options.is_empty():
                # Run real admission and accounting boundary, without camera sync.
                p._last_sync_msec=Time.get_ticks_msec()
                var progress: Dictionary=p.pump_stream()
                if progress["error"]!=OK:
                    return _close(p,{"error":progress["error"],"stage":"publication pump"})
            else:
                if mode>=4:
                    if p._geometry_worker.reconcile(p._reader,p._desired_tiles,p._priority_ranks())!=OK:
                        return _close(p,{"error":ERR_BUG,"stage":"reconcile"})
                if mode>=3:
                    p._publish_worker_results(started)
                p._build_pending_tiles(started)
            var elapsed: int=Time.get_ticks_usec()-started
            batch_main+=elapsed
            if batch>0:
                main.add(float(elapsed)/1000.0)
                pump_count+=1
            var s: Dictionary=p.stats()
            if s["last_error"]!=OK or s["geometry_reservations"]>cap or s["source"]["tile_view_active_pages"]!=0:
                return _close(p,{"error":ERR_BUG,"stage":"work bounds"})
            if mode>=3 and (s["geometry_worker"]["slots"]>cap or s["geometry_worker"]["submitted"]>4*(batch+1)):
                return _close(p,{"error":ERR_BUG,"stage":"duplicate job or capacity"})
            if p._pending_tiles.is_empty():
                break
            OS.delay_msec(1)
        if not p._pending_tiles.is_empty() or not p._geometry_jobs.is_empty() or p.stats()["mesh_builds"]!=4*(batch+1):
            return _close(p,{"error":ERR_BUG,"stage":"equal completion"})
        var wall: int=Time.get_ticks_usec()-begin
        if batch>0:
            total_wall_us+=wall
            total_main_us+=batch_main
            batch_wall.add(float(wall)/1000.0)
        var hashes: Dictionary=_fingerprints(p)
        if hashes.size()!=4 or (batch>0 and hashes!=reference):
            return _close(p,{"error":ERR_INVALID_DATA,"stage":"resource parity"})
        reference=hashes
    var s: Dictionary=p.stats()
    if bool(s["scalar_worker_cropped_halo_active"])!=scalar_crop or int(s["scalar_worker_cropped_submissions"])!=((BATCHES+1)*4 if scalar_crop else 0):
        return _close(p,{"error":ERR_BUG,"stage":"scalar crop evidence"})
    if bool(s["camera_worker_cropped_halo_active"])!=camera_crop or int(s["camera_worker_cropped_submissions"])!=((BATCHES+1)*4 if camera_crop else 0):
        return _close(p,{"error":ERR_BUG,"stage":"camera crop evidence"})
    var after: Dictionary=p._reader.stats()
    if before["disk_reads"]!=after["disk_reads"] or before["evictions"]!=after["evictions"] or before["submitted"]!=after["submitted"]:
        return _close(p,{"error":ERR_BUG,"stage":"unexpected IO"})
    var result: Dictionary={"error":OK,"format":format+1,"mode":mode,"cap":cap if mode>=3 else 0,"completed":BATCHES*4,"warmup_builds":4,"pages":pages.size(),"main_total_us":total_main_us,"wall_total_us":total_wall_us,"main_us_per_tile":float(total_main_us)/(BATCHES*4),"wall_us_per_tile":float(total_wall_us)/(BATCHES*4),"pumps":pump_count,"main_ms":main.report(),"batch_wall_ms":batch_wall.report(),"fingerprints":reference,"worker":s["geometry_worker"],"copy_ms_including_warmup":s["geometry_copy_ms"],"queue_ms_including_warmup":s["geometry_queue_ms"],"build_ms_including_warmup":s["geometry_worker_ms"],"delivery_ms_including_warmup":s["geometry_delivery_ms"],"publish_ms_including_warmup":s["geometry_publish_ms"]}
    result["hybrid_policy"]=hybrid_policy.duplicate()
    result["hybrid_cropped_submissions"]=s["hybrid_cropped_submissions"]
    result["effective_sampling_strategy"]=s["effective_sampling_strategy"]
    result["camera_crop"]=camera_crop
    result["camera_cropped_submissions"]=s["camera_worker_cropped_submissions"]
    result["scalar_crop"]=scalar_crop
    result["scalar_cropped_submissions"]=s["scalar_worker_cropped_submissions"]
    result["publication"]=s.get("publication",{})
    result["publication_options"]=publication_options.duplicate()
    # Teardown with outstanding work: submit then close immediately.
    if mode>=3:
        var accepted: Dictionary=p._geometry_worker.submit(p._reader,Vector2i(15,15),0,DESIRED)
        if accepted["error"]!=OK:
            return _close(p,{"error":ERR_BUG,"stage":"close setup"})
    p.stop_preview()
    if p._geometry_worker!=null or p._reader!=null or not p._geometry_jobs.is_empty() or not p._tiles.is_empty():
        return _close(p,{"error":ERR_BUG,"stage":"close"})
    p.free()
    return result
