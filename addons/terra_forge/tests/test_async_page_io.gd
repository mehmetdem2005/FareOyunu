@tool
extends SceneTree
## P1.2b real Godot Thread / Mutex / Semaphore integration regression.
## Run with --headless, NO graphical Node/GPU operations on the worker.
const HEIGHTS = preload("res://addons/terra_forge/core/height_store.gd")
const EXPORT = preload("res://addons/terra_forge/core/region_export.gd")
const ASYNC = preload("res://addons/terra_forge/core/async_region_source.gd")
const CAMERA = preload("res://addons/terra_forge/core/camera_page_prefetch.gd")
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")

func _fail(reason: String) -> void:
    push_error("TerraForge async page IO: " + reason)
    quit(1)

func _drain(reader, expected: Array[Vector2i], max_steps: int = 2000) -> bool:
    for step in range(max_steps):
        reader.poll_results(3)
        var all_ready: bool = true
        for key in expected:
            var status: Error = reader.page_status(key)
            if status != OK:
                if status != ERR_BUSY:
                    return false
                all_ready = false
        if all_ready:
            return true
        OS.delay_msec(1)
    return false

func _initialize() -> void:
    var suffix: String = str(Time.get_ticks_usec())
    var source: String = "user://tf_async_" + suffix + ".tfh"
    var world: String = "user://tf_async_" + suffix + "_world"
    var src = HEIGHTS.new()
    src.initialize(Vector2i(96, 96), 1.0)
    for z in range(97):
        for x in range(97):
            src.heights[src.index_of(x, z)] = float(x) * 0.375 - float(z) * 0.625
    if src.save_file(source) != OK:
        _fail("Fixture TFH save failed")
        return
    var source_hash: String = FileAccess.get_sha256(source)
    if EXPORT.export_file(source, world, 2).get("error", ERR_FILE_CORRUPT) != OK:
        _fail("Fixture TFM1 export failed")
        return
    var page_path: String = world + "/r_00000_00000.tfr"
    var page_hash: String = FileAccess.get_sha256(page_path)
    var reader = ASYNC.new()
    if reader.open(world, 4, 2) != OK or not reader.is_open():
        _fail("Could not open verified world and launch worker")
        return
    if reader.get_height(0, 0).get("error", OK) != ERR_BUSY:
        reader.close()
        _fail("Unloaded page should be pending rather than invented flat ground")
        return
    var keyset: Array[Vector2i] = [
        Vector2i(0, 0), Vector2i(1, 0),
        Vector2i(0, 1), Vector2i(1, 1)
    ]
    # Max two outstanding jobs. Enqueue in two waves; worker must never
    # expose mutable source buffers to the main-thread cache.
    for i in range(keyset.size()):
        var key: Vector2i = keyset[i]
        var error: Error = reader.request_page(key)
        if error == ERR_BUSY:
            reader.poll_results(2)
            OS.delay_msec(2)
            error = reader.request_page(key)
        if error == ERR_BUSY:
            for wait in range(1000):
                reader.poll_results(2)
                if reader.request_page(key) == OK:
                    error = OK
                    break
                OS.delay_msec(1)
        if error != OK:
            reader.close()
            _fail("Worker queue stalled or rejected valid page request")
            return
        var state: Dictionary = reader.stats()
        if int(state["outstanding"]) + int(state["inflight"]) + int(state["finished"]) > 2:
            reader.close()
            _fail("Thread job queue exceeded configured capacity")
            return
    if not _drain(reader, keyset):
        reader.close()
        _fail("Queued pages did not complete on background worker")
        return
    var sample: Dictionary = reader.sample_local(31.5, 31.5)
    var correct: float = src.sample_local(31.5, 31.5)
    if int(sample.get("error", -1)) != OK or absf(float(sample["height"]) - correct) > 0.00001:
        reader.close()
        _fail("Worker Float32 decode or cross-page bilinear mismatch")
        return
    if int(reader.stats()["resident"]) > 4:
        reader.close()
        _fail("Completed results exceeded Float32 resident bound")
        return
    if reader.get_height(96, 96).get("error", OK) != ERR_BUSY:
        reader.close()
        _fail("Cold outer sample was fabricated instead of pending")
        return

    # A new generation must cancel queued work and discard any in-flight
    # result that comes back after the camera has teleported.
    var camera = CAMERA.new()
    if camera.configure_async(reader, 1) != OK:
        reader.close()
        _fail("Async camera path could not be configured")
        return
    if camera.request_focus(0.0, 0.0, 1) != OK:
        reader.close()
        _fail("First camera focus invalid")
        return
    camera.tick()
    var first_generation: int = int(camera.stats()["generation"])
    if camera.request_focus(96.0, 96.0, 0) != OK:
        reader.close()
        _fail("Teleport focus invalid")
        return
    if int(camera.stats()["generation"]) <= first_generation:
        reader.close()
        _fail("Camera teleport failed to change queue generation")
        return
    var complete: bool = false
    for step in range(2000):
        var progress: Dictionary = camera.tick()
        if int(progress.get("error", -1)) != OK:
            reader.close()
            _fail("Async camera returned error before region was ready")
            return
        if int(progress["submitted"]) > 1 or int(progress["loaded"]) > 1:
            reader.close()
            _fail("Async camera exceeded per-tick submit/commit budget")
            return
        if bool(progress["complete"]):
            complete = true
            break
        OS.delay_msec(1)
    if not complete:
        reader.close()
        _fail("Async camera never completed its last requested generation")
        return
    var outer: Dictionary = reader.get_height(96, 96)
    if outer.get("error", ERR_BUSY) != OK or absf(float(outer["height"]) - src.heights[src.index_of(96, 96)]) > 0.00001:
        reader.close()
        _fail("New camera generation did not load correct outer height")
        return
    if int(reader.stats()["resident"]) > 4:
        reader.close()
        _fail("Async camera grew resident Float32 cache unbounded")
        return

    # Corrupt AFTER open; cold verified read must reject the modified page.
    # Explicitly evict page 0 so the next access cannot use cached values.
    reader.release_outside(Vector2i(3, 3), Vector2i(3, 3))
    var damaged: FileAccess = FileAccess.open(page_path, FileAccess.READ_WRITE)
    if damaged == null:
        reader.close()
        _fail("Corrupt page test could not open disposable region fixture")
        return
    damaged.seek(REGIONS.HEADER_BYTES + 17)
    var byte: int = damaged.get_8()
    damaged.seek(REGIONS.HEADER_BYTES + 17)
    damaged.store_8(byte ^ 1)
    damaged.flush()
    damaged.close()
    var previous_generation: int = int(reader.stats()["generation"])
    if reader.set_generation(previous_generation + 1) != OK:
        reader.close()
        _fail("New request generation was rejected")
        return
    if reader.request_page(Vector2i.ZERO) != OK:
        reader.close()
        _fail("Corrupt page could not be submitted for detection")
        return
    var corrupted: bool = false
    for step in range(2000):
        reader.poll_results(2)
        var st: Error = reader.page_status(Vector2i.ZERO)
        if st == ERR_FILE_CORRUPT:
            corrupted = true
            break
        if st != ERR_BUSY:
            reader.close()
            _fail("Corrupt page returned an unrelated status")
            return
        OS.delay_msec(1)
    if not corrupted or reader.get_height(0, 0).has("height"):
        reader.close()
        _fail("Corrupt file was silently displayed as valid terrain")
        return
    if reader.request_page(Vector2i.ZERO) != ERR_FILE_CORRUPT:
        reader.close()
        _fail("Corrupt page retried repeatedly in same generation")
        return

    if FileAccess.get_sha256(source) != source_hash:
        reader.close()
        _fail("Background IO modified original TFH source")
        return
    if FileAccess.get_sha256(page_path) == page_hash:
        reader.close()
        _fail("Corruption fixture never actually altered page")
        return

    # Thread must be joined and safely reopened, including after an error.
    reader.close()
    if reader.is_open() or reader.get_height(0, 0).has("height"):
        _fail("Closed worker still returned cached heights")
        return
    if reader.open(world, 2, 1) != ERR_FILE_CORRUPT or reader.is_open():
        _fail("Reopen should refuse corrupted manifest world")
        return
    print("PASS: Godot worker IO, bounded jobs/results, stale generation cancellation, Float32 seams and corruption")
    quit(0)
