@tool
class_name TerraForgeTerrain
extends Node3D
## A self-contained, Float32, tiled terrain. Generated children are transient.
const HEIGHT_STORE = preload("res://addons/terra_forge/core/height_store.gd")
const TILE_CELLS: int = 32
const MAX_HISTORY: int = 20

@export_range(32, 2048, 32) var cells_x: int = 256
@export_range(32, 2048, 32) var cells_z: int = 256
@export_range(0.25, 4.0, 0.25) var sample_spacing: float = 1.0
@export_file("*.tfh") var data_file: String = "res://terraforge_data/terrain.tfh"

var height_data
var _tile_nodes: Dictionary = {}
var _dirty_tiles: Dictionary = {}
var _history: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _stroke_before: Dictionary = {}
var _stroke_open: bool = false
var _flatten_target: float = 0.0
var _flatten_target_set: bool = false
var _changed_since_save: bool = false
var _last_edit_time: int = 0
var _last_mesh_time: int = 0
var _terrain_material: StandardMaterial3D

func _ready() -> void:
    height_data = HEIGHT_STORE.new()
    var load_error: Error = height_data.load_file(data_file)
    if load_error != OK:
        height_data.initialize(
            Vector2i(maxi(TILE_CELLS, cells_x), maxi(TILE_CELLS, cells_z)),
            sample_spacing
        )
        if load_error != ERR_FILE_NOT_FOUND:
            push_warning("TerraForge: Cannot open terrain file (%s). Starting a blank temporary preview; do NOT save over the damaged file." % error_string(load_error))
            _changed_since_save = false
    cells_x = height_data.cells.x
    cells_z = height_data.cells.y
    sample_spacing = height_data.spacing
    _terrain_material = StandardMaterial3D.new()
    _terrain_material.vertex_color_use_as_albedo = true
    _terrain_material.roughness = 0.95
    _build_tiles()
    set_process(true)

func _exit_tree() -> void:
    if _changed_since_save and not _stroke_open:
        save_data()

func _process(_delta: float) -> void:
    var now: int = Time.get_ticks_msec()
    if not _dirty_tiles.is_empty() and now - _last_mesh_time >= 90:
        _refresh_dirty_tiles()
        _last_mesh_time = now
    if _changed_since_save and not _stroke_open and now - _last_edit_time >= 2500:
        save_data()

func _tile_key(tx: int, tz: int) -> Vector2i:
    return Vector2i(tx, tz)

func _build_tiles() -> void:
    for key in _tile_nodes.keys():
        var item: Dictionary = _tile_nodes[key]
        var old_node: Node3D = item["root"]
        if is_instance_valid(old_node):
            old_node.free()
    _tile_nodes.clear()
    var nx: int = int(height_data.cells.x / TILE_CELLS)
    var nz: int = int(height_data.cells.y / TILE_CELLS)
    for tz in range(nz):
        for tx in range(nx):
            var root: Node3D = Node3D.new()
            root.name = "TF_Tile_%d_%d" % [tx, tz]
            root.position = Vector3(
                float(tx * TILE_CELLS) * height_data.spacing,
                0.0,
                float(tz * TILE_CELLS) * height_data.spacing
            )
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
            collision.scale = Vector3(height_data.spacing, 1.0, height_data.spacing)
            physics.add_child(collision)
            var item: Dictionary = {"root": root, "visual": visual, "collision": collision}
            _tile_nodes[_tile_key(tx, tz)] = item
            _rebuild_tile(tx, tz, item)

func _rebuild_tile(tx: int, tz: int, item: Dictionary) -> void:
    var width: int = TILE_CELLS + 1
    var vertices: PackedVector3Array = PackedVector3Array()
    var normals: PackedVector3Array = PackedVector3Array()
    var uv: PackedVector2Array = PackedVector2Array()
    var colors: PackedColorArray = PackedColorArray()
    var indices: PackedInt32Array = PackedInt32Array()
    var height_samples: PackedFloat32Array = PackedFloat32Array()
    var step: float = height_data.spacing
    for z in range(width):
        for x in range(width):
            var gx: int = tx * TILE_CELLS + x
            var gz: int = tz * TILE_CELLS + z
            var y: float = height_data.get_height(gx, gz)
            var slope_x: float = (
                height_data.get_height(gx + 1, gz) -
                height_data.get_height(gx - 1, gz)
            ) / (2.0 * step)
            var slope_z: float = (
                height_data.get_height(gx, gz + 1) -
                height_data.get_height(gx, gz - 1)
            ) / (2.0 * step)
            var normal: Vector3 = Vector3(-slope_x, 1.0, -slope_z).normalized()
            var steepness: float = clampf(1.0 - normal.y, 0.0, 1.0)
            var grass: Color = Color(0.27, 0.39, 0.22)
            var stone: Color = Color(0.48, 0.46, 0.41)
            vertices.append(Vector3(float(x) * step, y, float(z) * step))
            normals.append(normal)
            uv.append(Vector2(float(gx), float(gz)) * step * 0.125)
            colors.append(grass.lerp(stone, clampf(steepness * 3.0, 0.0, 1.0)))
            height_samples.append(y)
    for z in range(TILE_CELLS):
        for x in range(TILE_CELLS):
            var a: int = z * width + x
            # Upward-facing triangle winding.
            indices.append(a)
            indices.append(a + width)
            indices.append(a + 1)
            indices.append(a + 1)
            indices.append(a + width)
            indices.append(a + width + 1)
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
    var shape: HeightMapShape3D = HeightMapShape3D.new()
    shape.map_width = width
    shape.map_depth = width
    shape.map_data = height_samples
    var collision: CollisionShape3D = item["collision"]
    collision.shape = shape

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
            var item: Dictionary = _tile_nodes[key]
            _rebuild_tile(key.x, key.y, item)
    _dirty_tiles.clear()

func begin_stroke() -> void:
    if _stroke_open:
        end_stroke()
    _stroke_open = true
    _stroke_before.clear()
    _flatten_target_set = false

func paint_at(global_hit: Vector3, tool: int, brush_radius: float, strength: float) -> void:
    if not _stroke_open:
        return
    var local_hit: Vector3 = to_local(global_hit)
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
    for z in range(low_z, high_z + 1):
        for x in range(low_x, high_x + 1):
            var dist: float = Vector2(float(x) - px, float(z) - pz).length()
            if dist > rs:
                continue
            var falloff: float = pow(1.0 - dist / rs, 2.0)
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
                    var average: float = (
                        height_data.get_height(x - 1, z) +
                        height_data.get_height(x + 1, z) +
                        height_data.get_height(x, z - 1) +
                        height_data.get_height(x, z + 1)
                    ) * 0.25
                    result = lerpf(original, average, clampf(factor * 2.0, 0.0, 1.0))
                3:
                    result = lerpf(original, _flatten_target, clampf(factor, 0.0, 1.0))
            result = clampf(result, -2000.0, 2000.0)
            if absf(result - original) < 0.000001:
                continue
            if not _stroke_before.has(idx):
                _stroke_before[idx] = original
            height_data.heights[idx] = result
            _mark_sample_dirty(x, z)
    if not _stroke_before.is_empty():
        _changed_since_save = true
        _last_edit_time = Time.get_ticks_msec()

func end_stroke() -> void:
    if not _stroke_open:
        return
    _stroke_open = false
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
    var result: Error = height_data.save_file(data_file)
    if result == OK:
        _changed_since_save = false
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
