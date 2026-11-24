extends RefCounted
## Isolated TFM2 benchmark generator. No TFH1 forgery or arbitrary output path.
const IDX = preload("res://addons/terra_forge/core/region_index_v2.gd")
const PAGE = preload("res://addons/terra_forge/core/region_page_codec.gd")
const READER = preload("res://addons/terra_forge/core/region_read_v2.gd")
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")
const MAX_FIXTURE_CELLS: int = 8192
const PREFIX: String = "user://tf_profile_v2_"

var _mutex: Mutex = Mutex.new()
var _thread: Thread
var _cancel: bool = false
var _done: bool = false
var _progress: Dictionary = {}
var _result: Dictionary = {}

## Does not allocate pages or touch disk. Byte estimates exclude filesystem overhead.
static func preflight(dimensions: Vector2i) -> Dictionary:
    if not IDX._dimensions_valid(dimensions):
        return {"error": ERR_INVALID_PARAMETER}
    var pages: Vector2i = IDX._pages(dimensions)
    var shards: Vector2i = IDX._shards(pages)
    var count: int = pages.x * pages.y
    var shard_count: int = shards.x * shards.y
    var root_bytes: int = 112 + shard_count * 32
    var shard_bytes: int = shard_count * 80 + count * 32
    var region_bytes: int = count * REGIONS.FILE_BYTES
    return {"error": OK if dimensions.x <= MAX_FIXTURE_CELLS and dimensions.y <= MAX_FIXTURE_CELLS else ERR_UNAVAILABLE,
        "pages": count, "shards": shard_count, "root_bytes": root_bytes, "shard_bytes": shard_bytes,
        "region_bytes": region_bytes, "logical_upper_bytes": root_bytes + shard_bytes + region_bytes + 64,
        "filesystem_overhead_included": false}

## Canonical 24-byte descriptor: TFG1, generator version 1, cells x/z,
## Float32 spacing=1, algorithm id=1. Integer-only dyadic terrain formula.
static func descriptor(dimensions: Vector2i) -> PackedByteArray:
    var raw: PackedByteArray = "TFG1".to_ascii_buffer()
    raw.resize(24)
    raw.encode_u32(4, 1)
    raw.encode_u32(8, dimensions.x)
    raw.encode_u32(12, dimensions.y)
    raw.encode_float(16, 1.0)
    raw.encode_u32(20, 1)
    return raw

static func sample(x: int, z: int) -> float:
    # Exact dyadic arithmetic, portable deterministic Float32. Triangular
    # ridges and cross terms intentionally stress seams, not production art.
    var ridge_x: int = 128 - absi((x % 256) - 128)
    var ridge_z: int = 96 - absi((z % 192) - 96)
    var diagonal: int = 32 - absi(((x + z) % 64) - 32)
    return 8.0 + float(ridge_x) / 16.0 + float(ridge_z) / 32.0 + float(diagonal) / 64.0

func start(dimensions: Vector2i) -> Error:
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
    var reserve: int = int(plan["logical_upper_bytes"]) + (int(plan["pages"]) + int(plan["shards"])) * 8192 + 16 * 1024 * 1024
    if parent.get_space_left() < reserve:
        return ERR_OUT_OF_MEMORY
    _mutex.lock()
    _cancel = false
    _done = false
    _result = {}
    _progress = {"phase": "starting", "completed": 0, "total": 1}
    _mutex.unlock()
    _thread = Thread.new()
    var status: Error = _thread.start(Callable(self, "_work").bind(dimensions), Thread.PRIORITY_LOW)
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

func _work(dimensions: Vector2i) -> void:
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
        err = _generate(stage, dimensions)
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

static func _write_new(path: String, raw: PackedByteArray) -> Error:
    if raw.is_empty() or FileAccess.file_exists(path):
        return ERR_INVALID_DATA
    var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return FileAccess.get_open_error()
    f.store_buffer(raw)
    f.flush()
    var err: Error = f.get_error()
    f.close()
    return err

