@tool
extends Node3D
## Opt-in P1.3 test-only terrain renderer backed by asynchronous TFR1 pages.
## NOT a replacement for TerraForgeTerrain: no editing, save, layer, or brush.
## Never constructs a full-world heights PackedFloat32Array.
const ASYNC = preload("res://addons/terra_forge/core/async_region_source.gd")
const LOD = preload("res://addons/terra_forge/core/lod_policy.gd")
const GEOMETRY = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const WORKER = preload("res://addons/terra_forge/core/geometry_worker.gd")
const HIST = preload("res://addons/terra_forge/core/profile_histogram.gd")
const PUBLICATION = preload("res://addons/terra_forge/core/publication_accounting.gd")
const FOOTPRINT = preload("res://addons/terra_forge/core/collision_footprint.gd")
const SUPPORT = preload("res://addons/terra_forge/core/support_tile_selection.gd")
const TILE_CELLS: int = 32

@export var preview_enabled: bool = false
@export_dir var region_directory: String = ""
## Explicit choice; never guess a format or fall back on errors.
@export_enum("TFM1", "TFM2") var region_index_format: int = 0
@export_range(1, 16, 1) var resident_shard_limit: int = 4
## Faster startup for this read-only opt-in preview: checks the TFM1
## manifest or TFM2 root first; each cold shard/page is verified on worker.
## Bad/missing pages stay ERR_FILE_CORRUPT/ERR_FILE_NOT_FOUND, never flat.
## Disable for the previous whole-world, strictly checked open behavior.
@export var verify_pages_on_demand: bool = true
## Experimental A/B CPU sampling path. Default stays baseline until measured.
@export var use_tile_read_view: bool = false
## -1 preserves serialized legacy bool. Explicit mode overrides it.
@export_enum("Legacy flag:-1", "A direct:0", "B tile view:1", "C dense buffer:2", "E geometry worker:3", "F priority worker:4", "G scalar priority worker:5", "H cached topology worker:6") var sampling_strategy: int = -1
var _active_sampling_strategy: int = 0
var _dense_payload_peak: int = 0
@export_range(1,4,1) var geometry_job_limit: int = 2
var _geometry_worker
var _geometry_jobs: Dictionary = {}
var _copy_hist = HIST.new()
var _queue_hist = HIST.new()
var _worker_hist = HIST.new()
var _delivery_hist = HIST.new()
var _publish_hist = HIST.new()
var _publish_peak_per_pump: int = 0
## Optional observation only; pinned on open. Not a GPU budget.
@export var observe_publication: bool = false
@export var enforce_publication_budget: bool = false
@export_range(4096,1048576,4096) var publication_byte_target: int = 131072
@export_range(100,8000,100) var publication_time_target_us: int = 1000
var _publication_budget_active: bool=false
var _publication
@export_range(9, 64, 1) var resident_page_limit: int = 16
@export_range(1, 8, 1) var max_background_jobs: int = 4
@export_range(80.0, 640.0, 16.0) var view_distance: float = 160.0
## Experimental, session-pinned, single caller. Never enabled by default.
@export var enable_support_retention: bool = false
var _support_active: bool = false
var _support_keys: Array[Vector2i] = []
var _support_session: int = 0
var _support_revision: int = 0
var _support_cap_rejections: int = 0
var _support_shape_reuses: int = 0
var _support_shape_replacements: int = 0
var _support_selection_hist = HIST.new()
var _support_claim_hist = HIST.new()
@export_range(1, 128, 1) var max_visible_tiles: int = 32:
    set(value):
        # An impossible runtime reduction must not silently drop live support.
        if _support_active and (value < maxi(1,_support_keys.size()) or value > SUPPORT.MAX_TOTAL):
            _support_cap_rejections += 1
            return
        max_visible_tiles = value
        if _support_active:
            _last_sync_msec = -100000
@export_range(1, 3, 1) var tile_updates_per_frame: int = 1
@export_range(1.0, 8.0, 0.5) var max_tile_work_ms: float = 3.0
@export_range(32.0, 180.0, 8.0) var high_detail_distance: float = 72.0
@export_range(80.0, 320.0, 8.0) var medium_detail_distance: float = 128.0

var _reader
var _tiles: Dictionary = {}
var _desired_tiles: Dictionary = {}
var _pending_tiles: Dictionary = {}
# Terminal failures are isolated per desired tile and camera generation.
# Existing verified geometry stays at its original world coordinate.
var _blocked_tiles: Dictionary = {}
var _material: StandardMaterial3D
var _anchor: Vector3 = Vector3.ZERO
var _anchor_valid: bool = false
var _queue_focus_page: Vector2i = Vector2i(-999999, -999999)
var _camera_cancellations: int = 0
var _waiting_tile_frames: int = 0
var _last_sync_msec: int = -100000
var _last_error: Error = OK
var _last_error_page: Vector2i = Vector2i(-1, -1)
var _mesh_builds: int = 0
var _last_build_ms: float = 0.0
var _max_build_ms: float = 0.0

