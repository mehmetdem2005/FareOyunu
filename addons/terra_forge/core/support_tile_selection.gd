@tool
extends RefCounted
## P1.5.7e1 pure selection only. No scene, reader, worker or lease mutation.
## Camera candidates arrive in already-ranked order; protected keys win.
const MAX_SUPPORT: int = 4
const MAX_TOTAL: int = 128

static func select(support: Array[Vector2i], camera: Array[Dictionary], grid: Vector2i, cap: int) -> Dictionary:
    if grid.x <= 0 or grid.y <= 0 or cap < 1 or cap > MAX_TOTAL:
        return {"error": ERR_INVALID_PARAMETER, "reason": "invalid_capacity"}
    if support.size() > MAX_SUPPORT or support.size() > cap:
        return {"error": ERR_INVALID_PARAMETER, "reason": "support_cap"}
    if camera.size() > MAX_TOTAL:
        return {"error": ERR_INVALID_PARAMETER, "reason": "camera_cap"}
    var selected: Dictionary = {}
    for key in support:
        if not _inside(key, grid) or selected.has(key):
            return {"error": ERR_INVALID_PARAMETER, "reason": "invalid_support"}
        selected[key] = 0
    # Validate all candidates, even those beyond the selected cap.
    # Overlap with support is expected; repeated camera keys are deduped.
    var seen: Dictionary = {}
    for entry in camera:
        if not entry.get("key") is Vector2i or typeof(entry.get("lod")) != TYPE_INT:
            return {"error": ERR_INVALID_PARAMETER, "reason": "invalid_camera"}
        var key: Vector2i = entry["key"]
        var lod: int = entry["lod"]
        if not _inside(key, grid) or lod < 0 or lod > 2:
            return {"error": ERR_INVALID_PARAMETER, "reason": "invalid_camera"}
        if seen.has(key):
            if int(seen[key]) != lod:
                return {"error": ERR_INVALID_PARAMETER, "reason": "conflicting_camera_lod"}
            continue
        seen[key] = lod
        if selected.size() < cap and not selected.has(key):
            selected[key] = lod
    return {"error": OK, "reason": "selected", "desired": selected, "support_count": support.size()}

static func _inside(key: Vector2i, grid: Vector2i) -> bool:
    return key.x >= 0 and key.y >= 0 and key.x < grid.x and key.y < grid.y
