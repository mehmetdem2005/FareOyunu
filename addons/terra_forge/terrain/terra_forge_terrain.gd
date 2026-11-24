@tool
class_name TerraForgeTerrain
extends Node3D
## A self-contained, Float32, tiled terrain. Generated children are transient.
const HEIGHT_STORE = preload("res://addons/terra_forge/core/height_store.gd")
const LOD_POLICY = preload("res://addons/terra_forge/core/lod_policy.gd")
const BRUSH_SHAPES = preload("res://addons/terra_forge/core/brush_shapes.gd")
const LANDFORM_PATHS = preload("res://addons/terra_forge/core/landform_paths.gd")
const WEATHERING = preload("res://addons/terra_forge/core/thermal_weathering.gd")
const TILE_CELLS: int = 32
const MAX_HISTORY: int = 20

@export_range(32, 2048, 32) var cells_x: int = 256
@export_range(32, 2048, 32) var cells_z: int = 256
@export_range(0.25, 4.0, 0.25) var sample_spacing: float = 1.0
@export_file("*.tfh") var data_file: String = "res://terraforge_data/terrain.tfh"
@export_range(80.0, 640.0, 16.0) var view_distance: float = 224.0
@export_range(32, 256, 8) var max_visible_tiles: int = 96
@export_range(1, 6, 1) var tile_updates_per_frame: int = 2
@export_range(1.0, 8.0, 0.5) var max_tile_work_ms: float = 3.0
@export_range(32.0, 180.0, 8.0) var high_detail_distance: float = 72.0
@export_range(80.0, 320.0, 8.0) var medium_detail_distance: float = 144.0

# Only the explicit "Create Terrain" editor action may initialize a missing
# height file. A reopened scene with a missing .tfh must fail closed instead.
var allow_data_creation: bool = false
var height_data
var _tile_nodes: Dictionary = {}  # Resident tiles only; not all map tiles.
var _desired_tiles: Dictionary = {}  # Keys + selected LOD before any node allocation.
var _dirty_tiles: Dictionary = {}
var _tile_queue: Dictionary = {}
var _stream_anchor: Vector3 = Vector3.ZERO
var _stream_anchor_valid: bool = false
var _last_stream_sync: int = -100000
var _last_stream_camera: Vector3 = Vector3(1000000.0, 0.0, 1000000.0)
var _read_only_source: bool = false
var _source_load_error: Error = OK
var _history: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _stroke_before: Dictionary = {}
var _stroke_open: bool = false
var _stroke_has_sample: bool = false
var _stroke_last_local: Vector3 = Vector3.ZERO
var _flatten_target: float = 0.0
var _flatten_target_set: bool = false
var _ramp_start_set: bool = false
var _ramp_start_local: Vector3 = Vector3.ZERO
var _ramp_end_local: Vector3 = Vector3.ZERO
var _ramp_width: float = 8.0
var _ramp_strength: float = 3.0
var _ramp_rise: float = 5.0
var _path_points: Array[Vector2] = []
var _path_strength: float = 3.0
var _path_radius: float = 8.0
var _path_tool: int = 4
var _path_length: float = 0.0
var _weather_center_set: bool = false
var _weather_center: Vector2 = Vector2.ZERO
var _weather_radius: float = 8.0
var _weather_strength: float = 3.0
var _weather_steps: int = 3
var _tile_builds: int = 0
var _tile_last_ms: float = 0.0
var _tile_max_ms: float = 0.0
var _edit_last_ms: float = 0.0
var _edit_max_ms: float = 0.0
var _changed_since_save: bool = false
var _last_edit_time: int = 0
var _last_mesh_time: int = 0
var _terrain_material: StandardMaterial3D

func _ready() -> void:
    height_data = HEIGHT_STORE.new()
    var load_error: Error = height_data.load_file(data_file)
    _source_load_error = load_error
    if load_error != OK:
        height_data.initialize(
            Vector2i(maxi(TILE_CELLS, cells_x), maxi(TILE_CELLS, cells_z)),
            sample_spacing
        )
        if load_error != ERR_FILE_NOT_FOUND or not allow_data_creation:
            _read_only_source = true
            push_error(
                "TerraForge: Height data is missing or unreadable. This scene is read-only "
                + "to protect the original terrain: " + data_file
            )
    cells_x = height_data.cells.x
    cells_z = height_data.cells.y
    sample_spacing = height_data.spacing
    _terrain_material = StandardMaterial3D.new()
    _terrain_material.vertex_color_use_as_albedo = true
    _terrain_material.roughness = 0.95
    _stream_anchor = Vector3(
        float(height_data.cells.x) * height_data.spacing * 0.5,
        0.0,
        float(height_data.cells.y) * height_data.spacing * 0.5
    )
    _stream_anchor_valid = true
    _sync_resident_tiles()
    set_process(true)

