@tool
extends RefCounted
## Fixed memory, bounded approximate percentile upper bounds in milliseconds.
const BOUNDS: Array[float] = [0.1, 0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 8.0, 10.0, 12.0, 16.7, 20.0, 25.0, 33.4, 40.0, 50.0, 67.0, 100.0, 150.0, 250.0, 500.0, 1000.0, 2000.0, 5000.0]
var _counts: PackedInt64Array = PackedInt64Array()
var _count: int = 0
var _sum: float = 0.0
var _max: float = 0.0

func _init() -> void:
    _counts.resize(BOUNDS.size() + 1)

func add(ms: float) -> void:
    if not is_finite(ms) or ms < 0.0:
        return
    var index: int = 0
    while index < BOUNDS.size() and ms > BOUNDS[index]:
        index += 1
    _counts[index] += 1
    _count += 1
    _sum += ms
    _max = maxf(_max, ms)

func _upper(q: float) -> Variant:
    if _count == 0:
        return null
    var rank: int = maxi(1, ceili(q * float(_count)))
    var cumulative: int = 0
    for index in range(_counts.size()):
        cumulative += _counts[index]
        if cumulative >= rank:
            # Overflow is still bounded by the actual observed maximum.
            return _max if index == BOUNDS.size() else minf(BOUNDS[index], _max)
    return null

func report() -> Dictionary:
    return {
        "count": _count, "mean_ms": _sum / float(_count) if _count > 0 else null,
        "p50_upper_ms": _upper(0.5), "p95_upper_ms": _upper(0.95),
        "p99_upper_ms": _upper(0.99), "max_ms": _max if _count > 0 else null,
        "bounds_ms": BOUNDS.duplicate(), "counts": Array(_counts), "overflow": _counts[-1]
    }
