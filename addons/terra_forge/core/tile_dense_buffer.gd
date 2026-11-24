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

static func build(view, tx: int, tz: int, stride: int) -> Dictionary:
    if view == null or not view.is_open() or stride not in [1,2,4]:
        return {"error": ERR_INVALID_PARAMETER}
    if tx < 0 or tz < 0 or (tx+1)*32 > view.cells.x or (tz+1)*32 > view.cells.y:
        return {"error": ERR_INVALID_PARAMETER}
    var first: Vector2i = Vector2i(maxi(0,tx*32-stride),maxi(0,tz*32-stride))
    var last: Vector2i = Vector2i(mini(view.cells.x,(tx+1)*32+stride),mini(view.cells.y,(tz+1)*32+stride))
    var extent: Vector2i = (last-first)/stride + Vector2i.ONE
    if extent.x <= 0 or extent.y <= 0 or extent.x*extent.y > MAX_SAMPLES:
        return {"error": ERR_INVALID_PARAMETER}
    var buffer = new()
    buffer.cells = view.cells
    buffer.spacing = view.spacing
    buffer._first = first
    buffer._extent = extent
    buffer._stride = stride
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
