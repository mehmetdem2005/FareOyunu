@tool
extends RefCounted
## P1 experimental disk-backed Float32 sample pages.
## NOT connected to TerraForgeTerrain yet: does not touch TFH/TFL documents.
## Each grid sample has ONE owner: floor(global_sample / 32). This avoids
## duplicated seams; boundary x=32 belongs to page 1, offset 0.
const MAGIC: String = "TFR1"
const PAGE_WIDTH: int = 32
const PAGE_VALUES: int = PAGE_WIDTH * PAGE_WIDTH
const HEADER_BYTES: int = 24
const HASH_BYTES: int = 64
const PAGE_BYTES: int = PAGE_VALUES * 4
const FILE_BYTES: int = HEADER_BYTES + PAGE_BYTES + HASH_BYTES
const MAX_WORLD_CELLS: int = 32768

var root_path: String = ""
var world_cells: Vector2i = Vector2i.ZERO
var spacing: float = 1.0
var max_resident: int = 4
var _cache: Dictionary = {}
var _lru: Array[Vector2i] = []
var _disk_reads: int = 0
var _disk_writes: int = 0

func initialize(directory: String, dimensions: Vector2i, cell_spacing: float, cache_pages: int = 4) -> Error:
    if directory.is_empty() or dimensions.x < 32 or dimensions.y < 32:
        return ERR_INVALID_PARAMETER
    if dimensions.x > MAX_WORLD_CELLS or dimensions.y > MAX_WORLD_CELLS:
        return ERR_INVALID_PARAMETER
    if not is_finite(cell_spacing) or cell_spacing <= 0.0 or cache_pages < 1 or cache_pages > 64:
        return ERR_INVALID_PARAMETER
    if not _cache.is_empty():
        # Never discard unsaved changes during reconfiguration.
        var saved: Error = flush_all()
        if saved != OK:
            return saved
    root_path = directory.trim_suffix("/")
    world_cells = dimensions
    spacing = cell_spacing
    max_resident = cache_pages
    _cache.clear()
    _lru.clear()
    _disk_reads = 0
    _disk_writes = 0
    return OK

func page_count() -> Vector2i:
    # Include the final x=max, z=max border samples.
    return Vector2i(int(world_cells.x / PAGE_WIDTH) + 1, int(world_cells.y / PAGE_WIDTH) + 1)

func resident_pages() -> int:
    return _cache.size()

func stats() -> Dictionary:
    return {
        "resident": _cache.size(),
        "limit": max_resident,
        "resident_float_bytes": _cache.size() * PAGE_BYTES,
        "disk_reads": _disk_reads,
        "disk_writes": _disk_writes
    }

func _valid_page(key: Vector2i) -> bool:
    var count: Vector2i = page_count()
    return key.x >= 0 and key.y >= 0 and key.x < count.x and key.y < count.y

func _valid_sample(x: int, z: int) -> bool:
    return x >= 0 and z >= 0 and x <= world_cells.x and z <= world_cells.y

func _page_key(x: int, z: int) -> Vector2i:
    return Vector2i(int(x / PAGE_WIDTH), int(z / PAGE_WIDTH))

func _page_offset(x: int, z: int) -> int:
    return (z % PAGE_WIDTH) * PAGE_WIDTH + (x % PAGE_WIDTH)

func _path_for(key: Vector2i) -> String:
    return "%s/r_%05d_%05d.tfr" % [root_path, key.x, key.y]

func _touch(key: Vector2i) -> void:
    var i: int = _lru.find(key)
    if i >= 0:
        _lru.remove_at(i)
    _lru.append(key)

func _parse_page(path: String, key: Vector2i) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"error": ERR_FILE_NOT_FOUND}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"error": FileAccess.get_open_error()}
    if file.get_length() != FILE_BYTES:
        return {"error": ERR_FILE_CORRUPT}
    var payload: PackedByteArray = file.get_buffer(HEADER_BYTES + PAGE_BYTES)
    var expected: String = file.get_buffer(HASH_BYTES).get_string_from_ascii()
    if payload.size() != HEADER_BYTES + PAGE_BYTES or expected.length() != HASH_BYTES:
        return {"error": ERR_FILE_CORRUPT}
    var hash: HashingContext = HashingContext.new()
    if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(payload) != OK:
        return {"error": ERR_CANT_OPEN}
    if hash.finish().hex_encode() != expected:
        return {"error": ERR_FILE_CORRUPT}
    file.seek(0)
    if file.get_buffer(4).get_string_from_ascii() != MAGIC:
        return {"error": ERR_FILE_CORRUPT}
    var file_cells: Vector2i = Vector2i(int(file.get_32()), int(file.get_32()))
    var file_key: Vector2i = Vector2i(int(file.get_32()), int(file.get_32()))
    var file_spacing: float = file.get_float()
    if file_cells != world_cells or file_key != key or not is_equal_approx(file_spacing, spacing):
        return {"error": ERR_INVALID_DATA}
    var values: PackedFloat32Array = file.get_buffer(PAGE_BYTES).to_float32_array()
    if values.size() != PAGE_VALUES:
        return {"error": ERR_FILE_CORRUPT}
    for value in values:
        if not is_finite(value):
            return {"error": ERR_INVALID_DATA}
    _disk_reads += 1
    return {"error": OK, "values": values}

