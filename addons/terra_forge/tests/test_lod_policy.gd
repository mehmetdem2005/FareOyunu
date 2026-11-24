@tool
extends SceneTree
## Run: godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_lod_policy.gd
const POLICY = preload("res://addons/terra_forge/core/lod_policy.gd")

func _initialize() -> void:
    var expected: Array[int] = [0, 0, 1, 2, -1]
    var distances: Array[float] = [0.0, 72.0, 72.1, 144.1, 224.1]
    for i in range(expected.size()):
        if POLICY.choose_lod(distances[i], 72.0, 144.0, 224.0) != expected[i]:
            push_error("TerraForge: unexpected LOD at " + str(distances[i]))
            quit(1)
            return
    for level in range(3):
        if POLICY.sample_stride(level) != (1 << level):
            push_error("TerraForge: incorrect sample stride")
            quit(1)
            return
    var candidates: Array[Dictionary] = POLICY.tile_candidates(
        Vector2i(1024, 1024), 32, 1.0,
        Vector3(128, 10, 128), 224.0, 72.0, 144.0, 96
    )
    if candidates.size() != 96:
        push_error("TerraForge: resident cap was not applied")
        quit(1)
        return
    var seen: Dictionary = {}
    var last_distance: float = 0.0
    for candidate in candidates:
        var key: Vector2i = candidate["key"]
        var distance: float = float(candidate["distance"])
        if seen.has(key) or distance < last_distance:
            push_error("TerraForge: duplicate or unsorted LOD tile")
            quit(1)
            return
        if int(candidate["lod"]) < 0:
            push_error("TerraForge: invisible tile selected")
            quit(1)
            return
        seen[key] = true
        last_distance = distance
    var off_map: Array[Dictionary] = POLICY.tile_candidates(
        Vector2i(128, 128), 32, 1.0,
        Vector3(-10000, 0, -10000), 160, 56, 104, 64
    )
    if not off_map.is_empty():
        push_error("TerraForge: tiles created outside the world")
        quit(1)
        return
    print("PASS: TerraForge LOD policy, residency cap and boundaries")
    quit(0)