func _ready() -> void:
    if preview_enabled:
        var status: Error = start_preview(region_directory, resident_page_limit, max_background_jobs)
        if status != OK:
            push_warning("TerraForge P1.3 preview unavailable: " + error_string(status))
    else:
        set_process(false)

func _exit_tree() -> void:
    stop_preview()

func _ensure_material() -> void:
    if _material != null:
        return
    _material = StandardMaterial3D.new()
    _material.vertex_color_use_as_albedo = true
    _material.roughness = 0.95

func start_preview(directory: String, cache_pages: int = 16, max_jobs: int = 4) -> Error:
    stop_preview()
    # One tile + a one-stride normal halo may span up to nine pages.
    if cache_pages < 9 or cache_pages > 64:
        _last_error = ERR_INVALID_PARAMETER
        return _last_error
    if directory.is_empty():
        _last_error = ERR_INVALID_PARAMETER
        return _last_error
    var selected: int = resolved_sampling_strategy()
    if selected < 0 or selected > 6:
        _last_error = ERR_INVALID_PARAMETER
        return _last_error
    if enforce_publication_budget and (publication_byte_target<4096 or publication_byte_target>1048576 or publication_time_target_us<100 or publication_time_target_us>8000):
        _last_error=ERR_INVALID_PARAMETER
        return _last_error
    _active_sampling_strategy = selected
    _dense_payload_peak = 0
    _ensure_material()
    var next = ASYNC.new()
    var status: Error = ERR_INVALID_PARAMETER
    if region_index_format == 0:
        status = next.open(directory, cache_pages, max_jobs, not verify_pages_on_demand)
    elif region_index_format == 1:
        status = next.open_v2(directory, cache_pages, max_jobs, not verify_pages_on_demand, resident_shard_limit)
    if status != OK:
        next.close()
        _last_error = status
        return status
    _reader = next
    _support_active = enable_support_retention
    if _support_active and (max_visible_tiles < 1 or max_visible_tiles > SUPPORT.MAX_TOTAL):
        stop_preview()
        _last_error=ERR_INVALID_PARAMETER
        return _last_error
    if selected>=3:
        _geometry_worker=WORKER.new()
        status=_geometry_worker.start(_reader,geometry_job_limit,selected>=5,selected==6)
        if status!=OK:
            stop_preview()
            _last_error=status
            return status
    _copy_hist=HIST.new()
    _queue_hist=HIST.new()
    _worker_hist=HIST.new()
    _delivery_hist=HIST.new()
    _publish_hist=HIST.new()
    _publish_peak_per_pump=0
    _publication_budget_active=enforce_publication_budget
    _publication=PUBLICATION.new() if observe_publication or _publication_budget_active else null
    if _publication!=null:
        _publication.configure_budget(_publication_budget_active,publication_byte_target if _publication_budget_active else PUBLICATION.BYTE_TARGET,publication_time_target_us if _publication_budget_active else PUBLICATION.TIME_TARGET_US)
    region_directory = directory
    resident_page_limit = cache_pages
    max_background_jobs = max_jobs
    _last_error = OK
    _last_error_page = Vector2i(-1, -1)
    _queue_focus_page = Vector2i(-999999, -999999)
    _camera_cancellations = 0
    _waiting_tile_frames = 0
    _mesh_builds = 0
    _last_build_ms = 0.0
    _max_build_ms = 0.0
    _anchor = Vector3(
        float(_reader.cells.x) * _reader.spacing * 0.5,
        0.0, float(_reader.cells.y) * _reader.spacing * 0.5
    )
    _anchor_valid = true
    _last_sync_msec = -100000
    _sync_tiles()
    set_process(true)
    return OK

func resolved_sampling_strategy() -> int:
    return (1 if use_tile_read_view else 0) if sampling_strategy == -1 else sampling_strategy

func stop_preview() -> void:
    set_process(false)
    # Explicit shutdown revokes even a held support lease. Camera epochs do not.
    _support_active=false
    _support_keys.clear()
    _support_session+=1
    _support_revision=0
    _support_cap_rejections=0
    _support_shape_reuses=0
    _support_shape_replacements=0
    _support_selection_hist=HIST.new()
    _support_claim_hist=HIST.new()
    if _geometry_worker!=null:
        _geometry_worker.close()
        _geometry_worker=null
    _geometry_jobs.clear()
    _publication=null
    _publication_budget_active=false
    for item in _tiles.values():
        var root: Node3D = item["root"]
        if is_instance_valid(root):
            root.free()
    _tiles.clear()
    _desired_tiles.clear()
    _pending_tiles.clear()
    _blocked_tiles.clear()
    _anchor_valid = false
    _queue_focus_page = Vector2i(-999999, -999999)
    if _reader != null:
        _reader.close()  # explicit safe worker Thread join; not per-frame.
        _reader = null

