@tool
extends RefCounted
## TFM2/TFS2 v1 binary read-only index codec. No page writes, no SceneTree.
## All offsets are little-endian. Entry coordinates are implicit row-major.
const ROOT_NAME: String = "manifest.tfm2"
const VERSION: int = 1
const PAGE_WIDTH: int = 32
const SHARD_WIDTH: int = 16
const MAX_CELLS: int = 32768
const DIGEST_BYTES: int = 32
const ROOT_HEADER: int = 80
const SHARD_HEADER: int = 48
const ROOT_CAP: int = 256 * 1024
const SHARD_CAP: int = 16 * 1024
enum Provenance { TFH1 = 1, TFL1 = 2, TFL2 = 3, SYNTHETIC_V1 = 4 }

## Only scalar metadata and packed digest buffers. No per-page dictionaries.
class RootIndex:
    extends RefCounted
    var _raw: PackedByteArray
    func _init(raw: PackedByteArray) -> void:
        _raw = raw
    func cells() -> Vector2i:
        return Vector2i(_raw.decode_u32(8), _raw.decode_u32(12))
    func spacing() -> float:
        return _raw.decode_float(16)
    func page_count() -> Vector2i:
        return Vector2i(_raw.decode_u32(24), _raw.decode_u32(28))
    func shard_count() -> Vector2i:
        return Vector2i(_raw.decode_u32(32), _raw.decode_u32(36))
    func provenance() -> int:
        return _raw.decode_u32(40)
    func source_digest() -> PackedByteArray:
        return _raw.slice(48, 80)
    func byte_count() -> int:
        return _raw.size()
    func snapshot_digest() -> PackedByteArray:
        return _raw.slice(_raw.size() - 32)
    func shard_digest(key: Vector2i) -> PackedByteArray:
        var count: Vector2i = shard_count()
        if key.x < 0 or key.y < 0 or key.x >= count.x or key.y >= count.y:
            return PackedByteArray()
        var offset: int = 80 + (key.y * count.x + key.x) * 32
        return _raw.slice(offset, offset + 32)
    func shard_for_page(page: Vector2i) -> Vector2i:
        var count: Vector2i = page_count()
        if page.x < 0 or page.y < 0 or page.x >= count.x or page.y >= count.y:
            return Vector2i(-1, -1)
        return Vector2i(page.x >> 4, page.y >> 4)

class ShardIndex:
    extends RefCounted
    var _raw: PackedByteArray
    func _init(raw: PackedByteArray) -> void:
        _raw = raw
    func key() -> Vector2i:
        return Vector2i(_raw.decode_u32(24), _raw.decode_u32(28))
    func extent() -> Vector2i:
        return Vector2i(_raw.decode_u32(32), _raw.decode_u32(36))
    func byte_count() -> int:
        return _raw.size()
    func page_digest(page: Vector2i) -> PackedByteArray:
        var local: Vector2i = page - key() * 16
        var bounds: Vector2i = extent()
        if local.x < 0 or local.y < 0 or local.x >= bounds.x or local.y >= bounds.y:
            return PackedByteArray()
        var offset: int = 48 + (local.y * bounds.x + local.x) * 32
        return _raw.slice(offset, offset + 32)

static func sha(raw: PackedByteArray) -> PackedByteArray:
    var ctx: HashingContext = HashingContext.new()
    if ctx.start(HashingContext.HASH_SHA256) != OK or ctx.update(raw) != OK:
        return PackedByteArray()
    return ctx.finish()

static func _digest_valid(digest: PackedByteArray) -> bool:
    if digest.size() != DIGEST_BYTES:
        return false
    for value in digest:
        if value != 0:
            return true
    return false

static func _entries_valid(raw: PackedByteArray, first: int, count: int) -> bool:
    # No per-entry allocation. All-zero is reserved, not a missing-page marker.
    for i in range(count):
        var any: bool = false
        for j in range(DIGEST_BYTES):
            if raw[first + i * DIGEST_BYTES + j] != 0:
                any = true
                break
        if not any:
            return false
    return true

static func _dimensions_valid(cells: Vector2i) -> bool:
    return cells.x >= 32 and cells.y >= 32 and cells.x <= MAX_CELLS and cells.y <= MAX_CELLS and cells.x % 32 == 0 and cells.y % 32 == 0

static func _pages(cells: Vector2i) -> Vector2i:
    return Vector2i((cells.x >> 5) + 1, (cells.y >> 5) + 1)

static func _shards(pages: Vector2i) -> Vector2i:
    return Vector2i((pages.x + 15) >> 4, (pages.y + 15) >> 4)

