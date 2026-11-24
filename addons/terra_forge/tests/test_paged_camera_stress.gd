@tool
extends SceneTree
## P1.3b camera jump, page halo LRU priority and collision stress.
## Real Godot Thread + mesh/physics; requires no Android hardware.
const HEIGHT = preload("res://addons/terra_forge/core/height_store.gd")
const EXPORT = preload("res://addons/terra_forge/core/region_export.gd")
const PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")

func _fail(message: String, preview: Node = null) -> void:
    if preview != null:
        preview.free()
    push_error("TerraForge paged camera stress: " + message)
    quit(1)

func _drive(preview, camera_position: Vector3, expected_tile: Vector2i) -> bool:
    preview.set_stream_center(camera_position)
    var valid_mesh: bool = false
    for step in range(2400):
        var progress: Dictionary = preview.pump_stream()
        if int(progress.get("error", ERR_FILE_CORRUPT)) != OK:
            print("Camera stress error: ", progress, " last_page=", preview.stats()["last_error_page"])
            return false
        var stats: Dictionary = preview.stats()
        var src: Dictionary = stats["source"]
        if int(src["resident"]) > 9 or int(src["resident_float_bytes"]) > 9 * 4096:
            print("Cache cap exceeded: ", src)
            return false
        if int(src["outstanding"]) + int(src["inflight"]) + int(src["finished"]) > 2:
            print("IO queue cap exceeded: ", src)
            return false
        if int(stats["pending_tiles"]) > 8:
            print("Visible tile budget exceeded: ", stats)
            return false
        if preview._tiles.has(expected_tile):
            var tile: Dictionary = preview._tiles[expected_tile]
            var visual: MeshInstance3D = tile["visual"]
            var collision: CollisionShape3D = tile["collision"]
            if visual.mesh != null and collision.shape is HeightMapShape3D:
                valid_mesh = true
                break
        OS.delay_msec(1)
    return valid_mesh

func _initialize() -> void:
    var suffix: String = str(Time.get_ticks_usec())
    var tfh: String = "user://tf_jump_" + suffix + ".tfh"
    var folder: String = "user://tf_jump_" + suffix + "_world"
    var source = HEIGHT.new()
    source.initialize(Vector2i(128, 128), 1.0)
    for z in range(129):
        for x in range(129):
            source.heights[source.index_of(x, z)] = 0.1 * float(x) + 0.05 * float(z) + sin(float(x) * 0.1)
    if source.save_file(tfh) != OK:
        _fail("Unable to write Float32 fixture")
        return
    var fingerprint: String = FileAccess.get_sha256(tfh)
    if EXPORT.export_file(tfh, folder, 2).get("error", ERR_FILE_CORRUPT) != OK:
        _fail("Unable to export verified TFM1 world")
        return

    var preview = PREVIEW.new()
    preview.view_distance = 96.0
    preview.max_visible_tiles = 8
    preview.high_detail_distance = 64.0
    preview.medium_detail_distance = 80.0
    preview.tile_updates_per_frame = 2
    if preview.start_preview(folder, 9, 2) != OK:
        _fail("Failed to start nine-page read-only preview", preview)
        return
    if not _drive(preview, Vector3(8.0, 20.0, 8.0), Vector2i.ZERO):
        _fail("Initial camera region never built with a minimum 9-page cache", preview)
        return
    var before_generation: int = int(preview._reader.stats()["generation"])
    var first_build_count: int = int(preview.stats()["mesh_builds"])
    # Enqueue an old-region request to test cancellation; it may already
    # finish before focus moves, which is still a valid race outcome.
    preview._reader.request_page(Vector2i(0, 2))
    preview.set_stream_center(Vector3(120.0, 20.0, 120.0))
    preview.pump_stream()
    var new_generation: int = int(preview._reader.stats()["generation"])
    if new_generation <= before_generation or int(preview.stats()["camera_cancellations"]) < 1:
        _fail("Distant camera teleport left obsolete worker jobs alive", preview)
        return
    if preview._desired_tiles.has(Vector2i.ZERO):
        _fail("Distant camera desired-set still contains origin terrain", preview)
        return
    if preview._tiles.has(Vector2i.ZERO):
        _fail("Old camera left an unneeded collision mesh resident", preview)
        return
    if not _drive(preview, Vector3(120.0, 20.0, 120.0), Vector2i(3, 3)):
        _fail("Camera teleport never built the new collision tile", preview)
        return
    if int(preview.stats()["mesh_builds"]) <= first_build_count:
        _fail("After teleport no new terrain mesh was built", preview)
        return

    # Cross a second large distance, returning to a different map edge.
    if not _drive(preview, Vector3(8.0, 20.0, 88.0), Vector2i(0, 2)):
        _fail("Second camera jump starved on old / evicted halo pages", preview)
        return
    var metrics: Dictionary = preview.stats()
    if int(metrics["camera_cancellations"]) < 3:
        _fail("Camera focus cancellations were not recorded", preview)
        return
    if int(metrics["waiting_tile_frames"]) <= 0:
        _fail("Async page readiness was never observed", preview)
        return
    if preview.save_data() != ERR_UNAVAILABLE or bool(metrics["writable"]):
        _fail("Regional streaming unlocked destructive writes", preview)
        return
    if FileAccess.get_sha256(tfh) != fingerprint:
        _fail("Streaming modified authoritative TFH height document", preview)
        return
    preview.stop_preview()
    if preview._reader != null or not preview._tiles.is_empty():
        _fail("Stop did not release worker and transient collision tiles", preview)
        return
    preview.free()
    print("PASS: 9-page LRU halo, fast camera generation cancel, bounded 2-job worker, repeated LOD0 collision and immutable TFH")
    quit(0)
