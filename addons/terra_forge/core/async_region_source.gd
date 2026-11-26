@tool
extends RefCounted
## P1.2b: ONE background IO worker, bounded jobs/results, main-thread cache.
## The worker uses only file bytes / SHA / Float32 decode; no SceneTree,
## Mesh, Physics, ResourceLoader or shared mutable heightfield access.
## Strict open validates all pages; on-demand open checks only the manifest.
## Camera epoch cancellation never changes the pinned manifest.
const IDX = preload("res://addons/terra_forge/core/region_index_v2.gd")
const READER_V2 = preload("res://addons/terra_forge/core/region_read_v2.gd")
const TILE_VIEW = preload("res://addons/terra_forge/core/tile_read_view.gd")
const PAGE_CODEC = preload("res://addons/terra_forge/core/region_page_codec.gd")
const HISTOGRAM = preload("res://addons/terra_forge/core/profile_histogram.gd")
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
var _root_v2 = null
var _snapshot_id: String = ""
# Monotonic per reader instance; TFM1 also needs reopen isolation.
var _session_serial: int = 0
var _shard_limit: int = 4
var _verified_bits: PackedByteArray = PackedByteArray()
var _verified_unique: int = 0
# V2 error status: one byte per page, allocated only on first failure.
# Error enum values fit in a byte; zero denotes no terminal failure.
var _error_bytes: PackedByteArray = PackedByteArray()
var _error_count: int = 0
# Worker-only cache, read/reset by main only after thread join.
var _shard_cache: Dictionary = {}
var _shard_lru: Array[Vector2i] = []
var _shard_hits: int = 0
var _shard_misses: int = 0
var _shard_loads: int = 0
var _shard_evictions: int = 0
# Published under mutex; stats never access the live worker cache.
var _shard_stats: Dictionary = {}
var _cache: Dictionary = {}
var _tile_view = null
var _view_acquires: int = 0
var _view_reads: int = 0
var _view_page_touches: int = 0
var _view_peak_pages: int = 0
var _direct_height_reads: int = 0
var _lru_touches: int = 0
var _lru: Array[Vector2i] = []
var _errors: Dictionary = {}
var _reserved: Dictionary = {}  # Main thread only: key -> request generation.
var _read_count: int = 0
var _cache_hits: int = 0
var _evictions: int = 0
var _discarded: int = 0
var _worker_errors: int = 0
var _last_io_ms: float = 0.0
var _io_histogram = HISTOGRAM.new()
var _queue_histogram = HISTOGRAM.new()
var _delivery_histogram = HISTOGRAM.new()
var _total_histogram = HISTOGRAM.new()
var _accepted_results: int = 0
var collect_io_profile: bool = false
var _max_io_ms: float = 0.0
var _open_verify_ms: float = 0.0
var _verified_all_at_open: bool = false
var _verified_once: Dictionary = {}  # Main thread; one entry per successfully loaded page.


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
# Binary wake ownership: true while a wake is pending OR the worker drains.
# All counters below are protected by _mutex.
var _wake_armed: bool = false
var _wake_posts: int = 0
var _wake_cycles: int = 0
var _submitted: int = 0
var _cancelled_pending: int = 0
var _cancelled_finished: int = 0
var _cancelled_inflight: int = 0

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
    var result: Dictionary = PAGE_CODEC.load_page(str(job["path"]), job["cells"], float(job["spacing"]), key, str(job["sha256"]).hex_decode(), false)
    result["key"] = key
    result["generation"] = int(job["generation"])
    result["io_ms"] = float(Time.get_ticks_usec() - begin) / 1000.0
    return result

