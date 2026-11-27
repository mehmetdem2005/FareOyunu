@tool
extends RefCounted
## Pure world-space stroke sampler. No terrain, GPU, editor or native calls.
## Producer offers input points; consumer processes at most its own frame budget.
## A rejected offer is atomic: caller must pause/retry or explicitly cancel.
const MAX_PENDING := 256
const EPS := 0.000001
var _pending: Array[Vector2] = []
var _step: float = 1.0
var _remaining: float = 1.0
var _previous := Vector2.ZERO
var _has_previous := false
var _sealed := false
var _valid := false

func begin(step_m: float) -> bool:
    _pending.clear()
    _has_previous = false
    _sealed = false
    _valid = is_finite(step_m) and step_m >= 0.25 and step_m <= 36.0
    if not _valid:
        return false
    _step = step_m
    _remaining = step_m
    return true

func offer(point: Vector2) -> bool:
    if not _valid or _sealed or not point.is_finite() or absf(point.x)>10000000.0 or absf(point.y)>10000000.0:
        return false
    if not _has_previous:
        if _pending.size() >= MAX_PENDING:
            return false
        _pending.append(point)
        _previous = point
        _has_previous = true
        _remaining = _step
        return true
    var delta := point - _previous
    var distance := delta.length()
    if distance <= EPS:
        return true
    # Check capacity before modifying either the queue or residual phase.
    var count := 0
    if distance + EPS >= _remaining:
        count = 1 + maxi(0, floori((distance - _remaining + EPS) / _step))
    if count > MAX_PENDING - _pending.size():
        return false
    var direction := delta / distance
    for i in range(count):
        var offset := minf(distance, _remaining + float(i) * _step)
        _pending.append(_previous + direction * offset)
    _remaining = _remaining + float(count) * _step - distance
    # Floating-point noise at an exact multiple must not create duplicate dabs.
    _remaining = clampf(_remaining, EPS, _step)
    _previous = point
    return true

func break_path() -> void:
    # Ray miss / multi-touch: do not draw a bridge over an unobserved surface.
    # Keep already accepted samples for the consumer.
    _has_previous = false
    _remaining = _step

func seal() -> bool:
    if not _valid:
        return false
    if _sealed:
        return true
    # Include the final endpoint only when it is at least half a step away.
    if _has_previous and _step - _remaining >= _step * 0.5:
        if _pending.size() >= MAX_PENDING:
            return false
        _pending.append(_previous)
    _sealed = true
    return true

func pending_count() -> int:
    return _pending.size()

func take_next() -> Vector2:
    assert(not _pending.is_empty())
    return _pending.pop_front()

func is_complete() -> bool:
    return _sealed and _pending.is_empty()

func cancel() -> void:
    _pending.clear()
    _valid = false
    _sealed = true
    _has_previous = false