static func _edge(pages: Vector2i, key: Vector2i) -> Vector2i:
    var bounds: Vector2i = _shards(pages)
    if key.x < 0 or key.y < 0 or key.x >= bounds.x or key.y >= bounds.y:
        return Vector2i.ZERO
    return Vector2i(mini(16, pages.x - key.x * 16), mini(16, pages.y - key.y * 16))

static func _put(raw: PackedByteArray, offset: int, data: PackedByteArray) -> void:
    # PackedByteArray is reference-shared for function arguments in GDScript.
    for i in range(data.size()):
        raw[offset + i] = data[i]

static func _valid_provenance(tag: int) -> bool:
    return tag >= Provenance.TFH1 and tag <= Provenance.SYNTHETIC_V1

static func _seal(payload: PackedByteArray) -> PackedByteArray:
    var digest: PackedByteArray = sha(payload)
    if not _digest_valid(digest):
        return PackedByteArray()
    payload.append_array(digest)
    return payload

static func encode_root(cells: Vector2i, spacing: float, provenance: int, source: PackedByteArray, entries: PackedByteArray) -> PackedByteArray:
    if not _dimensions_valid(cells) or not is_finite(spacing) or spacing <= 0.0 or not _valid_provenance(provenance) or not _digest_valid(source):
        return PackedByteArray()
    var pages: Vector2i = _pages(cells)
    var shards: Vector2i = _shards(pages)
    var count: int = shards.x * shards.y
    if entries.size() != count * DIGEST_BYTES or not _entries_valid(entries, 0, count):
        return PackedByteArray()
    var raw: PackedByteArray = PackedByteArray()
    raw.resize(ROOT_HEADER)
    _put(raw, 0, "TFM2".to_ascii_buffer())
    raw.encode_u32(4, VERSION)
    raw.encode_u32(8, cells.x)
    raw.encode_u32(12, cells.y)
    raw.encode_float(16, spacing)
    if not is_finite(raw.decode_float(16)) or raw.decode_float(16) <= 0.0:
        return PackedByteArray()
    raw.encode_u16(20, PAGE_WIDTH)
    raw.encode_u16(22, SHARD_WIDTH)
    raw.encode_u32(24, pages.x)
    raw.encode_u32(28, pages.y)
    raw.encode_u32(32, shards.x)
    raw.encode_u32(36, shards.y)
    raw.encode_u32(40, provenance)
    raw.encode_u32(44, 0)
    _put(raw, 48, source)
    raw.append_array(entries)
    return _seal(raw)

static func encode_shard(cells: Vector2i, spacing: float, key: Vector2i, entries: PackedByteArray) -> PackedByteArray:
    if not _dimensions_valid(cells) or not is_finite(spacing) or spacing <= 0.0:
        return PackedByteArray()
    var edge: Vector2i = _edge(_pages(cells), key)
    var count: int = edge.x * edge.y
    if count == 0 or entries.size() != count * DIGEST_BYTES or not _entries_valid(entries, 0, count):
        return PackedByteArray()
    var raw: PackedByteArray = PackedByteArray()
    raw.resize(SHARD_HEADER)
    _put(raw, 0, "TFS2".to_ascii_buffer())
    raw.encode_u32(4, VERSION)
    raw.encode_u32(8, cells.x)
    raw.encode_u32(12, cells.y)
    raw.encode_float(16, spacing)
    if not is_finite(raw.decode_float(16)) or raw.decode_float(16) <= 0.0:
        return PackedByteArray()
    raw.encode_u16(20, PAGE_WIDTH)
    raw.encode_u16(22, SHARD_WIDTH)
    raw.encode_u32(24, key.x)
    raw.encode_u32(28, key.y)
    raw.encode_u32(32, edge.x)
    raw.encode_u32(36, edge.y)
    raw.encode_u32(40, 0)
    raw.encode_u32(44, 0)
    raw.append_array(entries)
    return _seal(raw)

static func _header_valid(raw: PackedByteArray, magic: String) -> bool:
    return raw.slice(0, 4).get_string_from_ascii() == magic and raw.decode_u32(4) == VERSION and raw.decode_u16(20) == PAGE_WIDTH and raw.decode_u16(22) == SHARD_WIDTH and is_finite(raw.decode_float(16)) and raw.decode_float(16) > 0.0

static func _checksum_valid(raw: PackedByteArray) -> bool:
    var end: int = raw.size() - DIGEST_BYTES
    var checksum: PackedByteArray = sha(raw.slice(0, end))
    return _digest_valid(checksum) and checksum == raw.slice(end)