func set_stream_center(global_position: Vector3) -> void:
    if _reader == null:
        return
    var local: Vector3 = (
        to_local(global_position) if is_inside_tree()
        else transform.affine_inverse() * global_position
    )
    if not _anchor_valid or _anchor.distance_squared_to(local) > 64.0:
        _anchor = local
        _anchor_valid = true
        _last_sync_msec = -100000

func _process(_delta: float) -> void:
    if _reader == null:
        return
    if not Engine.is_editor_hint():
        var cam: Camera3D = get_viewport().get_camera_3d()
        if cam != null:
            set_stream_center(cam.global_position)
    pump_stream()

## Public for reproducible headless tests, without relying on idle frames.
func pump_stream() -> Dictionary:
    if _reader == null or not _reader.is_open():
        return {"error": ERR_UNCONFIGURED}
    var completed: Dictionary = _reader.poll_results(max_background_jobs)
    if int(completed.get("error", ERR_FILE_CORRUPT)) != OK:
        return completed
    var current: int = Time.get_ticks_msec()
    if current - _last_sync_msec > 220:
        _sync_tiles()
        _last_sync_msec = current
    var started: int=Time.get_ticks_usec()
    if _publication!=null:
        _publication.begin_pump(tile_updates_per_frame)
    if _geometry_worker!=null:
        if _active_sampling_strategy>=4 or _publication_budget_active or _support_active:
            var reconciled: Error=_geometry_worker.reconcile(_reader,_desired_tiles,_priority_ranks())
            if reconciled!=OK:
                _last_error=reconciled
                if _publication!=null:
                    _publication.end_pump(_publication_resident())
                return {"error":reconciled}
        _publish_worker_results(started)
    _build_pending_tiles(started)
    if _publication!=null:
        _publication.end_pump(_publication_resident())
    return {
        "error": _last_error,
        "resident_tiles": _tiles.size(),
        "pending_tiles": _pending_tiles.size(),
        "resident_pages": int(_reader.stats()["resident"])
    }

func _sync_tiles() -> void:
    if _reader == null or not _anchor_valid:
        return
    # The original preview only changed which MESHES were desired. It
    # never cancelled disk work for an old camera location. Cancel when
    # the camera moved at least two regions from the last queue focus;
    # this avoids cancelling useful reads at every normal tile boundary.
    var tile_world: float = float(TILE_CELLS) * _reader.spacing
    var focus_page: Vector2i = Vector2i(
        floori(_anchor.x / tile_world), floori(_anchor.z / tile_world)
    )
    if _queue_focus_page.x == -999999:
        _queue_focus_page = focus_page
    elif maxi(
            absi(focus_page.x - _queue_focus_page.x),
            absi(focus_page.y - _queue_focus_page.y)
        ) >= 2:
        var current_generation: int = int(_reader.stats()["generation"])
        var cancel_error: Error = _reader.set_generation(current_generation + 1)
        if cancel_error != OK:
            _last_error = cancel_error
            return
        _queue_focus_page = focus_page
        _camera_cancellations += 1
        _blocked_tiles.clear()
        # Page errors from the old camera generation do not describe the
        # current area; if damage persists, the new IO reports it again.
        _last_error = OK
        _last_error_page = Vector2i(-1, -1)
    var found: Array[Dictionary] = LOD.tile_candidates(
        _reader.cells, TILE_CELLS, _reader.spacing,
        _anchor, view_distance, high_detail_distance,
        medium_detail_distance, max_visible_tiles
    )
    var new_desired: Dictionary = {}
    for entry in found:
        var key: Vector2i = entry["key"]
        var old_lod: int = int(_desired_tiles.get(key, -1))
        new_desired[key] = LOD.choose_stable_lod(
            float(entry["distance"]), high_detail_distance,
            medium_detail_distance, view_distance, old_lod, 8.0
        )
    if _support_active:
        var selection_started: int=Time.get_ticks_usec()
        var ranked: Array[Dictionary]=[]
        for entry in found:
            var key: Vector2i=entry["key"]
            ranked.append({"key":key,"lod":int(new_desired[key])})
        var grid=Vector2i(int(_reader.cells.x/TILE_CELLS),int(_reader.cells.y/TILE_CELLS))
        var chosen: Dictionary=SUPPORT.select(_support_keys,ranked,grid,max_visible_tiles)
        _support_selection_hist.add(float(Time.get_ticks_usec()-selection_started)/1000.0)
        if chosen["error"]!=OK:
            # Never partially apply an invalid support/cap selection.
            _last_error=int(chosen["error"])
            return
        new_desired=chosen["desired"]
    var previous: Dictionary = _desired_tiles
    _desired_tiles = new_desired
    for key in new_desired:
        var level: int = int(new_desired[key])
        if not _tiles.has(key) or int(_tiles[key]["lod"]) != level:
            _pending_tiles[key] = true
        if int(previous.get(key, -1)) != level:
            _blocked_tiles.erase(key)
            for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                var adjacent: Vector2i = key + direction
                if _tiles.has(adjacent) and new_desired.has(adjacent):
                    _pending_tiles[adjacent] = true
                    _blocked_tiles.erase(adjacent)
    # In support mode detect removed neighbors in synchronous paths too:
    # changing desired neighbor LOD can change seam heights.
    if _geometry_worker!=null or _support_active:
        for key in new_desired:
            var lod: int=int(new_desired[key])
            var before: Dictionary=WORKER.signature(key,lod,previous,_reader.cells)
            var after: Dictionary=WORKER.signature(key,lod,new_desired,_reader.cells)
            if before.get("levels",[])!=after.get("levels",[]):
                _blocked_tiles.erase(key)
            if _tiles.has(key) and _tiles[key].get("levels",[])!=after.get("levels",[]):
                _pending_tiles[key]=true
    for key in _tiles.keys():
        if not new_desired.has(key):
            var root: Node3D = _tiles[key]["root"]
            if is_instance_valid(root):
                root.free()
            _tiles.erase(key)
    for key in _pending_tiles.keys():
        if not new_desired.has(key):
            _pending_tiles.erase(key)
            _blocked_tiles.erase(key)

