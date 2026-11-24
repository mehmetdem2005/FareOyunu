@tool
extends RefCounted
## Quick, opt-in editor health check; never touches the user's terrain.
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const PATHS = preload("res://addons/terra_forge/core/landform_paths.gd")
const THERMAL = preload("res://addons/terra_forge/core/thermal_weathering.gd")
const LOD = preload("res://addons/terra_forge/core/lod_policy.gd")
const SHAPES = preload("res://addons/terra_forge/core/brush_shapes.gd")
const DRAINAGE = preload("res://addons/terra_forge/core/drainage_analysis.gd")

static func run() -> Dictionary:
    var errors: Array[String] = []
    var start_us: int = Time.get_ticks_usec()
    var data = STORE.new()
    data.initialize(Vector2i(64, 64), 1.0)
    var target_index: int = data.index_of(9, 11)
    data.heights[target_index] = 17.03125

    var file_name: String = "user://terraforge_selftest_" + str(Time.get_ticks_usec()) + ".tfh"
    var err: Error = data.save_file(file_name)
    if err != OK:
        errors.append("Float32 write: " + error_string(err))
    else:
        var restored = STORE.new()
        err = restored.load_file(file_name)
        if err != OK:
            errors.append("Float32 read: " + error_string(err))
        elif restored.heights[target_index] != data.heights[target_index]:
            errors.append("Float32 roundtrip mismatch")
        DirAccess.remove_absolute(ProjectSettings.globalize_path(file_name))
    var data_ms: float = float(Time.get_ticks_usec() - start_us) / 1000.0

    var path_start: int = Time.get_ticks_usec()
    data.heights[target_index] = 0.0
    var path_a: Array[Vector2] = [Vector2(5, 32), Vector2(59, 32)]
    var path_b: Array[Vector2] = [Vector2(5, 32), Vector2(22, 32), Vector2(39, 32), Vector2(59, 32)]
    var a: Dictionary = PATHS.build(data, path_a, 9.0, 3.0, false)
    var b: Dictionary = PATHS.build(data, path_b, 9.0, 3.0, false)
    if a.is_empty() or a.size() != b.size():
        errors.append("Continuous path sample coverage")
    else:
        for index in a:
            if not b.has(index) or absf(float(a[index]) - float(b[index])) > 0.0001:
                errors.append("Continuous path varies with touch cadence")
                break
    var path_ms: float = float(Time.get_ticks_usec() - path_start) / 1000.0

    var weather_start: int = Time.get_ticks_usec()
    var center: int = data.index_of(32, 32)
    data.heights[center] = 12.0
    var changes: Dictionary = THERMAL.build(data, Vector2(32, 32), 15.0, 4, 0.8)
    var height_difference: float = 0.0
    for index in changes:
        height_difference += float(changes[index]) - data.heights[int(index)]
    if changes.is_empty() or not changes.has(center) or float(changes[center]) >= 12.0:
        errors.append("Thermal erosion did not transfer material")
    if absf(height_difference) > 0.01:
        errors.append("Thermal mass balance exceeded 0.01m")
    var weather_ms: float = float(Time.get_ticks_usec() - weather_start) / 1000.0

    var shape_start: int = Time.get_ticks_usec()
    var noise: FastNoiseLite = FastNoiseLite.new()
    noise.seed = 137
    noise.frequency = 1.0 / 26.0
    var center_pos: Vector2 = Vector2(22, 22)
    if SHAPES.organic_stamp(0, center_pos, center_pos, 12.0, noise) < 0.99:
        errors.append("Organic stamp center")
    if SHAPES.organic_stamp(0, center_pos + Vector2(12, 0), center_pos, 12.0, noise) != 0.0:
        errors.append("Organic stamp edge")
    if LOD.choose_stable_lod(76.0, 72.0, 144.0, 224.0, 0, 8.0) != 0:
        errors.append("LOD hysteresis")
    if LOD.choose_stable_lod(84.0, 72.0, 144.0, 224.0, 0, 8.0) != 1:
        errors.append("LOD level transition")
    var shape_ms: float = float(Time.get_ticks_usec() - shape_start) / 1000.0

    var drainage_start: int = Time.get_ticks_usec()
    var sample_data = STORE.new()
    sample_data.initialize(Vector2i(32, 32), 1.0)
    sample_data.heights[sample_data.index_of(16, 16)] = -6.0
    var drainage: Dictionary = DRAINAGE.analyze(sample_data, Vector2(16, 16), 8.0)
    if drainage.is_empty() or int(drainage["filled_cells"]) < 1:
        errors.append("Priority-flood depression conditioning")
    elif absf(float(drainage["outlet_flow"]) - float(drainage["rainfall_cells"])) > 0.5:
        errors.append("Multiple-flow water balance")
    if sample_data.heights[sample_data.index_of(16, 16)] != -6.0:
        errors.append("Drainage modified source heights")
    var drainage_ms: float = float(Time.get_ticks_usec() - drainage_start) / 1000.0

    var all_passed: bool = errors.is_empty()
    return {
        "ok": all_passed,
        "errors": errors,
        "data_ms": data_ms,
        "path_ms": path_ms,
        "weather_ms": weather_ms,
        "shape_ms": shape_ms,
        "drainage_ms": drainage_ms,
        "total_ms": float(Time.get_ticks_usec() - start_us) / 1000.0,
        "summary": (
            "PASS | F32 %.1fms | Path %.1fms | Weather %.1fms | Shape %.1fms | Drain %.1fms" % [data_ms, path_ms, weather_ms, shape_ms, drainage_ms]
            if all_passed
            else "FAIL: " + ", ".join(errors)
        )
    }
