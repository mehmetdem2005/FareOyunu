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
const MICRO = preload("res://addons/terra_forge/core/publication_micro_profile.gd")
const PUMP_MICRO = preload("res://addons/terra_forge/core/pump_micro_profile.gd")
const FOOTPRINT = preload("res://addons/terra_forge/core/collision_footprint.gd")
const SUPPORT = preload("res://addons/terra_forge/core/support_tile_selection.gd")
const MOTION = preload("res://addons/terra_forge/core/motion_prefetch.gd")
const MOTION_LATENCY = preload("res://addons/terra_forge/core/motion_latency_window.gd")
const VIEW_BUDGET = preload("res://addons/terra_forge/core/adaptive_view_budget.gd")
const CAPACITY_WAIT=preload("res://addons/terra_forge/core/capacity_wait_profile.gd")
const WORK_BUDGET = preload("res://addons/terra_forge/core/adaptive_work_budget.gd")
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
## Experimental G/H only; pinned at start, never changes E/F or A.
@export var enable_scalar_worker_cropped_halo: bool=false
var _scalar_worker_cropped_halo_active: bool=false
var _scalar_worker_cropped_submissions: int=0
## Independent E/F camera-only opt-in. Existing motion halo stays unchanged.
@export var enable_camera_worker_cropped_halo: bool=false
var _camera_worker_cropped_halo_active: bool=false
var _camera_worker_cropped_submissions: int=0
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
@export var observe_publication_micro: bool = false
var _publication_micro
@export var observe_pump_micro: bool=false
var _pump_micro
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
## P1.5.8a experiment, requires support retention. Pinned on open.
@export var enable_motion_prefetch: bool = false
## Independent opt-in, requires motion prefetch. Pinned on open.
@export var enable_adaptive_motion_horizon: bool = false
## P1.5.9a experimental far-view pressure controller, requires support mode.
@export var enable_adaptive_view_budget: bool=false
## Independent opt-in; shares adaptive view pressure tier, not its tile cap.
@export var enable_adaptive_work_budget: bool=false
## Independent experiment: reserve one geometry slot for LOD0 when cap>=2.
@export var enable_critical_worker_reservation: bool=false
## Independent opt-in: lend reserved slot only without pending LOD0 demand.
@export var enable_critical_slot_lending: bool=false
## Independent observation flag; no policy change.
@export var observe_geometry_latency: bool=false
## Independent diagnostic; no scheduler changes.
@export var observe_capacity_wait: bool=false
var _capacity_wait
var _critical_lending_active: bool=false
var _critical_demand_pumps: int=0
var _critical_saturated_pumps: int=0
var _critical_reservation_active: bool=false
var _critical_reservation_skips: int=0
var _adaptive_work_active: bool=false
var _work_budget=WORK_BUDGET.new()
@export_enum("30 FPS:30","60 FPS:60") var adaptive_target_fps: int=30
var _adaptive_view_active: bool=false
var _view_budget=VIEW_BUDGET.new()
var _view_far_candidates: int=0
var _view_far_admitted: int=0
var _motion_adaptive: bool=false
var _motion_latency=MOTION_LATENCY.new()
var _motion_wait_started: Dictionary={}
var _motion_already_ready: int=0
var _motion_cancelled_samples: int=0
var _motion_failed_samples: int=0
var _motion_active: bool=false
var _motion_keys: Array[Vector2i]=[]
var _motion_selected: Array[Vector2i]=[]
var _motion_velocity: Vector2=Vector2.ZERO
var _motion_point: Vector2=Vector2.ZERO
var _motion_tick: int=-1
var _motion_changes: int=0
var _motion_expirations: int=0
var _motion_relocations: int=0
var _motion_promotions: int=0
var _motion_abandoned: int=0
var _motion_published: int=0
var _motion_hist=HIST.new()
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
    if selected < 0 or selected > 6 or (enable_scalar_worker_cropped_halo and selected not in [5,6]) or (enable_camera_worker_cropped_halo and selected not in [3,4]):
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
    _scalar_worker_cropped_halo_active=enable_scalar_worker_cropped_halo
    _camera_worker_cropped_halo_active=enable_camera_worker_cropped_halo
    _support_active = enable_support_retention
    _motion_active=enable_motion_prefetch and _support_active
    _motion_adaptive=_motion_active and enable_adaptive_motion_horizon
    _adaptive_view_active=enable_adaptive_view_budget and _support_active
    _adaptive_work_active=enable_adaptive_work_budget and _adaptive_view_active
    _critical_reservation_active=enable_critical_worker_reservation and _adaptive_work_active and selected>=3 and geometry_job_limit>=2
    _critical_lending_active=_critical_reservation_active and enable_critical_slot_lending
    if _adaptive_view_active and _view_budget.configure(adaptive_target_fps)!=OK:
        stop_preview()
        _last_error=ERR_INVALID_PARAMETER
        return _last_error
    if _support_active and (max_visible_tiles < 1 or max_visible_tiles > SUPPORT.MAX_TOTAL):
        stop_preview()
        _last_error=ERR_INVALID_PARAMETER
        return _last_error
    if selected>=3:
        _capacity_wait=CAPACITY_WAIT.new() if observe_capacity_wait else null
        _geometry_worker=WORKER.new()
        status=_geometry_worker.start(_reader,geometry_job_limit,selected>=5,selected==6,_critical_reservation_active,_critical_lending_active,observe_geometry_latency)
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
    _publication_micro=MICRO.new() if observe_publication_micro else null
    _pump_micro=PUMP_MICRO.new() if observe_pump_micro else null
    _publication=PUBLICATION.new() if observe_publication or _publication_budget_active or observe_publication_micro else null
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
    _camera_worker_cropped_halo_active=false
    _camera_worker_cropped_submissions=0
    _scalar_worker_cropped_halo_active=false
    _scalar_worker_cropped_submissions=0
    # Explicit shutdown revokes even a held support lease. Camera epochs do not.
    _capacity_wait=null
    _critical_reservation_active=false
    _critical_lending_active=false
    _critical_demand_pumps=0
    _critical_saturated_pumps=0
    _critical_reservation_skips=0
    _adaptive_work_active=false
    _work_budget=WORK_BUDGET.new()
    _adaptive_view_active=false
    _view_budget=VIEW_BUDGET.new()
    _view_far_candidates=0
    _view_far_admitted=0
    _motion_active=false
    _motion_adaptive=false
    _motion_latency=MOTION_LATENCY.new()
    _motion_wait_started.clear()
    _motion_already_ready=0
    _motion_cancelled_samples=0
    _motion_failed_samples=0
    _motion_keys.clear()
    _motion_selected.clear()
    _motion_velocity=Vector2.ZERO
    _motion_tick=-1
    _motion_changes=0
    _motion_expirations=0
    _motion_relocations=0
    _motion_promotions=0
    _motion_abandoned=0
    _motion_published=0
    _motion_hist=HIST.new()
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
    _publication_micro=null
    _pump_micro=null
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
        if _adaptive_view_active:
            sample_view_pressure(_delta*1000.0)
    pump_stream()