func _create_tile(tx: int, tz: int) -> Dictionary:
    var root: Node3D = Node3D.new()
    root.name = "TF_Paged_%d_%d" % [tx, tz]
    root.position = Vector3(
        float(tx * TILE_CELLS) * _reader.spacing,
        0.0, float(tz * TILE_CELLS) * _reader.spacing
    )
    add_child(root, false, Node.INTERNAL_MODE_FRONT)
    var visual: MeshInstance3D = MeshInstance3D.new()
    visual.name = "Visual"
    visual.material_override = _material
    root.add_child(visual)
    var physics: StaticBody3D = StaticBody3D.new()
    physics.name = "Physics"
    root.add_child(physics)
    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.name = "HeightCollision"
    collision.position = Vector3(
        float(TILE_CELLS) * _reader.spacing * 0.5, 0.0,
        float(TILE_CELLS) * _reader.spacing * 0.5
    )
    collision.scale = Vector3.ONE * _reader.spacing
    physics.add_child(collision)
    return {
        "root": root, "visual": visual, "collision": collision,
        "lod": -1, "vertex_count": 0
    }

## Experimental F: actual anchor tile first, then desired LOD0 tiles
## without attached collision, then ordinary distance order.
func _priority_ranks() -> Dictionary:
    var width: float=float(TILE_CELLS)*_reader.spacing
    var focus: Vector2i=Vector2i(floori(_anchor.x/width),floori(_anchor.z/width))
    var keys: Array=_desired_tiles.keys()
    var classes: Dictionary={}
    for key in keys:
        var has_shape: bool=_tiles.has(key) and _tiles[key]["collision"].shape is HeightMapShape3D
        classes[key]=0 if key==focus and int(_desired_tiles[key])==0 and not has_shape else (1 if int(_desired_tiles[key])==0 and not has_shape else 2)
        if _support_active and _support_keys.has(key):
            classes[key]=-1
    keys.sort_custom(func(a: Variant,b: Variant)->bool:
        if classes[a]!=classes[b]:
            return int(classes[a])<int(classes[b])
        var da: float=LOD.tile_distance(a,width,_anchor)
        var db: float=LOD.tile_distance(b,width,_anchor)
        if da==db:
            return a.y<b.y if a.y!=b.y else a.x<b.x
        return da<db
    )
    var result: Dictionary={}
    for i in range(keys.size()):
        result[keys[i]]=i
    return result

