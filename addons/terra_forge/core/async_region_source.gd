@tool
extends RefCounted
## P1.2b: ONE background IO worker, bounded jobs/results, main-thread cache.
## The worker uses only file bytes / SHA / Float32 decode; no SceneTree,
## Mesh, Physics, ResourceLoader or shared mutable heightfield access.
## open() still validates the ENTIRE TFM1 world synchronously: this is a
## safety-first prototype, not a startup-latency solution.
const MANIFEST = preload("res://addons/terra_forge/core/region_manifest.gd")
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")
const PAGE_WIDTH: int = REGIONS.PAGE_WIDTH
const PAGE_BYTES: int = REGIONS.PAGE_BYTES
const FILE_BYTES: int = REGIONS.FILE_BYTES

var cells: Vector2i = Vector2i.ZERO
var spacing: float = 1.0
var _directory: String = ""
var _opened: bool = false
var _limit: int = 4
var _job_limit: int = 3
var _manifest_hashes: Dictionary = {}
var _cache: Dictionary = {}
var _lru: Array[Vector2i] = []
var _errors: Dictionary = {}
var _reserved: Dictionary = {}  # Main thread only: key -> request generation.
var _read_count: int = 0
var _cache_hits: int = 0
var _evictions: int = 0
var _discarded: int = 0
var _worker_errors: int = 0
var _last_io_ms: float = 0.0
var _max_io_ms: float = 0.0
var _open_verify_ms: float = 0.0

# Shared across main/worker, ALL guarded by _mutex.
var _mutex: Mutex = Mutex.new()
var _wake: Semaphore = Semaphore.new()
var _thread: Thread = Thread.new()
var _thread_started: bool = false
var _stop: bool = false
var _generation: int = 0
var _pending: Array[Dictionary] = []
var _finished: Array[Dictionary] = []
var _inflight: int = 0

static func _sha(data: PackedByteArray) -> String:
    var ctx: HashingContext = HashingContext.new()
    if ctx.start(HashingContext.HASH_SHA256) != OK:
        return ""
    if ctx.update(data) != OK:
        return ""
    return ctx.finish().hex_encode()

# Job has only independent value data. No shared source/cache is dereferenced.
static func _read_page_file(job: Dictionary) -> Dictionary:
    var begin: int = Time.get_ticks_usec()
    var key: Vector2i = job["key"]
    var result: Dictionary = {
        "key": key, "generation": int(job["generation"]),
        "error": ERR_FILE_CORRUPT
    }
    var path: String = str(job["path"])
    if not FileAccess.file_exists(path):
        result["error"] = ERR_FILE_NOT_FOUND
    else:
        var file: FileAccess = FileAccess.open(path, FileAccess.READ)
        if file == null:
            result["error"] = FileAccess.get_open_error()
        elif file.get_length() != FILE_BYTES:
            result["error"] = ERR_FILE_CORRUPT
        else:
            # One file handle, one immutable byte snapshot; no hash(path) /
            # parse(path) / hash(path) time-of-check/time-of-use gap.
            var raw: PackedByteArray = file.get_buffer(FILE_BYTES)
            file.close()
            if raw.size() == FILE_BYTES and _sha(raw) == str(job["sha256"]):
                var payload: PackedByteArray = raw.slice(0, REGIONS.HEADER_BYTES + PAGE_BYTES)
                var inner: String = raw.slice(REGIONS.HEADER_BYTES + PAGE_BYTES, FILE_BYTES).get_string_from_ascii()
                if raw.slice(0, 4).get_string_from_ascii() == REGIONS.MAGIC and _sha(payload) == inner:
                    var sizes: Vector2i = Vector2i(int(raw.decode_u32(4)), int(raw.decode_u32(8)))
                    var source_key: Vector2i = Vector2i(int(raw.decode_u32(12)), int(raw.decode_u32(16)))
                    var size: float = raw.decode_float(20)
                    if sizes == job["cells"] and source_key == key and is_equal_approx(size, float(job["spacing"])):
                        var values: PackedFloat32Array = raw.slice(REGIONS.HEADER_BYTES, REGIONS.HEADER_BYTES + PAGE_BYTES).to_float32_array()
                        if values.size() == REGIONS.PAGE_VALUES:
                            var finite: bool = true
                            for v in values:
                                if not is_finite(v):
                                    finite = false
                                    break
                            if finite:
                                result["error"] = OK
                                result["values"] = values
    result["io_ms"] = float(Time.get_ticks_usec() - begin) / 1000.0
    return result