## Default mode remains STRICT to avoid changing callers' safety guarantees.
## verify_all_pages=false validates ONLY the checksummed, schema-checked
## TFM1 manifest synchronously; each TFR1 page MUST pass full-file SHA-256
## and internal payload checks on its first and every subsequent disk load.
## 'open' in this mode means MANIFEST OPEN, not WORLD FULLY VERIFIED.
func open(directory: String, resident_limit: int = 4, max_jobs: int = 3,
        verify_all_pages: bool = true) -> Error:
    close()
    if directory.is_empty() or resident_limit < 1 or resident_limit > 64:
        return ERR_INVALID_PARAMETER
    if max_jobs < 1 or max_jobs > 8:
        return ERR_INVALID_PARAMETER
    var started: int = Time.get_ticks_usec()
    var doc_result: Dictionary = MANIFEST.load(directory, verify_all_pages)
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
    _manifest_hashes = hashes
    return _start_worker(directory, resident_limit, max_jobs, verify_all_pages, checked_ms)

## Explicit opt-in; no auto detection or fallback to TFM1.
func open_v2(directory: String, resident_limit: int = 4, max_jobs: int = 3,
        verify_all_pages: bool = true, shard_limit: int = 4) -> Error:
    close()
    if directory.is_empty() or resident_limit < 1 or resident_limit > 64 or max_jobs < 1 or max_jobs > 8 or shard_limit < 1 or shard_limit > 16:
        return ERR_INVALID_PARAMETER
    var started: int = Time.get_ticks_usec()
    var opened: Dictionary = READER_V2.open_root(directory)
    if opened["error"] != OK:
        return int(opened["error"])
    var root = opened["index"]
    if verify_all_pages:
        var checked: Dictionary = READER_V2.verify_all(directory, root)
        if checked["error"] != OK:
            return int(checked["error"])
    _root_v2 = root
    _snapshot_id = root.snapshot_digest().hex_encode()
    _shard_limit = shard_limit
    cells = root.cells()
    spacing = root.spacing()
    var pages: Vector2i = root.page_count()
    _verified_bits.resize((pages.x * pages.y + 7) >> 3)
    return _start_worker(directory, resident_limit, max_jobs, verify_all_pages, float(Time.get_ticks_usec() - started) / 1000.0)

func _start_worker(directory: String, resident_limit: int, max_jobs: int, verify_all_pages: bool, checked_ms: float) -> Error:
    _directory = directory.trim_suffix("/")
    _limit = resident_limit
    _job_limit = max_jobs
    _open_verify_ms = checked_ms
    _verified_all_at_open = verify_all_pages
    _verified_once.clear()
    _mutex.lock()
    _stop = false
    _generation = 0
    _mutex.unlock()
    _thread = Thread.new()
    var status: Error = _thread.start(Callable(self, "_worker_loop"), Thread.PRIORITY_LOW)
    if status != OK:
        close()
        return status
    _thread_started = true
    _opened = true
    _session_serial += 1
    return OK

func session_serial() -> int:
    return _session_serial

## Main-thread queries for streaming and publication. stats() is diagnostic.
func generation() -> int:
    return _generation

func snapshot_id() -> String:
    return _snapshot_id

func resident_page_count() -> int:
    return _cache.size()

func is_open() -> bool:
    return _opened

func page_count() -> Vector2i:
    if not _opened:
        return Vector2i.ZERO
    return Vector2i(int(cells.x / PAGE_WIDTH) + 1, int(cells.y / PAGE_WIDTH) + 1)

func _valid_page(key: Vector2i) -> bool:
    var bounds: Vector2i = page_count()
    return _opened and key.x >= 0 and key.y >= 0 and key.x < bounds.x and key.y < bounds.y

