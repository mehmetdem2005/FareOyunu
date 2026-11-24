@tool
extends SceneTree
## Missing nearest page cannot starve unrelated tiles or erase last-good collision.
const HEIGHT = preload("res://addons/terra_forge/core/height_store.gd")
const EXPORT = preload("res://addons/terra_forge/core/region_export.gd")
const PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")

func _fail(message: String, preview = null) -> void:
    if preview != null:
        preview.stop_preview()
        preview.free()
    push_error("TerraForge paged failure isolation: " + message)
    quit(1)

func _initialize() -> void:
    var prefix: String = "user://tf_failed_" + str(Time.get_ticks_usec())
    var tfh: String = prefix + ".tfh"
    var folder: String = prefix + "_world"
    var h = HEIGHT.new()
    h.initialize(Vector2i(128, 128), 1.0)
    for z in range(129):
        for x in range(129):
            h.heights[h.index_of(x, z)] = 2.0 + float(x + z) * 0.125
    if h.save_file(tfh) != OK or EXPORT.export_file(tfh, folder, 2).get("error", ERR_FILE_CORRUPT) != OK:
        _fail("Could not create disposable region fixture")
        return
    var original: String = FileAccess.get_sha256(tfh)
    var preview = PREVIEW.new()
    preview.max_visible_tiles = 1
    preview.high_detail_distance = 180.0
    if preview.start_preview(folder, 9, 2) != OK:
        _fail("Could not open fixture", preview)
        return
    preview.set_stream_center(Vector3(8.0, 20.0, 8.0))
    for attempt in range(2400):
        preview.pump_stream()
        if preview._tiles.has(Vector2i.ZERO):
            break
        OS.delay_msec(1)
    if not preview._tiles.has(Vector2i.ZERO):
        _fail("Initial verified tile missing", preview)
        return
    var first: Dictionary = preview._tiles[Vector2i.ZERO]
    var old_mesh: Mesh = (first["visual"] as MeshInstance3D).mesh
    var old_shape: Shape3D = (first["collision"] as CollisionShape3D).shape
    if old_mesh == null or not old_shape is HeightMapShape3D:
        _fail("Initial mesh or collision missing", preview)
        return
    # Simulate a later cold-page failure after the rendered mesh is valid.
    # Only the disposable snapshot is damaged; the authoritative TFH remains.
    var missing: String = folder + "/r_00000_00000.tfr"
    if preview._reader.release_outside(Vector2i(4, 4), Vector2i(4, 4)) != OK or DirAccess.remove_absolute(ProjectSettings.globalize_path(missing)) != OK:
        _fail("Could not force cold missing-page fixture", preview)
        return
    preview.max_visible_tiles = 16
    preview._pending_tiles[Vector2i.ZERO] = true
    preview._last_sync_msec = -100000
    var healthy: Vector2i = Vector2i(2, 0)
    var never_loaded: Vector2i = Vector2i(1, 0)
    for attempt in range(3000):
        preview.pump_stream()
        var stats: Dictionary = preview.stats()
        if int(stats["tiles"]) > 16 or int(stats["source"]["resident"]) > 9:
            _fail("Streaming budgets exceeded", preview)
            return
        if preview._tiles.has(healthy) and preview._blocked_tiles.has(Vector2i.ZERO) and preview._blocked_tiles.has(never_loaded):
            break
        OS.delay_msec(1)
    if not preview._tiles.has(healthy) or not preview._blocked_tiles.has(Vector2i.ZERO) or not preview._blocked_tiles.has(never_loaded):
        _fail("A failed nearby tile starved healthy independent terrain", preview)
        return
    var retained: Dictionary = preview._tiles[Vector2i.ZERO]
    if (retained["visual"] as MeshInstance3D).mesh != old_mesh or (retained["collision"] as CollisionShape3D).shape != old_shape:
        _fail("Failed rebuild replaced last-known-good geometry", preview)
        return
    if preview._tiles.has(never_loaded) or preview._reader.get_height(0, 0).has("height"):
        _fail("Missing page fabricated geometry or samples", preview)
        return
    var good: Dictionary = preview._tiles[healthy]
    if (good["visual"] as MeshInstance3D).mesh == null or not (good["collision"] as CollisionShape3D).shape is HeightMapShape3D:
        _fail("Healthy tile lacks real collision", preview)
        return
    var final_stats: Dictionary = preview.stats()
    if int(final_stats["retained_failed_tiles"]) != 1 or int(final_stats["last_error"]) != ERR_FILE_NOT_FOUND or int(final_stats["source"]["worker_errors"]) != 1:
        _fail("Failure accounting or same-generation retry policy incorrect", preview)
        return
    if FileAccess.get_sha256(tfh) != original or preview.save_data() != ERR_UNAVAILABLE:
        _fail("Readonly preview changed source or enabled writes", preview)
        return
    preview.stop_preview()
    if not preview._blocked_tiles.is_empty() or not preview._tiles.is_empty():
        _fail("Stop did not clear blocked and resident tiles", preview)
        return
    preview.free()
    print("PASS: failed nearest tile isolated, verified mesh and collision retained, independent terrain proceeds, cache bound and no fake samples")
    quit(0)
