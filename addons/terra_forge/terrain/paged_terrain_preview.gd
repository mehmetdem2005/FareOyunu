@tool
extends Node3D
## Opt-in P1.3 test-only terrain renderer backed by asynchronous TFR1 pages.
## NOT a replacement for TerraForgeTerrain: no editing, save, layer, or brush.
## Never constructs a full-world heights PackedFloat32Array.
const ASYNC = preload("res://addons/terra_forge/core/async_region_source.gd")
const LOD = preload("res://addons/terra_forge/core/lod_policy.gd")
const GEOMETRY = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const TILE_CELLS: int = 32

@export var preview_enabled: bool = false
@export_dir var region_directory: String = ""
@export_range(9, 64, 1) var resident_page_limit: int = 16
@export_range(1, 8, 1) var max_background_jobs: int = 4
@export_range(80.0, 640.0, 16.0) var view_distance: float = 160.0
@export_range(1, 128, 1) var max_visible_tiles: int = 32
@export_range(1, 3, 1) var tile_updates_per_frame: int = 1
@export_range(1.0, 8.0, 0.5) var max_tile_work_ms: float = 3.0
@export_range(32.0, 180.0, 8.0) var high_detail_distance: float = 72.0
@export_range(80.0, 320.0, 8.0) var medium_detail_distance: float = 128.0

var _reader
var _tiles: Dictionary = {}
var _desired_tiles: Dictionary = {}
var _pending_tiles: Dictionary = {}
var _material: StandardMaterial3D
var _anchor: Vector3 = Vector3.ZERO
var _anchor_valid: bool = false
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
    _ensure_material()
    var next = ASYNC.new()
    var status: Error = next.open(directory, cache_pages, max_jobs)
    if status != OK:
        next.close()
        _last_error = status
        return status
    _reader = next
    region_directory = directory
    resident_page_limit = cache_pages
    max_background_jobs = max_jobs
    _last_error = OK
    _last_error_page = Vector2i(-1, -1)
    _anchor = Vector3(
        float(_reader.cells.x) * _reader.spacing * 0.5,
        0.0, float(_reader.cells.y) * _reader.spacing * 0.5
    )
    _anchor_valid = true
    _last_sync_msec = -100000
    _sync_tiles()
    set_process(true)
    return OK

func stop_preview() -> void:
    set_process(false)
    for item in _tiles.values():
        var root: Node3D = item["root"]
        if is_instance_valid(root):
            root.free()
    _tiles.clear()
    _desired_tiles.clear()
    _pending_tiles.clear()
    _anchor_valid = false
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
    _build_pending_tiles()
    return {
        "error": _last_error,
        "resident_tiles": _tiles.size(),
        "pending_tiles": _pending_tiles.size(),
        "resident_pages": int(_reader.stats()["resident"])
    }

func _sync_tiles() -> void:
    if _reader == null or not _anchor_valid:
        return
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
    var previous: Dictionary = _desired_tiles
    _desired_tiles = new_desired
    for key in new_desired:
        var level: int = int(new_desired[key])
        if not _tiles.has(key) or int(_tiles[key]["lod"]) != level:
            _pending_tiles[key] = true
        if int(previous.get(key, -1)) != level:
            for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                var adjacent: Vector2i = key + direction
                if _tiles.has(adjacent) and new_desired.has(adjacent):
                    _pending_tiles[adjacent] = true
    for key in _tiles.keys():
        if not new_desired.has(key):
            var root: Node3D = _tiles[key]["root"]
            if is_instance_valid(root):
                root.free()
            _tiles.erase(key)
    for key in _pending_tiles.keys():
        if not new_desired.has(key):
            _pending_tiles.erase(key)

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

func _build_pending_tiles() -> void:
    if _pending_tiles.is_empty():
        return
    var keys: Array = _pending_tiles.keys()
    keys.sort_custom(func(a: Variant, b: Variant) -> bool:
        return LOD.tile_distance(a, float(TILE_CELLS) * _reader.spacing, _anchor) < LOD.tile_distance(b, float(TILE_CELLS) * _reader.spacing, _anchor)
    )
    var max_builds: int = maxi(1, tile_updates_per_frame)
    var submitted: int = 0
    var started: int = Time.get_ticks_usec()
    for key in keys:
        if max_builds <= 0 or float(Time.get_ticks_usec() - started) >= max_tile_work_ms * 1000.0:
            break
        var lod: int = int(_desired_tiles[key])
        var required: Array[Vector2i] = GEOMETRY.required_pages(_reader, key.x, key.y, lod)
        var all_resident: bool = true
        for page in required:
            var state: Error = _reader.page_status(page)
            if state != OK:
                all_resident = false
                if state != ERR_BUSY:
                    _last_error = state
                    _last_error_page = page
                    return
                if submitted < max_background_jobs:
                    var request: Error = _reader.request_page(page)
                    if request != OK and request != ERR_BUSY:
                        _last_error = request
                        _last_error_page = page
                        return
                    if request == OK:
                        submitted += 1
        if not all_resident:
            # Focus only on the nearest pending tile. Otherwise page loads
            # for far tiles can evict this tile's required border samples.
            break
        var generated: Dictionary = GEOMETRY.generate(
            _reader, key.x, key.y, lod, _desired_tiles
        )
        var error: Error = int(generated.get("error", ERR_FILE_CORRUPT))
        if error != OK:
            if error != ERR_BUSY:
                _last_error = error
                _last_error_page = key
            break
        # Fail-closed: don't allocate or replace any visible/collision tile
        # until ALL required Float32 data and geometry arrays are valid.
        if not _tiles.has(key):
            _tiles[key] = _create_tile(key.x, key.y)
        var tile: Dictionary = _tiles[key]
        var mesh: ArrayMesh = ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, generated["arrays"])
        (tile["visual"] as MeshInstance3D).mesh = mesh
        var collision: CollisionShape3D = tile["collision"]
        if lod == 0:
            var shape: HeightMapShape3D = HeightMapShape3D.new()
            shape.map_width = int(generated["width"])
            shape.map_depth = int(generated["width"])
            shape.map_data = generated["collision_heights"]
            collision.shape = shape
        else:
            collision.shape = null
        tile["lod"] = lod
        tile["vertex_count"] = int(generated["vertex_count"])
        _tiles[key] = tile
        _pending_tiles.erase(key)
        _mesh_builds += 1
        _last_build_ms = float(Time.get_ticks_usec() - started) / 1000.0
        _max_build_ms = maxf(_max_build_ms, _last_build_ms)
        max_builds -= 1

func stats() -> Dictionary:
    var source: Dictionary = _reader.stats() if _reader != null else {}
    var vertices: int = 0
    for tile in _tiles.values():
        vertices += int(tile["vertex_count"])
    return {
        "active": _reader != null,
        "tiles": _tiles.size(),
        "pending_tiles": _pending_tiles.size(),
        "vertices": vertices,
        "mesh_builds": _mesh_builds,
        "last_build_ms": _last_build_ms,
        "max_build_ms": _max_build_ms,
        "source": source,
        "last_error": _last_error,
        "last_error_page": _last_error_page,
        "writable": false
    }

## Deliberate read-only API: a paged snapshot must never be saved or sculpted.
func save_data() -> Error:
    return ERR_UNAVAILABLE

func begin_stroke() -> void:
    pass

func paint_at(_world_position: Vector3, _tool: int, _radius: float, _strength: float) -> Error:
    return ERR_UNAVAILABLE