## Single synchronous lease, with a rectangular <=3x3 resident page halo.
## No eviction can retain extra payload: revoke before cache mutation.
func acquire_tile_view(keys: Array[Vector2i]) -> Dictionary:
    if not _opened:
        return {"error": ERR_UNCONFIGURED}
    if _tile_view != null:
        return {"error": ERR_BUSY}
    if keys.is_empty() or keys.size() > TILE_VIEW.MAX_PAGES:
        return {"error": ERR_INVALID_PARAMETER}
    var first: Vector2i = keys[0]
    var last: Vector2i = first
    var unique: Dictionary = {}
    for key in keys:
        if not _valid_page(key) or unique.has(key):
            return {"error": ERR_INVALID_PARAMETER}
        unique[key] = true
        first = Vector2i(mini(first.x, key.x), mini(first.y, key.y))
        last = Vector2i(maxi(last.x, key.x), maxi(last.y, key.y))
    var extent: Vector2i = last - first + Vector2i.ONE
    if extent.x > 3 or extent.y > 3 or extent.x * extent.y != keys.size():
        return {"error": ERR_INVALID_PARAMETER}
    var pages: Array[PackedFloat32Array] = []
    for z in range(first.y, last.y + 1):
        for x in range(first.x, last.x + 1):
            var key: Vector2i = Vector2i(x,z)
            var status: Error = page_status(key)
            if status != OK:
                return {"error": status}
            var values: PackedFloat32Array = _cache[key]
            if values.size() != REGIONS.PAGE_VALUES:
                return {"error": ERR_FILE_CORRUPT}
            pages.append(values)
    for key in keys:
        _touch(key)
    _view_page_touches += keys.size()
    _view_acquires += 1
    _view_peak_pages = maxi(_view_peak_pages, pages.size())
    _tile_view = TILE_VIEW.new(cells, spacing, first, extent, pages)
    return {"error": OK, "view": _tile_view}

func release_tile_view(view) -> Error:
    if _tile_view == null or view != _tile_view:
        return ERR_INVALID_PARAMETER
    _revoke_tile_view()
    return OK

func _revoke_tile_view() -> void:
    if _tile_view != null:
        _view_reads += _tile_view._revoke()
        _tile_view = null

func set_generation(next_id: int) -> Error:
    if not _opened or next_id < 0:
        return ERR_INVALID_PARAMETER
    _mutex.lock()
    if next_id <= _generation:
        _mutex.unlock()
        return ERR_INVALID_PARAMETER
    _generation = next_id
    # Already-started reads may finish; worker discards their result.
    _cancelled_pending += _pending.size()
    _cancelled_finished += _finished.size()
    _pending.clear()
    _finished.clear()
    _mutex.unlock()
    _revoke_tile_view()
    _reserved.clear()
    _errors.clear()
    _error_bytes.clear()
    _error_count = 0
    return OK

func _ordinal(key: Vector2i) -> int:
    return key.y * page_count().x + key.x

func _terminal_error(key: Vector2i) -> Error:
    if _root_v2 == null:
        return int(_errors.get(key, OK))
    if _error_bytes.is_empty():
        return OK
    return int(_error_bytes[_ordinal(key)])

func _record_error(key: Vector2i, err: Error) -> void:
    if _root_v2 == null:
        _errors[key] = err
        return
    if _error_bytes.is_empty():
        var count: Vector2i = page_count()
        _error_bytes.resize(count.x * count.y)
    var index: int = _ordinal(key)
    if _error_bytes[index] == 0:
        _error_count += 1
    _error_bytes[index] = int(err)

func _record_verified(key: Vector2i) -> void:
    if _root_v2 == null:
        _verified_once[key] = true
        return
    var ordinal: int = _ordinal(key)
    var byte_index: int = ordinal >> 3
    var mask: int = 1 << (ordinal & 7)
    if (_verified_bits[byte_index] & mask) == 0:
        _verified_bits[byte_index] = _verified_bits[byte_index] | mask
        _verified_unique += 1

func request_page(key: Vector2i) -> Error:
    if not _valid_page(key) or (_root_v2 == null and not _manifest_hashes.has(key)):
        return ERR_INVALID_PARAMETER
    if _cache.has(key):
        _cache_hits += 1
        _touch(key)
        return OK
    var terminal: Error = _terminal_error(key)
    if terminal != OK:
        return terminal
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
        "sha256": str(_manifest_hashes.get(key, "")),
        "snapshot": _snapshot_id,
        "cells": cells, "spacing": spacing,
        "submitted_us": Time.get_ticks_usec(), "profile": collect_io_profile
    }
    _pending.append(job)
    _submitted += 1
    var notify: bool = not _wake_armed
    if notify:
        _wake_armed = true
        _wake_posts += 1
    _mutex.unlock()
    _reserved[key] = generation
    if notify:
        _wake.post()
    return OK