func open(directory: String, resident_limit: int = 4, max_jobs: int = 3) -> Error:
    close()
    if directory.is_empty() or resident_limit < 1 or resident_limit > 64:
        return ERR_INVALID_PARAMETER
    if max_jobs < 1 or max_jobs > 8:
        return ERR_INVALID_PARAMETER
    var started: int = Time.get_ticks_usec()
    var doc_result: Dictionary = MANIFEST.load(directory, true)
    var checked_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
    var status: Error = int(doc_result.get("error", ERR_FILE_CORRUPT))
    if status != OK:
        return status
    var doc: Dictionary = doc_result["document"]
    var hashes: Dictionary = {}
    for entry in doc["pages"]:
        var page: Dictionary = entry
        hashes[Vector2i(int(page["x"]), int(page["z"]))] = str(page["sha256"])
    cells = Vector2i(int(doc["cells_x"]), int(doc["cells_z"]))
    spacing = float(doc["spacing"])
    _directory = directory.trim_suffix("/")
    _manifest_hashes = hashes
    _limit = resident_limit
    _job_limit = max_jobs
    _open_verify_ms = checked_ms
    _mutex.lock()
    _stop = false
    _generation = 0
    _mutex.unlock()
    _thread = Thread.new()
    status = _thread.start(Callable(self, "_worker_loop"), Thread.PRIORITY_LOW)
    if status != OK:
        close()
        return status
    _thread_started = true
    _opened = true
    return OK

func is_open() -> bool:
    return _opened

func page_count() -> Vector2i:
    if not _opened:
        return Vector2i.ZERO
    return Vector2i(int(cells.x / PAGE_WIDTH) + 1, int(cells.y / PAGE_WIDTH) + 1)

func _valid_page(key: Vector2i) -> bool:
    var bounds: Vector2i = page_count()
    return _opened and key.x >= 0 and key.y >= 0 and key.x < bounds.x and key.y < bounds.y

func set_generation(next_id: int) -> Error:
    if not _opened or next_id < 0:
        return ERR_INVALID_PARAMETER
    _mutex.lock()
    if next_id <= _generation:
        _mutex.unlock()
        return ERR_INVALID_PARAMETER
    _generation = next_id
    # Already-started reads may finish; worker discards their result.
    _pending.clear()
    _finished.clear()
    _mutex.unlock()
    _reserved.clear()
    _errors.clear()
    return OK

func request_page(key: Vector2i) -> Error:
    if not _valid_page(key) or not _manifest_hashes.has(key):
        return ERR_INVALID_PARAMETER
    if _cache.has(key):
        _cache_hits += 1
        _touch(key)
        return OK
    if _errors.has(key):
        return int(_errors[key])
    if _reserved.has(key):
        return OK
    _mutex.lock()
    var outstanding: int = _pending.size() + _inflight + _finished.size()
    if outstanding >= _job_limit or _stop:
        _mutex.unlock()
        return ERR_BUSY
    var generation: int = _generation
    var job: Dictionary = {
        "key": key, "generation": generation,
        "path": "%s/r_%05d_%05d.tfr" % [_directory, key.x, key.y],
        "sha256": str(_manifest_hashes[key]),
        "cells": cells, "spacing": spacing
    }
    _pending.append(job)
    _mutex.unlock()
    _reserved[key] = generation
    _wake.post()
    return OK

func _worker_loop() -> void:
    while true:
        _wake.wait()
        _mutex.lock()
        if _stop:
            _mutex.unlock()
            return
        if _pending.is_empty():
            _mutex.unlock()
            continue
        var job: Dictionary = _pending.pop_front()
        _inflight += 1
        _mutex.unlock()
        var output: Dictionary = _read_page_file(job)
        _mutex.lock()
        _inflight -= 1
        if not _stop and int(job["generation"]) == _generation:
            # Bounded result storage, never unbounded PackedFloat32 buildup.
            if _finished.size() < _job_limit:
                _finished.append(output)
        _mutex.unlock()

func poll_results(max_results: int = 3) -> Dictionary:
    if not _opened or max_results < 1 or max_results > 8:
        return {"error": ERR_INVALID_PARAMETER}
    var found: Array[Dictionary] = []
    _mutex.lock()
    var current: int = _generation
    while not _finished.is_empty() and found.size() < max_results:
        found.append(_finished.pop_front())
    _mutex.unlock()
    var committed: int = 0
    var failures: int = 0
    for result in found:
        if int(result["generation"]) != current:
            _discarded += 1
            continue
        var key: Vector2i = result["key"]
        _reserved.erase(key)
        var duration: float = float(result["io_ms"])
        _last_io_ms = duration
        _max_io_ms = maxf(_max_io_ms, duration)
        var err: Error = int(result["error"])
        if err != OK:
            _errors[key] = err
            _worker_errors += 1
            failures += 1
            continue
        var values: PackedFloat32Array = result["values"]
        if values.size() != REGIONS.PAGE_VALUES:
            _errors[key] = ERR_FILE_CORRUPT
            failures += 1
            continue
        if _cache.size() >= _limit and not _cache.has(key):
            var oldest: Vector2i = _lru.pop_front()
            _cache.erase(oldest)
            _evictions += 1
        _cache[key] = values
        _touch(key)
        _read_count += 1
        committed += 1
    return {"error": OK, "committed": committed, "failed": failures, "discarded": _discarded}

