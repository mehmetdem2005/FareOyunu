@tool
extends SceneTree
## P1 regression: lossless base preservation, sparse additive layers,
## visibility/opacity, file roundtrip, and fail-closed corrupt loads.
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const LAYERS = preload("res://addons/terra_forge/core/height_layers.gd")

func _fail(message: String) -> void:
    push_error("TerraForge layers: " + message)
    quit(1)

func _initialize() -> void:
    var heights = STORE.new()
    heights.initialize(Vector2i(64, 64), 0.5)
    var crest_index: int = heights.index_of(32, 32)
    var edge_index: int = heights.index_of(64, 64)
    heights.heights[crest_index] = 11.0
    heights.heights[edge_index] = -2.25

    var model = LAYERS.new()
    if model.initialize(heights.heights, heights.cells, heights.spacing) != OK:
        _fail("Could not initialize base")
        return
    heights.heights[crest_index] = 100.0
    if model.base_heights[crest_index] != 11.0:
        _fail("Base was aliased to input and changed externally")
        return

    var sculpt: int = model.add_layer("Sculpt")
    var erosion: int = model.add_layer("Erosion")
    if sculpt != 0 or erosion != 1:
        _fail("Layer creation failed")
        return
    if model.put_delta(sculpt, crest_index, 3.0) != OK or model.put_delta(erosion, crest_index, -1.25) != OK:
        _fail("Layer edit failed")
        return
    if model.put_delta(sculpt, edge_index, 1.25) != OK:
        _fail("Shared outer border sample was rejected")
        return
    if absf(model.composite_height(crest_index) - 12.75) > 0.00001:
        _fail("Additive composite is wrong")
        return
    if absf(model.compose()[edge_index] - (-1.0)) > 0.00001:
        _fail("Outer border was not composed")
        return
    model.set_enabled(erosion, false)
    if absf(model.composite_height(crest_index) - 14.0) > 0.00001:
        _fail("Hidden layer still contributes")
        return
    model.set_enabled(erosion, true)
    model.set_opacity(erosion, 0.5)
    if absf(model.composite_height(crest_index) - 13.375) > 0.00001:
        _fail("Half opacity is wrong")
        return
    if model.move_layer(0, 1) != OK or absf(model.composite_height(crest_index) - 13.375) > 0.00001:
        _fail("Layer reorder changed additive result")
        return

    var file: String = "user://tf_layers_" + str(Time.get_ticks_usec()) + ".tfl"
    if model.save_file(file) != OK:
        _fail("Layer save failed")
        return
    var reopened = LAYERS.new()
    if reopened.load_file(file) != OK:
        _fail("Layer reopen failed")
        return
    var left: PackedFloat32Array = model.compose()
    var right: PackedFloat32Array = reopened.compose()
    if reopened.cells != model.cells or reopened.spacing != model.spacing or reopened.layers.size() != 2:
        _fail("Layer file dimensions/header mismatch")
        return
    if right.size() != left.size():
        _fail("Layer file lost sample count")
        return
    for i in range(left.size()):
        if left[i] != right[i]:
            _fail("Float32 layer composition roundtrip mismatch at index " + str(i))
            return
    # Poison the format magic and prove it cannot replace live state.
    var before_corruption: float = reopened.composite_height(crest_index)
    var bad: String = file + ".bad"
    var writer: FileAccess = FileAccess.open(bad, FileAccess.WRITE)
    writer.store_buffer(PackedByteArray([66, 65, 68, 33]))
    writer.close()
    if reopened.load_file(bad) == OK or reopened.composite_height(crest_index) != before_corruption:
        _fail("Corrupted layer file damaged in-memory data")
        return
    if model.put_delta(2, crest_index, 3.0) == OK or model.put_delta(0, -1, 3.0) == OK:
        _fail("Out-of-range layer modification accepted")
        return

    DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(bad))
    print("PASS: Float32 non-destructive sparse layers, visibility, opacity, roundtrip and fail-closed load")
    quit(0)
