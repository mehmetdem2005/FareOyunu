@tool
extends SceneTree
## P1 disk-backed sample paging: unique seam ownership, strict missing file,
## bounded LRU, dirty writeback, SHA validation and fail-closed corruption.
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")

func _fail(message: String) -> void:
    push_error("TerraForge region store: " + message)
    quit(1)

func _initialize() -> void:
    var root: String = "user://tf_region_test_" + str(Time.get_ticks_usec())
    var store = REGIONS.new()
    if store.initialize(root, Vector2i(96, 96), 0.5, 2) != OK:
        _fail("Could not initialize region cache")
        return
    if store.page_count() != Vector2i(4, 4):
        _fail("Outer border samples not included in paging")
        return
    if store.read_height(12, 12).get("error", OK) != ERR_FILE_NOT_FOUND:
        _fail("Missing region silently fell back to a zero height")
        return
    if store.write_height(2, 2, 5.0) != ERR_FILE_NOT_FOUND:
        _fail("Write unexpectedly created an absent page")
        return

    for key in [
        Vector2i(0, 0), Vector2i(1, 0),
        Vector2i(0, 1), Vector2i(1, 1), Vector2i(3, 3)
    ]:
        if store.create_blank_page(key) != OK:
            _fail("Explicit page creation failed: " + str(key))
            return
        if store.resident_pages() > 2:
            _fail("Resident page cache exceeded its strict limit")
            return
    # Every global grid sample belongs to exactly one 32x32 sample page.
    # Thus (31,31) and (32,32) are independent samples, with no duplicated
    # shared border that could develop a seam during sculpting.
    if store.write_height(31, 31, 3.25) != OK:
        _fail("Could not write first page's right/bottom sample")
        return
    if store.write_height(32, 31, 9.5) != OK:
        _fail("Could not write neighboring page's first column")
        return
    if store.write_height(31, 32, -5.0) != OK:
        _fail("Could not write neighboring page's first row")
        return
    if store.write_height(32, 32, 17.125) != OK:
        _fail("Could not write intersection sample")
        return
    if store.write_height(96, 96, 1.75) != OK:
        _fail("Could not write far outer corner")
        return
    if store.write_height(96, 97, 3.0) != ERR_INVALID_PARAMETER:
        _fail("Out-of-bounds sample was accepted")
        return
    if store.flush_all() != OK or store.unload_all() != OK:
        _fail("Dirty pages did not flush and unload")
        return
    if store.resident_pages() != 0:
        _fail("Unloaded cache still retains Float32 pages")
        return

    var reopened = REGIONS.new()
    if reopened.initialize(root, Vector2i(96, 96), 0.5, 2) != OK:
        _fail("Could not reopen regional store")
        return
    var expectations: Dictionary = {
        Vector2i(31, 31): 3.25,
        Vector2i(32, 31): 9.5,
        Vector2i(31, 32): -5.0,
        Vector2i(32, 32): 17.125,
        Vector2i(96, 96): 1.75
    }
    for coord in expectations:
        var sample: Dictionary = reopened.read_height(coord.x, coord.y)
        if int(sample.get("error", -1)) != OK or float(sample["height"]) != float(expectations[coord]):
            _fail("Region reload failed at " + str(coord))
            return
        if reopened.resident_pages() > 2:
            _fail("Reload exceeded residency budget")
            return
    var stats: Dictionary = reopened.stats()
    if int(stats["resident_float_bytes"]) > 2 * REGIONS.PAGE_BYTES:
        _fail("Resident height sample memory grew above limit")
        return

    # Write second generation: the first should survive in a .bak file.
    if reopened.write_height(31, 31, 8.25) != OK or reopened.flush_all() != OK:
        _fail("Incremental dirty page save failed")
        return
    var page_path: String = root + "/r_00000_00000.tfr"
    var backup_path: String = page_path + ".bak"
    if not FileAccess.file_exists(backup_path):
        _fail("Previous verified region file was not backed up")
        return

    # Corrupt a saved region; new cache must reject it without guessing 0.
    var writer: FileAccess = FileAccess.open(page_path, FileAccess.READ_WRITE)
    if writer == null:
        _fail("Cannot simulate single-byte corruption")
        return
    writer.seek(REGIONS.HEADER_BYTES + 22)
    var prior: int = writer.get_8()
    writer.seek(REGIONS.HEADER_BYTES + 22)
    writer.store_8(prior ^ 1)
    writer.flush()
    writer.close()
    var damaged = REGIONS.new()
    damaged.initialize(root, Vector2i(96, 96), 0.5, 1)
    if damaged.read_height(31, 31).get("error", OK) != ERR_FILE_CORRUPT:
        _fail("Corrupted region passed checksum")
        return
    if damaged.write_height(31, 31, 4.0) == OK:
        _fail("Damaged primary region was silently overwritten")
        return

    # A partial .tmp is ignored; never promoted as authoritative.
    var other: String = root + "/r_00001_00001.tfr"
    var tmp: FileAccess = FileAccess.open(other + ".tmp", FileAccess.WRITE)
    tmp.store_buffer(PackedByteArray([1, 2, 3]))
    tmp.close()
    var partial = REGIONS.new()
    partial.initialize(root, Vector2i(96, 96), 0.5, 1)
    var valid_sample: Dictionary = partial.read_height(32, 32)
    if valid_sample.get("error", ERR_FILE_CORRUPT) != OK or float(valid_sample["height"]) != 17.125:
        _fail("Incomplete temp file replaced a committed page")
        return
    # Different world dimensions must not read a valid but unrelated page.
    var mismatched = REGIONS.new()
    mismatched.initialize(root, Vector2i(64, 64), 0.5, 1)
    if mismatched.read_height(32, 32).get("error", OK) != ERR_INVALID_DATA:
        _fail("Cross-world region file was accepted")
        return

    print("PASS: unique seam samples, strict LRU, Float32 save/evict/reload, verified backup and corruption rejection")
    quit(0)