## Public for reproducible headless tests, without relying on idle frames.
func pump_stream() -> Dictionary:
    if _reader == null or not _reader.is_open():
        return {"error": ERR_UNCONFIGURED}
    var event: Variant=null
    if _pump_micro!=null:
        event=PUMP_MICRO.begin(_mesh_builds,_pending_tiles.size(),_geometry_jobs.size())
    var completed: Dictionary = _reader.poll_results(max_background_jobs)
    if event!=null:
        PUMP_MICRO.mark(event,"io_accept")
    if int(completed.get("error", ERR_FILE_CORRUPT)) != OK:
        if event!=null:
            _pump_micro.finish(event,int(completed.get("error",ERR_FILE_CORRUPT)),_mesh_builds,0)
        return completed
    if _motion_active and _motion_tick>=0 and Engine.get_physics_frames()-_motion_tick>4:
        _motion_tick=-1
        _motion_velocity=Vector2.ZERO
        _motion_expirations+=1
        _set_motion_keys([])
    if event!=null:
        PUMP_MICRO.mark(event,"motion_expiry")
    var current: int = Time.get_ticks_msec()
    if current - _last_sync_msec > 220:
        _sync_tiles()
        _last_sync_msec = current
    if event!=null:
        PUMP_MICRO.mark(event,"sync_and_eviction")
    var started: int=Time.get_ticks_usec()
    if _adaptive_work_active:
        _work_budget.begin_pump(_view_budget.tier,int(max_tile_work_ms*1000.0))
    if _publication!=null:
        _publication.begin_pump(tile_updates_per_frame)
    if event!=null:
        PUMP_MICRO.mark(event,"budget_setup")
    if _geometry_worker!=null:
        if _active_sampling_strategy>=4 or _publication_budget_active or _support_active:
            var reconciled: Error=_geometry_worker.reconcile(_reader,_desired_tiles,_priority_ranks())
            if reconciled!=OK:
                _last_error=reconciled
                if _publication!=null:
                    _publication.end_pump(_publication_resident())
                if event!=null:
                    PUMP_MICRO.mark(event,"reconcile_error")
                    _pump_micro.finish(event,reconciled,_mesh_builds,started)
                return {"error":reconciled}
        if event!=null:
            PUMP_MICRO.mark(event,"worker_reconcile")
        if _critical_lending_active:
            var demand: bool=_has_pending_critical()
            var demand_error: Error=_geometry_worker.set_critical_demand(_reader,demand)
            if demand_error!=OK:
                _last_error=demand_error
                if _publication!=null:
                    _publication.end_pump(_publication_resident())
                if event!=null:
                    PUMP_MICRO.mark(event,"lending_error")
                    _pump_micro.finish(event,demand_error,_mesh_builds,started)
                return {"error":demand_error}
            if demand:
                _critical_demand_pumps+=1
                var capacity: Dictionary=_geometry_worker.stats()
                if int(capacity["optional_slots"])>=int(capacity["cap"]):
                    _critical_saturated_pumps+=1
        if event!=null:
            PUMP_MICRO.mark(event,"critical_demand")
        _publish_worker_results(started,event)
        if event!=null:
            PUMP_MICRO.mark(event,"worker_delivery_publish")
        _observe_capacity_gate()
        if event!=null:
            PUMP_MICRO.mark(event,"capacity_observe")
    _build_pending_tiles(started,event)
    if event!=null:
        PUMP_MICRO.mark(event,"pending_build_submit")
    # A stale in-flight job may drop after the pre-submit ID snapshot.
    # Reconcile after submissions too: the worker never creates new IDs.
    if _geometry_worker!=null:
        _prune_geometry_reservations()
    if event!=null:
        PUMP_MICRO.mark(event,"post_submit_prune")
    if _publication!=null:
        _publication.end_pump(_publication_resident())
    if event!=null:
        PUMP_MICRO.mark(event,"publication_accounting")
    var result: Dictionary={
        "error": _last_error,
        "resident_tiles": _tiles.size(),
        "pending_tiles": _pending_tiles.size(),
        "resident_pages": int(_reader.stats()["resident"])
    }
    if event!=null:
        PUMP_MICRO.mark(event,"result_stats")
        _pump_micro.finish(event,_last_error,_mesh_builds,started)
    return result

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
    var motion_epoch_changed: bool=false
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
        if _motion_adaptive:
            _motion_cancelled_samples+=_motion_wait_started.size()
            _motion_wait_started.clear()
            motion_epoch_changed=true
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
        var ahead: Array[Vector2i]=[]
        if _motion_active:
            for key in _motion_keys:
                if not _support_keys.has(key) and ahead.size()<max_visible_tiles-_support_keys.size():
                    ahead.append(key)
                    ranked.append({"key":key,"lod":0})
        var far_count: int=0
        if _adaptive_view_active:
            for entry in found:
                var key: Vector2i=entry["key"]
                if int(new_desired[key])>0 and not ahead.has(key) and not _support_keys.has(key):
                    far_count+=1
        var far_limit: int=_view_budget.far_limit(far_count) if _adaptive_view_active else SUPPORT.MAX_TOTAL
        var far_admitted: int=0
        for entry in found:
            var key: Vector2i=entry["key"]
            if ahead.has(key) or ranked.size()>=SUPPORT.MAX_TOTAL:
                continue
            var lod: int=int(new_desired[key])
            if _adaptive_view_active and lod>0 and not _support_keys.has(key):
                if far_admitted>=far_limit:
                    continue
                far_admitted+=1
            ranked.append({"key":key,"lod":lod})
        if _adaptive_view_active:
            _view_far_candidates=far_count
            _view_far_admitted=far_admitted
        var grid=Vector2i(int(_reader.cells.x/TILE_CELLS),int(_reader.cells.y/TILE_CELLS))
        var chosen: Dictionary=SUPPORT.select(_support_keys,ranked,grid,max_visible_tiles)
        _support_selection_hist.add(float(Time.get_ticks_usec()-selection_started)/1000.0)
        if chosen["error"]!=OK:
            # Never partially apply an invalid support/cap selection.
            _last_error=int(chosen["error"])
            return
        new_desired=chosen["desired"]
        if _motion_active:
            for key in _motion_selected:
                if not ahead.has(key):
                    if _support_keys.has(key):
                        _motion_promotions+=1
                    else:
                        _motion_abandoned+=1
            if _motion_adaptive:
                for key in _motion_wait_started.keys():
                    if not ahead.has(key):
                        _motion_wait_started.erase(key)
                        _motion_cancelled_samples+=1
                for key in ahead:
                    if motion_epoch_changed or not _motion_selected.has(key):
                        if _tiles.has(key) and int(_tiles[key]["lod"])==0 and not _pending_tiles.has(key) and not _blocked_tiles.has(key):
                            _motion_already_ready+=1
                        else:
                            _motion_wait_started[key]=Engine.get_physics_frames()
            _motion_selected=ahead
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

