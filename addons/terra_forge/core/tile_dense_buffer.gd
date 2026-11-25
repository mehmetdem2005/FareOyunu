@tool
extends RefCounted
## Experimental C: copied, stride-aligned canonical heights plus a normal
## halo. Independent of the page cache after synchronous construction.
## Workers may own a private copy; never share a mutable buffer.
const MAX_SAMPLES: int = 35 * 35
var cells: Vector2i
var spacing: float
var _first: Vector2i
var _extent: Vector2i
var _stride: int
var _values: PackedFloat32Array = PackedFloat32Array()

# Rectangular sample window shared by the IO planner and owned buffer copy.
# The four bits follow the worker signature order (west, east, north, south).
const FULL_HALO: int = 15
static func sample_bounds(cells: Vector2i, key: Vector2i, stride: int, halo_mask: int) -> Rect2i:
    var first := key * 32
    var last := first + Vector2i(32, 32)
    if halo_mask & 1:
        first.x -= stride
    if halo_mask & 2:
        last.x += stride
    if halo_mask & 4:
        first.y -= stride
    if halo_mask & 8:
        last.y += stride
    first = first.max(Vector2i.ZERO)
    last = last.min(cells)
    return Rect2i(first, last - first + Vector2i.ONE)

static func build(view, tx: int, tz: int, stride: int, halo_mask: int = FULL_HALO) -> Dictionary:
    if view == null or not view.is_open() or stride not in [1,2,4]:
        return {"error": ERR_INVALID_PARAMETER}
    if tx < 0 or tz < 0 or (tx+1)*32 > view.cells.x or (tz+1)*32 > view.cells.y:
        return {"error": ERR_INVALID_PARAMETER}
    var bounds := sample_bounds(view.cells, Vector2i(tx, tz), stride, halo_mask)
    var first: Vector2i = bounds.position
    var extent: Vector2i = (bounds.size - Vector2i.ONE) / stride + Vector2i.ONE
    if extent.x <= 0 or extent.y <= 0 or extent.x*extent.y > MAX_SAMPLES:
        return {"error": ERR_INVALID_PARAMETER}
    var buffer = new()
    buffer.cells = view.cells
    buffer.spacing = view.spacing
    buffer._first = first
    buffer._extent = extent
    buffer._stride = stride
    if view.has_method("copy_grid"):
        buffer._values = view.copy_grid(first, extent, stride)
        if buffer._values.size() != extent.x * extent.y:
            return {"error": ERR_FILE_CORRUPT}
        return {"error": OK, "buffer": buffer}
    var resized: Error = buffer._values.resize(extent.x*extent.y)
    if resized != OK:
        return {"error": resized}
    for z in range(extent.y):
        for x in range(extent.x):
            var value: float = view.read_finite_or_nan(first.x+x*stride,first.y+z*stride)
            if not is_finite(value):
                return {"error": ERR_FILE_CORRUPT}
            buffer._values[z*extent.x+x] = value
    return {"error": OK,"buffer":buffer}

func is_open() -> bool:
    return not _values.is_empty()

func payload_bytes() -> int:
    return _values.size()*4

func get_height(x: int,z: int) -> Dictionary:
    var dx: int = x-_first.x
    var dz: int = z-_first.y
    if not is_open() or dx<0 or dz<0 or dx%_stride!=0 or dz%_stride!=0:
        return {"error":ERR_INVALID_PARAMETER}
    var ix: int = dx/_stride
    var iz: int = dz/_stride
    if ix>=_extent.x or iz>=_extent.y or x>cells.x or z>cells.y:
        return {"error":ERR_INVALID_PARAMETER}
    return {"error":OK,"height":_values[iz*_extent.x+ix]}

## Scalar access for the worker-owned copy. No dictionary on success;
## off-grid/outside samples and nonfinite values fail closed.
func read_finite_or_nan(x: int,z: int) -> float:
    var dx: int=x-_first.x
    var dz: int=z-_first.y
    if not is_open() or dx<0 or dz<0 or dx%_stride!=0 or dz%_stride!=0:
        return NAN
    var ix: int=dx/_stride
    var iz: int=dz/_stride
    if ix>=_extent.x or iz>=_extent.y or x>cells.x or z>cells.y:
        return NAN
    var value: float=_values[iz*_extent.x+ix]
    return value if is_finite(value) else NAN