func _exit_tree() -> void:
    if _changed_since_save and not _stroke_open:
        save_data()

func _process(_delta: float) -> void:
    if height_data == null:
        return
    # In a running game, follow the actual scene camera. In the editor,
    # plugin.gd forwards the 3D editor camera explicitly.
    if not Engine.is_editor_hint():
        var scene_camera: Camera3D = get_viewport().get_camera_3d()
        if scene_camera != null:
            set_stream_center(scene_camera.global_position)
    var now: int = Time.get_ticks_msec()
    if now - _last_stream_sync > 220:
        _sync_resident_tiles()
        _last_stream_sync = now
    if not _dirty_tiles.is_empty() and now - _last_mesh_time >= 85:
        _refresh_dirty_tiles()
        _last_mesh_time = now
    _drain_tile_queue()
    if _changed_since_save and not _stroke_open and now - _last_edit_time >= 2500:
        save_data()

func set_stream_center(global_position: Vector3) -> void:
    var local_position: Vector3 = to_local(global_position)
    if not _stream_anchor_valid or _stream_anchor.distance_squared_to(local_position) > 64.0:
        _stream_anchor = local_position
        _stream_anchor_valid = true
        _last_stream_sync = -100000

func _tile_key(tx: int, tz: int) -> Vector2i:
    return Vector2i(tx, tz)

func _create_tile(tx: int, tz: int) -> Dictionary:
    var root: Node3D = Node3D.new()
    root.name = "TF_Tile_%d_%d" % [tx, tz]
    root.position = Vector3(
        float(tx * TILE_CELLS) * height_data.spacing,
        0.0,
        float(tz * TILE_CELLS) * height_data.spacing
    )
    # Internal children never pollute the saved 3D scene or user's scene tree.
    add_child(root, false, Node.INTERNAL_MODE_FRONT)
    var visual: MeshInstance3D = MeshInstance3D.new()
    visual.name = "Visual"
    visual.material_override = _terrain_material
    root.add_child(visual)
    var physics: StaticBody3D = StaticBody3D.new()
    physics.name = "Physics"
    root.add_child(physics)
    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.name = "HeightCollision"
    collision.position = Vector3(
        float(TILE_CELLS) * height_data.spacing * 0.5,
        0.0,
        float(TILE_CELLS) * height_data.spacing * 0.5
    )
    # GodotPhysics3D requires uniform scale. The height map samples
    # are divided by spacing when building the collision shape.
    collision.scale = Vector3.ONE * height_data.spacing
    physics.add_child(collision)
    return {"root": root, "visual": visual, "collision": collision, "lod": -1, "desired_lod": 0}

func _sync_resident_tiles() -> void:
    if not _stream_anchor_valid or height_data == null:
        return
    var candidates: Array[Dictionary] = LOD_POLICY.tile_candidates(
        height_data.cells,
        TILE_CELLS,
        height_data.spacing,
        _stream_anchor,
        view_distance,
        high_detail_distance,
        medium_detail_distance,
        max_visible_tiles
    )
    var desired: Dictionary = {}
    for entry in candidates:
        var key: Vector2i = entry["key"]
        var previous_level: int = int(_desired_tiles.get(key, -1))
        desired[key] = LOD_POLICY.choose_stable_lod(
            float(entry["distance"]),
            high_detail_distance, medium_detail_distance, view_distance,
            previous_level, 8.0
        )

    # Leave allocation for _drain_tile_queue(): the per-frame tile budget
    # must cover creating Nodes *and* mesh/physics work, not just mesh work.
    var previous: Dictionary = _desired_tiles
    _desired_tiles = desired
    for key in desired:
        var level: int = int(desired[key])
        if not _tile_nodes.has(key):
            _tile_queue[key] = true
        else:
            var tile: Dictionary = _tile_nodes[key]
            if int(tile["desired_lod"]) != level:
                tile["desired_lod"] = level
                _tile_queue[key] = true
        if int(previous.get(key, -1)) != level:
            # A changing neighbor LOD changes the seam geometry of the
            # fine tile, even when that fine tile's own LOD stays the same.
            for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                var adjacent: Vector2i = key + offset
                if _tile_nodes.has(adjacent) and desired.has(adjacent):
                    _tile_queue[adjacent] = true

    # Release all geometry, collision, and CPU meshes outside the resident set.
    for key in _tile_nodes.keys():
        if not desired.has(key):
            var tile: Dictionary = _tile_nodes[key]
            var root: Node3D = tile["root"]
            if is_instance_valid(root):
                root.free()
            _tile_nodes.erase(key)

    for key in _tile_queue.keys():
        if not desired.has(key):
            _tile_queue.erase(key)
    _last_stream_camera = _stream_anchor