func _create_tile(tx: int, tz: int, event: Variant=null) -> Dictionary:
    var root: Node3D = Node3D.new()
    root.name = "TF_Paged_%d_%d" % [tx, tz]
    root.position = Vector3(
        float(tx * TILE_CELLS) * _reader.spacing,
        0.0, float(tz * TILE_CELLS) * _reader.spacing
    )
    if event!=null:
        MICRO.mark(event,"root_allocate")
    add_child(root, false, Node.INTERNAL_MODE_FRONT)
    if event!=null:
        MICRO.mark(event,"root_attach")
    var visual: MeshInstance3D = MeshInstance3D.new()
    visual.name = "Visual"
    visual.material_override = _material
    if event!=null:
        MICRO.mark(event,"visual_allocate")
    root.add_child(visual)
    if event!=null:
        MICRO.mark(event,"visual_attach")
    var physics: StaticBody3D = StaticBody3D.new()
    physics.name = "Physics"
    if event!=null:
        MICRO.mark(event,"body_allocate")
    root.add_child(physics)
    if event!=null:
        MICRO.mark(event,"body_attach")
    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.name = "HeightCollision"
    collision.position = Vector3(
        float(TILE_CELLS) * _reader.spacing * 0.5, 0.0,
        float(TILE_CELLS) * _reader.spacing * 0.5
    )
    collision.scale = Vector3.ONE * _reader.spacing
    if event!=null:
        MICRO.mark(event,"collision_node_allocate")
    physics.add_child(collision)
    if event!=null:
        MICRO.mark(event,"collision_node_attach")
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
            classes[key]=-4 if _motion_active else -1
            if _motion_active and has_shape and _pending_tiles.has(key) and not _blocked_tiles.has(key):
                var desired := WORKER.signature(key, 0, _desired_tiles, _reader.cells)
                if _same_lod0_height_edges(_tiles[key].get("levels", []), desired.get("levels", [])):
                    # A height-equivalent held rebuild can wait for a first
                    # forecast shape, but still precedes ordinary camera work.
                    classes[key] = -2
        elif _motion_active and _motion_selected.has(key):
            classes[key] = -1 if has_shape else -3
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

