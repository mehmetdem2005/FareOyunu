@tool
extends RefCounted
## P1.2 read-only TFM1/TFR1 Float32 sample source.
## Standalone proof of paging: intentionally NOT connected to live terrain yet.
## No writes, no fallback to flat heights, no Godot scene/physics API.
const MANIFEST = preload("res://addons/terra_forge/core/region_manifest.gd")
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")
const PAGE_WIDTH: int = REGIONS.PAGE_WIDTH
const PAGE_BYTES: int = REGIONS.PAGE_BYTES

var cells: Vector2i = Vector2i.ZERO
var spacing: float = 1.0
var _directory: String = ""
var _opened: bool = false
var _limit: int = 4
var _expected_hashes: Dictionary = {}
var _cache: Dictionary = {}
var _lru: Array[Vector2i] = []
var _page_reader = REGIONS.new()
var _disk_reads: int = 0
var _hits: int = 0
var _misses: int = 0
var _evictions: int = 0
var _last_io_ms: float = 0.0
var _max_io_ms: float = 0.0
var _open_verify_ms: float = 0.0
var _prefetch_a: Vector2i = Vector2i(-1, -1)
var _prefetch_b: Vector2i = Vector2i(-1, -1)
var _prefetch_cursor: int = 0
var _prefetch_generation: int = 0

func _clear_state() -> void:
    # Never continue serving old cached heights after an invalid reopen.
    _opened = false
    _directory = ""
    cells = Vector2i.ZERO
    spacing = 1.0
    _expected_hashes.clear()
    _cache.clear()
    _lru.clear()
    _disk_reads = 0
    _hits = 0
    _misses = 0
    _evictions = 0
    _last_io_ms = 0.0
    _max_io_ms = 0.0
    _open_verify_ms = 0.0
    _prefetch_a = Vector2i(-1, -1)
    _prefetch_b = Vector2i(-1, -1)
    _prefetch_cursor = 0
    _prefetch_generation = 0
    _page_reader = REGIONS.new()

func open(directory: String, cache_pages: int = 4) -> Error:
    _clear_state()
    if directory.is_empty() or cache_pages < 1 or cache_pages > 64:
        return ERR_INVALID_PARAMETER
    var started: int = Time.get_ticks_usec()
    # Verification is deliberate and synchronous at open. Every page must
    # match both the world manifest's file SHA and its own internal checksum.
    var verified: Dictionary = MANIFEST.load(directory, true)
    _open_verify_ms = float(Time.get_ticks_usec() - started) / 1000.0
    var result: Error = int(verified.get("error", ERR_FILE_CORRUPT))
    if result != OK:
        return result
    var doc: Dictionary = verified["document"]
    var dimensions: Vector2i = Vector2i(int(doc["cells_x"]), int(doc["cells_z"]))
    var size: float = float(doc["spacing"])
    result = _page_reader.initialize(directory, dimensions, size, cache_pages)
    if result != OK:
        return result
    var hashes: Dictionary = {}
    for listed in doc["pages"]:
        var page: Dictionary = listed
        var key: Vector2i = Vector2i(int(page["x"]), int(page["z"]))
        hashes[key] = str(page["sha256"])
    _expected_hashes = hashes
    cells = dimensions
    spacing = size
    _limit = cache_pages
    _directory = directory.trim_suffix("/")
    _opened = true
    return OK

func is_open() -> bool:
    return _opened

func page_count() -> Vector2i:
    if not _opened:
        return Vector2i.ZERO
    return _page_reader.page_count()

func stats() -> Dictionary:
    return {
        "open": _opened,
        "resident": _cache.size(),
        "limit": _limit,
        "resident_float_bytes": _cache.size() * PAGE_BYTES,
        "manifest_entries": _expected_hashes.size(),
        "disk_reads": _disk_reads,
        "cache_hits": _hits,
        "cache_misses": _misses,
        "evictions": _evictions,
        "io_last_ms": _last_io_ms,
        "io_max_ms": _max_io_ms,
        "manifest_open_verify_ms": _open_verify_ms,
        "prefetch_generation": _prefetch_generation
    }

func _valid_page(key: Vector2i) -> bool:
    var count: Vector2i = _page_reader.page_count()
    return (
        _opened and key.x >= 0 and key.y >= 0
        and key.x < count.x and key.y < count.y
    )

func _touch(key: Vector2i) -> void:
    var position: int = _lru.find(key)
    if position >= 0:
        _lru.remove_at(position)
    _lru.append(key)

func _load_page(key: Vector2i) -> Error:
    if not _valid_page(key) or not _expected_hashes.has(key):
        return ERR_INVALID_PARAMETER
    if _cache.has(key):
        _hits += 1
        _touch(key)
        return OK
    _misses += 1
    var started: int = Time.get_ticks_usec()
    var path: String = _page_reader._path_for(key)
    var err: Error = OK
    var contents: PackedFloat32Array = PackedFloat32Array()
    if not FileAccess.file_exists(path):
        err = ERR_FILE_NOT_FOUND
    elif FileAccess.get_sha256(path) != str(_expected_hashes[key]):
        err = ERR_FILE_CORRUPT
    else:
        var parsed: Dictionary = _page_reader._parse_page(path, key)
        err = int(parsed.get("error", ERR_FILE_CORRUPT))
        if err == OK:
            # No TOCTOU-prone acceptance of a file changed while parsing.
            if FileAccess.get_sha256(path) != str(_expected_hashes[key]):
                err = ERR_FILE_CORRUPT
            else:
                contents = parsed["values"]
    _last_io_ms = float(Time.get_ticks_usec() - started) / 1000.0
    _max_io_ms = maxf(_max_io_ms, _last_io_ms)
    if err != OK:
        return err
    if contents.size() != REGIONS.PAGE_VALUES:
        return ERR_FILE_CORRUPT
    # Evict only AFTER a valid new page has been read, so a corrupt page
    # cannot discard the last useful region from the resident cache.
    if _cache.size() >= _limit:
        var oldest: Vector2i = _lru.pop_front()
        _cache.erase(oldest)
        _evictions += 1
    _cache[key] = contents
    _touch(key)
    _disk_reads += 1
    return OK

