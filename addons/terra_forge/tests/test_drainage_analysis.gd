@tool
extends SceneTree
## Experimental, non-destructive priority-flood + MFD drainage checks.
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const DRAINAGE = preload("res://addons/terra_forge/core/drainage_analysis.gd")

func _fail(message: String) -> void:
    push_error("TerraForge drainage analysis: " + message)
    quit(1)

func _conserves_rainfall(report: Dictionary) -> bool:
    var count: int = int(report["rainfall_cells"])
    var outlet: float = float(report["outlet_flow"])
    return absf(outlet - float(count)) <= maxf(0.2, float(count) * 0.001)

func _initialize() -> void:
    var data = STORE.new()
    data.initialize(Vector2i(64, 64), 1.0)

    var flat: Dictionary = DRAINAGE.analyze(data, Vector2(32, 32), 16.0)
    if flat.is_empty() or flat["size"] != Vector2i(33, 33):
        _fail("Flat DEM patch had unexpected size")
        return
    if int(flat["filled_cells"]) != 0:
        _fail("Flat DEM was artificially elevated")
        return
    if not _conserves_rainfall(flat):
        _fail("Flat DEM lost accumulated rainfall")
        return
    var flat_flow: PackedFloat32Array = flat["accumulation"]
    var flat_width: int = flat["size"].x
    var flat_mid: int = int(flat["size"].y / 2)
    var west_flow: float = flat_flow[flat_mid * flat_width + 1]
    var east_flow: float = flat_flow[flat_mid * flat_width + flat_width - 2]
    # Open-border drainage on a plane should not pick one arbitrary
    # corner merely because boundary pixels were inserted first.
    if minf(west_flow, east_flow) < 1.0 or maxf(west_flow, east_flow) > minf(west_flow, east_flow) * 2.0:
        _fail("Flat-water routing is strongly biased by heap insertion order")
        return

    # Fill a local closed depression to its spill elevation without
    # editing the canonical height data.
    var middle_index: int = data.index_of(32, 32)
    data.heights[middle_index] = -10.0
    var pit: Dictionary = DRAINAGE.analyze(data, Vector2(32, 32), 16.0)
    var origin: Vector2i = pit["origin"]
    var size: Vector2i = pit["size"]
    var local_index: int = (32 - origin.y) * size.x + 32 - origin.x
    var filled: PackedFloat32Array = pit["filled"]
    if absf(filled[local_index]) > 0.000001 or int(pit["filled_cells"]) < 1:
        _fail("Closed pit was not conditioned to an outlet")
        return
    if data.heights[middle_index] != -10.0:
        _fail("Drainage analysis modified the real terrain")
        return
    if not _conserves_rainfall(pit):
        _fail("Filled depression lost accumulated rainfall")
        return

    # Sloped DEM should accumulate more upstream water down-gradient.
    for z in range(65):
        for x in range(65):
            data.heights[data.index_of(x, z)] = 0.15 * float(64 - x)
    var slope: Dictionary = DRAINAGE.analyze(data, Vector2(32, 32), 16.0)
    var flow: PackedFloat32Array = slope["accumulation"]
    var y: int = int(slope["size"].y / 2)
    var w: int = slope["size"].x
    if float(flow[y * w + (w - 2)]) <= float(flow[y * w + 1]):
        _fail("Flow did not accumulate toward the lower slope boundary")
        return
    if not _conserves_rainfall(slope):
        _fail("Sloped DEM lost rainfall mass")
        return

    print("PASS: flat DEM, depression fill, downhill MFD flow and water balance")
    quit(0)
