@tool
extends SceneTree
## P1.2 staged camera requests: deterministic near-first priorities,
## cancel unstarted tasks, max disk reads/tick, bounded LRU, no source writes.
const HEIGHTS = preload("res://addons/terra_forge/core/height_store.gd")
const EXPORT = preload("res://addons/terra_forge/core/region_export.gd")
const SOURCE = preload("res://addons/terra_forge/core/paged_height_source.gd")
const CAMERA = preload("res://addons/terra_forge/core/camera_page_prefetch.gd")
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")

func _fail(reason: String) -> void:
    push_error("TerraForge camera paging: " + reason)
    quit(1)

func _initialize() -> void:
    var suffix: String = str(Time.get_ticks_usec())
    var tfh: String = "user://tf_camera_pages_" + suffix + ".tfh"
    var directory: String = "user://tf_camera_pages_" + suffix
    var original = HEIGHTS.new()
    original.initialize(Vector2i(96, 96), 1.0)
    for z in range(97):
        for x in range(97):
            original.heights[original.index_of(x, z)] = float(x * 2 - z) * 0.125
    if original.save_file(tfh) != OK:
        _fail("Could not create Float32 source fixture")
        return
    if EXPORT.export_file(tfh, directory, 3).get("error", ERR_FILE_CORRUPT) != OK:
        _fail("Could not create TFM1 region snapshot")
        return
    var reference: PackedByteArray = FileAccess.get_file_as_bytes(tfh)
    var sample_page: String = directory + "/r_00000_00000.tfr"
    var page_before: PackedByteArray = FileAccess.get_file_as_bytes(sample_page)

    var reader = SOURCE.new()
    if reader.open(directory, 3) != OK:
        _fail("Read-only page source failed to open")
        return
    var planner = CAMERA.new()
    if planner.configure(reader, 1) != OK:
        _fail("Camera planner rejected valid source")
        return
    if planner.request_focus(16.0, 16.0, 2, Vector2.RIGHT) != OK:
        _fail("Initial camera focus failed")
        return
    var selected: Array = planner.stats()["selected"]
    if selected.is_empty() or selected[0] != Vector2i.ZERO or selected.size() > 3:
        _fail("Priority queue did not start at closest page or exceed capacity")
        return
    var initial_generation: int = int(planner.stats()["generation"])
    var first: Dictionary = planner.tick()
    if int(first.get("error", -1)) != OK or int(first["loaded"]) > 1:
        _fail("One-tick disk budget violated")
        return
    var count_at_start: int = int(planner.stats()["pending"])
    if count_at_start < 1:
        _fail("Expected queued pages beyond the first disk read")
        return

    # Camera teleports while old requests are pending: generation reset.
    if planner.request_focus(80.0, 80.0, 2, Vector2(-1, 0)) != OK:
        _fail("Camera teleport focus failed")
        return
    var teleported: Dictionary = planner.stats()
    if int(teleported["generation"]) <= initial_generation:
        _fail("Teleport did not cancel pending generation")
        return
    var center: Vector2i = Vector2i(2, 2)
    if (teleported["selected"] as Array)[0] != center:
        _fail("New focus did not prioritize the camera's new center")
        return
    for step in range(5):
        var frame: Dictionary = planner.tick()
        if frame.get("error", ERR_FILE_CORRUPT) != OK or int(frame["loaded"]) > 1:
            _fail("Per-tick page read budget broken")
            return
        if reader.stats()["resident"] > 3:
            _fail("Camera streaming exceeded resident page limit")
            return
        if bool(frame["complete"]):
            break
    if int(planner.stats()["pending"]) != 0:
        _fail("Camera prefetch queue never completed")
        return

    # Requesting exactly the same focus must not restart completed work.
    var settled_generation: int = int(planner.stats()["generation"])
    planner.request_focus(80.0, 80.0, 2, Vector2(-1, 0))
    if int(planner.stats()["generation"]) != settled_generation:
        _fail("Repeated identical camera request restarted prefetch")
        return
    if planner.release_distant() != OK:
        _fail("Could not safely evict pages far from camera")
        return

    # Camera sweeps repeatedly across a 4x4 page world.
    for step in range(80):
        var wx: float = float((step * 31 + 7) % 97)
        var wz: float = float((step * 23 + 17) % 97)
        if planner.request_focus(wx, wz, 2, Vector2(1, -1)) != OK:
            _fail("Camera trace focus invalid")
            return
        var result: Dictionary = planner.tick()
        if int(result.get("error", ERR_FILE_CORRUPT)) != OK or int(result["loaded"]) > 1:
            _fail("High-speed camera trace exceeded disk read budget")
            return
        if int(reader.stats()["resident"]) > 3:
            _fail("High-speed camera trace resident cache leaked")
            return
    if int(reader.stats()["resident_float_bytes"]) > 3 * REGIONS.PAGE_BYTES:
        _fail("Raw Float32 resident memory exceeded capacity")
        return
    if int(planner.stats()["ticks"]) < 80:
        _fail("Camera trace frames not recorded")
        return

    var before_invalid: int = int(planner.stats()["generation"])
    if planner.request_focus(-1.0, 12.0, 1) != ERR_INVALID_PARAMETER:
        _fail("Negative world coordinate incorrectly accepted")
        return
    if planner.request_focus(200.0, 12.0, 1) != ERR_INVALID_PARAMETER:
        _fail("Out-of-world camera coordinate incorrectly accepted")
        return
    if int(planner.stats()["generation"]) != before_invalid:
        _fail("Invalid camera request invalidated valid pending job generation")
        return

    if FileAccess.get_file_as_bytes(tfh) != reference:
        _fail("Read-only camera data access modified original TFH")
        return
    if FileAccess.get_file_as_bytes(sample_page) != page_before:
        _fail("Read-only camera data access modified region page")
        return

    # Change a page on disk AFTER the world was verified, then target that
    # cold page. The scheduler MUST report the error instead of flat terrain.
    reader.release_outside(Vector2i(3, 3), Vector2i(3, 3))
    var write: FileAccess = FileAccess.open(sample_page, FileAccess.READ_WRITE)
    if write == null:
        _fail("Could not simulate page corruption")
        return
    write.seek(REGIONS.HEADER_BYTES + 16)
    var value: int = write.get_8()
    write.seek(REGIONS.HEADER_BYTES + 16)
    write.store_8(value ^ 1)
    write.flush()
    write.close()
    planner.request_focus(0.0, 0.0, 0)
    var failure: Dictionary = planner.tick()
    if int(failure.get("error", OK)) != ERR_FILE_CORRUPT:
        _fail("Invalid region page silently passed camera prefetch")
        return
    if not failure.has("page") or failure["page"] != Vector2i.ZERO:
        _fail("Failed page identity missing from diagnostic")
        return

    print("PASS: bounded camera paging, near-first ordering, teleport cancellation, cache budgets and corruption errors")
    quit(0)