func _build_pending_tiles(started: int = -1) -> void:
    if _pending_tiles.is_empty():
        return
    var keys: Array = _pending_tiles.keys().filter(func(key: Variant) -> bool:
        return not _blocked_tiles.has(key) and not _geometry_jobs.has(key)
    )
    if _active_sampling_strategy>=4 or _publication_budget_active or _support_active:
        var ranks: Dictionary=_priority_ranks()
        keys.sort_custom(func(a: Variant,b: Variant)->bool: return int(ranks[a])<int(ranks[b]))
    else:
        keys.sort_custom(func(a: Variant, b: Variant) -> bool:
            return LOD.tile_distance(a, float(TILE_CELLS) * _reader.spacing, _anchor) < LOD.tile_distance(b, float(TILE_CELLS) * _reader.spacing, _anchor)
        )
    var max_builds: int = maxi(1, tile_updates_per_frame)
    var submitted: int = 0
    if started<0:
        started=Time.get_ticks_usec()
    for key in keys:
        if max_builds <= 0 or float(Time.get_ticks_usec() - started) >= max_tile_work_ms * 1000.0:
            break
        if _geometry_worker!=null:
            var worker_stats: Dictionary=_geometry_worker.stats()
            if worker_stats["slots"]>=worker_stats["cap"]:
                break
        var lod: int = int(_desired_tiles[key])
        if _publication_budget_active and _geometry_worker==null and not _publication.admit(lod):
            break
        var required: Array[Vector2i] = GEOMETRY.required_pages(_reader, key.x, key.y, lod)
        # Keep every already-loaded member of this tile's height/normal
        # halo hotter than unrelated pages before new IO completions
        # evict anything. The reader still enforces its exact page cap.
        # Check terminal errors before issuing more IO for this tile.
        # One missing page must not starve independent healthy tiles.
        var blocked: bool = false
        for page in required:
            var state: Error = _reader.page_status(page)
            if state != OK and state != ERR_BUSY:
                _block_tile(key, page, state)
                blocked = true
                break
        if blocked:
            continue
        _reader.prioritize_resident(required)
        var all_resident: bool = true
        for page in required:
            var state: Error = _reader.page_status(page)
            if state != OK:
                all_resident = false
                if state != ERR_BUSY:
                    _block_tile(key, page, state)
                    blocked = true
                    break
                if submitted < max_background_jobs and not _reader.is_requested(page):
                    var request: Error = _reader.request_page(page)
                    if request != OK and request != ERR_BUSY:
                        _block_tile(key, page, request)
                        blocked = true
                        break
                    if request == OK:
                        submitted += 1
        if blocked:
            continue
        if not all_resident:
            _waiting_tile_frames += 1
            # Focus only on the nearest pending tile. Otherwise page loads
            # for far tiles can evict this tile's required border samples.
            break
        if _geometry_worker!=null:
            var accepted: Dictionary=_geometry_worker.submit(_reader,key,lod,_desired_tiles)
            var status: Error=int(accepted["error"])
            if status==OK:
                _geometry_jobs[key]=accepted["id"]
                _copy_hist.add(float(accepted["copy_elapsed_us"])/1000.0)
                _dense_payload_peak=maxi(_dense_payload_peak,int(accepted["input_bytes"]))
                max_builds-=1
            elif status==ERR_BUSY:
                break
            else:
                _block_tile(key,key,status)
            continue
        var generated: Dictionary
        match _active_sampling_strategy:
            0: generated = GEOMETRY.generate(_reader, key.x, key.y, lod, _desired_tiles)
            1: generated = GEOMETRY.generate_with_view(_reader, key.x, key.y, lod, _desired_tiles)
            2: generated = GEOMETRY.generate_with_dense(_reader, key.x, key.y, lod, _desired_tiles)
            _: generated = {"error": ERR_INVALID_PARAMETER}
        _dense_payload_peak = maxi(_dense_payload_peak, int(generated.get("dense_payload_bytes", 0)))
        var error: Error = int(generated.get("error", ERR_FILE_CORRUPT))
        if error != OK:
            if error != ERR_BUSY:
                _block_tile(key, key, error)
                continue
            break
        var publication_error: Error=_publish_geometry(key,lod,generated,started)
        if publication_error!=OK:
            _block_tile(key,key,publication_error)
            continue
        max_builds -= 1