## Includes queued/building/completed LOD0 and cold page dependencies.
## A terminally blocked key cannot keep idle headroom reserved forever.
func _observe_capacity_gate() -> void:
    if _capacity_wait==null or _geometry_worker==null:
        return
    var capacity:Dictionary=_geometry_worker.stats()
    var eligible:Dictionary={}
    for key in _pending_tiles:
        if not _blocked_tiles.has(key) and not _geometry_jobs.has(key) and _desired_tiles.has(key):
            eligible[key]=int(_desired_tiles[key])
    # Snapshot after polling, before submission; no extra page IO.
    _capacity_wait.observe(int(capacity["epoch"]),eligible,int(capacity["slots"])>=int(capacity["cap"]),Time.get_ticks_usec())

func capacity_wait_profile() -> Dictionary:
    return _capacity_wait.report(Time.get_ticks_usec()) if _capacity_wait!=null else {}

func _has_pending_critical() -> bool:
    for key in _pending_tiles:
        if not _blocked_tiles.has(key) and int(_desired_tiles.get(key,-1))==0:
            return true
    return false

func _tile_halo(key: Vector2i, lod: int) -> int:
    if ((_motion_active or _camera_worker_cropped_halo_active) and _active_sampling_strategy in [3, 4]) or _scalar_worker_cropped_halo_active:
        return GEOMETRY.normal_halo(key, lod, _desired_tiles)
    return GEOMETRY.DENSE.FULL_HALO

