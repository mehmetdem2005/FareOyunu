@tool
extends SceneTree
## Reopened scenes with missing height data must NEVER silently overwrite it.
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")

func _fail(message: String) -> void:
    push_error("TerraForge data safety: " + message)
    quit(1)

func _initialize() -> void:
    var path: String = "user://tf_missing_" + str(Time.get_ticks_usec()) + ".tfh"
    var existing: TerraForgeTerrain = TERRAIN.new()
    existing.data_file = path
    existing.cells_x = 32
    existing.cells_z = 32
    existing._ready()
    if not existing._read_only_source:
        existing.free()
        _fail("A reopened scene with missing .tfh was editable")
        return
    if existing.save_data() != ERR_FILE_NOT_FOUND or FileAccess.file_exists(path):
        existing.free()
        _fail("Missing original data was silently overwritten")
        return
    existing.free()

    var created: TerraForgeTerrain = TERRAIN.new()
    created.data_file = path
    created.cells_x = 32
    created.cells_z = 32
    created.allow_data_creation = true
    created._ready()
    if created._read_only_source or created.save_data() != OK:
        created.free()
        _fail("Explicit new-terrain creation cannot write first .tfh")
        return
    if not FileAccess.file_exists(path) or created.allow_data_creation:
        created.free()
        _fail("New height data missing or unsafe create flag still enabled")
        return
    created.free()

    var reopened: TerraForgeTerrain = TERRAIN.new()
    reopened.data_file = path
    reopened._ready()
    if reopened._read_only_source or reopened.height_data.cells != Vector2i(32, 32):
        reopened.free()
        _fail("Saved terrain did not reopen normally")
        return
    reopened.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("PASS: missing .tfh protected, explicit new file created, reopen succeeds")
    quit(0)
