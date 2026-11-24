@tool
extends SceneTree
## P1.2 read-only paging: exact Float32 grid samples, cross-page bilinear,
## strict source residency, incremental prefetch, hash failures and no writes.
const SOURCE = preload("res://addons/terra_forge/core/paged_height_source.gd")
const HEIGHTS = preload("res://addons/terra_forge/core/height_store.gd")
const LAYERS = preload("res://addons/terra_forge/core/height_layers.gd")
const EXPORT = preload("res://addons/terra_forge/core/region_export.gd")
const MANIFEST = preload("res://addons/terra_forge/core/region_manifest.gd")
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")

func _fail(message: String) -> void:
    push_error("Paged height source: " + message)
    quit(1)

func _expect(reader, x: int, z: int, baseline: PackedFloat32Array, width: int) -> bool:
    var found: Dictionary = reader.get_height(x, z)
    return (
        int(found.get("error", -1)) == OK
        and found.has("height")
        and float(found["height"]) == float(baseline[z * (width + 1) + x])
    )

func _initialize() -> void:
    var suffix: String = str(Time.get_ticks_usec())
    var base_path: String = "user://tf_paged_" + suffix + ".tfh"
    var folder: String = "user://tf_paged_" + suffix + "_world"
    var layered_file: String = "user://tf_paged_" + suffix + ".tfl"
    var layered_dir: String = "user://tf_paged_" + suffix + "_layers"
    var flat = HEIGHTS.new()
    flat.initialize(Vector2i(96, 64), 0.5)
    for z in range(65):
        for x in range(97):
            flat.heights[flat.index_of(x, z)] = (
                float(x) * 0.125 - float(z) * 0.625
                + sin(float(x) * 0.05) * 1.25
            )
    if flat.save_file(base_path) != OK:
        _fail("Could not create TFH fixture")
        return
    var saved_source: PackedByteArray = FileAccess.get_file_as_bytes(base_path)
    if int(EXPORT.export_file(base_path, folder, 2).get("error", -1)) != OK:
        _fail("Could not create immutable TFM1 region snapshot")
        return
    var file: String = folder + "/r_00000_00000.tfr"
    var saved_page: PackedByteArray = FileAccess.get_file_as_bytes(file)
    var reader = SOURCE.new()
    if reader.open(folder, 2) != OK or reader.cells != flat.cells:
        _fail("Verified world could not be opened as read-only pager")
        return
    if reader.page_count() != Vector2i(4, 3):
        _fail("Page count did not include outer boundary region")
        return
    if int(reader.stats()["resident"]) != 0:
        _fail("Opening a world kept its entire height grid in memory")
        return

    # Exact border ownership and all four world edges.
    for z in [0, 1, 31, 32, 33, 63, 64]:
        for x in [0, 1, 31, 32, 33, 63, 64, 95, 96]:
            if not _expect(reader, x, z, flat.heights, flat.cells.x):
                _fail("Float32 mismatch at grid coordinate " + str(Vector2i(x, z)))
                return
            if int(reader.stats()["resident"]) > 2:
                _fail("Raw height resident cache exceeded two-page limit")
                return
    # Bilinear at cross-region boundaries; compare with legacy interpolator.
    for z in [0.0, 15.25, 15.75, 16.0, 16.25, 31.75, 32.0]:
        for x in [0.0, 15.25, 15.75, 16.0, 16.25, 47.75, 48.0]:
            var sample: Dictionary = reader.sample_local(x, z)
            var legacy: float = flat.sample_local(x, z)
            if int(sample.get("error", -1)) != OK or absf(float(sample["height"]) - legacy) > 0.00015:
                _fail("Cross-page bilinear interpolation disagrees with TFH1")
                return
    for invalid in [
        Vector2(-0.01, 0.0), Vector2(0.0, -0.25),
        Vector2(48.01, 1.0), Vector2(1.0, 32.001)
    ]:
        var failed: Dictionary = reader.sample_local(invalid.x, invalid.y)
        if int(failed.get("error", OK)) != ERR_INVALID_PARAMETER or failed.has("height"):
            _fail("Out-of-bounds interpolator fabricated heights")
            return
    var out_sample: Dictionary = reader.get_height(97, 64)
    if out_sample.get("error", OK) != ERR_INVALID_PARAMETER or out_sample.has("height"):
        _fail("Out-of-bounds exact sample did not fail closed")
        return

    # Explicit prefetch calls never load more than their IO budget, and
    # preserve their progress across calls rather than restarting forever.
    var bounds_a: Vector2i = Vector2i.ZERO
    var bounds_b: Vector2i = Vector2i(3, 2)
    var generation: int = -1
    var complete: bool = false
    for step in range(12):
        var progress: Dictionary = reader.prefetch_rect(bounds_a, bounds_b, 2)
        if int(progress.get("error", -1)) != OK or int(progress["loaded"]) > 2:
            _fail("Prefetch crossed its disk reads-per-call budget")
            return
        if step == 0:
            generation = int(progress["generation"])
        if int(progress["generation"]) != generation:
            _fail("Prefetch unexpectedly reset its progress generation")
            return
        if int(reader.stats()["resident"]) > 2:
            _fail("Prefetch exceeded resident height budget")
            return
        if bool(progress["complete"]):
            complete = true
            break
    if not complete or not bool(reader.prefetch_rect(bounds_a, bounds_b, 1)["complete"]):
        _fail("Incremental prefetch never reached completion")
        return
    var changed: Dictionary = reader.prefetch_rect(Vector2i(1, 1), Vector2i(2, 1), 1)
    if int(changed.get("error", -1)) != OK or int(changed["generation"]) <= generation:
        _fail("Changed camera bounds did not cancel stale prefetch generation")
        return
    if reader.release_outside(Vector2i(1, 0), Vector2i(2, 1)) != OK:
        _fail("Read-only page release failed")
        return
    if int(reader.stats()["resident_float_bytes"]) > 2 * REGIONS.PAGE_BYTES:
        _fail("Raw Float32 cache bytes not bounded")
        return
    if reader.prefetch_rect(Vector2i(0, 0), Vector2i(3, 2), 0).get("error", OK) != ERR_INVALID_PARAMETER:
        _fail("Zero prefetch budget unexpectedly accepted")
        return
    if int(reader.stats()["disk_reads"]) == 0 or int(reader.stats()["cache_misses"]) == 0:
        _fail("Read-only source never recorded cold page IO")
        return

    # TFL2 snapshot source retains visible composite but does not touch
    # original editable layers or export file bytes.
    var stack = LAYERS.new()
    if stack.initialize(flat.heights, flat.cells, flat.spacing) != OK:
        _fail("TFL2 fixture initialize failed")
        return
    var changed_layer: int = stack.add_layer("Eroded Ridge")
    var hidden_layer: int = stack.add_layer("Hidden")
    stack.set_delta(changed_layer, flat.index_of(32, 31), 7.25)
    stack.set_delta(hidden_layer, flat.index_of(31, 32), 99.0)
    stack.set_enabled(hidden_layer, false)
    if stack.save_file(layered_file) != OK:
        _fail("TFL2 fixture save failed")
        return
    var tfl_original: PackedByteArray = FileAccess.get_file_as_bytes(layered_file)
    if EXPORT.export_file(layered_file, layered_dir, 1).get("error", -1) != OK:
        _fail("TFL2 snapshot export failed")
        return
    var layer_reader = SOURCE.new()
    if layer_reader.open(layered_dir, 1) != OK:
        _fail("TFL2 region snapshot failed verification")
        return
    var visible: PackedFloat32Array = stack.compose()
    if not _expect(layer_reader, 32, 31, visible, 96):
        _fail("Visible layer delta missing at region boundary")
        return
    if not _expect(layer_reader, 31, 32, visible, 96):
        _fail("Disabled layer was incorrectly exported")
        return
    if FileAccess.get_file_as_bytes(layered_file) != tfl_original:
        _fail("Read-only TFL2 export modified its editable source")
        return

    # Change one canonical page after open; evict it to force verified reload.
    if reader.release_outside(Vector2i(3, 2), Vector2i(3, 2)) != OK:
        _fail("Could not evict page to test runtime corruption")
        return
    var mutate: FileAccess = FileAccess.open(file, FileAccess.READ_WRITE)
    if mutate == null:
        _fail("Cannot open scratch region page for corruption test")
        return
    mutate.seek(REGIONS.HEADER_BYTES + 15)
    var prior: int = mutate.get_8()
    mutate.seek(REGIONS.HEADER_BYTES + 15)
    mutate.store_8(prior ^ 1)
    mutate.flush()
    mutate.close()
    var corrupt: Dictionary = reader.get_height(0, 0)
    if int(corrupt.get("error", OK)) != ERR_FILE_CORRUPT or corrupt.has("height"):
        _fail("Modified region page was accepted after manifest verification")
        return
    var fresh = SOURCE.new()
    if fresh.open(folder, 2) != ERR_FILE_CORRUPT or fresh.is_open():
        _fail("Corrupt world should refuse to open")
        return
    if fresh.get_height(0, 0).has("height"):
        _fail("Unopened world returned a default height")
        return

    # Restore only test fixture data, then simulate a missing region file.
    var rewrite: FileAccess = FileAccess.open(file, FileAccess.WRITE)
    rewrite.store_buffer(saved_page)
    rewrite.close()
    var missing_page: String = folder + "/r_00001_00000.tfr"
    var missing_copy: PackedByteArray = FileAccess.get_file_as_bytes(missing_page)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_page))
    if fresh.open(folder, 2) != ERR_FILE_NOT_FOUND or fresh.is_open():
        _fail("Missing region must fail closed during manifest verification")
        return
    var restore: FileAccess = FileAccess.open(missing_page, FileAccess.WRITE)
    restore.store_buffer(missing_copy)
    restore.close()

    # An incomplete .tmp is NOT the authoritative snapshot file.
    var pending: FileAccess = FileAccess.open(file + ".tmp", FileAccess.WRITE)
    pending.store_buffer(PackedByteArray([66, 65, 68]))
    pending.close()
    if fresh.open(folder, 2) != OK:
        _fail("Truncated temporary file replaced an authoritative page")
        return
    var different: String = folder + "/r_00002_00000.tfr"
    var other_bytes: PackedByteArray = FileAccess.get_file_as_bytes(different)
    var swapped: FileAccess = FileAccess.open(file, FileAccess.WRITE)
    swapped.store_buffer(other_bytes)
    swapped.close()
    if fresh.release_outside(Vector2i(3, 2), Vector2i(3, 2)) != OK:
        _fail("Could not evict region before cross-world identity test")
        return
    if fresh.get_height(0, 0).get("error", OK) != ERR_FILE_CORRUPT:
        _fail("Replaced region passed manifest's per-page hash")
        return
    if FileAccess.get_file_as_bytes(base_path) != saved_source:
        _fail("Reading a region snapshot modified original TFH1 data")
        return
    var empty = SOURCE.new()
    if empty.open(folder + "_missing", 1) != ERR_FILE_NOT_FOUND:
        _fail("Missing manifest silently accepted")
        return

    print("PASS: paged Float32 heights, cross-page bilinear, bounded prefetch, TFL composite and fail-closed hash")
    quit(0)
