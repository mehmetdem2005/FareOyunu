@tool
extends RefCounted
## Main-thread-only short-lived read lease. No source pointer, no disk IO.
## Only source constructs/revokes this internal view. Packed pages shared
## read-only by convention; no array returned to callers.
const MAX_PAGES: int = 9
var cells: Vector2i
var spacing: float
var _first: Vector2i
var _extent: Vector2i
var _pages: Array[PackedFloat32Array] = []
var _open: bool = true
var _reads: int = 0

func _init(dimensions: Vector2i, sample_spacing: float, first: Vector2i, extent: Vector2i, pages: Array[PackedFloat32Array]) -> void:
    cells = dimensions
    spacing = sample_spacing
    _first = first
    _extent = extent
    _pages = pages

func is_open() -> bool:
    return _open

func get_height(x: int, z: int) -> Dictionary:
    if not _open:
        return {"error": ERR_UNCONFIGURED}
    if x < 0 or z < 0 or x > cells.x or z > cells.y:
        return {"error": ERR_INVALID_PARAMETER}
    var local: Vector2i = Vector2i(x >> 5, z >> 5) - _first
    if local.x < 0 or local.y < 0 or local.x >= _extent.x or local.y >= _extent.y:
        return {"error": ERR_INVALID_PARAMETER}
    var values: PackedFloat32Array = _pages[local.y * _extent.x + local.x]
    _reads += 1
    return {"error": OK, "height": values[(z & 31) * 32 + (x & 31)]}

## Internal scalar path for validated buffer construction; NAN is an
## error sentinel, never a height. All decoded TFR1 samples are finite.
func read_finite_or_nan(x: int, z: int) -> float:
    if not _open or x < 0 or z < 0 or x > cells.x or z > cells.y:
        return NAN
    var local: Vector2i = Vector2i(x >> 5, z >> 5) - _first
    if local.x < 0 or local.y < 0 or local.x >= _extent.x or local.y >= _extent.y:
        return NAN
    var values: PackedFloat32Array = _pages[local.y * _extent.x + local.x]
    _reads += 1
    return values[(z & 31) * 32 + (x & 31)]

## Snapshot a validated rectangle in page runs. The returned array belongs
## to the caller and can outlive this lease.
func copy_grid(first: Vector2i, extent: Vector2i, stride: int) -> PackedFloat32Array:
    var result := PackedFloat32Array()
    if not _open or stride not in [1, 2, 4] or extent.x < 1 or extent.y < 1 or extent.x > 35 or extent.y > 35:
        return result
    var last := first + (extent - Vector2i.ONE) * stride
    var first_page := Vector2i(first.x >> 5, first.y >> 5) - _first
    var last_page := Vector2i(last.x >> 5, last.y >> 5) - _first
    if first.x < 0 or first.y < 0 or last.x > cells.x or last.y > cells.y:
        return result
    if first_page.x < 0 or first_page.y < 0 or last_page.x >= _extent.x or last_page.y >= _extent.y:
        return result
    if result.resize(extent.x * extent.y) != OK:
        return PackedFloat32Array()
    var out_index := 0
    for row in range(extent.y):
        var z := first.y + row * stride
        var page_row := ((z >> 5) - _first.y) * _extent.x
        var x := first.x
        while x <= last.x:
            var page := _pages[page_row + (x >> 5) - _first.x]
            var offset := ((z & 31) << 5) + (x & 31)
            var stop := mini(last.x + 1, ((x >> 5) + 1) << 5)
            while x < stop:
                var height := page[offset]
                if not is_finite(height):
                    return PackedFloat32Array()
                result[out_index] = height
                out_index += 1
                offset += stride
                x += stride
    _reads += out_index
    return result

func page_count_held() -> int:
    return _pages.size()

func _revoke() -> int:
    _open = false
    _pages.clear()
    return _reads
