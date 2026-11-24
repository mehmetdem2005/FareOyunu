@tool
extends SceneTree
## P1 regression: exported layer-mode settings survive packed-scene
## serialization and reopen from the one authoritative TFL1 document.
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")

func _fail(message: String) -> void:
    push_error("TerraForge layer scene roundtrip: " + message)
    quit(1)

func _initialize() -> void:
    var suffix: String = str(Time.get_ticks_usec())
    var tfh: String = "user://tf_scene_" + suffix + ".tfh"
    var scene_path: String = "user://tf_scene_" + suffix + ".tscn"
    var store = STORE.new()
    store.initialize(Vector2i(64, 64), 1.0)
    store.heights[store.index_of(12, 14)] = 4.25
    if store.save_file(tfh) != OK:
        _fail("Could not prepare original TFH data")
        return

    var root: Node3D = Node3D.new()
    root.name = "TestWorld"
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.name = "TestTerrain"
    terrain.data_file = tfh
    root.add_child(terrain)
    terrain.owner = root
    # Direct _ready() is sufficient for the headless geometry/load setup.
    terrain._ready()
    if terrain.enable_layers() != OK:
        _fail("Could not enable layer mode before saving scene")
        return
    var layer_path: String = terrain.layer_file
    terrain.begin_stroke()
    terrain.paint_at(Vector3(12, 0, 14), 0, 4.0, 3.0)
    terrain.end_stroke()
    if terrain.save_data() != OK:
        _fail("Could not save new layer document")
        return
    var expected: float = terrain.height_data.get_height(12, 14)

    var packed: PackedScene = PackedScene.new()
    if packed.pack(root) != OK or ResourceSaver.save(packed, scene_path) != OK:
        _fail("Could not pack layer-enabled Godot scene")
        return
    root.free()

    # Loading from disk should preserve both the flag and sidecar path.
    var loaded: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE)
    if loaded == null:
        _fail("Could not reload saved Godot scene")
        return
    var instantiated: Node = loaded.instantiate()
    var restored: TerraForgeTerrain = instantiated.get_node_or_null("TestTerrain") as TerraForgeTerrain
    if restored == null or not restored.layer_mode or restored.layer_file != layer_path:
        _fail("Scene lost exported layer_mode or layer_file properties")
        return
    restored._ready()
    if restored._read_only_source or absf(restored.height_data.get_height(12, 14) - expected) > 0.0001:
        _fail("Reopened scene did not use the saved authoritative TFL1")
        return
    instantiated.free()

    var legacy_verify = STORE.new()
    if legacy_verify.load_file(tfh) != OK or legacy_verify.get_height(12, 14) != 4.25:
        _fail("Legacy TFH changed during layered editing")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(tfh))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(layer_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_path))
    print("PASS: packed Godot scene retains opt-in TFL1 settings and live sculpted geometry")
    quit(0)
