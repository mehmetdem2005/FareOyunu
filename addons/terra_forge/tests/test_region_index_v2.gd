extends SceneTree
const IDX = preload("res://addons/terra_forge/core/region_index_v2.gd")

func _initialize() -> void:
    var cells: Vector2i = Vector2i(512, 1024)
    var source: PackedByteArray = IDX.sha("synthetic-v1".to_utf8_buffer())
    var entries: PackedByteArray = PackedByteArray()
    var shards: Array[PackedByteArray] = []
    # 17x33 pages, 2x3 shards; includes 1-column/1-row edge shards.
    for z in range(3):
        for x in range(2):
            var hashes: PackedByteArray = PackedByteArray()
            for local_z in range(1 if z == 2 else 16):
                for local_x in range(1 if x == 1 else 16):
                    hashes.append_array(_page_hash(Vector2i(x * 16 + local_x, z * 16 + local_z)))
            var encoded: PackedByteArray = IDX.encode_shard(cells, 0.5, Vector2i(x, z), hashes)
            if encoded.is_empty():
                _fail("encode shard")
                return
            shards.append(encoded)
            entries.append_array(IDX.sha(encoded))
    var raw: PackedByteArray = IDX.encode_root(cells, 0.5, IDX.Provenance.SYNTHETIC_V1, source, entries)
    var decoded: Dictionary = IDX.decode_root(raw)
    if decoded["error"] != OK:
        _fail("root roundtrip")
        return
    var root = decoded["index"]
    if root.cells() != cells or root.page_count() != Vector2i(17, 33) or root.shard_count() != Vector2i(2, 3) or root.source_digest() != source or root.provenance() != IDX.Provenance.SYNTHETIC_V1 or root.spacing() != 0.5 or root.byte_count() != 304:
        _fail("root metadata")
        return
    for z in range(3):
        for x in range(2):
            var key: Vector2i = Vector2i(x, z)
            var s: Dictionary = IDX.decode_shard(shards[z * 2 + x], root, key)
            if s["error"] != OK:
                _fail("shard roundtrip")
                return
            var index = s["index"]
            var edge: Vector2i = index.extent()
            if edge != Vector2i(1 if x == 1 else 16, 1 if z == 2 else 16):
                _fail("edge extent")
                return
            for lz in range(edge.y):
                for lx in range(edge.x):
                    var page: Vector2i = key * 16 + Vector2i(lx, lz)
                    if root.shard_for_page(page) != key or index.page_digest(page) != _page_hash(page):
                        _fail("implicit ordinal mismatch")
                        return
            if not index.page_digest(key * 16 + edge).is_empty():
                _fail("outside shard accepted")
                return
    if not root.shard_digest(Vector2i(2, 0)).is_empty() or root.shard_for_page(Vector2i(17, 0)) != Vector2i(-1, -1):
        _fail("outside root accepted")
        return
    # Malformed but correctly re-sealed headers must fail independently of SHA.
    for offset in [4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44]:
        var altered: PackedByteArray = raw.slice(0, raw.size() - 32)
        altered.encode_u32(offset, 0xffffffff)
        altered.append_array(IDX.sha(altered))
        if IDX.decode_root(altered)["error"] == OK:
            _fail("re-sealed root field accepted: " + str(offset))
            return
    var zero: PackedByteArray = raw.slice(0, raw.size() - 32)
    for i in range(80, 112):
        zero[i] = 0
    zero.append_array(IDX.sha(zero))
    if IDX.decode_root(zero)["error"] == OK:
        _fail("zero digest accepted")
        return
    # Tamper all bytes of compact root without repairing digest.
    for i in range(raw.size()):
        var damaged: PackedByteArray = raw.duplicate()
        damaged[i] = damaged[i] ^ 1
        if IDX.decode_root(damaged)["error"] == OK:
            _fail("mutated root accepted")
            return
    for size in [0, 4, 79, 111, raw.size() - 1]:
        if IDX.decode_root(raw.slice(0, size))["error"] == OK:
            _fail("truncated root")
            return
    var extra: PackedByteArray = raw.duplicate()
    extra.append(0)
    if IDX.decode_root(extra)["error"] == OK or IDX.decode_shard(shards[0], root, Vector2i(1, 0))["error"] == OK:
        _fail("trailing bytes or wrong shard")
        return
    # Rebind root to forged shard so external SHA alone cannot hide bad fields.
    for offset in [4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48]:
        var fake: PackedByteArray = shards[0].slice(0, shards[0].size() - 32)
        if offset == 48:
            for i in range(48, 80):
                fake[i] = 0
        else:
            fake.encode_u32(offset, 0xffffffff)
        fake.append_array(IDX.sha(fake))
        var rebind: PackedByteArray = IDX.sha(fake)
        rebind.append_array(entries.slice(32))
        var r: Dictionary = IDX.decode_root(IDX.encode_root(cells, 0.5, IDX.Provenance.SYNTHETIC_V1, source, rebind))
        if r["error"] != OK or IDX.decode_shard(fake, r["index"], Vector2i.ZERO)["error"] == OK:
            _fail("re-sealed shard accepted at " + str(offset))
            return
    # Max index capacity without allocating terrain or one million page hashes.
    var max_entries: PackedByteArray = PackedByteArray()
    max_entries.resize(65 * 65 * 32)
    max_entries.fill(1)
    var max_raw: PackedByteArray = IDX.encode_root(Vector2i(32768, 32768), 1.0, IDX.Provenance.SYNTHETIC_V1, source, max_entries)
    var max_doc: Dictionary = IDX.decode_root(max_raw)
    if max_doc["error"] != OK or max_raw.size() != 135312 or max_doc["index"].page_count() != Vector2i(1025, 1025) or max_doc["index"].shard_for_page(Vector2i(1024, 1024)) != Vector2i(64, 64):
        _fail("maximum theoretical capacity")
        return
    if not IDX.encode_root(cells, 1e-100, 4, source, entries).is_empty() or not IDX.encode_root(cells, 1e100, 4, source, entries).is_empty():
        _fail("Float32 spacing underflow/overflow")
        return
    # Disk read cap and pinned root: malformed on-disk shard never returns index.
    var directory: String = "user://tf_index_test_" + str(Time.get_ticks_usec())
    if DirAccess.make_dir_absolute(directory) != OK or not _write(directory.path_join(IDX.ROOT_NAME), raw) or not _write(directory.path_join("s_00000_00000.tfs"), shards[0]):
        _fail("scratch IO")
        return
    var disk: Dictionary = IDX.load_root(directory)
    if disk["error"] != OK or IDX.load_shard(directory, disk["index"], Vector2i.ZERO)["error"] != OK or IDX.load_shard(directory, disk["index"], Vector2i(1, 0))["error"] != ERR_FILE_NOT_FOUND:
        _fail("disk read")
        return
    var oversized: PackedByteArray = PackedByteArray()
    oversized.resize(IDX.SHARD_CAP + 1)
    if not _write(directory.path_join("s_00000_00000.tfs"), oversized) or IDX.load_shard(directory, disk["index"], Vector2i.ZERO)["error"] == OK:
        _fail("oversized shard")
        return
    oversized.resize(IDX.ROOT_CAP + 1)
    if not _write(directory.path_join(IDX.ROOT_NAME), oversized) or IDX.load_root(directory)["error"] == OK:
        _fail("oversized root")
        return
    # Caller buffer mutation cannot change an already decoded index.
    raw.fill(0)
    if root.shard_digest(Vector2i.ZERO) != entries.slice(0, 32):
        _fail("root aliasing")
        return
    DirAccess.remove_absolute(directory.path_join(IDX.ROOT_NAME))
    DirAccess.remove_absolute(directory.path_join("s_00000_00000.tfs"))
    DirAccess.remove_absolute(directory)
    print("PASS: TFM2/TFS2 bounded codec, 561 implicit page digests, edge shards, corruption, pinned bytes, max root 135312 bytes")
    quit(0)

func _page_hash(key: Vector2i) -> PackedByteArray:
    return IDX.sha(("%d:%d" % [key.x, key.y]).to_utf8_buffer())

func _write(path: String, raw: PackedByteArray) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_buffer(raw)
    file.flush()
    var status: Error = file.get_error()
    file.close()
    return status == OK

func _fail(message: String) -> void:
    push_error("TFM2: " + message)
    quit(1)