func _drain_tile_queue() -> void:
    if _tile_queue.is_empty():
        return
    var keys: Array = _tile_queue.keys()
    keys.sort_custom(func(a: Variant, b: Variant) -> bool:
        var da: float = LOD_POLICY.tile_distance(a, float(TILE_CELLS) * height_data.spacing, _stream_anchor)
        var db: float = LOD_POLICY.tile_distance(b, float(TILE_CELLS) * height_data.spacing, _stream_anchor)
        return da < db
    )
    var budget: int = maxi(1, tile_updates_per_frame)
    var start_us: int = Time.get_ticks_usec()
    for key in keys:
        if budget <= 0:
            break
        _tile_queue.erase(key)
        if not _desired_tiles.has(key):
            continue
        if not _tile_nodes.has(key):
            _tile_nodes[key] = _create_tile(key.x, key.y)
        var tile: Dictionary = _tile_nodes[key]
        var level: int = int(_desired_tiles[key])
        tile["desired_lod"] = level
        _rebuild_tile(key.x, key.y, tile, level)
        tile["lod"] = level
        budget -= 1
        # A single tile can exceed the budget; stop *after* that tile so
        # additional rebuilds cannot compound a large frame hitch.
        if float(Time.get_ticks_usec() - start_us) >= max_tile_work_ms * 1000.0:
            break

func get_stream_stats() -> Dictionary:
    var lod_counts: PackedInt32Array = PackedInt32Array([0, 0, 0])
    var resident_vertices: int = 0
    for key in _tile_nodes:
        var tile: Dictionary = _tile_nodes[key]
        var lod: int = int(tile["lod"])
        if lod >= 0 and lod < lod_counts.size():
            lod_counts[lod] += 1
        resident_vertices += int(tile.get("vertex_count", 0))
    return {
        "resident": _tile_nodes.size(), "pending": _tile_queue.size(),
        "lod0": lod_counts[0], "lod1": lod_counts[1], "lod2": lod_counts[2],
        "vertices": resident_vertices, "builds": _tile_builds,
        "tile_last_ms": _tile_last_ms, "tile_max_ms": _tile_max_ms,
        "edit_last_ms": _edit_last_ms, "edit_max_ms": _edit_max_ms
    }

func set_quality_profile(profile: int) -> void:
    match profile:
        0: # Low-end Android
            view_distance = 160.0
            max_visible_tiles = 64
            high_detail_distance = 56.0
            medium_detail_distance = 104.0
            tile_updates_per_frame = 1
            max_tile_work_ms = 2.5
        1: # Balanced Android (default)
            view_distance = 224.0
            max_visible_tiles = 96
            high_detail_distance = 72.0
            medium_detail_distance = 144.0
            tile_updates_per_frame = 2
            max_tile_work_ms = 4.0
        2: # Higher-end devices
            view_distance = 320.0
            max_visible_tiles = 160
            high_detail_distance = 112.0
            medium_detail_distance = 208.0
            tile_updates_per_frame = 3
            max_tile_work_ms = 6.0
    _last_stream_sync = -100000

func _seam_height(tx: int, tz: int, sample_x: int, sample_z: int, lod: int) -> float:
    # Match the coarse neighbor's straight edge exactly, with no protruding
    # dark/gray skirt geometry. All tiles share the same Float32 source.
    var gx: int = tx * TILE_CELLS + sample_x
    var gz: int = tz * TILE_CELLS + sample_z
    var original: float = height_data.get_height(gx, gz)
    var neighbor: Vector2i = Vector2i(-1000000, -1000000)
    var along: int = 0
    var horizontal: bool = false
    if sample_x == 0:
        neighbor = Vector2i(tx - 1, tz)
        along = sample_z
    elif sample_x == TILE_CELLS:
        neighbor = Vector2i(tx + 1, tz)
        along = sample_z
    elif sample_z == 0:
        neighbor = Vector2i(tx, tz - 1)
        along = sample_x
        horizontal = true
    elif sample_z == TILE_CELLS:
        neighbor = Vector2i(tx, tz + 1)
        along = sample_x
        horizontal = true
    if not _desired_tiles.has(neighbor):
        return original
    var neighbor_lod: int = int(_desired_tiles[neighbor])
    if neighbor_lod <= lod:
        return original
    var coarse_step: int = LOD_POLICY.sample_stride(neighbor_lod)
    var start_along: int = int(along / coarse_step) * coarse_step
    if start_along == along:
        return original
    var end_along: int = mini(TILE_CELLS, start_along + coarse_step)
    var start_height: float
    var end_height: float
    if horizontal:
        start_height = height_data.get_height(tx * TILE_CELLS + start_along, gz)
        end_height = height_data.get_height(tx * TILE_CELLS + end_along, gz)
    else:
        start_height = height_data.get_height(gx, tz * TILE_CELLS + start_along)
        end_height = height_data.get_height(gx, tz * TILE_CELLS + end_along)
    return lerpf(start_height, end_height, float(along - start_along) / float(end_along - start_along))

