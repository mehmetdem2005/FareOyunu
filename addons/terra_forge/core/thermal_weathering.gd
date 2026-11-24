@tool
extends RefCounted
## Conservative, bounded local thermal weathering.
## Transfers height from steep neighboring samples to lower neighbors when
## slope exceeds a talus threshold. No water physics is claimed.
## All transfers are accumulated in a buffer, avoiding scan-order bias.
## The result is a dictionary of changed height indices for one Undo action.
const MAX_RADIUS_METERS: float = 32.0
const MAX_ITERATIONS: int = 6

static func build(
        height_store: RefCounted,
        center: Vector2,
        radius_m: float,
        iterations: int = 3,
        strength: float = 0.55,
        talus_slope: float = 0.6
    ) -> Dictionary:
    var result: Dictionary = {}
    if height_store == null:
        return result
    var spacing: float = height_store.spacing
    var radius: float = clampf(radius_m, spacing, MAX_RADIUS_METERS)
    var nsteps: int = clampi(iterations, 1, MAX_ITERATIONS)
    var mobility: float = clampf(strength, 0.0, 1.0)
    if mobility <= 0.0:
        return result

    var left: int = clampi(floori((center.x - radius) / spacing), 0, height_store.cells.x)
    var right: int = clampi(ceili((center.x + radius) / spacing), 0, height_store.cells.x)
    var top: int = clampi(floori((center.y - radius) / spacing), 0, height_store.cells.y)
    var bottom: int = clampi(ceili((center.y + radius) / spacing), 0, height_store.cells.y)
    var width: int = right - left + 1
    var depth: int = bottom - top + 1
    var count: int = width * depth
    if count <= 0:
        return result
    var source: PackedFloat32Array = PackedFloat32Array()
    source.resize(count)
    var current: PackedFloat32Array = PackedFloat32Array()
    current.resize(count)
    var weights: PackedFloat32Array = PackedFloat32Array()
    weights.resize(count)
    for z in range(depth):
        for x in range(width):
            var local_idx: int = z * width + x
            var value: float = height_store.get_height(left + x, top + z)
            source[local_idx] = value
            current[local_idx] = value
            var distance: float = Vector2(float(left + x) * spacing, float(top + z) * spacing).distance_to(center)
            # Restrict transfers to the inner area. The fringe has no flow,
            # preserving the original shape at the brush perimeter.
            weights[local_idx] = clampf((radius - distance) / maxf(0.001, radius * 0.24), 0.0, 1.0)

    var talus: float = maxf(0.05, talus_slope) * spacing
    var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    for step in range(nsteps):
        var change: PackedFloat32Array = PackedFloat32Array()
        change.resize(count)
        for z in range(depth):
            for x in range(width):
                var idx: int = z * width + x
                if weights[idx] <= 0.0:
                    continue
                var source_height: float = current[idx]
                var potential_sum: float = 0.0
                var maximum_potential: float = 0.0
                for direction in offsets:
                    var nx: int = x + direction.x
                    var nz: int = z + direction.y
                    if nx < 0 or nz < 0 or nx >= width or nz >= depth:
                        continue
                    var other: int = nz * width + nx
                    if weights[other] <= 0.0:
                        continue
                    var excess: float = maxf(0.0, source_height - current[other] - talus)
                    if excess <= 0.0:
                        continue
                    # No per-vertex temporary arrays: two cheap scans over
                    # four neighbors cost less than thousands of allocations.
                    var edge_weight: float = minf(weights[idx], weights[other])
                    potential_sum += excess * edge_weight
                    maximum_potential = maxf(maximum_potential, excess)
                if potential_sum <= 0.0:
                    continue
                # All outflows and inflows update a shared delta buffer,
                # preserving material volume independent of scan order.
                var outflow: float = minf(maximum_potential * 0.24, potential_sum * 0.22) * mobility
                for direction in offsets:
                    var nx: int = x + direction.x
                    var nz: int = z + direction.y
                    if nx < 0 or nz < 0 or nx >= width or nz >= depth:
                        continue
                    var other: int = nz * width + nx
                    if weights[other] <= 0.0:
                        continue
                    var excess: float = maxf(0.0, source_height - current[other] - talus)
                    if excess <= 0.0:
                        continue
                    var potential: float = excess * minf(weights[idx], weights[other])
                    var moved: float = outflow * potential / potential_sum
                    change[idx] -= moved
                    change[other] += moved
        for i in range(count):
            current[i] += change[i]

    for z in range(depth):
        for x in range(width):
            var local_idx: int = z * width + x
            var old: float = source[local_idx]
            var fresh: float = clampf(current[local_idx], -2000.0, 2000.0)
            if absf(old - fresh) > 0.000001:
                result[height_store.index_of(left + x, top + z)] = fresh
    return result