## Poll before submission, share same soft main-thread time budget.
## One result is transferred/published synchronously, never accumulated.
func _publish_worker_results(started: int) -> void:
    var count: int=0
    while count<maxi(1,tile_updates_per_frame) and float(Time.get_ticks_usec()-started)<max_tile_work_ms*1000.0:
        var remaining: int=_publication.admission_bytes() if _publication_budget_active else -1
        if remaining==0:
            break
        var polled: Dictionary=_geometry_worker.poll(_reader,_desired_tiles,remaining)
        if _publication_budget_active and polled.get("deferred_bytes",false):
            _publication.note_byte_deferral()
        var status: Error=int(polled["error"])
        if status!=OK:
            if status!=ERR_BUSY:
                _last_error=status
            break
        var result: Dictionary=polled["result"]
        var key: Vector2i=result["key"]
        var lod: int=result["lod"]
        var signature: Dictionary=WORKER.signature(key,lod,_desired_tiles,_reader.cells)
        var current: Dictionary=_reader.stats()
        if _geometry_jobs.get(key,-1)!=result["id"] or not _pending_tiles.has(key) or _blocked_tiles.has(key) or result["epoch"]!=current["generation"] or result["snapshot"]!=current["snapshot_id"] or result["source_serial"]!=_reader.session_serial() or signature.get("error",FAILED)!=OK or signature["levels"]!=result["levels"]:
            continue
        _geometry_jobs.erase(key)
        var generated: Dictionary=result["geometry"]
        if generated["error"]!=OK:
            _block_tile(key,key,int(generated["error"]))
            continue
        _queue_hist.add(float(result["queue_wait_us"])/1000.0)
        _worker_hist.add(float(result["build_elapsed_us"])/1000.0)
        _delivery_hist.add(float(result["delivery_wait_us"])/1000.0)
        var publish_start: int=Time.get_ticks_usec()
        var publication_error: Error=_publish_geometry(key,lod,generated,started)
        if publication_error!=OK:
            _block_tile(key,key,publication_error)
            continue
        _publish_hist.add(float(Time.get_ticks_usec()-publish_start)/1000.0)
        count+=1
    _publish_peak_per_pump=maxi(_publish_peak_per_pump,count)
    # Only release reservations for jobs that no longer exist. Worker can
    # finish during this snapshot but cannot create a new job on its own.
    var active: Array[int]=_geometry_worker.active_ids()
    for key in _geometry_jobs.keys():
        if not active.has(int(_geometry_jobs[key])):
            _geometry_jobs.erase(key)

func _publish_geometry(key: Vector2i,lod: int,generated: Dictionary,started: int) -> Error:
    var info: Dictionary={}
    if _publication!=null:
        info=PUBLICATION.describe(generated,lod)
        if info["error"]!=OK:
            return int(info["error"])
    var publish_start: int=Time.get_ticks_usec() if _publication!=null else 0
    # Fail-closed: don't allocate or replace any visible/collision tile
    # until ALL required Float32 data and geometry arrays are valid.
    if not _tiles.has(key):
        _tiles[key] = _create_tile(key.x, key.y)
    var tile: Dictionary = _tiles[key]
    var mesh_start: int=Time.get_ticks_usec() if _publication!=null else 0
    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, generated["arrays"])
    (tile["visual"] as MeshInstance3D).mesh = mesh
    var mesh_us: int=Time.get_ticks_usec()-mesh_start if _publication!=null else 0
    var shape_start: int=Time.get_ticks_usec() if _publication!=null else 0
    var collision: CollisionShape3D = tile["collision"]
    if lod == 0:
        var protected: bool=_support_active and _support_keys.has(key)
        var old_shape: HeightMapShape3D=collision.shape as HeightMapShape3D
        var width: int=int(generated["width"])
        # Only reuse when every Float32 height and dimensions match exactly.
        # Changed seam data still gets a real replacement, never a fake shape.
        if protected and old_shape!=null and old_shape.map_width==width and old_shape.map_depth==width and old_shape.map_data==generated["collision_heights"]:
            _support_shape_reuses+=1
        else:
            var shape: HeightMapShape3D=HeightMapShape3D.new()
            shape.map_width=width
            shape.map_depth=width
            shape.map_data=generated["collision_heights"]
            collision.shape=shape
            if protected:
                _support_shape_replacements+=1
    else:
        collision.shape = null
    var shape_us: int=Time.get_ticks_usec()-shape_start if _publication!=null else 0
    tile["lod"] = lod
    if _publication!=null:
        tile["publication_info"]=info
    if _geometry_worker!=null or _support_active:
        tile["levels"]=WORKER.signature(key,lod,_desired_tiles,_reader.cells)["levels"]
    tile["vertex_count"] = int(generated["vertex_count"])
    _tiles[key] = tile
    _pending_tiles.erase(key)
    _mesh_builds += 1
    _last_build_ms = float(Time.get_ticks_usec() - started) / 1000.0
    _max_build_ms = maxf(_max_build_ms, _last_build_ms)
    if _publication!=null:
        _publication.record(lod,info,mesh_us,shape_us,Time.get_ticks_usec()-publish_start)
    return OK

func _publication_resident() -> Dictionary:
    var result: Dictionary={"vertices":0,"triangles":0,"mesh_bytes":0,"shape_bytes":0,"total_bytes":0,"meshes":0,"shapes":0}
    for tile in _tiles.values():
        var info: Dictionary=tile.get("publication_info",{})
        for key in result:
            result[key]+=int(info.get(key,0))
    return result