func _rebuild_tile(tx: int, tz: int, item: Dictionary, lod: int) -> void:
    var build_start_us: int = Time.get_ticks_usec()
    var stride: int = LOD_POLICY.sample_stride(lod)
    var width: int = int(TILE_CELLS / stride) + 1
    var vertices: PackedVector3Array = PackedVector3Array()
    var normals: PackedVector3Array = PackedVector3Array()
    var uv: PackedVector2Array = PackedVector2Array()
    var colors: PackedColorArray = PackedColorArray()
    var indices: PackedInt32Array = PackedInt32Array()
    var height_samples: PackedFloat32Array = PackedFloat32Array()
    var step: float = height_data.spacing
    for z in range(width):
        for x in range(width):
            var sx: int = x * stride
            var sz: int = z * stride
            var gx: int = tx * TILE_CELLS + sx
            var gz: int = tz * TILE_CELLS + sz
            var y: float = _seam_height(tx, tz, sx, sz, lod)
            vertices.append(Vector3(float(sx) * step, y, float(sz) * step))
            normals.append(Vector3.UP)
            uv.append(Vector2(float(gx), float(gz)) * step * 0.125)
            colors.append(Color.WHITE)
            height_samples.append(y / step)
    # Compute normals from the *rendered* edge-adjusted vertex heights.
    # Using the original Float32 height samples here gave incorrect shading
    # at mixed-LOD seams whenever the visible edge had been interpolated.
    var cell_world: float = step * float(stride)
    var grass: Color = Color(0.27, 0.39, 0.22)
    var stone: Color = Color(0.48, 0.46, 0.41)
    var west_same: bool = int(_desired_tiles.get(Vector2i(tx - 1, tz), -1)) == lod
    var east_same: bool = int(_desired_tiles.get(Vector2i(tx + 1, tz), -1)) == lod
    var north_same: bool = int(_desired_tiles.get(Vector2i(tx, tz - 1), -1)) == lod
    var south_same: bool = int(_desired_tiles.get(Vector2i(tx, tz + 1), -1)) == lod
    for z in range(width):
        for x in range(width):
            var i: int = z * width + x
            var west: int = maxi(0, x - 1)
            var east: int = mini(width - 1, x + 1)
            var north: int = maxi(0, z - 1)
            var south: int = mini(width - 1, z + 1)
            var dx: float = (
                vertices[z * width + east].y - vertices[z * width + west].y
            ) / (float(east - west) * cell_world)
            var dz: float = (
                vertices[south * width + x].y - vertices[north * width + x].y
            ) / (float(south - north) * cell_world)
            # When the neighbor has the same LOD, use centered gradients
            # across the actual shared edge. One-sided tile-edge gradients
            # gave a visible lighting seam even with identical vertices.
            var global_x: int = tx * TILE_CELLS + x * stride
            var global_z: int = tz * TILE_CELLS + z * stride
            if x == 0 and west_same:
                dx = (vertices[i + 1].y - height_data.get_height(global_x - stride, global_z)) / (2.0 * cell_world)
            elif x == width - 1 and east_same:
                dx = (height_data.get_height(global_x + stride, global_z) - vertices[i - 1].y) / (2.0 * cell_world)
            if z == 0 and north_same:
                dz = (vertices[i + width].y - height_data.get_height(global_x, global_z - stride)) / (2.0 * cell_world)
            elif z == width - 1 and south_same:
                dz = (height_data.get_height(global_x, global_z + stride) - vertices[i - width].y) / (2.0 * cell_world)
            var normal: Vector3 = Vector3(-dx, 1.0, -dz).normalized()
            normals[i] = normal
            colors[i] = grass.lerp(stone, clampf((1.0 - normal.y) * 3.0, 0.0, 1.0))
    for z in range(width - 1):
        for x in range(width - 1):
            var a: int = z * width + x
            # Godot uses clockwise front faces. Viewed from above,
            # a -> +X -> +Z faces upward; the old order was backface-culled.
            indices.append(a)
            indices.append(a + 1)
            indices.append(a + width)
            indices.append(a + 1)
            indices.append(a + width + 1)
            indices.append(a + width)
    # No continuous skirts: they were visible as ugly square walls on flat
    # ground. Edge samples now conform to the neighboring coarser tile.
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var new_mesh: ArrayMesh = ArrayMesh.new()
    new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var visual: MeshInstance3D = item["visual"]
    visual.mesh = new_mesh

    # Only LOD0 tiles have physics. Uniform scale is required by GodotPhysics3D.
    var collision: CollisionShape3D = item["collision"]
    if lod == 0:
        var shape: HeightMapShape3D = HeightMapShape3D.new()
        shape.map_width = width
        shape.map_depth = width
        shape.map_data = height_samples
        collision.shape = shape
    else:
        collision.shape = null
    item["vertex_count"] = vertices.size()
    _tile_builds += 1
    _tile_last_ms = float(Time.get_ticks_usec() - build_start_us) / 1000.0
    _tile_max_ms = maxf(_tile_max_ms, _tile_last_ms)

