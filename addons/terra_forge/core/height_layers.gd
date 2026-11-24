@tool
extends RefCounted
## TerraForge P1: versioned, sparse, additive Float32 height layers.
## This core DOES NOT modify existing .tfh files or terrain scenes.
## Tiles hold 32x32 independent sample deltas, never duplicated borders.
const MAGIC: String = "TFL1"
const TILE_SIZE: int = 32
const TILE_VALUES: int = TILE_SIZE * TILE_SIZE
const MAX_CELLS: int = 2048
const MAX_LAYERS: int = 8
const MAX_NAME_BYTES: int = 64
const MAX_FILE_BYTES: int = 192 * 1024 * 1024

var cells: Vector2i = Vector2i.ZERO
var spacing: float = 1.0
var base_heights: PackedFloat32Array = PackedFloat32Array()
var layers: Array[Dictionary] = []

func initialize(source: PackedFloat32Array, dimensions: Vector2i, cell_spacing: float) -> Error:
    if not _valid_dimensions(dimensions) or not is_finite(cell_spacing) or cell_spacing <= 0.0:
        return ERR_INVALID_PARAMETER
    if source.size() != (dimensions.x + 1) * (dimensions.y + 1):
        return ERR_INVALID_DATA
    for h in source:
        if not is_finite(h):
            return ERR_INVALID_DATA
    cells = dimensions
    spacing = cell_spacing
    base_heights = source.duplicate()
    layers.clear()
    return OK

static func _valid_dimensions(dimensions: Vector2i) -> bool:
    return dimensions.x >= 32 and dimensions.y >= 32 and dimensions.x <= MAX_CELLS and dimensions.y <= MAX_CELLS and dimensions.x % 32 == 0 and dimensions.y % 32 == 0

func add_layer(name: String) -> int:
    if layers.size() >= MAX_LAYERS or base_heights.is_empty():
        return -1
    var safe_name: String = name.strip_edges()
    if safe_name.is_empty() or safe_name.to_utf8_buffer().size() > MAX_NAME_BYTES:
        return -1
    layers.append({"name": safe_name, "enabled": true, "opacity": 1.0, "tiles": {}})
    return layers.size() - 1

func set_enabled(layer_index: int, enabled: bool) -> Error:
    if not _valid_layer(layer_index):
        return ERR_INVALID_PARAMETER
    layers[layer_index]["enabled"] = enabled
    return OK

func set_opacity(layer_index: int, opacity: float) -> Error:
    if not _valid_layer(layer_index) or not is_finite(opacity) or opacity < 0.0 or opacity > 1.0:
        return ERR_INVALID_PARAMETER
    layers[layer_index]["opacity"] = opacity
    return OK

func move_layer(from_index: int, to_index: int) -> Error:
    if not _valid_layer(from_index) or not _valid_layer(to_index):
        return ERR_INVALID_PARAMETER
    var layer: Dictionary = layers[from_index]
    layers.remove_at(from_index)
    layers.insert(to_index, layer)
    return OK

func _valid_layer(index: int) -> bool:
    return index >= 0 and index < layers.size()

func _valid_index(index: int) -> bool:
    return index >= 0 and index < base_heights.size()

func _tile_sample_address(index: int) -> Dictionary:
    var gx: int = index % (cells.x + 1)
    var gz: int = int(index / (cells.x + 1))
    var tx: int = int(gx / TILE_SIZE)
    var tz: int = int(gz / TILE_SIZE)
    return {
        "tile": Vector2i(tx, tz),
        "offset": (gz % TILE_SIZE) * TILE_SIZE + (gx % TILE_SIZE)
    }

func read_delta(layer_index: int, index: int) -> float:
    if not _valid_layer(layer_index) or not _valid_index(index):
        return 0.0
    var address: Dictionary = _tile_sample_address(index)
    var tiles: Dictionary = layers[layer_index]["tiles"]
    var key: Vector2i = address["tile"]
    if not tiles.has(key):
        return 0.0
    var values: PackedFloat32Array = tiles[key]
    return values[int(address["offset"])]