func _generate(stage: String, dimensions: Vector2i) -> Error:
    var desc: PackedByteArray = descriptor(dimensions)
    var err: Error = _write_new(stage.path_join("fixture.tfg"), desc)
    if err != OK:
        return err
    var pages: Vector2i = IDX._pages(dimensions)
    var shards: Vector2i = IDX._shards(pages)
    var root_hashes: PackedByteArray = PackedByteArray()
    var done: int = 0
    for sz in range(shards.y):
        for sx in range(shards.x):
            var shard_key: Vector2i = Vector2i(sx, sz)
            var edge: Vector2i = IDX._edge(pages, shard_key)
            var hashes: PackedByteArray = PackedByteArray()
            for lz in range(edge.y):
                for lx in range(edge.x):
                    if _cancelled():
                        return ERR_SKIP
                    var key: Vector2i = shard_key * 16 + Vector2i(lx, lz)
                    var values: PackedFloat32Array = PackedFloat32Array()
                    values.resize(REGIONS.PAGE_VALUES)
                    for z in range(32):
                        var gz: int = key.y * 32 + z
                        if gz > dimensions.y:
                            break
                        for x in range(32):
                            var gx: int = key.x * 32 + x
                            if gx > dimensions.x:
                                break
                            values[z * 32 + x] = sample(gx, gz)
                    var raw: PackedByteArray = PAGE.encode(dimensions, 1.0, key, values)
                    err = _write_new(stage.path_join("r_%05d_%05d.tfr" % [key.x, key.y]), raw)
                    if err != OK:
                        return err
                    hashes.append_array(IDX.sha(raw))
                    done += 1
                    _update("region pages", done, pages.x * pages.y)
            var shard_raw: PackedByteArray = IDX.encode_shard(dimensions, 1.0, shard_key, hashes)
            err = _write_new(stage.path_join("s_%05d_%05d.tfs" % [sx, sz]), shard_raw)
            if err != OK:
                return err
            root_hashes.append_array(IDX.sha(shard_raw))
    if _cancelled():
        return ERR_SKIP
    var source: PackedByteArray = IDX.sha(desc)
    var root_raw: PackedByteArray = IDX.encode_root(dimensions, 1.0, IDX.Provenance.SYNTHETIC_V1, source, root_hashes)
    err = _write_new(stage.path_join(IDX.ROOT_NAME), root_raw)
    if err != OK:
        return err
    var loaded: Dictionary = READER.open_root(stage)
    if loaded["error"] != OK:
        return int(loaded["error"])
    var root = loaded["index"]
    var source_read: Dictionary = IDX._read_bounded(stage.path_join("fixture.tfg"), 24, 24)
    if source_read["error"] != OK or IDX.sha(source_read["raw"]) != root.source_digest() or root.snapshot_digest() != root_raw.slice(root_raw.size() - 32):
        return ERR_FILE_CORRUPT
    return int(READER.verify_all(stage, root, _cancelled, _update)["error"])

## Only called for a directory exclusively created by this instance.
## Never recurse into unexpected directories or follow links.
static func _cleanup_owned(stage: String) -> Error:
    if not stage.begins_with(PREFIX) or not stage.ends_with(".staging"):
        return ERR_INVALID_PARAMETER
    var dir: DirAccess = DirAccess.open(stage)
    if dir == null:
        return DirAccess.get_open_error()
    # Stream directory enumeration instead of allocating a list of 66k names.
    dir.include_hidden = true
    var status: Error = dir.list_dir_begin()
    if status != OK:
        return status
    var name: String = dir.get_next()
    while not name.is_empty():
        if dir.current_is_dir() or dir.is_link(name):
            dir.list_dir_end()
            return ERR_INVALID_DATA
        var err: Error = dir.remove(name)
        if err != OK:
            dir.list_dir_end()
            return err
        name = dir.get_next()
    dir.list_dir_end()
    return DirAccess.remove_absolute(stage)
