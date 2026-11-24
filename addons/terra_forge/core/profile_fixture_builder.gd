extends RefCounted
## Diagnostic fixture only. No user path input, no modification of existing worlds.
## Produces a genuine TFH1 source by rows and TFR1 pages by blocks, not a full height array.
const MATCHED = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")
const MANIFEST = preload("res://addons/terra_forge/core/region_manifest.gd")
const MAX_FIXTURE_CELLS: int = STORE.MAX_CELLS
const PREFIX: String = "user://tf_profile_fixture_"

var _mutex: Mutex = Mutex.new()
var _thread: Thread
var _cancel: bool = false
var _done: bool = false
var _progress: Dictionary = {}
var _result: Dictionary = {}

## Does not allocate pages or touch disk. Byte estimates exclude filesystem overhead.
static func preflight(dimensions: Vector2i) -> Dictionary:
    if dimensions.x < 32 or dimensions.y < 32 or dimensions.x > REGIONS.MAX_WORLD_CELLS or dimensions.y > REGIONS.MAX_WORLD_CELLS or dimensions.x % 32 != 0 or dimensions.y % 32 != 0:
        return {"error": ERR_INVALID_PARAMETER}
    var nx: int = int(dimensions.x / 32) + 1
    var nz: int = int(dimensions.y / 32) + 1
    var count: int = nx * nz
    # Conservative bound for the current pretty JSON writer (ASCII hashes,
    # decimal x/z <= 1024, fixed schema), not actual serialized size.
    var manifest_bound: int = 4096 + count * 160
    var source_bytes: int = 16 + (dimensions.x + 1) * (dimensions.y + 1) * 4
    var region_bytes: int = count * REGIONS.FILE_BYTES
    var tfm1_supported: bool = count <= MANIFEST.MAX_PAGES and manifest_bound <= MANIFEST.MAX_MANIFEST_BYTES
    var source_supported: bool = dimensions.x <= MAX_FIXTURE_CELLS and dimensions.y <= MAX_FIXTURE_CELLS
    return {
        "error": OK if tfm1_supported and source_supported else ERR_UNAVAILABLE,
        "pages": count, "tfm1_supported_by_bound": tfm1_supported,
        "tfh1_supported": source_supported, "source_bytes": source_bytes,
        "region_bytes": region_bytes, "manifest_upper_bytes": manifest_bound + 72,
        "logical_upper_bytes": source_bytes + region_bytes + manifest_bound + 72,
        "filesystem_overhead_included": false
    }

## Smooth deterministic analytical height; diagnostic geometry, not art.
## Both the row source and every page use identical Float32 rounding.
static func sample(x: int, z: int) -> float:
    return 8.0 + 3.0 * sin(float(x) * 0.04) + 4.0 * cos(float(z) * 0.035) + 0.5 * sin(float(x + z) * 0.17)

func start(dimensions: Vector2i, matched_recipe: bool = false) -> Error:
    if _thread != null:
        return ERR_BUSY
    var plan: Dictionary = preflight(dimensions)
    if int(plan["error"]) != OK:
        return int(plan["error"])
    var parent: DirAccess = DirAccess.open("user://")
    if parent == null:
        return DirAccess.get_open_error()
    # Allow conservative extra filesystem overhead and temporary page files.
    # A zero/unavailable free-space report is not permission to fill storage.
    var reserve: int = int(plan["logical_upper_bytes"]) + int(plan["pages"]) * 8192 + 16 * 1024 * 1024
    if parent.get_space_left() < reserve:
        return ERR_OUT_OF_MEMORY
    _mutex.lock()
    _cancel = false
    _done = false
    _result = {}
    _progress = {"phase": "starting", "completed": 0, "total": 1}
    _mutex.unlock()
    _thread = Thread.new()
    var status: Error = _thread.start(Callable(self, "_work").bind(dimensions, matched_recipe), Thread.PRIORITY_LOW)
    if status != OK:
        _thread = null
    return status

func _cancelled() -> bool:
    _mutex.lock()
    var value: bool = _cancel
    _mutex.unlock()
    return value

func _update(phase: String, completed: int, total: int) -> void:
    _mutex.lock()
    _progress = {"phase": phase, "completed": completed, "total": total}
    _mutex.unlock()

func progress() -> Dictionary:
    _mutex.lock()
    var p: Dictionary = _progress.duplicate()
    p["done"] = _done
    _mutex.unlock()
    return p

func request_cancel() -> void:
    _mutex.lock()
    _cancel = true
    _mutex.unlock()

## Only after done; never block the render thread on active generation.
func take_result() -> Dictionary:
    if _thread == null:
        return {"error": ERR_UNCONFIGURED}
    if not bool(progress()["done"]):
        return {"error": ERR_BUSY}
    _thread.wait_to_finish()
    _thread = null
    _mutex.lock()
    var r: Dictionary = _result.duplicate()
    _mutex.unlock()
    return r

## Explicit lifecycle shutdown. May wait for one disk operation.
func close() -> void:
    if _thread != null:
        request_cancel()
        _thread.wait_to_finish()
        _thread = null

