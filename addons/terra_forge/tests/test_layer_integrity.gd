@tool
extends SceneTree
## TFL2 SHA-256, prior-save backup, corrupt-file quarantine,
## backward-compatible TFL1 read, and deliberate backup recovery.
const LAYERS = preload("res://addons/terra_forge/core/height_layers.gd")
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const TERRAIN = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")

func _fail(message: String) -> void:
    push_error("TerraForge recovery: " + message)
    quit(1)

func _initialize() -> void:
    var prefix: String = "user://tf_integrity_" + str(Time.get_ticks_usec())
    var file: String = prefix + ".tfl"
    var legacy_path: String = prefix + "_legacy.tfl"
    var store = STORE.new()
    store.initialize(Vector2i(64, 64), 1.0)
    var idx: int = store.index_of(20, 20)
    store.heights[idx] = 13.0
    var doc = LAYERS.new()
    if doc.initialize(store.heights, store.cells, store.spacing) != OK:
        _fail("Layer setup failed")
        return
    var layer: int = doc.add_layer("Ridge")
    doc.set_delta(layer, idx, 3.0)
    if doc.save_file(file) != OK:
        _fail("Initial TFL2 save failed")
        return
    var original: PackedByteArray = FileAccess.get_file_as_bytes(file)
    if original.slice(0, 4).get_string_from_ascii() != "TFL2" or original.size() < 100:
        _fail("TFL2 magic or digest footer missing")
        return
    if FileAccess.file_exists(file + ".bak"):
        _fail("Brand-new layer file unexpectedly created a backup")
        return
    var first_height: float = doc.composite_height(idx)
    doc.set_delta(layer, idx, 9.0)
    if doc.save_file(file) != OK:
        _fail("Second save did not preserve previous version")
        return
    var backup = LAYERS.new()
    if not FileAccess.file_exists(file + ".bak") or backup.load_file(file + ".bak") != OK:
        _fail("Previous known-good backup is missing or invalid")
        return
    if absf(backup.composite_height(idx) - first_height) > 0.0001:
        _fail("Backup is not the preceding committed version")
        return
    var second_height: float = doc.composite_height(idx)
    var current = LAYERS.new()
    if current.load_file(file) != OK or absf(current.composite_height(idx) - second_height) > 0.0001:
        _fail("Latest save did not load with matching SHA-256")
        return

    # Tamper with a single payload byte, preserving its 64-byte footer.
    var writer: FileAccess = FileAccess.open(file, FileAccess.READ_WRITE)
    if writer == null:
        _fail("Could not open test file for corruption simulation")
        return
    writer.seek(24)
    var old_byte: int = writer.get_8()
    writer.seek(24)
    writer.store_8(old_byte ^ 1)
    writer.flush()
    writer.close()
    var unmodified_in_memory: float = current.composite_height(idx)
    if current.load_file(file) != ERR_FILE_CORRUPT or current.composite_height(idx) != unmodified_in_memory:
        _fail("Tampered payload was accepted or changed existing live data")
        return
    if doc.save_file(file) == OK:
        _fail("Saving should refuse to overwrite a damaged primary")
        return

    # Corrupted layered scenes are not secretly rolled back.
    var terrain: TerraForgeTerrain = TERRAIN.new()
    terrain.layer_mode = true
    terrain.layer_file = file
    terrain.cells_x = 64
    terrain.cells_z = 64
    terrain._ready()
    if not terrain._read_only_source or not terrain.can_restore_layer_backup():
        _fail("Broken primary did not enter explicit recovery-only mode")
        return
    if terrain.restore_layer_backup() != OK:
        _fail("Explicit recovery from verified previous save failed")
        return
    if terrain._read_only_source or absf(terrain.height_data.heights[idx] - first_height) > 0.0001:
        _fail("Recovery did not load prior working heights into terrain")
        return
    if backup.load_file(file + ".bak") != OK:
        _fail("Recovery destroyed the retained verified backup")
        return
    terrain.free()

    # TFL1 can still be read and migrated without altering its prior bytes
    # unless the developer explicitly calls save_file().
    var stripped: PackedByteArray = original.slice(0, original.size() - LAYERS.CHECKSUM_BYTES)
    stripped[3] = 49  # '1'
    var legacy_writer: FileAccess = FileAccess.open(legacy_path, FileAccess.WRITE)
    if legacy_writer == null:
        _fail("Legacy fixture file could not be created")
        return
    legacy_writer.store_buffer(stripped)
    legacy_writer.close()
    var legacy = LAYERS.new()
    if legacy.load_file(legacy_path) != OK or absf(legacy.composite_height(idx) - first_height) > 0.0001:
        _fail("Backward-compatible TFL1 loading failed")
        return
    if legacy.save_file(legacy_path) != OK:
        _fail("Explicit TFL1 to TFL2 save migration failed")
        return
    if FileAccess.get_file_as_bytes(legacy_path).slice(0, 4).get_string_from_ascii() != "TFL2":
        _fail("Save did not migrate legacy TFL1 to checksummed TFL2")
        return
    var preserved_old = LAYERS.new()
    if preserved_old.load_file(legacy_path + ".bak") != OK:
        _fail("TFL1 original was not preserved in backup on conversion")
        return

    # A pending .tmp is not authoritative after interruption.
    var temp: FileAccess = FileAccess.open(file + ".tmp", FileAccess.WRITE)
    temp.store_buffer(PackedByteArray([66, 65, 68]))
    temp.close()
    var recovered = LAYERS.new()
    if recovered.load_file(file) != OK or absf(recovered.composite_height(idx) - first_height) > 0.0001:
        _fail("Partial temporary data interrupted authoritative recovery")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(file + ".bak"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(file + ".tmp"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path + ".bak"))
    print("PASS: TFL2 SHA-256 integrity, backup, explicit recovery, and legacy TFL1 migration")
    quit(0)
