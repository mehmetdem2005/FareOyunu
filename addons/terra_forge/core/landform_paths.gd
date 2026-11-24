@tool
extends RefCounted
## Continuous, world-space, geology-inspired ridge and valley corridors.
## Unlike repeated circular stamps, each sample receives one deformation:
## the MAX influence of the nearest segment, so no "sausage beads" appear.
## Noise is coherent in world coordinates and only warps the corridor,
## never the source data or tile borders.
const SHAPES = preload("res://addons/terra_forge/core/brush_shapes.gd")
const MAX_POINTS: int = 256
const MAX_LENGTH: float = 256.0

static func build(
        height_store: RefCounted,
        points: Array[Vector2],
        radius_m: float,
        strength: float,
        carve_valley: bool,
        seed: int = 137
    ) -> Dictionary:
    var results: Dictionary = {}
    if points.is_empty() or height_store == null:
        return results
    var radius: float = clampf(radius_m, 1.0, 36.0)
    var spacing: float = height_store.spacing
    var amplitude: float = clampf(strength, 0.0, 12.0) * 0.42
    if amplitude <= 0.0:
        return results
    var influence: Dictionary = {}
    var noise: FastNoiseLite = FastNoiseLite.new()
    noise.seed = seed
    noise.frequency = 1.0 / maxf(28.0, radius * 7.0)
    var segments: int = maxi(1, mini(points.size() - 1, MAX_POINTS - 1))
    var total_length: float = 0.0
    for i in range(segments):
        var start: Vector2 = points[i]
        var finish: Vector2 = points[mini(i + 1, points.size() - 1)]
        var path: Vector2 = finish - start
        var length: float = path.length()
        if length <= 0.001 and points.size() > 1:
            continue
        if total_length >= MAX_LENGTH:
            break
        var remaining: float = MAX_LENGTH - total_length
        if length > remaining:
            finish = start + path.normalized() * remaining
            path = finish - start
            length = remaining
        total_length += length
        var len_sq: float = maxf(0.000001, path.length_squared())
        var unit: Vector2 = path.normalized() if length > 0.001 else Vector2.RIGHT
        # Include a halo for coherent domain warping. The blend remains 0
        # outside the chosen radius, regardless of warped search bounds.
        var reach: float = radius * 1.26
        var x0: int = clampi(floori((minf(start.x, finish.x) - reach) / spacing), 0, height_store.cells.x)
        var x1: int = clampi(ceili((maxf(start.x, finish.x) + reach) / spacing), 0, height_store.cells.x)
        var z0: int = clampi(floori((minf(start.y, finish.y) - reach) / spacing), 0, height_store.cells.y)
        var z1: int = clampi(ceili((maxf(start.y, finish.y) + reach) / spacing), 0, height_store.cells.y)
        for z in range(z0, z1 + 1):
            for x in range(x0, x1 + 1):
                var world: Vector2 = Vector2(float(x), float(z)) * spacing
                var warp_x: float = noise.get_noise_2d(world.x, world.y) * radius * 0.14
                var warp_z: float = noise.get_noise_2d(world.x + 113.17, world.y - 91.73) * radius * 0.14
                var warped: Vector2 = world + Vector2(warp_x, warp_z)
                var projection: float = clampf((warped - start).dot(path) / len_sq, 0.0, 1.0)
                var closest: Vector2 = start + path * projection
                var signed_dist: float = unit.cross(warped - closest)
                # Opposing slopes are intentionally unequal like a real
                # asymmetric watershed; sign is continuous along the path.
                var side_scale: float = 1.14 if signed_dist >= 0.0 else 0.86
                var normalized: float = (warped - closest).length() / (radius * side_scale)
                if normalized >= 1.0:
                    continue
                var profile: float = SHAPES.valley(normalized) if carve_valley else SHAPES.ridge(normalized)
                var weight: float = maxf(0.0, profile)
                var idx: int = height_store.index_of(x, z)
                influence[idx] = maxf(float(influence.get(idx, 0.0)), weight)
    var sign: float = -1.0 if carve_valley else 1.0
    for idx in influence:
        var base_height: float = height_store.heights[idx]
        var result: float = clampf(base_height + sign * amplitude * float(influence[idx]), -2000.0, 2000.0)
        if absf(result - base_height) > 0.000001:
            results[idx] = result
    return results