func _mark_rect_dirty(low_x: int, low_z: int, high_x: int, high_z: int) -> void:
    # Include a one-sample halo: adjacent mesh normals and tile borders
    # share height values even when vertices lie just outside the brush.
    var max_x: int = int(height_data.cells.x / TILE_CELLS) - 1
    var max_z: int = int(height_data.cells.y / TILE_CELLS) - 1
    var tx0: int = clampi(floori(float(low_x - 1) / float(TILE_CELLS)), 0, max_x)
    var tx1: int = clampi(floori(float(high_x) / float(TILE_CELLS)), 0, max_x)
    var tz0: int = clampi(floori(float(low_z - 1) / float(TILE_CELLS)), 0, max_z)
    var tz1: int = clampi(floori(float(high_z) / float(TILE_CELLS)), 0, max_z)
    for tz in range(tz0, tz1 + 1):
        for tx in range(tx0, tx1 + 1):
            _dirty_tiles[Vector2i(tx, tz)] = true

func _mark_sample_dirty(x: int, z: int) -> void:
    var tx1: int = floori(float(x) / float(TILE_CELLS))
    var tz1: int = floori(float(z) / float(TILE_CELLS))
    var tx0: int = floori(float(x - 1) / float(TILE_CELLS))
    var tz0: int = floori(float(z - 1) / float(TILE_CELLS))
    var max_x: int = int(height_data.cells.x / TILE_CELLS)
    var max_z: int = int(height_data.cells.y / TILE_CELLS)
    for tz in range(tz0, tz1 + 1):
        for tx in range(tx0, tx1 + 1):
            if tx >= 0 and tz >= 0 and tx < max_x and tz < max_z:
                _dirty_tiles[_tile_key(tx, tz)] = true

func _refresh_dirty_tiles() -> void:
    for key in _dirty_tiles.keys():
        if _tile_nodes.has(key):
            _tile_queue[key] = true
    _dirty_tiles.clear()

func begin_stroke() -> void:
    if _stroke_open:
        end_stroke()
    _stroke_open = true
    _stroke_before.clear()
    _stroke_has_sample = false
    _stroke_last_local = Vector3.ZERO
    _flatten_target_set = false
    _ramp_start_set = false
    _ramp_start_local = Vector3.ZERO
    _ramp_end_local = Vector3.ZERO
    _path_points.clear()
    _path_length = 0.0
    _weather_center_set = false
    _weather_center = Vector2.ZERO

func paint_at(
        global_hit: Vector3,
        tool: int,
        brush_radius: float,
        strength: float,
        stamp_preset: int = 0,
        ramp_rise: float = 5.0
    ) -> void:
    if not _stroke_open or _read_only_source or height_data == null:
        return
    # Unit tests may operate on an off-tree terrain. Node3D.to_local()
    # uses the global transform and emits engine errors before _enter_tree().
    # The local transform is mathematically equivalent for a root node.
    var local_hit: Vector3 = (
        to_local(global_hit)
        if is_inside_tree()
        else transform.affine_inverse() * global_hit
    )
    if tool == 4 or tool == 5:
        var point: Vector2 = Vector2(local_hit.x, local_hit.z)
        var threshold: float = maxf(0.6, brush_radius * 0.3)
        if _path_points.is_empty():
            _path_points.append(point)
        else:
            var last: Vector2 = _path_points.back()
            var distance: float = last.distance_to(point)
            if distance >= threshold and _path_points.size() < LANDFORM_PATHS.MAX_POINTS and _path_length < LANDFORM_PATHS.MAX_LENGTH:
                var available: float = LANDFORM_PATHS.MAX_LENGTH - _path_length
                var offset: Vector2 = (point - last).limit_length(available)
                _path_points.append(last + offset)
                _path_length += offset.length()
        _path_radius = brush_radius
        _path_strength = strength
        _path_tool = tool
        return
    if tool == 8:
        if not _weather_center_set:
            _weather_center = Vector2(local_hit.x, local_hit.z)
            _weather_center_set = true
            _weather_radius = brush_radius
            _weather_strength = strength
            _weather_steps = clampi(int(round(ramp_rise)), 1, 6)
        return
    if tool == BRUSH_SHAPES.TOOL_RAMP:
        # Drag to set endpoints; apply one corridor when the finger lifts.
        # This keeps one ramp = one undo action and avoids repeatedly
        # mutating the same pixels on high-frequency touch events.
        if not _ramp_start_set:
            _ramp_start_local = local_hit
            _ramp_start_set = true
        _ramp_end_local = local_hit
        _ramp_width = brush_radius
        _ramp_strength = strength
        _ramp_rise = ramp_rise
        return

    var cursor: Vector2 = Vector2(local_hit.x, local_hit.z)
    if not _stroke_has_sample:
        _stroke_last_local = local_hit
        _stroke_has_sample = true
        _apply_stamp(local_hit, tool, brush_radius, strength, stamp_preset)
        return
    if tool == BRUSH_SHAPES.TOOL_STAMP:
        # Procedural stamps are placed once per touch, not sprayed.
        return
    # Fixed distance sampling: device touch-event frequency does not change
    # how many bumps are applied along a ridge or valley.
    var step_size: float = maxf(0.25, brush_radius * 0.2)
    var previous: Vector2 = Vector2(_stroke_last_local.x, _stroke_last_local.z)
    var distance: float = previous.distance_to(cursor)
    if distance < step_size:
        return
    var direction: Vector2 = (cursor - previous) / distance
    var count: int = mini(96, floori(distance / step_size))
    for i in range(count):
        var point: Vector2 = previous + direction * step_size * float(i + 1)
        var stamp: Vector3 = Vector3(point.x, local_hit.y, point.y)
        _apply_stamp(stamp, tool, brush_radius, strength, stamp_preset)
        _stroke_last_local = stamp

