extends SceneTree
const B = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const I = preload("res://addons/terra_forge/core/region_index_v2.gd")
const R = preload("res://addons/terra_forge/core/region_read_v2.gd")
const P = preload("res://addons/terra_forge/core/region_page_codec.gd")

func _initialize() -> void:
    var b = B.new()
    var plan: Dictionary = B.preflight(Vector2i(8192, 8192))
    if plan["error"] != OK or plan["pages"] != 66049 or plan["shards"] != 289 or B.preflight(Vector2i(32768, 32768))["error"] != ERR_UNAVAILABLE:
        _fail("capacity", b)
        return
    if b.start(Vector2i(512, 512)) != OK:
        _fail("start", b)
        return
    var result: Dictionary = _wait(b)
    if result["error"] != OK:
        _fail("generate " + str(result), b)
        return
    var dir: String = result["directory"]
    var opened: Dictionary = R.open_root(dir)
    if opened["error"] != OK:
        _fail("root", b)
        return
    var root = opened["index"]
    if root.provenance() != I.Provenance.SYNTHETIC_V1 or root.source_digest() != I.sha(B.descriptor(Vector2i(512, 512))) or FileAccess.get_sha256(dir.path_join("fixture.tfg")) != root.source_digest().hex_encode() or root.shard_count() != Vector2i(2, 2):
        _fail("source provenance", b)
        return
    var checked: Dictionary = R.verify_all(dir, root)
    if checked["error"] != OK or checked["verified_pages"] != 289:
        _fail("strict scan", b)
        return
    for key in [Vector2i(0,0), Vector2i(15,15), Vector2i(16,15), Vector2i(15,16), Vector2i(16,16)]:
        var page: Dictionary = R.read_page(dir, root, key)
        if page["error"] != OK:
            _fail("page lookup", b)
            return
        for z in range(32):
            for x in range(32):
                var gx: int = key.x * 32 + x
                var gz: int = key.y * 32 + z
                var expected: float = B.sample(gx, gz) if gx <= 512 and gz <= 512 else 0.0
                if page["values"][z*32+x] != expected:
                    _fail("sample or border mismatch", b)
                    return
    var path: String = dir.path_join("r_00016_00016.tfr")
    var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
    var broken: PackedByteArray = original.duplicate()
    broken[24] = broken[24] ^ 1
    if not _write(path, broken) or R.open_root(dir)["error"] != OK or R.read_page(dir, root, Vector2i(16,16))["error"] == OK or R.verify_all(dir, root)["error"] == OK or R.read_page(dir, root, Vector2i.ZERO)["error"] != OK:
        _fail("page corruption isolation", b)
        return
    if not _write(path, original):
        _fail("restore scratch page", b)
        return
    var wrong: PackedByteArray = original.duplicate()
    wrong.encode_float(20, 1.00001)
    var payload: PackedByteArray = wrong.slice(0, 4120)
    payload.append_array(I.sha(payload).hex_encode().to_ascii_buffer())
    if P.decode(payload, Vector2i(512,512), 1.0, Vector2i(16,16), I.sha(payload))["error"] == OK:
        _fail("exact spacing not enforced", b)
        return
    var shard_path: String = dir.path_join("s_00001_00001.tfs")
    var shard: PackedByteArray = FileAccess.get_file_as_bytes(shard_path)
    if DirAccess.remove_absolute(shard_path) != OK or R.read_page(dir, root, Vector2i(16,16))["error"] != ERR_FILE_NOT_FOUND or R.verify_all(dir, root)["error"] == OK or R.read_page(dir, root, Vector2i.ZERO)["error"] != OK:
        _fail("missing shard", b)
        return
    if not _write(shard_path, shard) or not _write(dir.path_join("manifest.tfm"), PackedByteArray([1])) or R.open_root(dir)["error"] == OK:
        _fail("mixed format accepted", b)
        return
    DirAccess.remove_absolute(dir.path_join("manifest.tfm"))
    if b.start(Vector2i(1024,1024)) != OK:
        _fail("cancel start", b)
        return
    b.request_cancel()
    result = _wait(b)
    if result["error"] != ERR_SKIP or result["cleanup_error"] != OK or not str(result["directory"]).is_empty() or R.verify_all(dir, root)["error"] != OK:
        _fail("cancel or prior world", b)
        return
    b.close()
    print("PASS: 289 genuine TFR1 pages, 4 TFS2 shards, synthetic provenance, strict/lazy checks, seam samples, corruption isolation, cancellation")
    quit(0)

func _write(path: String, raw: PackedByteArray) -> bool:
    var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_buffer(raw)
    f.flush()
    var err: Error = f.get_error()
    f.close()
    return err == OK

func _wait(b) -> Dictionary:
    var deadline: int = Time.get_ticks_msec() + 45000
    while Time.get_ticks_msec() < deadline:
        var r: Dictionary = b.take_result()
        if r["error"] != ERR_BUSY:
            return r
        OS.delay_msec(2)
    return {"error": ERR_TIMEOUT}

func _fail(msg: String, b) -> void:
    b.close()
    push_error("TFM2 fixture: " + msg)
    quit(1)
