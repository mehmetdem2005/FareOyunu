extends SceneTree
const ASYNC = preload("res://addons/terra_forge/core/async_region_source.gd")
const B = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const I = preload("res://addons/terra_forge/core/region_index_v2.gd")

func _initialize() -> void:
    var b = B.new()
    var src = ASYNC.new()
    if b.start(Vector2i(512,512)) != OK:
        _fail("fixture start", src, b)
        return
    var result: Dictionary = {}
    var deadline: int = Time.get_ticks_msec() + 30000
    while Time.get_ticks_msec() < deadline:
        result = b.take_result()
        if result["error"] != ERR_BUSY:
            break
        OS.delay_msec(2)
    if result.get("error", FAILED) != OK:
        _fail("fixture generation", src, b)
        return
    var dir: String = result["directory"]
    if src.open(dir, 2, 2, false) == OK or src.open_v2(dir, 2, 2, true, 1) != OK:
        _fail("explicit format/strict open", src, b)
        return
    if not src.stats()["verified_at_open"] or src.stats()["index_format"] != "TFM2":
        _fail("strict metadata", src, b)
        return
    src.close()
    if src.open_v2(dir, 2, 2, false, 1) != OK:
        _fail("lazy open", src, b)
        return
    var id: String = src.stats()["snapshot_id"]
    var keys: Array[Vector2i] = [Vector2i(15,15),Vector2i(14,15),Vector2i(16,15),Vector2i(15,16),Vector2i(16,16),Vector2i(15,15)]
    for key in keys:
        if _load(src,key) != OK:
            _fail("cross-shard load", src, b)
            return
        var h: Dictionary = src.get_height(key.x * 32,key.y * 32)
        if h["error"] != OK or h["height"] != B.sample(key.x * 32,key.y * 32):
            _fail("sample parity", src, b)
            return
        var s: Dictionary = src.stats()
        if s["resident"] > 2 or s["shard_resident"] > 1 or s["shard_resident_bytes"] > 8272 or s["snapshot_id"] != id or not _conserved(s):
            _fail("bounded cache", src, b)
            return
    var s: Dictionary = src.stats()
    if s["shard_hits"] != 1 or s["shard_loads"] != 5 or s["shard_evictions"] != 4 or s["pages_verified_on_demand"] != 5 or s["verification_bitmap_bytes"] != 37 or s["root_index_bytes"] != 240 or not src._manifest_hashes.is_empty() or not src._verified_once.is_empty():
        _fail("compact counters " + str(s), src, b)
        return
    # Force cold shard and cold page reads. Cached verified bytes remain valid.
    var target: Vector2i = Vector2i(16,16)
    var path: String = dir.path_join("r_00016_00016.tfr")
    var old: PackedByteArray = FileAccess.get_file_as_bytes(path)
    var broken: PackedByteArray = old.duplicate()
    broken[24] = broken[24] ^ 1
    if not _write(path, broken) or src.release_outside(Vector2i.ZERO,Vector2i.ZERO) != OK or _load(src,target) == OK or src.get_height(512,512).has("height"):
        _fail("corrupt cold page", src, b)
        return
    if src.stats()["terminal_errors"] != 1 or src.stats()["terminal_error_bytes"] != 289:
        _fail("error memory", src, b)
        return
    if not _write(path,old) or src.set_generation(1) != OK or src.stats()["terminal_error_bytes"] != 0 or _load(src,target) != OK:
        _fail("retry after epoch", src, b)
        return
    var shard_path: String = dir.path_join("s_00000_00000.tfs")
    var shard: PackedByteArray = FileAccess.get_file_as_bytes(shard_path)
    if DirAccess.remove_absolute(shard_path) != OK or src.release_outside(Vector2i(16,16),Vector2i(16,16)) != OK or _load(src,Vector2i.ZERO) != ERR_FILE_NOT_FOUND or src.get_height(512,512)["error"] != OK:
        _fail("missing shard isolation", src, b)
        return
    src.close()
    if src.open_v2(dir,2,2,true,1) == OK or src.open_v2(dir,2,2,false,1) != OK:
        _fail("strict versus lazy corruption", src, b)
        return
    if not _write(shard_path,shard):
        _fail("restore scratch shard", src, b)
        return
    for epoch in range(1,301):
        src.request_page(Vector2i(epoch % 17, epoch % 17))
        if src.set_generation(epoch) != OK or not _conserved(src.stats()):
            _fail("epoch conservation", src, b)
            return
    if _load(src,Vector2i(16,16)) != OK or src.stats()["snapshot_id"] != id or not _conserved(src.stats()):
        _fail("stale epoch starvation", src, b)
        return
    src.close()
    if src.stats()["shard_resident"] != 0 or src.stats()["verification_bitmap_bytes"] != 0 or not src.stats()["snapshot_id"].is_empty():
        _fail("close reset", src, b)
        return
    b.close()
    print("PASS: TFM2 opt-in strict/lazy, cross-shard cache, compact exact telemetry, corrupt cold page, missing shard, 300 epochs, close")
    quit(0)

func _load(src,key: Vector2i) -> Error:
    var deadline: int = Time.get_ticks_msec() + 5000
    while Time.get_ticks_msec() < deadline:
        var status: Error = src.page_status(key)
        if status != ERR_BUSY:
            return status
        src.request_page(key)
        src.poll_results(2)
        OS.delay_msec(1)
    return ERR_TIMEOUT

func _conserved(s: Dictionary) -> bool:
    var n: int = int(s["outstanding"]) + int(s["inflight"]) + int(s["finished"])
    return n <= int(s["max_jobs"]) and int(s["submitted"]) == n + int(s["accepted_results"]) + int(s["cancelled_pending"]) + int(s["cancelled_finished"]) + int(s["cancelled_inflight"])

func _write(path: String, raw: PackedByteArray) -> bool:
    var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_buffer(raw)
    f.flush()
    var err: Error = f.get_error()
    f.close()
    return err == OK

func _fail(msg: String, src, b) -> void:
    src.close()
    b.close()
    push_error("TFM2 async: " + msg)
    quit(1)