func _apply_stamp(local_hit: Vector3, tool: int, brush_radius: float, strength: float, stamp_preset: int = 0) -> void:
    var px: float = local_hit.x / height_data.spacing
    var pz: float = local_hit.z / height_data.spacing
    var rs: float = maxf(0.5, brush_radius / height_data.spacing)
    if px < -rs or pz < -rs or px > float(height_data.cells.x) + rs or pz > float(height_data.cells.y) + rs:
        return
    if tool == 3 and not _flatten_target_set:
        _flatten_target = height_data.sample_local(local_hit.x, local_hit.z)
        _flatten_target_set = true
    var low_x: int = clampi(floori(px - rs), 0, height_data.cells.x)
    var high_x: int = clampi(ceili(px + rs), 0, height_data.cells.x)
    var low_z: int = clampi(floori(pz - rs), 0, height_data.cells.y)
    var high_z: int = clampi(ceili(pz + rs), 0, height_data.cells.y)
    # Smooth uses one immutable neighborhood snapshot per stamp. Updating
    # neighbors in scan order used to bias smoothing toward +X/+Z.
    var snapshot: PackedFloat32Array = PackedFloat32Array()
    var snap_width: int = high_x - low_x + 3
    var snap_height: int = high_z - low_z + 3
    if tool == 2:
        snapshot.resize(snap_width * snap_height)
        for zz in range(snap_height):
            for xx in range(snap_width):
                snapshot[zz * snap_width + xx] = height_data.get_height(
                    low_x + xx - 1, low_z + zz - 1
                )
    var stamp_noise: FastNoiseLite
    if tool == BRUSH_SHAPES.TOOL_STAMP:
        stamp_noise = FastNoiseLite.new()
        stamp_noise.seed = 137
        stamp_noise.frequency = 1.0 / maxf(12.0, brush_radius * 1.7)
        stamp_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
        stamp_noise.fractal_octaves = 2
    var changed_any: bool = false
    for z in range(low_z, high_z + 1):
        for x in range(low_x, high_x + 1):
            var dist: float = Vector2(float(x) - px, float(z) - pz).length()
            if dist > rs:
                continue
            var normalized_distance: float = dist / rs
            var falloff: float = pow(1.0 - normalized_distance, 2.0)
            var factor: float = maxf(0.0, strength) * falloff * 0.06
            var idx: int = height_data.index_of(x, z)
            var original: float = height_data.heights[idx]
            var result: float = original
            match tool:
                0:
                    result += factor
                1:
                    result -= factor
                2:
                    var local_x: int = x - low_x + 1
                    var local_z: int = z - low_z + 1
                    var center_old: float = snapshot[local_z * snap_width + local_x]
                    var samples: Array[float] = [
                        snapshot[local_z * snap_width + local_x - 1],
                        snapshot[local_z * snap_width + local_x + 1],
                        snapshot[(local_z - 1) * snap_width + local_x],
                        snapshot[(local_z + 1) * snap_width + local_x]
                    ]
                    var plain_sum: float = 0.0
                    var weighted_sum: float = 0.0
                    var total_weight: float = 0.0
                    var height_sigma: float = maxf(1.0, strength * 1.1)
                    for neighbor in samples:
                        plain_sum += neighbor
                        var deviation: float = (neighbor - center_old) / height_sigma
                        var weight: float = exp(-0.5 * deviation * deviation)
                        weighted_sum += neighbor * weight
                        total_weight += weight
                    var plain_average: float = plain_sum * 0.25
                    var bilateral_average: float = weighted_sum / maxf(0.00001, total_weight)
                    var target: float = lerpf(plain_average, bilateral_average, 0.55)
                    result = lerpf(original, target, clampf(factor * 2.0, 0.0, 1.0))
                3:
                    result = lerpf(original, _flatten_target, clampf(factor, 0.0, 1.0))
                7: # Asymmetric, coherently warped procedural Stamp.
                    result += maxf(0.0, strength) * 0.8 * BRUSH_SHAPES.organic_stamp(
                        stamp_preset, Vector2(float(x), float(z)) * height_data.spacing,
                        Vector2(local_hit.x, local_hit.z), brush_radius, stamp_noise
                    )
                _:
                    return
            result = clampf(result, -2000.0, 2000.0)
            if absf(result - original) < 0.000001:
                continue
            if not _stroke_before.has(idx):
                _stroke_before[idx] = original
            height_data.heights[idx] = result
            changed_any = true
    if changed_any:
        _mark_rect_dirty(low_x, low_z, high_x, high_z)
        _changed_since_save = true
        _last_edit_time = Time.get_ticks_msec()

