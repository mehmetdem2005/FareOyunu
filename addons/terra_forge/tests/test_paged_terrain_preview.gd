@tool
extends SceneTree
## P1.3: actual opt-in ArrayMesh + HeightMapShape3D from immutable TFR1,
## parity with the legacy terrain at all LODs and mixed-LOD borders.
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const EXPORT = preload("res://addons/terra_forge/core/region_export.gd")
const OLD_TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const BUILDER = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")

func _fail(message: String, preview: Node = null, legacy: Node = null) -> void:
    if preview != null:
        preview.free()
    if legacy != null:
        legacy.free()
    push_error("Paged terrain preview: " + message)
    quit(1)

func _ensure_pages(reader, pages: Array[Vector2i]) -> bool:
    for frame in range(1600):
        reader.poll_results(4)
        var ready: bool = true
        for page in pages:
            var status: Error = reader.page_status(page)
            if status == ERR_BUSY:
                ready = false
                var request: Error = reader.request_page(page)
                if request != OK and request != ERR_BUSY:
                    return false
            elif status != OK:
                return false
        if ready:
            return true
        OS.delay_msec(1)
    return false

func _check_geometry(ref_terrain, source, tx: int, tz: int, lod: int,
        desired: Dictionary) -> bool:
    if not _ensure_pages(source, BUILDER.required_pages(source, tx, tz, lod)):
        return false
    var built: Dictionary = BUILDER.generate(source, tx, tz, lod, desired)
    if int(built.get("error", -1)) != OK:
        return false
    ref_terrain._desired_tiles = desired
    var base_tile: Dictionary = ref_terrain._create_tile(tx, tz)
    ref_terrain._rebuild_tile(tx, tz, base_tile, lod)
    var old_arrays: Array = (base_tile["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
    var regional_arrays: Array = built["arrays"]
    var old_vertices: PackedVector3Array = old_arrays[Mesh.ARRAY_VERTEX]
    var new_vertices: PackedVector3Array = regional_arrays[Mesh.ARRAY_VERTEX]
    var old_normals: PackedVector3Array = old_arrays[Mesh.ARRAY_NORMAL]
    var new_normals: PackedVector3Array = regional_arrays[Mesh.ARRAY_NORMAL]
    var old_indices: PackedInt32Array = old_arrays[Mesh.ARRAY_INDEX]
    var new_indices: PackedInt32Array = regional_arrays[Mesh.ARRAY_INDEX]
    if old_vertices.size() != new_vertices.size() or old_indices != new_indices:
        return false
    for i in range(old_vertices.size()):
        if old_vertices[i].distance_to(new_vertices[i]) > 0.00002:
            return false
        if old_normals[i].distance_to(new_normals[i]) > 0.00002:
            return false
    if lod == 0:
        var old_shape: HeightMapShape3D = (base_tile["collision"] as CollisionShape3D).shape
        var new_heights: PackedFloat32Array = built["collision_heights"]
        if old_shape.map_width != int(built["width"]) or old_shape.map_data.size() != new_heights.size():
            return false
        for i in range(new_heights.size()):
            if absf(old_shape.map_data[i] - new_heights[i]) > 0.00002:
                return false
    elif not (built["collision_heights"] as PackedFloat32Array).is_empty():
        return false
    return true

func _initialize() -> void:
    var stamp: String = str(Time.get_ticks_usec())
    var source_path: String = "user://tf_preview_" + stamp + ".tfh"
    var world: String = "user://tf_preview_" + stamp + "_world"
    var original = STORE.new()
    original.initialize(Vector2i(96, 96), 0.5)
    for z in range(97):
        for x in range(97):
            original.heights[original.index_of(x, z)] = (
                0.01 * float(x * x) + 0.03 * float(z * z)
                + sin(float(x) * 0.2) * cos(float(z) * 0.17) * 1.25
            )
    if original.save_file(source_path) != OK:
        _fail("Could not create legacy Float32 sample world")
        return
    var saved_sha: String = FileAccess.get_sha256(source_path)
    var result: Dictionary = EXPORT.export_file(source_path, world, 2)
    if result.get("error", ERR_FILE_CORRUPT) != OK:
        _fail("Could not export immutable regional world")
        return

    var preview = PREVIEW.new()
    if preview.preview_enabled:
        _fail("Regional rendering must be opt-in, not default", preview)
        return
    if preview.start_preview(world, 16, 3) != OK:
        _fail("Could not start read-only regional preview", preview)
        return
    if preview.stats()["writable"] or preview.save_data() != ERR_UNAVAILABLE:
        _fail("Preview was unexpectedly editable/writable", preview)
        return
    if preview.paint_at(Vector3.ZERO, 0, 8.0, 2.0) != ERR_UNAVAILABLE:
        _fail("Sculpting was unexpectedly available", preview)
        return
    # Place camera near the origin so LOD0 tile 0,0 is prioritized.
    preview.set_stream_center(Vector3(8.0, 4.0, 8.0))
    var tile_key: Vector2i = Vector2i.ZERO
    var drawn: bool = false
    for frame in range(1800):
        preview.pump_stream()
        if preview._tiles.has(tile_key):
            drawn = true
            break
        OS.delay_msec(1)
    if not drawn:
        _fail("Async regional pages did not produce a real ArrayMesh tile", preview)
        return
    var tile: Dictionary = preview._tiles[tile_key]
    var visible: MeshInstance3D = tile["visual"]
    var collision: CollisionShape3D = tile["collision"]
    if visible.mesh == null or visible.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() != 1089:
        _fail("Read-only mesh was not actual 33x33 LOD0 geometry", preview)
        return
    var shape: HeightMapShape3D = collision.shape
    if shape == null or shape.map_width != 33 or shape.map_depth != 33:
        _fail("Read-only regional terrain did not create LOD0 HeightMapShape3D", preview)
        return
    if preview._reader.stats()["resident"] > 16 or preview._reader.stats()["resident_float_bytes"] > 16 * 4096:
        _fail("Mesh creation exceeded read-only page RAM ceiling", preview)
        return

    var legacy = OLD_TERRAIN.new()
    legacy.height_data = STORE.new()
    legacy.height_data.initialize(original.cells, original.spacing)
    legacy.height_data.heights = original.heights.duplicate()
    legacy._terrain_material = StandardMaterial3D.new()

    # Parity for three LODs, one shared same-LOD edge, mixed-LOD
    # interpolation and 4-corner region boundary samples.
    for lod in [0, 1, 2]:
        var desired: Dictionary = {Vector2i(0, 0): lod, Vector2i(1, 0): lod, Vector2i(0, 1): lod}
        if not _check_geometry(legacy, preview._reader, 0, 0, lod, desired):
            _fail("Float32 vertices/normals/collision disagree at LOD " + str(lod), preview, legacy)
            return
    var seam: Dictionary = {Vector2i(0, 0): 0, Vector2i(1, 0): 2}
    if not _check_geometry(legacy, preview._reader, 0, 0, 0, seam):
        _fail("LOD0-to-LOD2 seam not identical to legacy", preview, legacy)
        return
    # The preview node itself must render the same tile as the old builder.
    legacy._desired_tiles = preview._desired_tiles
    var first_tile: Dictionary = legacy._create_tile(0, 0)
    legacy._rebuild_tile(0, 0, first_tile, int(tile["lod"]))
    var regional: Array = visible.mesh.surface_get_arrays(0)
    var old: Array = (first_tile["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
    var points: PackedVector3Array = regional[Mesh.ARRAY_VERTEX]
    var old_points: PackedVector3Array = old[Mesh.ARRAY_VERTEX]
    for i in range(points.size()):
        if points[i].distance_to(old_points[i]) > 0.00002:
            _fail("Visible preview node does not match legacy ArrayMesh", preview, legacy)
            return

    # Cold corrupted page: after open but before first visible tile, the
    # read-only preview must not allocate blank mesh or collision.
    preview.stop_preview()
    legacy.free()
    var broken = PREVIEW.new()
    if broken.start_preview(world, 16, 2) != OK:
        _fail("Could not reopen intact regional fixture", broken)
        return
    broken.set_stream_center(Vector3(8.0, 4.0, 8.0))
    var page_path: String = world + "/r_00000_00000.tfr"
    var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(page_path)
    var corrupt: FileAccess = FileAccess.open(page_path, FileAccess.READ_WRITE)
    corrupt.seek(30)
    var before: int = corrupt.get_8()
    corrupt.seek(30)
    corrupt.store_8(before ^ 1)
    corrupt.flush()
    corrupt.close()
    var failure_seen: bool = false
    for frame in range(1200):
        broken.pump_stream()
        if int(broken.stats()["last_error"]) == ERR_FILE_CORRUPT:
            failure_seen = true
            break
        OS.delay_msec(1)
    if not failure_seen or broken._tiles.has(Vector2i.ZERO):
        _fail("A corrupt regional source fabricated a visible terrain tile", broken)
        return
    if FileAccess.get_sha256(source_path) != saved_sha:
        _fail("Regional preview modified the original TFH source", broken)
        return
    broken.stop_preview()
    var restored: FileAccess = FileAccess.open(page_path, FileAccess.WRITE)
    restored.store_buffer(original_bytes)
    restored.close()
    broken.free()
    preview.free()
    var unavailable = PREVIEW.new()
    if unavailable.start_preview(world + "_missing", 16, 2) != ERR_FILE_NOT_FOUND:
        _fail("A nonexistent world unexpectedly created flat terrain", unavailable)
        return
    unavailable.free()
    print("PASS: opt-in paged ArrayMesh/HeightMapShape3D, Float32 LOD0/1/2 normals and fail-closed corrupt tile")
    quit(0)