func _block_tile(key: Vector2i, page: Vector2i, error: Error) -> void:
    _blocked_tiles[key] = error
    _last_error = error
    _last_error_page = page
    # Do not free or modify an existing mesh/shape on a failed rebuild.
    # A never-loaded tile remains absent; never fabricate collision.

## Public read-only diagnostic hooks. No data mutation or synthetic collision.
func enable_io_profile() -> void:
    if _reader != null:
        _reader.collect_io_profile = true

func io_profile() -> Dictionary:
    return _reader.io_profile() if _reader != null else {}

func pipeline_profile() -> Dictionary:
    return _reader.pipeline_profile() if _reader != null else {}

func world_extent() -> Vector2:
    return Vector2(_reader.cells) * _reader.spacing if _reader != null else Vector2.ZERO

func has_collision_at(global_position: Vector3) -> bool:
    if _reader == null:
        return false
    var local: Vector3 = to_local(global_position) if is_inside_tree() else transform.affine_inverse() * global_position
    var extent: Vector2 = world_extent()
    if local.x < 0.0 or local.z < 0.0 or local.x >= extent.x or local.z >= extent.y:
        return false
    var size: float = float(TILE_CELLS) * _reader.spacing
    var key: Vector2i = Vector2i(floori(local.x / size), floori(local.z / size))
    if not _tiles.has(key):
        return false
    var collision: CollisionShape3D = _tiles[key]["collision"]
    return collision.shape is HeightMapShape3D and not collision.disabled

## Experimental read-only readiness query. Call during a physics tick,
## before proposing horizontal movement, with local XZ and local radius.
## Does NOT pin tiles, stream data, move a body, freeze gravity, or guarantee
## a capsule sweep. Recheck immediately before movement; caller owns policy.
func inspect_collision_footprint(start: Vector2,finish: Vector2,radius: float,exclude: Array[RID]=[]) -> Dictionary:
    if _reader==null or not is_inside_tree() or not Engine.is_in_physics_frame():
        return {"ready":false,"reason":"physics_context"}
    var size: float=float(TILE_CELLS)*_reader.spacing
    var planned: Dictionary=FOOTPRINT.plan(start,finish,radius,world_extent(),size)
    if not planned["ready"]:
        return planned
    var keys: Array[Vector2i]=planned["tiles"]
    # Validate all metadata before issuing any physics query.
    for key in keys:
        if int(_desired_tiles.get(key,-1))!=0 or not _tiles.has(key):
            return {"ready":false,"reason":"missing_lod0","tile":key,"tiles":keys,"ray_count":0}
        var tile: Dictionary=_tiles[key]
        if _blocked_tiles.has(key) or _pending_tiles.has(key) or int(tile["lod"])!=0:
            return {"ready":false,"reason":"unsettled","tile":key,"tiles":keys,"ray_count":0}
        var collision: CollisionShape3D=tile["collision"]
        if not is_instance_valid(collision) or collision.disabled or not collision.shape is HeightMapShape3D or not is_instance_valid(tile["visual"].mesh):
            return {"ready":false,"reason":"missing_shape","tile":key,"tiles":keys,"ray_count":0}
    var rays: int=0
    var space: PhysicsDirectSpaceState3D=get_world_3d().direct_space_state
    for key in keys:
        var tile: Dictionary=_tiles[key]
        var collision: CollisionShape3D=tile["collision"]
        var body: StaticBody3D=collision.get_parent()
        var bounds: AABB=tile["visual"].mesh.get_aabb()
        var center: Vector2=(Vector2(key)+Vector2(0.5,0.5))*size
        var query=PhysicsRayQueryParameters3D.create(to_global(Vector3(center.x,bounds.end.y+1.0,center.y)),to_global(Vector3(center.x,bounds.position.y-1.0,center.y)),body.collision_layer,exclude)
        query.collide_with_areas=false
        var hit: Dictionary=space.intersect_ray(query)
        rays+=1
        if hit.is_empty() or hit.get("collider")!=body:
            return {"ready":false,"reason":"physics_unconfirmed","tile":key,"tiles":keys,"ray_count":rays}
    return {"ready":true,"reason":"sampled_ready","tiles":keys,"ray_count":rays}

## Single-caller lease. Session/revision are stale-call guards, not authentication.
## Acquire or replace only on a verified CURRENT footprint. Caller supplies local
## coordinates; this does not move the actor, pin disk pages, or prove a sweep.
## A failed request leaves the prior lease intact. Call after physics movement
## to transfer support; do not release old support merely on predicted motion.
func update_support(point: Vector2,radius: float,session: int,revision: int,exclude: Array[RID]=[]) -> Dictionary:
    var began: int=Time.get_ticks_usec()
    var result: Dictionary=_update_support(point,radius,session,revision,exclude)
    if _support_active:
        _support_claim_hist.add(float(Time.get_ticks_usec()-began)/1000.0)
    return result

