@tool
extends RefCounted
## P1.2 synchronous camera-aware scheduling for the read-only pager.
## Limits disk page reads PER TICK, prioritizes camera-centered pages,
## cancels unstarted requests on camera jumps. No threads or scene nodes.
const PAGE_SOURCE = preload("res://addons/terra_forge/core/paged_height_source.gd")
const PAGE_WIDTH: int = 32

var _reader
var _reads_per_tick: int = 2
var _slots: Array[Vector2i] = []
var _cursor: int = 0
var _generation: int = 0
var _ticks: int = 0
var _requested: int = 0
var _completed: int = 0
var _last_tick_ms: float = 0.0
var _max_tick_ms: float = 0.0

func configure(reader, max_reads_per_tick: int = 2) -> Error:
    if reader == null or not reader.is_open():
        return ERR_INVALID_PARAMETER
    if max_reads_per_tick < 1 or max_reads_per_tick > 8:
        return ERR_INVALID_PARAMETER
    _reader = reader
    _reads_per_tick = max_reads_per_tick
    _slots.clear()
    _cursor = 0
    _generation = 0
    _ticks = 0
    _requested = 0
    _completed = 0
    _last_tick_ms = 0.0
    _max_tick_ms = 0.0
    return OK

func request_focus(world_x: float, world_z: float, radius_pages: int = 1,
        travel_direction: Vector2 = Vector2.ZERO) -> Error:
    if _reader == null or not _reader.is_open():
        return ERR_UNCONFIGURED
    if not is_finite(world_x) or not is_finite(world_z):
        return ERR_INVALID_PARAMETER
    if not is_finite(travel_direction.x) or not is_finite(travel_direction.y):
        return ERR_INVALID_PARAMETER
    if world_x < 0.0 or world_z < 0.0:
        return ERR_INVALID_PARAMETER
    if world_x > float(_reader.cells.x) * _reader.spacing:
        return ERR_INVALID_PARAMETER
    if world_z > float(_reader.cells.y) * _reader.spacing:
        return ERR_INVALID_PARAMETER
    if radius_pages < 0 or radius_pages > 6:
        return ERR_INVALID_PARAMETER
    var size: float = float(PAGE_WIDTH) * _reader.spacing
    var center: Vector2i = Vector2i(floori(world_x / size), floori(world_z / size))
    var counts: Vector2i = _reader.page_count()
    var a: Vector2i = Vector2i(
        maxi(0, center.x - radius_pages), maxi(0, center.y - radius_pages)
    )
    var b: Vector2i = Vector2i(
        mini(counts.x - 1, center.x + radius_pages),
        mini(counts.y - 1, center.y + radius_pages)
    )
    var direction: Vector2 = travel_direction.normalized()
    var candidates: Array[Dictionary] = []
    for z in range(a.y, b.y + 1):
        for x in range(a.x, b.x + 1):
            var delta: Vector2 = Vector2(float(x - center.x), float(z - center.y))
            # Center always wins; direction breaks ties for equally distant pages.
            var score: float = delta.length_squared() * 1024.0 - delta.dot(direction) * 32.0
            candidates.append({
                "key": Vector2i(x, z), "score": score,
                "x": x, "z": z
            })
    candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        if float(left["score"]) != float(right["score"]):
            return float(left["score"]) < float(right["score"])
        if int(left["z"]) != int(right["z"]):
            return int(left["z"]) < int(right["z"])
        return int(left["x"]) < int(right["x"])
    )
    # Cache can't retain more than its capacity. Do not prefetch 25 pages
    # into a four-page cache only to evict the very first pages immediately.
    var limit: int = int(_reader.stats()["limit"])
    var selected: Array[Vector2i] = []
    for entry in candidates:
        if selected.size() >= limit:
            break
        selected.append(entry["key"])
    if selected == _slots:
        return OK
    _slots = selected
    _cursor = 0
    _generation += 1
    _requested += 1
    return OK

func tick() -> Dictionary:
    if _reader == null or not _reader.is_open():
        return {"error": ERR_UNCONFIGURED}
    var started: int = Time.get_ticks_usec()
    var loaded: int = 0
    var processed: int = 0
    while _cursor < _slots.size():
        var key: Vector2i = _slots[_cursor]
        var before_reads: int = int(_reader.stats()["disk_reads"])
        var answer: Dictionary = _reader.get_height(
            key.x * PAGE_WIDTH, key.y * PAGE_WIDTH
        )
        var err: Error = int(answer.get("error", ERR_FILE_CORRUPT))
        if err != OK:
            _last_tick_ms = float(Time.get_ticks_usec() - started) / 1000.0
            _max_tick_ms = maxf(_max_tick_ms, _last_tick_ms)
            return {
                "error": err,
                "page": key,
                "loaded": loaded,
                "generation": _generation,
                "complete": false
            }
        _cursor += 1
        processed += 1
        loaded += int(_reader.stats()["disk_reads"]) - before_reads
        if loaded >= _reads_per_tick:
            break
    _ticks += 1
    _last_tick_ms = float(Time.get_ticks_usec() - started) / 1000.0
    _max_tick_ms = maxf(_max_tick_ms, _last_tick_ms)
    var done: bool = _cursor >= _slots.size()
    if done:
        _completed += 1
    return {
        "error": OK,
        "loaded": loaded,
        "processed": processed,
        "complete": done,
        "remaining": _slots.size() - _cursor,
        "generation": _generation,
        "last_tick_ms": _last_tick_ms
    }

func release_distant() -> Error:
    if _reader == null or not _reader.is_open():
        return ERR_UNCONFIGURED
    if _slots.is_empty():
        return OK
    var a: Vector2i = _slots[0]
    var b: Vector2i = _slots[0]
    for key in _slots:
        a = Vector2i(mini(a.x, key.x), mini(a.y, key.y))
        b = Vector2i(maxi(b.x, key.x), maxi(b.y, key.y))
    # Read-only pages; release removes cache data, not saved region files.
    return _reader.release_outside(a, b)

func stats() -> Dictionary:
    return {
        "generation": _generation,
        "pending": _slots.size() - _cursor,
        "selected": _slots.duplicate(),
        "reads_per_tick": _reads_per_tick,
        "ticks": _ticks,
        "focus_requests": _requested,
        "completed_ticks": _completed,
        "last_tick_ms": _last_tick_ms,
        "max_tick_ms": _max_tick_ms
    }
