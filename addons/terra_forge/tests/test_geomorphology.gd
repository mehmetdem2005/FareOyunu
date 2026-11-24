@tool
extends SceneTree
## Godot 4.7.2 headless: test continuous paths and thermal mass balance.
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const PATHS = preload("res://addons/terra_forge/core/landform_paths.gd")
const THERMAL = preload("res://addons/terra_forge/core/thermal_weathering.gd")

func _fail(reason: String) -> void:
    push_error("TerraForge geomorphology: " + reason)
    quit(1)

func _initialize() -> void:
    var data = STORE.new()
    data.initialize(Vector2i(128, 128), 1.0)
    var points_a: Array[Vector2] = [Vector2(20, 64), Vector2(100, 64)]
    var points_b: Array[Vector2] = [
        Vector2(20, 64), Vector2(40, 64), Vector2(60, 64),
        Vector2(80, 64), Vector2(100, 64)
    ]
    var ridge_sparse: Dictionary = PATHS.build(data, points_a, 12.0, 3.0, false)
    var ridge_dense: Dictionary = PATHS.build(data, points_b, 12.0, 3.0, false)
    if ridge_sparse.size() < 100 or ridge_sparse.size() != ridge_dense.size():
        _fail("Path produced too few samples or event-rate-dependent coverage")
        return
    for idx in ridge_sparse:
        if not ridge_dense.has(idx) or absf(float(ridge_sparse[idx]) - float(ridge_dense[idx])) > 0.0001:
            _fail("Same straight ridge depends on drag event frequency at " + str(idx))
            return
    var center: int = data.index_of(64, 64)
    if not ridge_sparse.has(center) or float(ridge_sparse[center]) <= 0.0:
        _fail("Ridge should raise centerline")
        return
    var outside: int = data.index_of(64, 93)
    if ridge_sparse.has(outside):
        _fail("Shape leaked outside its local falloff")
        return
    var valley: Dictionary = PATHS.build(data, points_a, 12.0, 3.0, true)
    if not valley.has(center) or float(valley[center]) >= 0.0:
        _fail("Valley should lower centerline")
        return

    var flat_changes: Dictionary = THERMAL.build(data, Vector2(64, 64), 20.0, 4, 0.85)
    if not flat_changes.is_empty():
        _fail("Flat terrain should not weather spontaneously")
        return

    # A single steep mound relaxes and redistributes height conservatively.
    data.heights[center] = 20.0
    var before_sum: float = 0.0
    for value in data.heights:
        before_sum += value
    var weathered: Dictionary = THERMAL.build(data, Vector2(64, 64), 18.0, 5, 0.8)
    if weathered.size() < 3 or not weathered.has(center) or float(weathered[center]) >= 20.0:
        _fail("Thermal weathering did not lower a steep center mound")
        return
    for idx in weathered:
        data.heights[int(idx)] = float(weathered[idx])
    var after_sum: float = 0.0
    for value in data.heights:
        after_sum += value
    if absf(after_sum - before_sum) > 0.01:
        _fail("Thermal weathering violated mass balance: " + str(after_sum - before_sum))
        return
    print("PASS: path continuity, noise bounds, slope weathering and mass balance")
    quit(0)