func _save_page(key: Vector2i) -> Error:
    if not _cache.has(key):
        return ERR_DOES_NOT_EXIST
    var record: Dictionary = _cache[key]
    if not bool(record["dirty"]):
        return OK
    var values: PackedFloat32Array = record["values"]
    if values.size() != PAGE_VALUES:
        return ERR_INVALID_DATA
    for value in values:
        if not is_finite(value):
            return ERR_INVALID_DATA
    var path: String = _path_for(key)
    var folder: String = ProjectSettings.globalize_path(root_path)
    var dir_error: Error = DirAccess.make_dir_recursive_absolute(folder)
    if dir_error != OK:
        return dir_error
    # Fail closed: never overwrite a damaged or mismatched existing page.
    if FileAccess.file_exists(path):
        var old: Dictionary = _parse_page(path, key)
        if int(old["error"]) != OK:
            return int(old["error"])
    var temp_path: String = path + ".tmp"
    var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_buffer(MAGIC.to_ascii_buffer())
    file.store_32(world_cells.x)
    file.store_32(world_cells.y)
    file.store_32(key.x)
    file.store_32(key.y)
    file.store_float(spacing)
    file.store_buffer(values.to_byte_array())
    file.flush()
    file.close()
    var digest: String = FileAccess.get_sha256(temp_path)
    if digest.length() != HASH_BYTES:
        return ERR_FILE_CORRUPT
    var append_file: FileAccess = FileAccess.open(temp_path, FileAccess.READ_WRITE)
    if append_file == null:
        return FileAccess.get_open_error()
    append_file.seek_end()
    append_file.store_buffer(digest.to_ascii_buffer())
    append_file.flush()
    append_file.close()
    var verification: Dictionary = _parse_page(temp_path, key)
    if int(verification["error"]) != OK:
        return int(verification["error"])
    var abs_path: String = ProjectSettings.globalize_path(path)
    var abs_temp: String = ProjectSettings.globalize_path(temp_path)
    if FileAccess.file_exists(path):
        var backup_tmp: String = ProjectSettings.globalize_path(path + ".bak.tmp")
        var copy_error: Error = DirAccess.copy_absolute(abs_path, backup_tmp)
        if copy_error != OK:
            return copy_error
        var move_backup: Error = DirAccess.rename_absolute(backup_tmp, ProjectSettings.globalize_path(path + ".bak"))
        if move_backup != OK:
            return move_backup
    var save_error: Error = DirAccess.rename_absolute(abs_temp, abs_path)
    if save_error != OK:
        return save_error
    record["dirty"] = false
    _cache[key] = record
    _disk_writes += 1
    return OK

func _evict_oldest() -> Error:
    if _lru.is_empty():
        return OK
    var key: Vector2i = _lru[0]
    var error: Error = _save_page(key)
    if error != OK:
        return error
    _lru.remove_at(0)
    _cache.erase(key)
    return OK

func _make_room() -> Error:
    if _cache.size() < max_resident:
        return OK
    return _evict_oldest()

func _ensure_loaded(key: Vector2i) -> Error:
    if not _valid_page(key):
        return ERR_INVALID_PARAMETER
    if _cache.has(key):
        _touch(key)
        return OK
    var loaded: Dictionary = _parse_page(_path_for(key), key)
    var error: Error = int(loaded["error"])
    if error != OK:
        return error
    error = _make_room()
    if error != OK:
        return error
    _cache[key] = {"values": loaded["values"], "dirty": false}
    _touch(key)
    return OK

func create_blank_page(key: Vector2i) -> Error:
    # Explicit initialization, never an implicit fallback for missing data.
    if not _valid_page(key):
        return ERR_INVALID_PARAMETER
    if _cache.has(key) or FileAccess.file_exists(_path_for(key)):
        return ERR_ALREADY_EXISTS
    var error: Error = _make_room()
    if error != OK:
        return error
    var values: PackedFloat32Array = PackedFloat32Array()
    values.resize(PAGE_VALUES)
    _cache[key] = {"values": values, "dirty": true}
    _touch(key)
    error = _save_page(key)
    if error != OK:
        _cache.erase(key)
        _lru.erase(key)
    return error

func read_height(x: int, z: int) -> Dictionary:
    if not _valid_sample(x, z):
        return {"error": ERR_INVALID_PARAMETER}
    var key: Vector2i = _page_key(x, z)
    var error: Error = _ensure_loaded(key)
    if error != OK:
        return {"error": error}
    var record: Dictionary = _cache[key]
    var values: PackedFloat32Array = record["values"]
    return {"error": OK, "height": values[_page_offset(x, z)]}

func write_height(x: int, z: int, height: float) -> Error:
    if not _valid_sample(x, z) or not is_finite(height):
        return ERR_INVALID_PARAMETER
    var key: Vector2i = _page_key(x, z)
    var error: Error = _ensure_loaded(key)
    if error != OK:
        return error
    var record: Dictionary = _cache[key]
    var values: PackedFloat32Array = record["values"]
    values[_page_offset(x, z)] = height
    record["values"] = values
    record["dirty"] = true
    _cache[key] = record
    return OK

func flush_all() -> Error:
    # Preserve dirty memory on the FIRST failed write.
    for key in _lru:
        var error: Error = _save_page(key)
        if error != OK:
            return error
    return OK

func unload_all() -> Error:
    var error: Error = flush_all()
    if error != OK:
        return error
    _cache.clear()
    _lru.clear()
    return OK