func _work(dimensions: Vector2i, matched_recipe: bool) -> void:
    var token: String = str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec()) + "_" + str(get_instance_id())
    var output: String = PREFIX + token
    var stage: String = output + ".staging"
    var begin: int = Time.get_ticks_usec()
    var err: Error = ERR_ALREADY_EXISTS
    var owned: bool = false
    if not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output):
        # Non-recursive exclusive creation; never adopt an existing staging dir.
        err = DirAccess.make_dir_absolute(stage)
        owned = err == OK
    if owned:
        err = _generate(stage, dimensions, matched_recipe)
    if err == OK:
        # Cancellation and publication are serialized; cancellation after
        # publication is not a promise to undo an already completed world.
        _mutex.lock()
        if _cancel:
            err = ERR_SKIP
        elif DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
            err = ERR_ALREADY_EXISTS
        else:
            err = DirAccess.rename_absolute(stage, output)
        _mutex.unlock()
    var cleanup: Error = OK
    if err != OK and owned:
        cleanup = _cleanup_owned(stage)
    _mutex.lock()
    _result = {"error": err, "directory": output if err == OK else "",
        "cleanup_error": cleanup, "remaining_staging": stage if cleanup != OK else "",
        "generation_ms": float(Time.get_ticks_usec() - begin) / 1000.0}
    _done = true
    _mutex.unlock()

func _generate(stage: String, dimensions: Vector2i, matched_recipe: bool) -> Error:
    var source_path: String = stage.path_join("source.tfh")
    var f: FileAccess = FileAccess.open(source_path, FileAccess.WRITE)
    if f == null:
        return FileAccess.get_open_error()
    f.store_buffer("TFH1".to_ascii_buffer())
    f.store_32(dimensions.x)
    f.store_32(dimensions.y)
    f.store_float(1.0)
    var row: PackedFloat32Array = PackedFloat32Array()
    row.resize(dimensions.x + 1)
    for z in range(dimensions.y + 1):
        if _cancelled():
            f.close()
            return ERR_SKIP
        for x in range(dimensions.x + 1):
            row[x] = MATCHED.sample(x, z) if matched_recipe else sample(x, z)
        f.store_buffer(row.to_byte_array())
        if f.get_error() != OK:
            var err: Error = f.get_error()
            f.close()
            return err
        if z % 16 == 0:
            _update("source rows", z + 1, dimensions.y + 1)
    f.flush()
    var write_error: Error = f.get_error()
    f.close()
    if write_error != OK:
        return write_error
    var source_digest: String = FileAccess.get_sha256(source_path)
    if source_digest.length() != 64:
        return ERR_FILE_CORRUPT
    var store = REGIONS.new()
    var init: Error = store.initialize(stage, dimensions, 1.0, 1)
    if init != OK:
        return init
    var count: Vector2i = store.page_count()
    var pages: Array[Dictionary] = []
    for pz in range(count.y):
        for px in range(count.x):
            if _cancelled():
                return ERR_SKIP
            var values: PackedFloat32Array = PackedFloat32Array()
            values.resize(REGIONS.PAGE_VALUES)
            for local_z in range(32):
                var gz: int = pz * 32 + local_z
                if gz > dimensions.y:
                    break
                for local_x in range(32):
                    var gx: int = px * 32 + local_x
                    if gx > dimensions.x:
                        break
                    values[local_z * 32 + local_x] = MATCHED.sample(gx, gz) if matched_recipe else sample(gx, gz)
            var key: Vector2i = Vector2i(px, pz)
            var status: Error = store.create_page_with_samples(key, values)
            if status != OK:
                return status
            var digest: String = FileAccess.get_sha256(store._path_for(key))
            if digest.length() != 64:
                return ERR_FILE_CORRUPT
            pages.append({"x": px, "z": pz, "sha256": digest})
            _update("region pages", pages.size(), count.x * count.y)
    if _cancelled():
        return ERR_SKIP
    var doc: Dictionary = MANIFEST.create_document(dimensions, 1.0, "TFH1", source_digest, pages)
    if doc.is_empty():
        return ERR_INVALID_DATA
    var saved: Error = MANIFEST.save(stage, doc)
    if saved != OK:
        return saved
    # Verify every final page against the pinned manifest before publication.
    # Per-page loop enables cancellation; no global heights array.
    var loaded: Dictionary = MANIFEST.load(stage, false)
    if int(loaded["error"]) != OK:
        return int(loaded["error"])
    var verified: int = 0
    for entry in loaded["document"]["pages"]:
        if _cancelled():
            return ERR_SKIP
        var key: Vector2i = Vector2i(int(entry["x"]), int(entry["z"]))
        var path: String = store._path_for(key)
        if FileAccess.get_sha256(path) != str(entry["sha256"]):
            return ERR_FILE_CORRUPT
        var checked: Dictionary = store._parse_page(path, key)
        if int(checked["error"]) != OK:
            return int(checked["error"])
        verified += 1
        _update("verify pages", verified, pages.size())
    if FileAccess.get_sha256(source_path) != source_digest:
        return ERR_FILE_CORRUPT
    return OK

## Only called for a directory exclusively created by this instance.
## Never recurse into unexpected directories or follow links.
static func _cleanup_owned(stage: String) -> Error:
    if not stage.begins_with(PREFIX) or not stage.ends_with(".staging"):
        return ERR_INVALID_PARAMETER
    var dir: DirAccess = DirAccess.open(stage)
    if dir == null:
        return DirAccess.get_open_error()
    if not dir.get_directories().is_empty():
        return ERR_INVALID_DATA
    for name in dir.get_files():
        if dir.is_link(name):
            return ERR_INVALID_DATA
        var err: Error = dir.remove(name)
        if err != OK:
            return err
    return DirAccess.remove_absolute(stage)
