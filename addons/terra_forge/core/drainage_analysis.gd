@tool
extends RefCounted
## Non-destructive DEM hydrology precursor: priority-flood depression fill,
## followed by deterministic multiple-flow-direction (MFD) accumulation.
## This is NOT a hydraulic erosion or sediment transport simulation.
## The complete operation is limited to a local 97x97 sample patch.
const MAX_RADIUS_SAMPLES: int = 48
const OFFSETS: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
    Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]
const FLAT_FLOW_WEIGHT: float = 0.01

static func _less(a: Vector3, b: Vector3) -> bool:
    if a.x != b.x:
        return a.x < b.x
    if a.y != b.y:
        return a.y < b.y
    return a.z < b.z

static func _heap_push(heap: Array[Vector3], entry: Vector3) -> void:
    heap.append(entry)
    var i: int = heap.size() - 1
    while i > 0:
        var parent: int = int((i - 1) / 2)
        if not _less(entry, heap[parent]):
            break
        heap[i] = heap[parent]
        i = parent
    heap[i] = entry

static func _heap_pop(heap: Array[Vector3]) -> Vector3:
    var head: Vector3 = heap[0]
    var tail: Vector3 = heap.pop_back()
    if heap.is_empty():
        return head
    var i: int = 0
    while true:
        var child: int = i * 2 + 1
        if child >= heap.size():
            break
        var right: int = child + 1
        if right < heap.size() and _less(heap[right], heap[child]):
            child = right
        if not _less(heap[child], tail):
            break
        heap[i] = heap[child]
        i = child
    heap[i] = tail
    return head