func _touch(key: Vector2i) -> void:
    var idx: int = _lru.find(key)
    if idx >= 0:
        _lru.remove_at(idx)
    _lru.append(key)

func page_status(key: Vector2i) -> Error:
    if not _valid_page(key):
        return ERR_INVALID_PARAMETER
    if _cache.has(key):
        return OK
    if _errors.has(key):
        return int(_errors[key])
    return ERR_BUSY

func get_height(x: int, z: int) -> Dictionary:
    if not _opened:
        return {"error": ERR_UNCONFIGURED}
    if x < 0 or z < 0 or x > cells.x or z > cells.y:
        return {"error": ERR_INVALID_PARAMETER}
    var key: Vector2i = Vector2i(int(x / PAGE_WIDTH), int(z / PAGE_WIDTH))
    var status: Error = page_status(key)
    if status != OK:
        return {"error": status}
    _touch(key)
    var values: PackedFloat32Array = _cache[key]
    return {"error": OK, "height": values[(z % PAGE_WIDTH) * PAGE_WIDTH + (x % PAGE_WIDTH)]}

func sample_local(world_x: float, world_z: float) -> Dictionary:
    if not _opened:
        return {"error": ERR_UNCONFIGURED}
    if not is_finite(world_x) or not is_finite(world_z):
        return {"error": ERR_INVALID_PARAMETER}
    if world_x < 0.0 or world_z < 0.0 or world_x > float(cells.x) * spacing or world_z > float(cells.y) * spacing:
        return {"error": ERR_INVALID_PARAMETER}
    var px: float = world_x / spacing
    var pz: float = world_z / spacing
    var ix: int = mini(floori(px), cells.x - 1)
    var iz: int = mini(floori(pz), cells.y - 1)
    var fx: float = px - float(ix)
    var fz: float = pz - float(iz)
    var first: Dictionary = get_height(ix, iz)
    if int(first["error"]) != OK:
        return first
    var second: Dictionary = get_height(ix + 1, iz)
    if int(second["error"]) != OK:
        return second
    var third: Dictionary = get_height(ix, iz + 1)
    if int(third["error"]) != OK:
        return third
    var fourth: Dictionary = get_height(ix + 1, iz + 1)
    if int(fourth["error"]) != OK:
        return fourth
    var top: float = lerpf(float(first["height"]), float(second["height"]), fx)
    var bottom: float = lerpf(float(third["height"]), float(fourth["height"]), fx)
    return {"error": OK, "height": lerpf(top, bottom, fz)}

func release_outside(first: Vector2i, last: Vector2i) -> Error:
    if not _valid_page(first) or not _valid_page(last) or first.x > last.x or first.y > last.y:
        return ERR_INVALID_PARAMETER
    for key in _lru.duplicate():
        if key.x < first.x or key.y < first.y or key.x > last.x or key.y > last.y:
            _cache.erase(key)
            _lru.erase(key)
            _evictions += 1
    return OK

func stats() -> Dictionary:
    _mutex.lock()
    var outstanding: int = _pending.size()
    var inflight: int = _inflight
    var finished: int = _finished.size()
    var generation: int = _generation
    _mutex.unlock()
    return {
        "open": _opened,
        "resident": _cache.size(),
        "limit": _limit,
        "resident_float_bytes": _cache.size() * PAGE_BYTES,
        "outstanding": outstanding,
        "inflight": inflight,
        "finished": finished,
        "max_jobs": _job_limit,
        "generation": generation,
        "disk_reads": _read_count,
        "cache_hits": _cache_hits,
        "evictions": _evictions,
        "stale_discarded": _discarded,
        "worker_errors": _worker_errors,
        "last_io_ms": _last_io_ms,
        "max_io_ms": _max_io_ms,
        "open_verify_ms": _open_verify_ms
    }

func close() -> void:
    # Join can block until a single in-flight file read finishes. Never call
    # this every frame. Caller must close before losing the last reference.
    _mutex.lock()
    _stop = true
    _pending.clear()
    _finished.clear()
    _mutex.unlock()
    if _thread_started:
        _wake.post()
        _thread.wait_to_finish()
    _thread_started = false
    _opened = false
    cells = Vector2i.ZERO
    spacing = 1.0
    _directory = ""
    _manifest_hashes.clear()
    _cache.clear()
    _lru.clear()
    _errors.clear()
    _reserved.clear()
    _mutex.lock()
    _inflight = 0
    _generation = 0
    _mutex.unlock()
    _read_count = 0
    _cache_hits = 0
    _evictions = 0
    _discarded = 0
    _worker_errors = 0
    _last_io_ms = 0.0
    _max_io_ms = 0.0
    _open_verify_ms = 0.0