## Worker-only shard LRU. Verified root is immutable for the entire open session.
func _read_v2(job: Dictionary) -> Dictionary:
    var begin: int = Time.get_ticks_usec()
    var key: Vector2i = job["key"]
    var sk: Vector2i = _root_v2.shard_for_page(key)
    var result: Dictionary = {"error": ERR_FILE_CORRUPT}
    if str(job["snapshot"]) == _snapshot_id and sk.x >= 0:
        var shard = _shard_cache.get(sk)
        if shard == null:
            _shard_misses += 1
            var loaded: Dictionary = IDX.load_shard(_directory, _root_v2, sk)
            if loaded["error"] == OK:
                shard = loaded["index"]
                _shard_loads += 1
                if _shard_cache.size() >= _shard_limit:
                    _shard_cache.erase(_shard_lru.pop_front())
                    _shard_evictions += 1
                _shard_cache[sk] = shard
                _shard_lru.append(sk)
            else:
                result = {"error": loaded["error"]}
        else:
            _shard_hits += 1
            _shard_lru.erase(sk)
            _shard_lru.append(sk)
        if shard != null:
            result = READER_V2.read_from_shard(_directory, _root_v2, shard, key)
    result["key"] = key
    result["generation"] = int(job["generation"])
    result["snapshot"] = job["snapshot"]
    result["io_ms"] = float(Time.get_ticks_usec() - begin) / 1000.0
    return result

func _publish_shard_stats() -> void:
    # Called only by worker, under mutex.
    var bytes: int = 0
    for shard in _shard_cache.values():
        bytes += shard.byte_count()
    _shard_stats = {"resident": _shard_cache.size(), "bytes": bytes,
        "hits": _shard_hits, "misses": _shard_misses,
        "loads": _shard_loads, "evictions": _shard_evictions}

func _worker_loop() -> void:
    while true:
        _wake.wait()
        _mutex.lock()
        _wake_cycles += 1
        _mutex.unlock()
        # Drain available work with a single wake. Camera cancellations can
        # remove pending jobs but cannot create a semaphore-token backlog.
        while true:
            _mutex.lock()
            if _stop:
                _mutex.unlock()
                return
            if _pending.is_empty():
                _wake_armed = false
                _mutex.unlock()
                break
            var job: Dictionary = _pending.pop_front()
            _inflight += 1
            _mutex.unlock()
            var started: int = Time.get_ticks_usec()
            var output: Dictionary = _read_v2(job) if _root_v2 != null else _read_page_file(job)
            if bool(job["profile"]):
                output["submitted_us"] = job["submitted_us"]
                output["started_us"] = started
                output["finished_us"] = Time.get_ticks_usec()
            _mutex.lock()
            _inflight -= 1
            if _root_v2 != null:
                _publish_shard_stats()
            if not _stop and int(job["generation"]) == _generation:
                # Admission already counts pending + inflight + finished.
                # There is guaranteed room for this result.
                _finished.append(output)
            else:
                _cancelled_inflight += 1
            _mutex.unlock()