func put_delta(layer_index: int, index: int, delta: float) -> Error:
    if not _valid_layer(layer_index) or not _valid_index(index) or not is_finite(delta):
        return ERR_INVALID_PARAMETER
    var address: Dictionary = _tile_sample_address(index)
    var key: Vector2i = address["tile"]
    var tiles: Dictionary = layers[layer_index]["tiles"]
    var values: PackedFloat32Array
    if tiles.has(key):
        values = tiles[key]
    else:
        values = PackedFloat32Array()
        values.resize(TILE_VALUES)
    var position: int = int(address["offset"])
    var new_delta: float = values[position] + delta
    if not is_finite(new_delta):
        return ERR_INVALID_DATA
    values[position] = new_delta
    tiles[key] = values
    layers[layer_index]["tiles"] = tiles
    return OK

## Absolute write for stroke Undo/Redo. Unlike put_delta(), setting a
## recorded value is idempotent and does not accumulate float rounding.
func set_delta(layer_index: int, index: int, value: float) -> Error:
    if not _valid_layer(layer_index) or not _valid_index(index) or not is_finite(value):
        return ERR_INVALID_PARAMETER
    var address: Dictionary = _tile_sample_address(index)
    var key: Vector2i = address["tile"]
    var tiles: Dictionary = layers[layer_index]["tiles"]
    if not tiles.has(key) and value == 0.0:
        return OK
    var values: PackedFloat32Array
    if tiles.has(key):
        values = tiles[key]
    else:
        values = PackedFloat32Array()
        values.resize(TILE_VALUES)
    values[int(address["offset"])] = value
    tiles[key] = values
    layers[layer_index]["tiles"] = tiles
    return OK

func composite_height(index: int) -> float:
    if not _valid_index(index):
        return 0.0
    var height: float = base_heights[index]
    for i in range(layers.size()):
        var layer: Dictionary = layers[i]
        if bool(layer["enabled"]) and float(layer["opacity"]) > 0.0:
            height += read_delta(i, index) * float(layer["opacity"])
    return height

func compose() -> PackedFloat32Array:
    var output: PackedFloat32Array = base_heights.duplicate()
    if output.is_empty():
        return output
    var row_stride: int = cells.x + 1
    for layer in layers:
        if not bool(layer["enabled"]) or float(layer["opacity"]) <= 0.0:
            continue
        var opacity: float = float(layer["opacity"])
        var tiles: Dictionary = layer["tiles"]
        for key in tiles:
            var base_x: int = key.x * TILE_SIZE
            var base_z: int = key.y * TILE_SIZE
            var values: PackedFloat32Array = tiles[key]
            for z in range(TILE_SIZE):
                var gz: int = base_z + z
                if gz > cells.y:
                    break
                for x in range(TILE_SIZE):
                    var gx: int = base_x + x
                    if gx > cells.x:
                        break
                    var delta: float = values[z * TILE_SIZE + x]
                    if delta != 0.0:
                        var sample_index: int = gz * row_stride + gx
                        output[sample_index] += delta * opacity
    return output

func save_file(path: String) -> Error:
    if base_heights.is_empty() or path.is_empty() or layers.size() > MAX_LAYERS:
        return ERR_INVALID_DATA
    var absolute_dir: String = ProjectSettings.globalize_path(path.get_base_dir())
    var dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_dir)
    if dir_error != OK:
        return dir_error
    var temp_path: String = path + ".tmp"
    var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_buffer(MAGIC.to_ascii_buffer())
    file.store_32(cells.x)
    file.store_32(cells.y)
    file.store_float(spacing)
    file.store_32(layers.size())
    file.store_buffer(base_heights.to_byte_array())
    for layer in layers:
        var name_bytes: PackedByteArray = str(layer["name"]).to_utf8_buffer()
        if name_bytes.size() == 0 or name_bytes.size() > MAX_NAME_BYTES:
            file.close()
            DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
            return ERR_INVALID_DATA
        file.store_32(name_bytes.size())
        file.store_buffer(name_bytes)
        file.store_8(1 if bool(layer["enabled"]) else 0)
        file.store_float(float(layer["opacity"]))
        var tiles: Dictionary = layer["tiles"]
        file.store_32(tiles.size())
        for key in tiles:
            var values: PackedFloat32Array = tiles[key]
            file.store_32(key.x)
            file.store_32(key.y)
            file.store_buffer(values.to_byte_array())
    file.flush()
    file.close()
    # Never load the entire serialized file into RAM merely to check size.
    var check: FileAccess = FileAccess.open(temp_path, FileAccess.READ)
    if check == null:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
        return FileAccess.get_open_error()
    var byte_count: int = check.get_length()
    check.close()
    if byte_count > MAX_FILE_BYTES:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
        return ERR_OUT_OF_MEMORY
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))

