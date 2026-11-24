@tool
extends SceneTree
## Run: godot --headless --path /path/to/project --script res://addons/terra_forge/tests/test_height_store.gd
const STORE = preload("res://addons/terra_forge/core/height_store.gd")

func _initialize() -> void:
    var store = STORE.new()
    store.initialize(Vector2i(64, 64), 0.5)
    for z in range(65):
        for x in range(65):
            store.heights[store.index_of(x, z)] = float((x + 7 * z) % 31) * 0.035
    var path: String = "user://tf_roundtrip_test.tfh"
    if store.save_file(path) != OK:
        push_error("TerraForge: Float32 save failed")
        quit(1)
        return
    var restored = STORE.new()
    if restored.load_file(path) != OK:
        push_error("TerraForge: Float32 load failed")
        quit(1)
        return
    if restored.cells != store.cells or absf(restored.spacing - 0.5) > 0.000001:
        push_error("TerraForge: Header mismatch")
        quit(1)
        return
    for i in range(store.heights.size()):
        if absf(restored.heights[i] - store.heights[i]) > 0.000001:
            push_error("TerraForge: Float32 roundtrip mismatch at index " + str(i))
            quit(1)
            return
    # Corrupted/truncated files must NOT change an existing in-memory map.
    var bad_path: String = "user://tf_corrupt_test.tfh"
    var f: FileAccess = FileAccess.open(bad_path, FileAccess.WRITE)
    f.store_buffer(PackedByteArray([84, 70, 72, 49]))
    f.close()
    var before: float = restored.heights[1]
    if restored.load_file(bad_path) == OK or restored.heights[1] != before:
        push_error("TerraForge: Corrupt file was accepted")
        quit(1)
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
    print("PASS: TerraForge Float32 roundtrip and corrupt-file guard")
    quit(0)