func _apply_height_changes(changes: Dictionary) -> void:
    var width: int = height_data.cells.x + 1
    for raw_index in changes:
        var idx: int = int(raw_index)
        var previous: float = height_data.heights[idx]
        var updated: float = clampf(float(changes[raw_index]), -2000.0, 2000.0)
        if absf(updated - previous) <= 0.000001:
            continue
        if not _stroke_before.has(idx):
            _stroke_before[idx] = previous
        height_data.heights[idx] = updated
        _mark_sample_dirty(idx % width, int(idx / width))
    if not _stroke_before.is_empty():
        _changed_since_save = true
        _last_edit_time = Time.get_ticks_msec()

func _commit_landform() -> void:
    if _path_points.is_empty() or _read_only_source:
        return
    var before_us: int = Time.get_ticks_usec()
    var changes: Dictionary = LANDFORM_PATHS.build(
        height_data, _path_points, _path_radius, _path_strength, _path_tool == 5
    )
    _apply_height_changes(changes)
    _edit_last_ms = float(Time.get_ticks_usec() - before_us) / 1000.0
    _edit_max_ms = maxf(_edit_max_ms, _edit_last_ms)

func _commit_weathering() -> void:
    if not _weather_center_set or _read_only_source:
        return
    var before_us: int = Time.get_ticks_usec()
    var changes: Dictionary = WEATHERING.build(
        height_data,
        _weather_center,
        minf(_weather_radius, WEATHERING.MAX_RADIUS_METERS),
        _weather_steps,
        clampf(_weather_strength / 8.0, 0.0, 1.0)
    )
    _apply_height_changes(changes)
    _edit_last_ms = float(Time.get_ticks_usec() - before_us) / 1000.0
    _edit_max_ms = maxf(_edit_max_ms, _edit_last_ms)

func _commit_ramp() -> void:
    if not _ramp_start_set or _read_only_source:
        return
    var start: Vector2 = Vector2(_ramp_start_local.x, _ramp_start_local.z)
    var finish: Vector2 = Vector2(_ramp_end_local.x, _ramp_end_local.z)
    var run: Vector2 = finish - start
    var length: float = run.length()
    if length < height_data.spacing:
        return
    # Limit a single expensive main-thread edit on mobile devices.
    if length > 256.0:
        run = run / length * 256.0
        finish = start + run
        length = 256.0
    var radius: float = maxf(0.5, _ramp_width)
    var spacing: float = height_data.spacing
    var min_x: int = clampi(floori((minf(start.x, finish.x) - radius) / spacing), 0, height_data.cells.x)
    var max_x: int = clampi(ceili((maxf(start.x, finish.x) + radius) / spacing), 0, height_data.cells.x)
    var min_z: int = clampi(floori((minf(start.y, finish.y) - radius) / spacing), 0, height_data.cells.y)
    var max_z: int = clampi(ceili((maxf(start.y, finish.y) + radius) / spacing), 0, height_data.cells.y)
    var begin_height: float = height_data.sample_local(start.x, start.y)
    var end_height: float = height_data.sample_local(finish.x, finish.y) + _ramp_rise
    var length_squared: float = run.length_squared()
    var intensity: float = clampf(_ramp_strength / 3.0, 0.0, 1.0)
    for z in range(min_z, max_z + 1):
        for x in range(min_x, max_x + 1):
            var sample: Vector2 = Vector2(float(x) * spacing, float(z) * spacing)
            var fraction: float = clampf((sample - start).dot(run) / length_squared, 0.0, 1.0)
            var closest: Vector2 = start + run * fraction
            var radial: float = sample.distance_to(closest) / radius
            if radial >= 1.0:
                continue
            var influence: float = BRUSH_SHAPES.blend(radial) * intensity
            if influence < 0.000001:
                continue
            var idx: int = height_data.index_of(x, z)
            var original: float = height_data.heights[idx]
            var target_height: float = lerpf(begin_height, end_height, fraction)
            var next_height: float = clampf(lerpf(original, target_height, influence), -2000.0, 2000.0)
            if absf(original - next_height) < 0.000001:
                continue
            if not _stroke_before.has(idx):
                _stroke_before[idx] = original
            height_data.heights[idx] = next_height
            _mark_sample_dirty(x, z)
    if not _stroke_before.is_empty():
        _changed_since_save = true
        _last_edit_time = Time.get_ticks_msec()