func load_file(path: String) -> Error:
    if path.is_empty() or not FileAccess.file_exists(path):
        return ERR_FILE_NOT_FOUND
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return FileAccess.get_open_error()
    var length: int = file.get_length()
    if length < 20 or length > MAX_FILE_BYTES or file.get_buffer(4).get_string_from_ascii() != MAGIC:
        return ERR_FILE_CORRUPT
    var dims: Vector2i = Vector2i(int(file.get_32()), int(file.get_32()))
    var file_spacing: float = file.get_float()
    var layer_count: int = int(file.get_32())
    if not _valid_dimensions(dims) or not is_finite(file_spacing) or file_spacing <= 0.0 or layer_count > MAX_LAYERS:
        return ERR_INVALID_DATA
    var sample_count: int = (dims.x + 1) * (dims.y + 1)
    var base_bytes: PackedByteArray = file.get_buffer(sample_count * 4)
    if base_bytes.size() != sample_count * 4:
        return ERR_FILE_CORRUPT
    var parsed_base: PackedFloat32Array = base_bytes.to_float32_array()
    if parsed_base.size() != sample_count:
        return ERR_FILE_CORRUPT
    for h in parsed_base:
        if not is_finite(h):
            return ERR_INVALID_DATA
    var parsed_layers: Array[Dictionary] = []
    var max_tile_x: int = int(dims.x / TILE_SIZE)
    var max_tile_z: int = int(dims.y / TILE_SIZE)
    var max_tiles: int = (max_tile_x + 1) * (max_tile_z + 1)
    for layer_idx in range(layer_count):
        if file.get_position() + 4 > length:
            return ERR_FILE_CORRUPT
        var name_length: int = int(file.get_32())
        if name_length < 1 or name_length > MAX_NAME_BYTES or file.get_position() + name_length + 9 > length:
            return ERR_INVALID_DATA
        var name: String = file.get_buffer(name_length).get_string_from_utf8()
        var enabled_flag: int = int(file.get_8())
        var opacity: float = file.get_float()
        var tile_count: int = int(file.get_32())
        if name.is_empty() or enabled_flag > 1 or not is_finite(opacity) or opacity < 0.0 or opacity > 1.0 or tile_count > max_tiles:
            return ERR_INVALID_DATA
        var tiles: Dictionary = {}
        for tile_idx in range(tile_count):
            if file.get_position() + 8 + TILE_VALUES * 4 > length:
                return ERR_FILE_CORRUPT
            var key: Vector2i = Vector2i(int(file.get_32()), int(file.get_32()))
            if key.x < 0 or key.y < 0 or key.x > max_tile_x or key.y > max_tile_z or tiles.has(key):
                return ERR_INVALID_DATA
            var bytes: PackedByteArray = file.get_buffer(TILE_VALUES * 4)
            if bytes.size() != TILE_VALUES * 4:
                return ERR_FILE_CORRUPT
            var values: PackedFloat32Array = bytes.to_float32_array()
            for delta in values:
                if not is_finite(delta):
                    return ERR_INVALID_DATA
            tiles[key] = values
        parsed_layers.append({"name": name, "enabled": enabled_flag == 1, "opacity": opacity, "tiles": tiles})
    if file.get_position() != length:
        return ERR_FILE_CORRUPT
    # Commit only after complete validation. A corrupt file never replaces a
    # live layer stack or its canonical base data.
    cells = dims
    spacing = file_spacing
    base_heights = parsed_base
    layers = parsed_layers
    return OK
