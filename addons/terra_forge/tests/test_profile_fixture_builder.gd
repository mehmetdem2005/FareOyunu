extends SceneTree
const BUILDER = preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const MANIFEST = preload("res://addons/terra_forge/core/region_manifest.gd")
const HEIGHT = preload("res://addons/terra_forge/core/height_store.gd")
const REGION = preload("res://addons/terra_forge/core/region_store.gd")

func _initialize() -> void:
    var b = BUILDER.new()
    var p: Dictionary = BUILDER.preflight(Vector2i(2048, 2048))
    if p["error"] != OK or p["pages"] != 4225:
        _fail("2048 capacity", b)
        return
    p = BUILDER.preflight(Vector2i(3168, 3168))
    if p["error"] != ERR_UNAVAILABLE or not p["tfm1_supported_by_bound"] or p["tfh1_supported"]:
        _fail("TFH vs TFM1 capacity", b)
        return
    p = BUILDER.preflight(Vector2i(4096, 4096))
    if p["error"] != ERR_UNAVAILABLE or p["pages"] != 16641 or p["tfm1_supported_by_bound"]:
        _fail("4096 limit", b)
        return
    if b.start(Vector2i(4096, 4096)) != ERR_UNAVAILABLE or b.start(Vector2i(33, 32)) != ERR_INVALID_PARAMETER:
        _fail("invalid dimensions accepted", b)
        return
    if b.start(Vector2i(64, 96)) != OK:
        _fail("start", b)
        return
    if b.start(Vector2i(64, 64)) != ERR_BUSY:
        _fail("concurrent start accepted", b)
        return
    var result: Dictionary = _wait(b)
    if result.get("error", FAILED) != OK:
        _fail("generation " + str(result), b)
        return
    var folder: String = result["directory"]
    var loaded: Dictionary = MANIFEST.load(folder, true)
    var h = HEIGHT.new()
    if loaded["error"] != OK or h.load_file(folder.path_join("source.tfh")) != OK or FileAccess.get_sha256(folder.path_join("source.tfh")) != loaded["document"]["source_sha256"]:
        _fail("genuine source provenance", b)
        return
    var regions = REGION.new()
    regions.initialize(folder, Vector2i(64, 96), 1.0, 1)
    for z in range(97):
        for x in range(65):
            var v: Dictionary = regions.read_height(x, z)
            if v["error"] != OK or v["height"] != h.get_height(x, z):
                _fail("Float32 source/page mismatch at " + str(Vector2i(x, z)), b)
                return
    if b.start(Vector2i(512, 512)) != OK:
        _fail("cancel start", b)
        return
    b.request_cancel()
    result = _wait(b)
    if result.get("error", FAILED) != ERR_SKIP or result.get("cleanup_error", FAILED) != OK or not str(result.get("directory", "")).is_empty():
        _fail("cancel published or leaked staging " + str(result), b)
        return
    if MANIFEST.load(folder, true)["error"] != OK:
        _fail("cancel modified previous world", b)
        return
    b.close()
    print("PASS: bounded row/page fixture, real TFH1 SHA, exact rectangular Float32 parity, capacity preflight, cancel and isolation")
    quit(0)

func _wait(b) -> Dictionary:
    var deadline: int = Time.get_ticks_msec() + 15000
    while Time.get_ticks_msec() < deadline:
        var r: Dictionary = b.take_result()
        if r["error"] != ERR_BUSY:
            return r
        OS.delay_msec(2)
    return {"error": ERR_TIMEOUT}

func _fail(message: String, b) -> void:
    b.close()
    push_error("TerraForge fixture: " + message)
    quit(1)
