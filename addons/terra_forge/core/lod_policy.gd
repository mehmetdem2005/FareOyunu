@tool
extends RefCounted
## Pure distance/LOD selection; no scene or RenderingServer access.
## -1 means outside the active view radius.
const HIDDEN: int = -1
const LOD0: int = 0
const LOD1: int = 1
const LOD2: int = 2

static func choose_lod(distance: float, near_radius: float, middle_radius: float, view_radius: float) -> int:
    if not is_finite(distance) or distance < 0.0 or distance > view_radius:
        return HIDDEN
    if distance <= near_radius:
        return LOD0
    if distance <= middle_radius:
        return LOD1
    return LOD2

## Avoid repeatedly switching LOD near distance thresholds.
## New tiles use the ordinary distance bands; only resident tiles
## get hysteresis. Large camera jumps may skip levels as intended.
static func choose_stable_lod(
        distance: float,
        near_radius: float,
        middle_radius: float,
        view_radius: float,
        previous_lod: int,
        hysteresis: float = 8.0
    ) -> int:
    var base: int = choose_lod(distance, near_radius, middle_radius, view_radius)
    if base == HIDDEN or previous_lod < 0 or previous_lod > 2:
        return base
    var band: float = maxf(0.0, hysteresis)
    match previous_lod:
        LOD0:
            if distance <= near_radius + band:
                return LOD0
        LOD1:
            if distance >= near_radius - band and distance <= middle_radius + band:
                return LOD1
        LOD2:
            if distance >= middle_radius - band:
                return LOD2
    return base

static func sample_stride(lod: int) -> int:
    return 1 << clampi(lod, 0, 2)

static func tile_distance(tile_coord: Vector2i, tile_size: float, camera_local: Vector3) -> float:
    var center: Vector2 = (Vector2(tile_coord) + Vector2(0.5, 0.5)) * tile_size
    return center.distance_to(Vector2(camera_local.x, camera_local.z))

static func tile_candidates(
        cells: Vector2i,
        tile_cells: int,
        spacing: float,
        anchor_local: Vector3,
        view_radius: float,
        near_radius: float,
        middle_radius: float,
        limit: int
    ) -> Array[Dictionary]:
    var tile_world_size: float = float(tile_cells) * spacing
    var max_tx: int = int(cells.x / tile_cells)
    var max_tz: int = int(cells.y / tile_cells)
    var tx0: int = maxi(0, floori((anchor_local.x - view_radius) / tile_world_size))
    var tx1: int = mini(max_tx - 1, floori((anchor_local.x + view_radius) / tile_world_size))
    var tz0: int = maxi(0, floori((anchor_local.z - view_radius) / tile_world_size))
    var tz1: int = mini(max_tz - 1, floori((anchor_local.z + view_radius) / tile_world_size))
    var result: Array[Dictionary] = []
    if tx1 < tx0 or tz1 < tz0:
        return result
    for tz in range(tz0, tz1 + 1):
        for tx in range(tx0, tx1 + 1):
            var key: Vector2i = Vector2i(tx, tz)
            var distance: float = tile_distance(key, tile_world_size, anchor_local)
            var lod: int = choose_lod(distance, near_radius, middle_radius, view_radius)
            if lod == HIDDEN:
                continue
            result.append({"key": key, "lod": lod, "distance": distance})
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a["distance"]) < float(b["distance"])
    )
    if result.size() > limit:
        result.resize(limit)
    return result