func get_height(x: int, z: int) -> Dictionary:
    if not _opened:
        return {"error": ERR_UNCONFIGURED}
    if x < 0 or z < 0 or x > cells.x or z > cells.y:
        return {"error": ERR_INVALID_PARAMETER}
    var key: Vector2i = Vector2i(int(x / PAGE_WIDTH), int(z / PAGE_WIDTH))
    var err: Error = _load_page(key)
    if err != OK:
        return {"error": err}
    var position: int = (z % PAGE_WIDTH) * PAGE_WIDTH + (x % PAGE_WIDTH)
    var values: PackedFloat32Array = _cache[key]
    return {"error": OK, "height": values[position]}

func sample_local(world_x: float, world_z: float) -> Dictionary:
    if not _opened:
        return {"error": ERR_UNCONFIGURED}
    if not is_finite(world_x) or not is_finite(world_z):
        return {"error": ERR_INVALID_PARAMETER}
    if world_x < 0.0 or world_z < 0.0:
        return {"error": ERR_INVALID_PARAMETER}
    if world_x > float(cells.x) * spacing or world_z > float(cells.y) * spacing:
        return {"error": ERR_INVALID_PARAMETER}
    var px: float = world_x / spacing
    var pz: float = world_z / spacing
    var ix: int = mini(floori(px), cells.x - 1)
    var iz: int = mini(floori(pz), cells.y - 1)
    var tx: float = px - float(ix)
    var tz: float = pz - float(iz)
    var top_left: Dictionary = get_height(ix, iz)
    if int(top_left["error"]) != OK:
        return {"error": int(top_left["error"])}
    var top_right: Dictionary = get_height(ix + 1, iz)
    if int(top_right["error"]) != OK:
        return {"error": int(top_right["error"])}
    var bottom_left: Dictionary = get_height(ix, iz + 1)
    if int(bottom_left["error"]) != OK:
        return {"error": int(bottom_left["error"])}
    var bottom_right: Dictionary = get_height(ix + 1, iz + 1)
    if int(bottom_right["error"]) != OK:
        return {"error": int(bottom_right["error"])}
    var upper: float = lerpf(float(top_left["height"]), float(top_right["height"]), tx)
    var lower: float = lerpf(float(bottom_left["height"]), float(bottom_right["height"]), tx)
    return {"error": OK, "height": lerpf(upper, lower, tz)}

func prefetch_rect(first: Vector2i, last: Vector2i, max_new_reads: int = 2) -> Dictionary:
    if not _opened:
        return {"error": ERR_UNCONFIGURED}
    if not _valid_page(first) or not _valid_page(last):
        return {"error": ERR_INVALID_PARAMETER}
    if first.x > last.x or first.y > last.y or max_new_reads < 1 or max_new_reads > 64:
        return {"error": ERR_INVALID_PARAMETER}
    if first != _prefetch_a or last != _prefetch_b:
        _prefetch_a = first
        _prefetch_b = last
        _prefetch_cursor = 0
        _prefetch_generation += 1
    var width: int = last.x - first.x + 1
    var total: int = width * (last.y - first.y + 1)
    var fetched: int = 0
    var examined: int = 0
    while _prefetch_cursor < total:
        var n: int = _prefetch_cursor
        var key: Vector2i = Vector2i(first.x + n % width, first.y + int(n / width))
        var resident: bool = _cache.has(key)
        if not resident and fetched >= max_new_reads:
            break
        var err: Error = _load_page(key)
        if err != OK:
            return {
                "error": err, "page": key, "loaded": fetched,
                "examined": examined, "complete": false
            }
        _prefetch_cursor += 1
        examined += 1
        if not resident:
            fetched += 1
    return {
        "error": OK,
        "loaded": fetched,
        "examined": examined,
        "complete": _prefetch_cursor == total,
        "remaining": total - _prefetch_cursor,
        "generation": _prefetch_generation
    }

func release_outside(first: Vector2i, last: Vector2i) -> Error:
    if not _opened:
        return ERR_UNCONFIGURED
    if not _valid_page(first) or not _valid_page(last):
        return ERR_INVALID_PARAMETER
    if first.x > last.x or first.y > last.y:
        return ERR_INVALID_PARAMETER
    # Read-only cache; nothing to flush or persist.
    for key in _lru.duplicate():
        if key.x < first.x or key.y < first.y or key.x > last.x or key.y > last.y:
            _cache.erase(key)
            _lru.erase(key)
            _evictions += 1
    return OK

func close() -> void:
    _clear_state()