func _build_pending_tiles(started: int = -1, event: Variant=null) -> void:
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
        if max_builds <= 0:
            if event!=null:
                PUMP_MICRO.stop(event,"build_count")
            break
        if float(Time.get_ticks_usec() - started) >= max_tile_work_ms * 1000.0:
            if event!=null:
                PUMP_MICRO.stop(event,"build_outer_time")
            break
        var lod: int = int(_desired_tiles[key])
        if _geometry_worker!=null:
            var worker_stats: Dictionary=_geometry_worker.stats()
            if worker_stats["slots"]>=worker_stats["cap"]:
                break
            if _critical_reservation_active and bool(worker_stats["reservation_enforced"]) and lod>0 and int(worker_stats["optional_slots"])>=int(worker_stats["cap"])-1:
                # Do not churn the page cache for an optional job that
                # cannot be admitted. Other eligible critical keys can run.
                _critical_reservation_skips+=1
                continue
        if _adaptive_work_active and lod>0 and not _work_budget.allows_optional(Time.get_ticks_usec()-started):
            _work_budget.note_deferral()
            continue
        if _publication_budget_active and _geometry_worker==null and not _publication.admit(lod):
            break
        var halo_mask := _tile_halo(key, lod)
        var required: Array[Vector2i] = GEOMETRY.required_pages(_reader, key.x, key.y, lod, halo_mask)
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
        if _adaptive_work_active:
            # Recheck after page bookkeeping; count attempted CPU work,
            # including an unsuccessful build/submit, rather than only wins.
            if lod>0 and not _work_budget.allows_optional(Time.get_ticks_usec()-started):
                _work_budget.note_deferral()
                continue
            _work_budget.record(lod,Time.get_ticks_usec()-started)
        if _geometry_worker!=null:
            var accepted: Dictionary=_geometry_worker.submit(_reader,key,lod,_desired_tiles,halo_mask)
            var status: Error=int(accepted["error"])
            if status==OK:
                _geometry_jobs[key]=accepted["id"]
                if _scalar_worker_cropped_halo_active and halo_mask!=GEOMETRY.DENSE.FULL_HALO:
                    _scalar_worker_cropped_submissions+=1
                if _camera_worker_cropped_halo_active and not _motion_active and halo_mask!=GEOMETRY.DENSE.FULL_HALO:
                    _camera_worker_cropped_submissions+=1
                _copy_hist.add(float(accepted["copy_elapsed_us"])/1000.0)
                _dense_payload_peak=maxi(_dense_payload_peak,int(accepted["input_bytes"]))
                max_builds-=1
            elif status==ERR_BUSY:
                if accepted.get("reserved_critical",false):
                    _critical_reservation_skips+=1
                    continue
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
func _publish_worker_results(started: int,event: Variant=null) -> void:
    var count: int=0
    while count<maxi(1,tile_updates_per_frame):
        if float(Time.get_ticks_usec()-started)>=max_tile_work_ms*1000.0:
            if event!=null:
                PUMP_MICRO.stop(event,"delivery_outer_time")
            break
        var remaining: int=_publication.admission_bytes() if _publication_budget_active else -1
        if remaining==0:
            break
        var critical_only: bool=_adaptive_work_active and not _work_budget.allows_optional(Time.get_ticks_usec()-started)
        var polled: Dictionary=_geometry_worker.poll(_reader,_desired_tiles,remaining,critical_only)
        if _adaptive_work_active and polled.get("deferred_optional",false):
            _work_budget.note_deferral()
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
        if _adaptive_work_active:
            _work_budget.record(lod,Time.get_ticks_usec()-started)
        var publish_start: int=Time.get_ticks_usec()
        var publication_error: Error=_publish_geometry(key,lod,generated,started)
        if publication_error!=OK:
            _block_tile(key,key,publication_error)
            continue
        _publish_hist.add(float(Time.get_ticks_usec()-publish_start)/1000.0)
        count+=1
    if event!=null and count>=maxi(1,tile_updates_per_frame):
        PUMP_MICRO.stop(event,"delivery_count")
    _publish_peak_per_pump=maxi(_publish_peak_per_pump,count)
    _prune_geometry_reservations()

func _prune_geometry_reservations() -> void:
    # Only release reservations for jobs that no longer exist. Worker can
    # finish during this snapshot but cannot create a new job on its own.
    var active: Array[int]=_geometry_worker.active_ids()
    for key in _geometry_jobs.keys():
        if not active.has(int(_geometry_jobs[key])):
            _geometry_jobs.erase(key)

