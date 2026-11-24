@tool
extends SceneTree
## P1 opt-in live mode: one authoritative TFL1 file, no legacy TFH writes.
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")

func _fail(message: String) -> void:
    push_error("TerraForge live layers: " + message)
    quit(1)

func _initialize() -> void:
    var suffix: String = str(Time.get_ticks_usec())
    var legacy_path: String = "user://tf_live_" + suffix + ".tfh"
    var layer_path: String = legacy_path.get_basename() + ".tfl"
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.data_file = legacy_path
    terrain.cells_x = 64
    terrain.cells_z = 64
    terrain.allow_data_creation = true
    terrain._ready()
    if terrain.save_data() != OK:
        _fail("Legacy baseline creation failed")
        return
    var legacy_bytes: PackedByteArray = FileAccess.get_file_as_bytes(legacy_path)
    if terrain.enable_layers() != OK or not FileAccess.file_exists(layer_path):
        _fail("Opt-in conversion did not create an authoritative .tfl")
        return
    if terrain.enable_layers() == OK:
        _fail("Opt-in conversion could be repeated over an existing layer file")
        return
    var point: int = terrain.height_data.index_of(20, 20)
    terrain.begin_stroke()
    terrain.paint_at(Vector3(20, 0, 20), 0, 5.0, 4.0)
    terrain.end_stroke()
    var raised: float = terrain.height_data.heights[point]
    if raised <= 0.0 or terrain._layer_stack.read_delta(0, point) <= 0.0:
        _fail("Sculpt did not write the selected non-destructive layer")
        return
    terrain.undo_stroke()
    if terrain.height_data.heights[point] != 0.0 or terrain._layer_stack.read_delta(0, point) != 0.0:
        _fail("Layer Undo did not restore the height and delta")
        return
    terrain.redo_stroke()
    if terrain.height_data.heights[point] != raised:
        _fail("Layer Redo did not restore sculpted shape")
        return
    var layer_2: int = terrain.add_edit_layer("Second Pass")
    if layer_2 != 1:
        _fail("Adding a new sculpt layer failed")
        return
    terrain.begin_stroke()
    terrain.paint_at(Vector3(20, 0, 20), 1, 5.0, 3.0)
    terrain.end_stroke()
    var composite: float = terrain.height_data.heights[point]
    if composite >= raised or terrain._layer_stack.read_delta(layer_2, point) >= 0.0:
        _fail("Second layer did not lower the surface independently")
        return
    terrain.set_edit_layer_visible(layer_2, false)
    if absf(terrain.height_data.heights[point] - raised) > 0.0001:
        _fail("Hiding the second layer did not restore the underlying sculpt")
        return
    terrain.set_edit_layer_visible(layer_2, true)
    if absf(terrain.height_data.heights[point] - composite) > 0.0001:
        _fail("Restoring the second layer did not restore the composite")
        return
    if terrain.save_data() != OK:
        _fail("Layer document save failed")
        return
    if FileAccess.get_file_as_bytes(legacy_path) != legacy_bytes:
        _fail("Layer mode modified legacy TFH; old terrain must be preserved")
        return

    var reopened: TerraForgeTerrain = TERRAIN.new()
    reopened.data_file = legacy_path
    reopened.layer_file = layer_path
    reopened.layer_mode = true
    reopened._ready()
    if reopened._read_only_source or reopened._layer_stack.layers.size() != 2:
        _fail("Layered scene could not reopen its layers")
        return
    if absf(reopened.height_data.heights[point] - composite) > 0.0001:
        _fail("Layered scene did not restore committed composite")
        return
    reopened.free()
    var lost: TerraForgeTerrain = TERRAIN.new()
    lost.data_file = legacy_path
    lost.layer_mode = true
    lost.layer_file = layer_path + ".missing"
    lost._ready()
    if not lost._read_only_source or lost.save_data() != ERR_FILE_NOT_FOUND:
        _fail("Missing authoritative TFL1 failed to lock the scene")
        return
    lost.free()
    terrain.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(layer_path))
    print("PASS: opt-in live layers, per-layer Undo/Redo, visibility, persistence and TFH immutability")
    quit(0)