static func analyze(
        height_store: RefCounted,
        center: Vector2,
        radius_m: float = 32.0
    ) -> Dictionary:
    if height_store == null or height_store.spacing <= 0.0:
        return {}
    var spacing: float = height_store.spacing
    var radius: int = clampi(ceili(maxf(0.0, radius_m) / spacing), 1, MAX_RADIUS_SAMPLES)
    var center_x: int = roundi(center.x / spacing)
    var center_z: int = roundi(center.y / spacing)
    var left: int = clampi(center_x - radius, 0, height_store.cells.x)
    var right: int = clampi(center_x + radius, 0, height_store.cells.x)
    var top: int = clampi(center_z - radius, 0, height_store.cells.y)
    var bottom: int = clampi(center_z + radius, 0, height_store.cells.y)
    var width: int = right - left + 1
    var depth: int = bottom - top + 1
    if width < 2 or depth < 2:
        return {}
    var count: int = width * depth
    var raw: PackedFloat32Array = PackedFloat32Array()
    var filled: PackedFloat32Array = PackedFloat32Array()
    var visited: PackedByteArray = PackedByteArray()
    var rank: PackedInt32Array = PackedInt32Array()
    var accumulation: PackedFloat32Array = PackedFloat32Array()
    raw.resize(count)
    filled.resize(count)
    visited.resize(count)
    rank.resize(count)
    accumulation.resize(count)
    accumulation.fill(1.0)

    for z in range(depth):
        for x in range(width):
            var i: int = z * width + x
            var h: float = height_store.get_height(left + x, top + z)
            raw[i] = h
            filled[i] = h

    # Priority flood from *all* local boundary samples. Each discovered
    # cell gets a rank after its flood parent, so flat pixels can be routed
    # toward an outlet without artificially raising the entire flat.
    var heap: Array[Vector3] = []
    var next_rank: int = 0
    for z in range(depth):
        for x in range(width):
            if x != 0 and x != width - 1 and z != 0 and z != depth - 1:
                continue
            var i: int = z * width + x
            visited[i] = 1
            rank[i] = next_rank
            next_rank += 1
            _heap_push(heap, Vector3(filled[i], 0.0, float(i)))

    while not heap.is_empty():
        var item: Vector3 = _heap_pop(heap)
        var i: int = int(item.z)
        var x: int = i % width
        var z: int = int(i / width)
        for offset in OFFSETS:
            var nx: int = x + offset.x
            var nz: int = z + offset.y
            if nx < 0 or nx >= width or nz < 0 or nz >= depth:
                continue
            var neighbor: int = nz * width + nx
            if visited[neighbor] != 0:
                continue
            visited[neighbor] = 1
            filled[neighbor] = maxf(raw[neighbor], filled[i])
            rank[neighbor] = next_rank
            next_rank += 1
            # Prefer nearer open outlets when elevations tie. This
            # reduces artificial directional bias on a perfectly flat DEM.
            var edge_distance: int = mini(
                mini(nx, width - 1 - nx),
                mini(nz, depth - 1 - nz)
            )
            _heap_push(heap, Vector3(filled[neighbor], float(edge_distance), float(neighbor)))

    # Descending filled altitude, then descending flood rank: a topological
    # order that prevents cycles on flats and in filled depressions.
    var order: Array[int] = []
    for i in range(count):
        order.append(i)
    order.sort_custom(func(a: int, b: int) -> bool:
        if filled[a] != filled[b]:
            return filled[a] > filled[b]
        return rank[a] > rank[b]
    )

    var outlet_flow: float = 0.0
    var max_accumulation: float = 1.0
    for i in order:
        var x: int = i % width
        var z: int = int(i / width)
        # Open patch boundaries are OUTLETS, not neighbors to be routed
        # along. Otherwise a perfectly flat DEM can concentrate all
        # rainfall into an arbitrary corner merely due to iteration order.
        if x == 0 or z == 0 or x == width - 1 or z == depth - 1:
            outlet_flow += accumulation[i]
            max_accumulation = maxf(max_accumulation, accumulation[i])
            continue
        var weight_sum: float = 0.0
        for offset in OFFSETS:
            var nx: int = x + offset.x
            var nz: int = z + offset.y
            if nx < 0 or nx >= width or nz < 0 or nz >= depth:
                continue
            var ni: int = nz * width + nx
            var difference: float = filled[i] - filled[ni]
            var length: float = 1.41421356237 if offset.x != 0 and offset.y != 0 else 1.0
            if difference > 0.000001:
                weight_sum += pow(difference / length, 1.1)
            elif absf(difference) <= 0.000001 and rank[ni] < rank[i]:
                weight_sum += FLAT_FLOW_WEIGHT / length
        if weight_sum <= 0.0:
            outlet_flow += accumulation[i]
            max_accumulation = maxf(max_accumulation, accumulation[i])
            continue
        for offset in OFFSETS:
            var nx: int = x + offset.x
            var nz: int = z + offset.y
            if nx < 0 or nx >= width or nz < 0 or nz >= depth:
                continue
            var ni: int = nz * width + nx
            var difference: float = filled[i] - filled[ni]
            var length: float = 1.41421356237 if offset.x != 0 and offset.y != 0 else 1.0
            var weight: float = 0.0
            if difference > 0.000001:
                weight = pow(difference / length, 1.1)
            elif absf(difference) <= 0.000001 and rank[ni] < rank[i]:
                weight = FLAT_FLOW_WEIGHT / length
            if weight <= 0.0:
                continue
            accumulation[ni] += accumulation[i] * weight / weight_sum
            max_accumulation = maxf(max_accumulation, accumulation[ni])

    var fill_count: int = 0
    for i in range(count):
        if filled[i] > raw[i] + 0.000001:
            fill_count += 1

    return {
        "origin": Vector2i(left, top),
        "size": Vector2i(width, depth),
        "raw": raw,
        "filled": filled,
        "rank": rank,
        "accumulation": accumulation,
        "filled_cells": fill_count,
        "max_accumulation": max_accumulation,
        "outlet_flow": outlet_flow,
        "rainfall_cells": count,
        "cell_area_m2": spacing * spacing
    }