func _publish_geometry(key: Vector2i,lod: int,generated: Dictionary,started: int) -> Error:
    var event: Variant=null
    if _publication_micro!=null:
        event=MICRO.begin(key,lod,not _tiles.has(key))
    var info: Dictionary={}
    if _publication!=null:
        info=PUBLICATION.describe(generated,lod)
        if event!=null:
            MICRO.mark(event,"validate")
        if info["error"]!=OK:
            if event!=null:
                _publication_micro.finish(event,int(info["error"]),0)
            return int(info["error"])
    var publish_start: int=Time.get_ticks_usec() if _publication!=null else 0
    # Fail-closed: don't allocate or replace any visible/collision tile
    # until ALL required Float32 data and geometry arrays are valid.
    if not _tiles.has(key):
        _tiles[key] = _create_tile(key.x, key.y,event)
    var tile: Dictionary = _tiles[key]
    if event!=null:
        MICRO.mark(event,"tile_lookup")
    var mesh_start: int=Time.get_ticks_usec() if _publication!=null else 0
    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, generated["arrays"])
    if event!=null:
        MICRO.mark(event,"mesh_create_surface")
    (tile["visual"] as MeshInstance3D).mesh = mesh
    if event!=null:
        MICRO.mark(event,"mesh_assign")
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
            if event!=null:
                MICRO.mark(event,"shape_compare_reuse")
        else:
            if event!=null:
                MICRO.mark(event,"shape_compare_reuse")
            var shape: HeightMapShape3D=HeightMapShape3D.new()
            shape.map_width=width
            shape.map_depth=width
            shape.map_data=generated["collision_heights"]
            if event!=null:
                MICRO.mark(event,"shape_create_data")
            collision.shape=shape
            if protected:
                _support_shape_replacements+=1
    else:
        collision.shape = null
    if event!=null:
        MICRO.mark(event,"shape_assign_release")
    var shape_us: int=Time.get_ticks_usec()-shape_start if _publication!=null else 0
    tile["lod"] = lod
    if _publication!=null:
        tile["publication_info"]=info
    if _geometry_worker!=null or _support_active:
        tile["levels"]=WORKER.signature(key,lod,_desired_tiles,_reader.cells)["levels"]
    if event!=null:
        MICRO.mark(event,"metadata_signature")
    tile["vertex_count"] = int(generated["vertex_count"])
    _tiles[key] = tile
    _pending_tiles.erase(key)
    _mesh_builds += 1
    if _motion_active and _motion_selected.has(key) and not _support_keys.has(key):
        _motion_published+=1
        if _motion_adaptive and _motion_wait_started.has(key) and lod==0:
            var elapsed_ticks: int=Engine.get_physics_frames()-int(_motion_wait_started[key])
            _motion_latency.observe(elapsed_ticks,Engine.physics_ticks_per_second)
            _motion_wait_started.erase(key)
    _last_build_ms = float(Time.get_ticks_usec() - started) / 1000.0
    _max_build_ms = maxf(_max_build_ms, _last_build_ms)
    if event!=null:
        MICRO.mark(event,"bookkeeping")
    if _publication!=null:
        _publication.record(lod,info,mesh_us,shape_us,Time.get_ticks_usec()-publish_start)
    if event!=null:
        MICRO.mark(event,"accounting")
        _publication_micro.finish(event,OK,int(info["total_bytes"]))
    return OK

func pump_micro_profile() -> Dictionary:
    return _pump_micro.report() if _pump_micro!=null else {}

func publication_micro_profile() -> Dictionary:
    return _publication_micro.report() if _publication_micro!=null else {}

func _publication_resident() -> Dictionary:
    var result: Dictionary={"vertices":0,"triangles":0,"mesh_bytes":0,"shape_bytes":0,"total_bytes":0,"meshes":0,"shapes":0}
    for tile in _tiles.values():
        var info: Dictionary=tile.get("publication_info",{})
        for key in result:
            result[key]+=int(info.get(key,0))
    return result

