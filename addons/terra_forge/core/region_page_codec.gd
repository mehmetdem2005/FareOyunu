@tool
extends RefCounted
## Shared immutable TFR1 codec. Existing TFR1 bytes unchanged.
const IDX = preload("res://addons/terra_forge/core/region_index_v2.gd")
const REG = preload("res://addons/terra_forge/core/region_store.gd")

static func encode(cells: Vector2i, spacing: float, key: Vector2i, values: PackedFloat32Array) -> PackedByteArray:
    if not IDX._dimensions_valid(cells) or not is_finite(spacing) or spacing <= 0.0 or values.size() != REG.PAGE_VALUES:
        return PackedByteArray()
    var bounds: Vector2i = IDX._pages(cells)
    if key.x < 0 or key.y < 0 or key.x >= bounds.x or key.y >= bounds.y:
        return PackedByteArray()
    for v in values:
        if not is_finite(v):
            return PackedByteArray()
    var raw: PackedByteArray = "TFR1".to_ascii_buffer()
    raw.resize(REG.HEADER_BYTES)
    raw.encode_u32(4, cells.x)
    raw.encode_u32(8, cells.y)
    raw.encode_u32(12, key.x)
    raw.encode_u32(16, key.y)
    raw.encode_float(20, spacing)
    if not is_finite(raw.decode_float(20)) or raw.decode_float(20) <= 0.0:
        return PackedByteArray()
    raw.append_array(values.to_byte_array())
    var digest: PackedByteArray = IDX.sha(raw)
    if digest.size() != 32:
        return PackedByteArray()
    raw.append_array(digest.hex_encode().to_ascii_buffer())
    return raw

static func decode(raw: PackedByteArray, cells: Vector2i, spacing: float, key: Vector2i, expected: PackedByteArray, exact_spacing: bool = true) -> Dictionary:
    if raw.size() != REG.FILE_BYTES or expected.size() != 32 or IDX.sha(raw) != expected:
        return {"error": ERR_FILE_CORRUPT}
    var payload: PackedByteArray = raw.slice(0, REG.HEADER_BYTES + REG.PAGE_BYTES)
    if raw.slice(0, 4).get_string_from_ascii() != REG.MAGIC or IDX.sha(payload).hex_encode().to_ascii_buffer() != raw.slice(payload.size()):
        return {"error": ERR_FILE_CORRUPT}
    var actual_spacing: float = raw.decode_float(20)
    if Vector2i(raw.decode_u32(4), raw.decode_u32(8)) != cells or Vector2i(raw.decode_u32(12), raw.decode_u32(16)) != key or not is_finite(actual_spacing) or actual_spacing <= 0.0:
        return {"error": ERR_FILE_CORRUPT}
    if (actual_spacing != spacing if exact_spacing else not is_equal_approx(actual_spacing, spacing)):
        return {"error": ERR_FILE_CORRUPT}
    var values: PackedFloat32Array = raw.slice(REG.HEADER_BYTES, payload.size()).to_float32_array()
    if values.size() != REG.PAGE_VALUES:
        return {"error": ERR_FILE_CORRUPT}
    for v in values:
        if not is_finite(v):
            return {"error": ERR_FILE_CORRUPT}
    return {"error": OK, "values": values}

static func load_page(path: String, cells: Vector2i, spacing: float, key: Vector2i, expected: PackedByteArray, exact_spacing: bool = true) -> Dictionary:
    var read: Dictionary = IDX._read_bounded(path, REG.FILE_BYTES, REG.FILE_BYTES)
    if read["error"] != OK:
        return read
    return decode(read["raw"], cells, spacing, key, expected, exact_spacing)