func end_stroke() -> void:
    if not _stroke_open:
        return
    if _ramp_start_set:
        _commit_ramp()
    if not _path_points.is_empty():
        _commit_landform()
    if _weather_center_set:
        _commit_weathering()
    _ramp_start_set = false
    _weather_center_set = false
    _path_points.clear()
    _path_length = 0.0
    _stroke_open = false
    _stroke_has_sample = false
    _stroke_last_local = Vector3.ZERO
    if not _stroke_before.is_empty():
        var indexes: PackedInt32Array = PackedInt32Array()
        var before: PackedFloat32Array = PackedFloat32Array()
        var after: PackedFloat32Array = PackedFloat32Array()
        for idx in _stroke_before.keys():
            indexes.append(int(idx))
            before.append(float(_stroke_before[idx]))
            after.append(height_data.heights[int(idx)])
        _history.append({"indices": indexes, "before": before, "after": after})
        if _history.size() > MAX_HISTORY:
            _history.remove_at(0)
        _redo.clear()
    _stroke_before.clear()
    _refresh_dirty_tiles()
    _last_edit_time = Time.get_ticks_msec()

func _apply_history(record: Dictionary, use_after: bool) -> void:
    var indexes: PackedInt32Array = record["indices"]
    var values: PackedFloat32Array = record["after"] if use_after else record["before"]
    var stride: int = height_data.cells.x + 1
    for i in range(indexes.size()):
        var idx: int = indexes[i]
        height_data.heights[idx] = values[i]
        _mark_sample_dirty(idx % stride, int(idx / stride))
    _refresh_dirty_tiles()
    _changed_since_save = true
    _last_edit_time = Time.get_ticks_msec()

func undo_stroke() -> void:
    if _stroke_open:
        end_stroke()
    if _history.is_empty():
        return
    var record: Dictionary = _history.pop_back()
    _apply_history(record, false)
    _redo.append(record)

func redo_stroke() -> void:
    if _stroke_open:
        end_stroke()
    if _redo.is_empty():
        return
    var record: Dictionary = _redo.pop_back()
    _apply_history(record, true)
    _history.append(record)

func save_data() -> Error:
    if height_data == null:
        return ERR_UNCONFIGURED
    if _read_only_source:
        return _source_load_error
    var result: Error = height_data.save_file(data_file)
    if result == OK:
        _changed_since_save = false
        _source_load_error = OK
        allow_data_creation = false
    else:
        push_error("TerraForge: Cannot save %s: %s" % [data_file, error_string(result)])
    return result

func find_surface_from_ray(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
    # Intersection is based on canonical height values, not stale editor collision.
    var local_origin: Vector3 = to_local(ray_origin)
    var local_direction: Vector3 = (to_local(ray_origin + ray_direction) - local_origin).normalized()
    var step_size: float = maxf(0.5, height_data.spacing * 2.0)
    var prev_distance: float = 0.0
    var previous: Vector3 = local_origin
    for i in range(1, 1001):
        var dist: float = float(i) * step_size
        var p: Vector3 = local_origin + local_direction * dist
        if p.x >= 0.0 and p.z >= 0.0 and p.x <= height_data.cells.x * height_data.spacing and p.z <= height_data.cells.y * height_data.spacing:
            if p.y <= height_data.sample_local(p.x, p.z) and previous.y >= height_data.sample_local(
                clampf(previous.x, 0.0, height_data.cells.x * height_data.spacing),
                clampf(previous.z, 0.0, height_data.cells.y * height_data.spacing)
            ):
                var lo: float = prev_distance
                var hi: float = dist
                for j in range(10):
                    var mid: float = (lo + hi) * 0.5
                    var test: Vector3 = local_origin + local_direction * mid
                    if test.y > height_data.sample_local(test.x, test.z):
                        lo = mid
                    else:
                        hi = mid
                var hit: Vector3 = local_origin + local_direction * hi
                return {"hit": true, "position": to_global(hit)}
        previous = p
        prev_distance = dist
    return {"hit": false}
