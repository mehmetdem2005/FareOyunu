@tool
extends SceneTree
## P1.5: manifest-first open must never silently trust missing/corrupt TFR1.
## Strict opening retains its old full-world verification contract.
const HEIGHTS = preload("res://addons/terra_forge/core/height_store.gd")
const EXPORT = preload("res://addons/terra_forge/core/region_export.gd")
const ASYNC = preload("res://addons/terra_forge/core/async_region_source.gd")
const PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const MANIFEST = preload("res://addons/terra_forge/core/region_manifest.gd")
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")

func _die(message: String) -> void:
    push_error("TerraForge lazy open: " + message)
    quit(1)

func _await_page(source, key: Vector2i) -> Error:
    for attempt in range(2200):
        source.poll_results(2)
        var result: Error = source.page_status(key)
        if result != ERR_BUSY:
            return result
        OS.delay_msec(1)
    return ERR_TIMEOUT

func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
    var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_buffer(bytes)
    f.flush()
    f.close()
    return true

func _initialize() -> void:
    var suffix: String = str(Time.get_ticks_usec())
    var tfh: String = "user://tf_lazy_" + suffix + ".tfh"
    var world: String = "user://tf_lazy_" + suffix + "_world"
    var h = HEIGHTS.new()
    h.initialize(Vector2i(128, 128), 1.0)
    for z in range(129):
        for x in range(129):
            h.heights[h.index_of(x, z)] = float(x * 3 - z) * 0.03125
    if h.save_file(tfh) != OK:
        _die("Failed to make Float32 source fixture")
        return
    var original_hash: String = FileAccess.get_sha256(tfh)
    if EXPORT.export_file(tfh, world, 2).get("error", ERR_FILE_CORRUPT) != OK:
        _die("TFR1 snapshot export failed")
        return
    var far: Vector2i = Vector2i(4, 4)
    var far_path: String = world + "/r_00004_00004.tfr"
    var far_bytes: PackedByteArray = FileAccess.get_file_as_bytes(far_path)
    if far_bytes.size() != REGIONS.FILE_BYTES:
        _die("Original outer border TFR1 fixture invalid")
        return

    # Strict defaults MUST reject incomplete worlds before starting worker.
    if DirAccess.remove_absolute(ProjectSettings.globalize_path(far_path)) != OK:
        _die("Failed to remove disposable far-page fixture")
        return
    var strict = ASYNC.new()
    if strict.open(world, 9, 2) != ERR_FILE_NOT_FOUND or strict.is_open():
        strict.close()
        _die("Default strict open accepted a missing TFR1 region")
        return
    if strict.open(world, 9, 2, true) != ERR_FILE_NOT_FOUND:
        strict.close()
        _die("Explicit strict mode failed to reject incomplete world")
        return

    # Lazy mode checks the TFM1 checksum/schema and pinned page hashes,
    # WITHOUT touching the missing, unrequested region at world open.
    var lazy = ASYNC.new()
    if lazy.open(world, 9, 2, false) != OK or not lazy.is_open():
        lazy.close()
        _die("Manifest-only lazy opening failed despite valid manifest")
        return
    var stats: Dictionary = lazy.stats()
    if bool(stats["verified_at_open"]) or stats["verification_mode"] != "on_demand":
        lazy.close()
        _die("Lazy source falsely reported a fully checked world")
        return
    if int(stats["manifest_entries"]) != 25 or int(stats["pages_verified_on_demand"]) != 0:
        lazy.close()
        _die("Manifest-only open secretly checked or loaded height pages")
        return
    if lazy.get_height(0, 0).get("error", OK) != ERR_BUSY:
        lazy.close()
        _die("Lazy source fabricated an unloaded height sample")
        return
    if lazy.request_page(Vector2i.ZERO) != OK or _await_page(lazy, Vector2i.ZERO) != OK:
        lazy.close()
        _die("Valid nearby page failed first cold full-SHA check")
        return
    var zero: Dictionary = lazy.get_height(0, 0)
    if zero.get("error", ERR_FILE_CORRUPT) != OK or absf(float(zero["height"]) - float(h.heights[0])) > 0.00001:
        lazy.close()
        _die("Lazy source returned wrong local Float32 height")
        return
    if int(lazy.stats()["pages_verified_on_demand"]) != 1:
        lazy.close()
        _die("Successful cold read did not increment verification count")
        return
    if lazy.request_page(far) != OK or _await_page(lazy, far) != ERR_FILE_NOT_FOUND:
        lazy.close()
        _die("Missing far page was not rejected when first requested")
        return
    if lazy.get_height(128, 128).has("height") or lazy.request_page(far) != ERR_FILE_NOT_FOUND:
        lazy.close()
        _die("Missing page generated fake heights or retried forever")
        return
    lazy.close()

    # Default preview opts into lazy open, keeping visible near-camera
    # terrain available even when a far page is missing. Still read-only.
    var preview = PREVIEW.new()
    preview.view_distance = 80.0
    preview.max_visible_tiles = 4
    if not preview.verify_pages_on_demand or preview.start_preview(world, 9, 2) != OK:
        preview.stop_preview()
        preview.free()
        _die("Read-only preview failed to use the manifest-first startup")
        return
    preview.set_stream_center(Vector3(8.0, 20.0, 8.0))
    var visible: bool = false
    for step in range(2200):
        preview.pump_stream()
        if preview._tiles.has(Vector2i.ZERO):
            var tile: Dictionary = preview._tiles[Vector2i.ZERO]
            if (tile["visual"] as MeshInstance3D).mesh != null and (tile["collision"] as CollisionShape3D).shape != null:
                visible = true
                break
        OS.delay_msec(1)
    if not visible or preview.stats()["source"]["verification_mode"] != "on_demand":
        preview.stop_preview()
        preview.free()
        _die("Missing distant tile prevented nearby, verified mesh/collision")
        return
    if preview.save_data() != ERR_UNAVAILABLE:
        preview.stop_preview()
        preview.free()
        _die("Readonly lazy preview unexpectedly allowed save")
        return
    preview.stop_preview()
    preview.free()
    if not _write_bytes(far_path, far_bytes):
        _die("Could not restore disposable outer page")
        return

    # A same-length tampered page may not be detected at LAZY open, but
    # it MUST be detected from the first cold read of that page's bytes.
    var tamper: FileAccess = FileAccess.open(far_path, FileAccess.READ_WRITE)
    if tamper == null:
        _die("Could not open scratch page for corruption")
        return
    tamper.seek(REGIONS.HEADER_BYTES + 11)
    var old: int = tamper.get_8()
    tamper.seek(REGIONS.HEADER_BYTES + 11)
    tamper.store_8(old ^ 1)
    tamper.flush()
    tamper.close()
    var damaged = ASYNC.new()
    if damaged.open(world, 9, 1, true) != ERR_FILE_CORRUPT:
        damaged.close()
        _die("Strict mode failed to reject corrupted region at startup")
        return
    if damaged.open(world, 9, 1, false) != OK:
        damaged.close()
        _die("Lazy mode wrongly did all-page checking at startup")
        return
    if damaged.request_page(far) != OK or _await_page(damaged, far) != ERR_FILE_CORRUPT:
        damaged.close()
        _die("Bad full-page SHA was not caught on demand")
        return
    if damaged.get_height(128, 128).has("height"):
        damaged.close()
        _die("Corrupt page returned height after worker verification error")
        return
    damaged.close()
    if not _write_bytes(far_path, far_bytes):
        _die("Cannot restore corrupted disposable region fixture")
        return

    # The TFM1 manifest itself is NEVER lazily trusted: checksum mismatch
    # and missing manifest must block open before any worker is started.
    var manifest_path: String = world + "/" + MANIFEST.FILE_NAME
    var manifest_bytes: PackedByteArray = FileAccess.get_file_as_bytes(manifest_path)
    var f: FileAccess = FileAccess.open(manifest_path, FileAccess.READ_WRITE)
    if f == null:
        _die("Could not open temporary TFM1 manifest")
        return
    f.seek(19)
    var digest_byte: int = f.get_8()
    f.seek(19)
    f.store_8(digest_byte ^ 1)
    f.flush()
    f.close()
    var invalid = ASYNC.new()
    if invalid.open(world, 9, 1, false) != ERR_FILE_CORRUPT or invalid.is_open():
        invalid.close()
        _die("Lazy mode accepted a tampered manifest checksum")
        return
    if not _write_bytes(manifest_path, manifest_bytes):
        _die("Could not restore temporary manifest fixture")
        return
    if invalid.open(world + "_does_not_exist", 9, 1, false) != ERR_FILE_NOT_FOUND:
        invalid.close()
        _die("Missing manifest was accepted")
        return
    if invalid.open(world, 9, 1) != OK:
        invalid.close()
        _die("Strict full-world verification failed on restored snapshot")
        return
    if not bool(invalid.stats()["verified_at_open"]) or invalid.stats()["verification_mode"] != "strict":
        invalid.close()
        _die("Strict source did not advertise its real verification scope")
        return
    invalid.close()
    if FileAccess.get_sha256(tfh) != original_hash:
        _die("Read-only lazy loading modified authoritative TFH document")
        return
    print("PASS: strict default preserved, TFM1 checksum always checked, lazy cold SHA, missing/corrupt page fail-closed, opt-in preview")
    quit(0)