func poll_results(max_results: int = 3) -> Dictionary:
    if not _opened or max_results < 1 or max_results > 8:
        return {"error": ERR_INVALID_PARAMETER}
    _revoke_tile_view()
    var found: Array[Dictionary] = []
    _mutex.lock()
    var current: int = _generation
    while not _finished.is_empty() and found.size() < max_results:
        found.append(_finished.pop_front())
    _mutex.unlock()
    var committed: int = 0
    var failures: int = 0
    for result in found:
        if int(result["generation"]) != current or str(result.get("snapshot", "")) != _snapshot_id:
            _discarded += 1
            continue
        var key: Vector2i = result["key"]
        _reserved.erase(key)
        var duration: float = float(result["io_ms"])
        _accepted_results += 1
        if result.has("submitted_us"):
            var accepted: int = Time.get_ticks_usec()
            _io_histogram.add(duration)
            _queue_histogram.add(float(int(result["started_us"]) - int(result["submitted_us"])) / 1000.0)
            _delivery_histogram.add(float(accepted - int(result["finished_us"])) / 1000.0)
            _total_histogram.add(float(accepted - int(result["submitted_us"])) / 1000.0)
        _last_io_ms = duration
        _max_io_ms = maxf(_max_io_ms, duration)
        var err: Error = int(result["error"])
        if err != OK:
            _record_error(key, err)
            _worker_errors += 1
            failures += 1
            continue
        var values: PackedFloat32Array = result["values"]
        if values.size() != REGIONS.PAGE_VALUES:
            _record_error(key, ERR_FILE_CORRUPT)
            failures += 1
            continue
        if _cache.size() >= _limit and not _cache.has(key):
            var oldest: Vector2i = _lru.pop_front()
            _cache.erase(oldest)
            _evictions += 1
        _cache[key] = values
        _record_verified(key)
        _touch(key)
        _read_count += 1
        committed += 1
    return {"error": OK, "committed": committed, "failed": failures, "discarded": _discarded}

func _touch(key: Vector2i) -> void:
    _lru_touches += 1
    var idx: int = _lru.find(key)
    if idx >= 0:
        _lru.remove_at(idx)
    _lru.append(key)

## Main-thread-only duplicate check for a pending, running, or
## completed-but-uncommitted read. Avoid counting duplicate requests
## against the per-pump *new job* submission budget.
func is_requested(key: Vector2i) -> bool:
    return _reserved.has(key)

## Cache pinning hint for a tile under construction. Only promotes
## already resident verified pages; does NOT retain extra pages.
func prioritize_resident(keys: Array[Vector2i]) -> void:
    if not _opened:
        return
    for key in keys:
        if _cache.has(key):
            _touch(key)

func page_status(key: Vector2i) -> Error:
    if not _valid_page(key):
        return ERR_INVALID_PARAMETER
    if _cache.has(key):
        return OK
    var terminal: Error = _terminal_error(key)
    return terminal if terminal != OK else ERR_BUSY

func get_height(x: int, z: int) -> Dictionary:
    if not _opened:
        return {"error": ERR_UNCONFIGURED}
    if x < 0 or z < 0 or x > cells.x or z > cells.y:
        return {"error": ERR_INVALID_PARAMETER}
    var key: Vector2i = Vector2i(int(x / PAGE_WIDTH), int(z / PAGE_WIDTH))
    var status: Error = page_status(key)
    if status != OK:
        return {"error": status}
    _direct_height_reads += 1
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
    _revoke_tile_view()
    for key in _lru.duplicate():
        if key.x < first.x or key.y < first.y or key.x > last.x or key.y > last.y:
            _cache.erase(key)
            _lru.erase(key)
            _evictions += 1
    return OK

func io_profile() -> Dictionary:
    return _io_histogram.report()

func pipeline_profile() -> Dictionary:
    return {
        "queue_wait_ms": _queue_histogram.report(),
        "worker_service_ms": _io_histogram.report(),
        "delivery_wait_ms": _delivery_histogram.report(),
        "request_to_accept_ms": _total_histogram.report()
    }