func _update_support(point: Vector2,radius: float,session: int,revision: int,exclude: Array[RID]) -> Dictionary:
    if not _support_active or _reader==null or not is_inside_tree() or not Engine.is_in_physics_frame():
        return {"error":ERR_UNCONFIGURED,"reason":"support_context"}
    if session!=_support_session or revision!=_support_revision:
        return {"error":ERR_INVALID_PARAMETER,"reason":"stale_lease"}
    var plan: Dictionary=FOOTPRINT.plan(point,point,radius,world_extent(),float(TILE_CELLS)*_reader.spacing)
    if not plan["ready"]:
        return {"error":ERR_INVALID_PARAMETER,"reason":plan["reason"]}
    var keys: Array[Vector2i]=plan["tiles"]
    if keys.size()>SUPPORT.MAX_SUPPORT or keys.size()>max_visible_tiles:
        return {"error":ERR_INVALID_PARAMETER,"reason":"support_cap"}
    var confirmed: Dictionary=inspect_collision_footprint(point,point,radius,exclude)
    if not confirmed["ready"]:
        return {"error":ERR_BUSY,"reason":confirmed["reason"],"ray_count":confirmed.get("ray_count",0)}
    if keys!=_support_keys:
        _support_keys=keys.duplicate()
        _support_revision+=1
        _last_sync_msec=-100000
    return {"error":OK,"reason":"held","session":_support_session,"revision":_support_revision,"tiles":_support_keys.duplicate(),"ray_count":confirmed["ray_count"]}

func release_support(session: int,revision: int) -> Error:
    if not _support_active or not is_inside_tree() or not Engine.is_in_physics_frame():
        return ERR_UNCONFIGURED
    if session!=_support_session or revision!=_support_revision:
        return ERR_INVALID_PARAMETER
    if not _support_keys.is_empty():
        _support_keys.clear()
        _support_revision+=1
        _last_sync_msec=-100000
    return OK

func support_state() -> Dictionary:
    return {"active":_support_active,"session":_support_session,"revision":_support_revision,"tiles":_support_keys.duplicate(),"cap":max_visible_tiles,"cap_rejections":_support_cap_rejections,"shape_reuses":_support_shape_reuses,"shape_replacements":_support_shape_replacements,"selection_ms":_support_selection_hist.report(),"claim_ms":_support_claim_hist.report()}

func stats() -> Dictionary:
    var source: Dictionary = _reader.stats() if _reader != null else {}
    var vertices: int = 0
    for tile in _tiles.values():
        vertices += int(tile["vertex_count"])
    var retained: int = 0
    for key in _blocked_tiles:
        if _tiles.has(key):
            retained += 1
    return {
        "active": _reader != null,
        "blocked_tiles": _blocked_tiles.size(),
        "retained_failed_tiles": retained,
        "tiles": _tiles.size(),
        "pending_tiles": _pending_tiles.size(),
        "vertices": vertices,
        "mesh_builds": _mesh_builds,
        "last_build_ms": _last_build_ms,
        "max_build_ms": _max_build_ms,
        "source": source,
        "verify_pages_on_demand": verify_pages_on_demand,
        "use_tile_read_view": use_tile_read_view,
        "sampling_strategy": _active_sampling_strategy if _reader != null else resolved_sampling_strategy(),
        "dense_payload_peak_bytes": _dense_payload_peak,
        "publication": _publication.report(_publication_resident()) if _publication!=null else {},
        "geometry_worker": _geometry_worker.stats() if _geometry_worker!=null else {},
        "geometry_reservations": _geometry_jobs.size(),
        "geometry_copy_ms": _copy_hist.report(), "geometry_queue_ms": _queue_hist.report(),
        "geometry_worker_ms": _worker_hist.report(), "geometry_delivery_ms": _delivery_hist.report(),
        "geometry_publish_ms": _publish_hist.report(), "geometry_publish_peak_per_pump": _publish_peak_per_pump,
        "index_format": source.get("index_format", "TFM2" if region_index_format == 1 else "TFM1"),
        "last_error": _last_error,
        "last_error_page": _last_error_page,
        "focus_page": _queue_focus_page,
        "camera_cancellations": _camera_cancellations,
        "waiting_tile_frames": _waiting_tile_frames,
        "support": support_state(),
        "writable": false
    }

## Deliberate read-only API: a paged snapshot must never be saved or sculpted.
func save_data() -> Error:
    return ERR_UNAVAILABLE

func begin_stroke() -> void:
    pass

func paint_at(_world_position: Vector3, _tool: int, _radius: float, _strength: float) -> Error:
    return ERR_UNAVAILABLE
