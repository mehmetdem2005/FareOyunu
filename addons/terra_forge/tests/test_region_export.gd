@tool
extends SceneTree
## P1 transactional export: TFH1 and TFL2 visible Float32 composites,
## source byte immutability, manifest integrity, foreign/partial data refusal.
const STORE = preload("res://addons/terra_forge/core/height_store.gd")
const LAYERS = preload("res://addons/terra_forge/core/height_layers.gd")
const REGIONS = preload("res://addons/terra_forge/core/region_store.gd")
const MANIFEST = preload("res://addons/terra_forge/core/region_manifest.gd")
const EXPORT = preload("res://addons/terra_forge/core/region_export.gd")

func _fail(message: String) -> void:
    push_error("TerraForge region export: " + message)
    quit(1)

func _verify_samples(directory: String, expected: PackedFloat32Array, dimensions: Vector2i) -> bool:
    var store = REGIONS.new()
    if store.initialize(directory, dimensions, 1.0, 2) != OK:
        return false
    for z in [0, 1, 31, 32, 33, 63, 64]:
        for x in [0, 1, 31, 32, 33, 63, 64, 95, 96]:
            var sample: Dictionary = store.read_height(x, z)
            if int(sample.get("error", ERR_FILE_CORRUPT)) != OK:
                return false
            var reference: float = expected[z * (dimensions.x + 1) + x]
            if float(sample["height"]) != reference:
                return false
    return store.resident_pages() <= 2

func _initialize() -> void:
    var suffix: String = str(Time.get_ticks_usec())
    var source_path: String = "user://tf_export_" + suffix + ".tfh"
    var layered_path: String = "user://tf_export_" + suffix + ".tfl"
    var world_dir: String = "user://tf_export_" + suffix + "_world"
    var layered_dir: String = "user://tf_export_" + suffix + "_layers"
    var original = STORE.new()
    original.initialize(Vector2i(96, 64), 1.0)
    for z in range(65):
        for x in range(97):
            original.heights[original.index_of(x, z)] = (
                float(x) * 0.125 - float(z) * 0.375 + sin(float(x) * 0.15) * 2.5
            )
    if original.save_file(source_path) != OK:
        _fail("TFH source fixture could not be saved")
        return
    var before_bytes: PackedByteArray = FileAccess.get_file_as_bytes(source_path)
    var before_sha: String = FileAccess.get_sha256(source_path)
    var exported: Dictionary = EXPORT.export_file(source_path, world_dir, 2)
    if int(exported.get("error", ERR_FILE_CORRUPT)) != OK or int(exported["pages"]) != 12:
        _fail("TFH export could not publish 4x3 region files")
        return
    var verified: Dictionary = MANIFEST.load(world_dir, true)
    if int(verified.get("error", ERR_FILE_CORRUPT)) != OK:
        _fail("TFH manifest or regional hashes failed validation")
        return
    var meta: Dictionary = verified["document"]
    if str(meta["source_sha256"]) != before_sha or bool(meta["flattened_layers"]):
        _fail("TFH manifest lost provenance metadata")
        return
    if not _verify_samples(world_dir, original.heights, original.cells):
        _fail("TFH export lost exact Float32 values at tile borders")
        return
    if FileAccess.get_file_as_bytes(source_path) != before_bytes:
        _fail("Export modified original TFH source bytes")
        return
    var one_page: String = world_dir + "/r_00001_00000.tfr"
    var page_hash: String = FileAccess.get_sha256(one_page)
    if int(EXPORT.export_file(source_path, world_dir).get("error", OK)) != ERR_ALREADY_EXISTS:
        _fail("Re-export unexpectedly overwrote existing published world")
        return
    if FileAccess.get_sha256(one_page) != page_hash:
        _fail("Overwrite refusal still modified a region file")
        return

    var layered = LAYERS.new()
    if layered.initialize(original.heights, original.cells, original.spacing) != OK:
        _fail("Layered source initialization failed")
        return
    var ridge: int = layered.add_layer("Ridge")
    var hidden: int = layered.add_layer("Hidden")
    if layered.set_delta(ridge, original.index_of(32, 31), 6.75) != OK:
        _fail("Could not prepare modified seam height")
        return
    layered.set_delta(ridge, original.index_of(96, 64), -2.25)
    layered.set_delta(hidden, original.index_of(31, 32), 90.0)
    layered.set_enabled(hidden, false)
    if layered.save_file(layered_path) != OK:
        _fail("TFL2 source save failed")
        return
    var layered_bytes: PackedByteArray = FileAccess.get_file_as_bytes(layered_path)
    var layered_sha: String = FileAccess.get_sha256(layered_path)
    var snapshot: PackedFloat32Array = layered.compose()
    var result: Dictionary = EXPORT.export_file(layered_path, layered_dir, 1)
    if int(result.get("error", ERR_FILE_CORRUPT)) != OK or not bool(result["flattened_layers"]):
        _fail("TFL2 flattened composite export failed")
        return
    if not _verify_samples(layered_dir, snapshot, original.cells):
        _fail("TFL2 composite export lost Float32 heights or ignored visibility")
        return
    var layer_manifest: Dictionary = MANIFEST.load(layered_dir, true)
    if int(layer_manifest.get("error", ERR_FILE_CORRUPT)) != OK:
        _fail("TFL2 manifest failed full page verification")
        return
    if str(layer_manifest["document"]["source_sha256"]) != layered_sha:
        _fail("TFL2 source provenance was lost")
        return
    if FileAccess.get_file_as_bytes(layered_path) != layered_bytes:
        _fail("Flattening modified the editable TFL2 original")
        return

    # Mismatched or deleted region data must block world verification.
    var missing_page: String = layered_dir + "/r_00000_00000.tfr"
    var delete_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_page))
    if delete_error != OK or int(MANIFEST.load(layered_dir, true).get("error", OK)) != ERR_FILE_NOT_FOUND:
        _fail("A missing region was accepted as a valid world")
        return

    # The manifest digest itself also fails closed after one byte is changed.
    var manifest_path: String = world_dir.path_join(MANIFEST.FILE_NAME)
    var damage: FileAccess = FileAccess.open(manifest_path, FileAccess.READ_WRITE)
    if damage == null:
        _fail("Manifest tamper fixture cannot open")
        return
    damage.seek(16)
    var old_byte: int = damage.get_8()
    damage.seek(16)
    damage.store_8(old_byte ^ 1)
    damage.flush()
    damage.close()
    if MANIFEST.load(world_dir, false).get("error", OK) != ERR_FILE_CORRUPT:
        _fail("Tampered manifest was accepted")
        return

    # An invalid source must not create its target directory.
    var bad_dir: String = "user://tf_export_" + suffix + "_invalid"
    if EXPORT.export_file(source_path + ".missing", bad_dir).get("error", OK) != ERR_FILE_NOT_FOUND:
        _fail("Missing source was accepted")
        return
    if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(bad_dir)):
        _fail("Invalid conversion created a published directory")
        return

    print("PASS: transactional TFH/TFL2 Float32 export, manifest hashes, seam ownership and immutable source")
    quit(0)