func _block_tile(key: Vector2i, page: Vector2i, error: Error) -> void:
    _blocked_tiles[key] = error
    # A terminal read failure is not a completed latency observation.
    # End its bounded sample without interpreting failure as fast success.
    if _motion_adaptive and _motion_wait_started.has(key):
        _motion_wait_started.erase(key)
        _motion_failed_samples+=1
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
## For this read-only source, absent and same-detail neighbors both use
## canonical LOD0 edge heights. They can change normals. A coarser
## neighbor may interpolate heights, so every coarse edge must match.
static func _same_lod0_height_edges(published: Array, desired: Array) -> bool:
    if published.size() != 4 or desired.size() != 4:
        return false
    for edge in range(4):
        var before: int = published[edge]
        var after: int = desired[edge]
        if before < -1 or after < -1 or before > 2 or after > 2:
            return false
        if maxi(0, before) != maxi(0, after):
            return false
    return true

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
        if _blocked_tiles.has(key) or int(tile["lod"])!=0:
            return {"ready":false,"reason":"unsettled","tile":key,"tiles":keys,"ray_count":0}
        if _pending_tiles.has(key):
            if not _support_active or not _support_keys.has(key):
                return {"ready":false,"reason":"unsettled","tile":key,"tiles":keys,"ray_count":0}
            var signature: Dictionary = WORKER.signature(key, 0, _desired_tiles, _reader.cells)
            if not _same_lod0_height_edges(tile.get("levels", []), signature.get("levels", [])):
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
        # A verified large relocation (not an ordinary seam transfer) must
        # revoke the previous motion forecast BEFORE another stream pump.
        # Keep learned latency session-scoped; no new generation or IO queue.
        if _motion_active and _motion_tick>=0 and point.distance_to(_motion_point)>float(TILE_CELLS)*_reader.spacing*0.5:
            _motion_velocity=Vector2.ZERO
            _motion_tick=-1
            _motion_relocations+=1
            _set_motion_keys([])
        _support_keys=keys.duplicate()
        _support_revision+=1
        _last_sync_msec=-100000
    return {"error":OK,"reason":"held","session":_support_session,"revision":_support_revision,"tiles":_support_keys.duplicate(),"ray_count":confirmed["ray_count"]}

## Experimental admission query for a held support lease. No actor motion,
## lease mutation, streaming request or future collision guarantee.
## Call before movement, then update_support using ACTUAL resulting XZ
## before any pump. If pending, hold horizontal movement; gravity is caller-owned.
func inspect_support_step(start: Vector2,finish: Vector2,radius: float,session: int,revision: int,exclude: Array[RID]=[]) -> Dictionary:
    if not _support_active or _reader==null or not is_inside_tree() or not Engine.is_in_physics_frame():
        return {"ready":false,"reason":"support_context","ray_count":0}
    if session!=_support_session or revision!=_support_revision:
        return {"ready":false,"reason":"stale_lease","ray_count":0}
    var size: float=float(TILE_CELLS)*_reader.spacing
    var current: Dictionary=FOOTPRINT.plan(start,start,radius,world_extent(),size)
    if not current["ready"]:
        return current
    if _support_keys.is_empty() or current["tiles"]!=_support_keys:
        return {"ready":false,"reason":"lease_footprint_mismatch","ray_count":0}
    var next: Dictionary=FOOTPRINT.plan(start,finish,radius,world_extent(),size)
    if not next["ready"]:
        return next
    if next["tiles"].size()>SUPPORT.MAX_SUPPORT or next["tiles"].size()>max_visible_tiles:
        return {"ready":false,"reason":"support_cap","ray_count":0}
    # Terminal tile failures are distinct from ordinary streaming delay.
    # Keep the old lease; caller can display a blocked-path state without
    # treating a damaged destination as an indefinitely slow IO request.
    for key in next["tiles"]:
        if _blocked_tiles.has(key):
            return {"ready":false,"reason":"terrain_blocked","tile":key,"tiles":next["tiles"],"tile_error":int(_blocked_tiles[key]),"ray_count":0}
    return inspect_collision_footprint(start,finish,radius,exclude)

## Call once per physics tick with local XZ position, actual prior velocity,
## and current requested horizontal velocity. Stale/invalid samples never
## replace the held footprint. No independent IO queue or data generation.
func sample_motion_prefetch(point: Vector2,actual: Vector2,intent: Vector2,radius: float,session: int,revision: int) -> Error:
    if not _motion_active or _reader==null or not is_inside_tree() or not Engine.is_in_physics_frame():
        return ERR_UNCONFIGURED
    if session!=_support_session or revision!=_support_revision or _support_keys.is_empty():
        return ERR_INVALID_PARAMETER
    var tick: int=Engine.get_physics_frames()
    if tick==_motion_tick:
        return ERR_BUSY
    var started: int=Time.get_ticks_usec()
    var size: float=float(TILE_CELLS)*_reader.spacing
    var previous: Vector2=_motion_velocity
    if _motion_tick<0 or tick-_motion_tick>4 or point.distance_to(_motion_point)>size*0.5:
        previous=Vector2.ZERO
    var horizon: float=_motion_latency.horizon if _motion_adaptive else MOTION.LOOKAHEAD_SECONDS
    var predicted: Dictionary=MOTION.predict(point,actual,intent,previous,radius,world_extent(),size,_support_keys,horizon)
    _motion_hist.add(float(Time.get_ticks_usec()-started)/1000.0)
    if predicted["error"]!=OK:
        return int(predicted["error"])
    _motion_point=point
    _motion_tick=tick
    _motion_velocity=predicted["velocity"]
    _set_motion_keys(predicted["keys"])
    return OK