static func decode_root(raw: PackedByteArray) -> Dictionary:
    if raw.size() < ROOT_HEADER + 2 * DIGEST_BYTES or raw.size() > ROOT_CAP:
        return {"error": ERR_FILE_CORRUPT}
    if not _header_valid(raw, "TFM2"):
        return {"error": ERR_INVALID_DATA}
    var cells: Vector2i = Vector2i(raw.decode_u32(8), raw.decode_u32(12))
    if not _dimensions_valid(cells):
        return {"error": ERR_INVALID_DATA}
    var pages: Vector2i = _pages(cells)
    var shards: Vector2i = _shards(pages)
    var count: int = shards.x * shards.y
    if raw.size() != ROOT_HEADER + (count + 1) * DIGEST_BYTES:
        return {"error": ERR_FILE_CORRUPT}
    if raw.decode_u32(24) != pages.x or raw.decode_u32(28) != pages.y or raw.decode_u32(32) != shards.x or raw.decode_u32(36) != shards.y or not _valid_provenance(raw.decode_u32(40)) or raw.decode_u32(44) != 0:
        return {"error": ERR_INVALID_DATA}
    if not _digest_valid(raw.slice(48, 80)) or not _entries_valid(raw, ROOT_HEADER, count):
        return {"error": ERR_INVALID_DATA}
    if not _checksum_valid(raw):
        return {"error": ERR_FILE_CORRUPT}
    return {"error": OK, "index": RootIndex.new(raw.duplicate())}

static func decode_shard(raw: PackedByteArray, root: RootIndex, key: Vector2i) -> Dictionary:
    if root == null:
        return {"error": ERR_INVALID_PARAMETER}
    var expected: PackedByteArray = root.shard_digest(key)
    if expected.is_empty():
        return {"error": ERR_INVALID_PARAMETER}
    if raw.size() < SHARD_HEADER + 2 * DIGEST_BYTES or raw.size() > SHARD_CAP:
        return {"error": ERR_FILE_CORRUPT}
    var edge: Vector2i = _edge(root.page_count(), key)
    var count: int = edge.x * edge.y
    if raw.size() != SHARD_HEADER + (count + 1) * DIGEST_BYTES:
        return {"error": ERR_FILE_CORRUPT}
    if sha(raw) != expected or not _checksum_valid(raw):
        return {"error": ERR_FILE_CORRUPT}
    if not _header_valid(raw, "TFS2"):
        return {"error": ERR_INVALID_DATA}
    var cells: Vector2i = Vector2i(raw.decode_u32(8), raw.decode_u32(12))
    if cells != root.cells() or raw.decode_float(16) != root.spacing() or raw.decode_u32(24) != key.x or raw.decode_u32(28) != key.y or raw.decode_u32(32) != edge.x or raw.decode_u32(36) != edge.y or raw.decode_u32(40) != 0 or raw.decode_u32(44) != 0 or not _entries_valid(raw, SHARD_HEADER, count):
        return {"error": ERR_INVALID_DATA}
    return {"error": OK, "index": ShardIndex.new(raw.duplicate())}

static func _read_bounded(path: String, minimum: int, maximum: int) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"error": ERR_FILE_NOT_FOUND}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"error": FileAccess.get_open_error()}
    var size: int = file.get_length()
    if size < minimum or size > maximum:
        file.close()
        return {"error": ERR_FILE_CORRUPT}
    var raw: PackedByteArray = file.get_buffer(size)
    var unchanged_size: bool = file.get_length() == size
    file.close()
    if raw.size() != size or not unchanged_size:
        return {"error": ERR_FILE_CORRUPT}
    return {"error": OK, "raw": raw}

static func load_root(directory: String) -> Dictionary:
    if directory.is_empty():
        return {"error": ERR_INVALID_PARAMETER}
    var read: Dictionary = _read_bounded(directory.path_join(ROOT_NAME), ROOT_HEADER + 64, ROOT_CAP)
    if read["error"] != OK:
        return read
    return decode_root(read["raw"])

static func load_shard(directory: String, root: RootIndex, key: Vector2i) -> Dictionary:
    if directory.is_empty() or root == null or root.shard_digest(key).is_empty():
        return {"error": ERR_INVALID_PARAMETER}
    var read: Dictionary = _read_bounded(directory.path_join("s_%05d_%05d.tfs" % [key.x, key.y]), SHARD_HEADER + 64, SHARD_CAP)
    if read["error"] != OK:
        return read
    return decode_shard(read["raw"], root, key)