func stats() -> Dictionary:
    _mutex.lock()
    var outstanding: int = _pending.size()
    var inflight: int = _inflight
    var finished: int = _finished.size()
    var generation: int = _generation
    var submitted: int = _submitted
    var cancelled_pending: int = _cancelled_pending
    var cancelled_finished: int = _cancelled_finished
    var cancelled_inflight: int = _cancelled_inflight
    var wake_posts: int = _wake_posts
    var wake_cycles: int = _wake_cycles
    var shard_stats: Dictionary = _shard_stats.duplicate()
    _mutex.unlock()
    var total_pages: Vector2i = page_count()
    return {
        "open": _opened,
        "resident": _cache.size(),
        "limit": _limit,
        "resident_float_bytes": _cache.size() * PAGE_BYTES,
        "direct_height_reads": _direct_height_reads, "lru_touches": _lru_touches,
        "tile_view_acquires": _view_acquires, "tile_view_reads": _view_reads + (_tile_view._reads if _tile_view != null else 0),
        "tile_view_page_touches": _view_page_touches, "tile_view_peak_pages": _view_peak_pages,
        "tile_view_active_pages": _tile_view.page_count_held() if _tile_view != null else 0,
        "outstanding": outstanding,
        "inflight": inflight,
        "finished": finished,
        "max_jobs": _job_limit,
        "generation": generation,
        "disk_reads": _read_count,
        "cache_hits": _cache_hits,
        "evictions": _evictions,
        "stale_discarded": _discarded + cancelled_pending + cancelled_finished + cancelled_inflight,
        "submitted": submitted, "accepted_results": _accepted_results,
        "cancelled_pending": cancelled_pending, "cancelled_finished": cancelled_finished,
        "cancelled_inflight": cancelled_inflight, "wake_posts": wake_posts, "wake_cycles": wake_cycles,
        "worker_errors": _worker_errors,
        "last_io_ms": _last_io_ms,
        "max_io_ms": _max_io_ms,
        "open_verify_ms": _open_verify_ms,
        "manifest_entries": total_pages.x * total_pages.y if _root_v2 != null else _manifest_hashes.size(),
        "index_format": "TFM2" if _root_v2 != null else "TFM1",
        "snapshot_id": _snapshot_id,
        "root_index_bytes": _root_v2.byte_count() if _root_v2 != null else 0,
        "shard_limit": _shard_limit if _root_v2 != null else 0,
        "shard_resident": shard_stats.get("resident", 0),
        "shard_resident_bytes": shard_stats.get("bytes", 0),
        "shard_hits": shard_stats.get("hits", 0), "shard_misses": shard_stats.get("misses", 0),
        "shard_loads": shard_stats.get("loads", 0), "shard_evictions": shard_stats.get("evictions", 0),
        "verification_bitmap_bytes": _verified_bits.size(), "terminal_error_bytes": _error_bytes.size(),
        "terminal_errors": _error_count if _root_v2 != null else _errors.size(),
        "verified_at_open": _verified_all_at_open,
        "pages_verified_on_demand": _verified_unique if _root_v2 != null else _verified_once.size(),
        "verification_mode": "strict" if _verified_all_at_open else "on_demand"
    }

func close() -> void:
    _revoke_tile_view()
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
    _root_v2 = null
    _snapshot_id = ""
    _verified_bits.clear()
    _verified_unique = 0
    _error_bytes.clear()
    _error_count = 0
    _shard_cache.clear()
    _shard_lru.clear()
    _shard_stats.clear()
    _shard_hits = 0
    _shard_misses = 0
    _shard_loads = 0
    _shard_evictions = 0
    _verified_all_at_open = false
    _verified_once.clear()
    _cache.clear()
    _lru.clear()
    _view_acquires = 0
    _view_reads = 0
    _view_page_touches = 0
    _view_peak_pages = 0
    _direct_height_reads = 0
    _lru_touches = 0
    _errors.clear()
    _reserved.clear()
    _mutex.lock()
    _inflight = 0
    _generation = 0
    _wake_armed = false
    _wake_posts = 0
    _wake_cycles = 0
    _submitted = 0
    _cancelled_pending = 0
    _cancelled_finished = 0
    _cancelled_inflight = 0
    _mutex.unlock()
    # Only replace after join: no stale wake tokens survive reopen.
    _wake = Semaphore.new()
    _accepted_results = 0
    _read_count = 0
    _cache_hits = 0
    _evictions = 0
    _discarded = 0
    _worker_errors = 0
    _io_histogram = HISTOGRAM.new()
    _queue_histogram = HISTOGRAM.new()
    _delivery_histogram = HISTOGRAM.new()
    _total_histogram = HISTOGRAM.new()
    collect_io_profile = false
    _last_io_ms = 0.0
    _max_io_ms = 0.0
    _open_verify_ms = 0.0