func _set_motion_keys(keys: Array[Vector2i]) -> void:
    if keys!=_motion_keys:
        _motion_keys=keys.duplicate()
        _motion_changes+=1
        _last_sync_msec=-100000

## Explicit sample API for deterministic CI or host-owned frame telemetry.
## The normal runtime path samples process delta once before the pump.
func sample_view_pressure(frame_ms: float) -> Error:
    if not _adaptive_view_active or _reader==null:
        return ERR_UNCONFIGURED
    var before: int=_view_budget.tier
    var status: Error=_view_budget.observe(frame_ms)
    if status==OK and before!=_view_budget.tier:
        _last_sync_msec=-100000
    return status

## Manual full-view override. Does not change user-specified hard caps.
func set_adaptive_view_auto(enabled: bool) -> Error:
    if not _adaptive_view_active or _reader==null:
        return ERR_UNCONFIGURED
    if _view_budget.set_auto(enabled):
        _last_sync_msec=-100000
    return OK

func geometry_latency_profile() -> Dictionary:
    return _geometry_worker.latency_profile() if _geometry_worker!=null else {}

func adaptive_work_state() -> Dictionary:
    return {"active":_adaptive_work_active,"controller":_work_budget.report() if _adaptive_work_active else {},"critical_reservation_active":_critical_reservation_active,"critical_reservation_skips":_critical_reservation_skips,"critical_lending_active":_critical_lending_active,"critical_demand_pumps":_critical_demand_pumps,"critical_saturated_pumps":_critical_saturated_pumps}

func adaptive_view_state() -> Dictionary:
    return {"active":_adaptive_view_active,"controller":_view_budget.report() if _adaptive_view_active else {},"far_candidates":_view_far_candidates,"far_admitted_candidates":_view_far_admitted}

func motion_prefetch_state() -> Dictionary:
    return {"active":_motion_active,"keys":_motion_keys.duplicate(),"selected":_motion_selected.duplicate(),"changes":_motion_changes,"expirations":_motion_expirations,"relocations":_motion_relocations,"promotions":_motion_promotions,"abandoned_selection":_motion_abandoned,"speculative_publications":_motion_published,"sample_ms":_motion_hist.report(),"adaptive":_motion_adaptive,"latency":_motion_latency.report() if _motion_adaptive else {},"pending_latency_samples":_motion_wait_started.size(),"already_ready_selections":_motion_already_ready,"cancelled_latency_samples":_motion_cancelled_samples,"failed_latency_samples":_motion_failed_samples}

func release_support(session: int,revision: int) -> Error:
    if not _support_active or not is_inside_tree() or not Engine.is_in_physics_frame():
        return ERR_UNCONFIGURED
    if session!=_support_session or revision!=_support_revision:
        return ERR_INVALID_PARAMETER
    if not _support_keys.is_empty():
        _support_keys.clear()
        _set_motion_keys([])
        _motion_tick=-1
        _motion_velocity=Vector2.ZERO
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
        "camera_worker_cropped_halo_active": _camera_worker_cropped_halo_active,
        "camera_worker_cropped_submissions": _camera_worker_cropped_submissions,
        "scalar_worker_cropped_halo_active": _scalar_worker_cropped_halo_active,
        "scalar_worker_cropped_submissions": _scalar_worker_cropped_submissions,
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
        "motion_prefetch": motion_prefetch_state(),
        "adaptive_view": adaptive_view_state(),
        "adaptive_work": adaptive_work_state(),
        "writable": false
    }

## Deliberate read-only API: a paged snapshot must never be saved or sculpted.
func save_data() -> Error:
    return ERR_UNAVAILABLE

func begin_stroke() -> void:
    pass

func paint_at(_world_position: Vector3, _tool: int, _radius: float, _strength: float) -> Error:
    return ERR_UNAVAILABLE
