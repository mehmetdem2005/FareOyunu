@tool
extends RefCounted
## TerraForge's canonical height data. This is never quantized to 8-bit PNG.
const MAGIC: String = "TFH1"
const MAX_CELLS: int = 2048

var cells: Vector2i = Vector2i(256, 256)
var spacing: float = 1.0
var heights: PackedFloat32Array = PackedFloat32Array()

func initialize(size: Vector2i, sample_spacing: float = 1.0) -> void:
    cells = Vector2i(clampi(size.x, 32, MAX_CELLS), clampi(size.y, 32, MAX_CELLS))
    spacing = maxf(0.01, sample_spacing)
    heights = PackedFloat32Array()
    heights.resize((cells.x + 1) * (cells.y + 1))

func index_of(x: int, z: int) -> int:
    return z * (cells.x + 1) + x

func get_height(x: int, z: int) -> float:
    var gx: int = clampi(x, 0, cells.x)
    var gz: int = clampi(z, 0, cells.y)
    return heights[index_of(gx, gz)]

func sample_local(x: float, z: float) -> float:
    var px: float = clampf(x / spacing, 0.0, float(cells.x))
    var pz: float = clampf(z / spacing, 0.0, float(cells.y))
    var ix: int = mini(floori(px), cells.x - 1)
    var iz: int = mini(floori(pz), cells.y - 1)
    var tx: float = px - float(ix)
    var tz: float = pz - float(iz)
    var top: float = lerpf(get_height(ix, iz), get_height(ix + 1, iz), tx)
    var bottom: float = lerpf(get_height(ix, iz + 1), get_height(ix + 1, iz + 1), tx)
    return lerpf(top, bottom, tz)

func load_file(path: String) -> Error:
    if path.is_empty() or not FileAccess.file_exists(path):
        return ERR_FILE_NOT_FOUND
    var f: FileAccess = FileAccess.open(path, FileAccess.READ)
    if f == null:
        return FileAccess.get_open_error()
    if f.get_length() < 16 or f.get_buffer(4).get_string_from_ascii() != MAGIC:
        return ERR_FILE_CORRUPT
    var width: int = int(f.get_32())
    var depth: int = int(f.get_32())
    var sample_spacing: float = f.get_float()
    if width < 32 or depth < 32 or width > MAX_CELLS or depth > MAX_CELLS:
        return ERR_INVALID_DATA
    if width % 32 != 0 or depth % 32 != 0:
        return ERR_INVALID_DATA
    if not is_finite(sample_spacing) or sample_spacing <= 0.0:
        return ERR_INVALID_DATA
    var count: int = (width + 1) * (depth + 1)
    if f.get_length() != 16 + count * 4:
        return ERR_FILE_CORRUPT
    var bytes: PackedByteArray = f.get_buffer(count * 4)
    if bytes.size() != count * 4:
        return ERR_FILE_CORRUPT
    var loaded: PackedFloat32Array = bytes.to_float32_array()
    if loaded.size() != count:
        return ERR_FILE_CORRUPT
    for h in loaded:
        if not is_finite(h):
            return ERR_INVALID_DATA
    cells = Vector2i(width, depth)
    spacing = sample_spacing
    heights = loaded
    return OK

func save_file(path: String) -> Error:
    if path.is_empty() or heights.size() != (cells.x + 1) * (cells.y + 1):
        return ERR_INVALID_DATA
    var folder: String = ProjectSettings.globalize_path(path.get_base_dir())
    var folder_error: Error = DirAccess.make_dir_recursive_absolute(folder)
    if folder_error != OK:
        return folder_error
    var temporary: String = path + ".tmp"
    var f: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
    if f == null:
        return FileAccess.get_open_error()
    f.store_buffer(MAGIC.to_ascii_buffer())
    f.store_32(cells.x)
    f.store_32(cells.y)
    f.store_float(spacing)
    f.store_buffer(heights.to_byte_array())
    f.flush()
    f.close()
    # Atomic rename on Android/Unix. Keep the old file intact on failure.
    return DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temporary),
        ProjectSettings.globalize_path(path)
    )
