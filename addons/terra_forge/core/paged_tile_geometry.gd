@tool
extends RefCounted
## Read-only terrain geometry builder. Identical height/LOD/normal/collision
## conventions to the legacy TerraForgeTerrain mesh, but NO full-world array.
## All reads are nonblocking from async_region_source.gd's resident cache.
const LOD_POLICY = preload("res://addons/terra_forge/core/lod_policy.gd")
const PAGE_WIDTH: int = 32
const TILE_CELLS: int = 32

static func required_pages(source, tx: int, tz: int, lod: int) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    if source == null or not source.is_open() or lod < 0 or lod > 2:
        return result
    var stride: int = LOD_POLICY.sample_stride(lod)
    # A one-stride halo covers centered normals at same-LOD boundaries.
    # Conservative up to 3x3 disk pages: never silently read absent pages.
    var min_x: int = maxi(0, tx * TILE_CELLS - stride)
    var min_z: int = maxi(0, tz * TILE_CELLS - stride)
    var max_x: int = mini(source.cells.x, (tx + 1) * TILE_CELLS + stride)
    var max_z: int = mini(source.cells.y, (tz + 1) * TILE_CELLS + stride)
    for pz in range(int(min_z / PAGE_WIDTH), int(max_z / PAGE_WIDTH) + 1):
        for px in range(int(min_x / PAGE_WIDTH), int(max_x / PAGE_WIDTH) + 1):
            result.append(Vector2i(px, pz))
    return result

static func _seam(source, tx: int, tz: int, x: int, z: int, lod: int,
        desired: Dictionary) -> Dictionary:
    var gx: int = tx * TILE_CELLS + x
    var gz: int = tz * TILE_CELLS + z
    var sample: Dictionary = source.get_height(gx, gz)
    if int(sample.get("error", ERR_FILE_CORRUPT)) != OK:
        return sample
    var neighbor: Vector2i = Vector2i(-100000, -100000)
    var along: int = 0
    var horizontal: bool = false
    if x == 0:
        neighbor = Vector2i(tx - 1, tz)
        along = z
    elif x == TILE_CELLS:
        neighbor = Vector2i(tx + 1, tz)
        along = z
    elif z == 0:
        neighbor = Vector2i(tx, tz - 1)
        along = x
        horizontal = true
    elif z == TILE_CELLS:
        neighbor = Vector2i(tx, tz + 1)
        along = x
        horizontal = true
    if not desired.has(neighbor):
        return sample
    var neighbor_lod: int = int(desired[neighbor])
    if neighbor_lod <= lod:
        return sample
    var coarse_step: int = LOD_POLICY.sample_stride(neighbor_lod)
    var start_along: int = int(along / coarse_step) * coarse_step
    if start_along == along:
        return sample
    var end_along: int = mini(TILE_CELLS, start_along + coarse_step)
    var first: Dictionary
    var last: Dictionary
    if horizontal:
        first = source.get_height(tx * TILE_CELLS + start_along, gz)
        last = source.get_height(tx * TILE_CELLS + end_along, gz)
    else:
        first = source.get_height(gx, tz * TILE_CELLS + start_along)
        last = source.get_height(gx, tz * TILE_CELLS + end_along)
    if int(first.get("error", ERR_FILE_CORRUPT)) != OK:
        return first
    if int(last.get("error", ERR_FILE_CORRUPT)) != OK:
        return last
    return {
        "error": OK,
        "height": lerpf(
            float(first["height"]), float(last["height"]),
            float(along - start_along) / float(end_along - start_along)
        )
    }

## Same geometry algorithm, only data-access strategy changes.
static func generate_with_view(source, tx: int, tz: int, lod: int, desired: Dictionary) -> Dictionary:
    if source == null or not source.is_open() or lod < 0 or lod > 2 or tx < 0 or tz < 0 or (tx + 1) * TILE_CELLS > source.cells.x or (tz + 1) * TILE_CELLS > source.cells.y:
        return {"error": ERR_INVALID_PARAMETER}
    var acquired: Dictionary = source.acquire_tile_view(required_pages(source, tx, tz, lod))
    if acquired["error"] != OK:
        return acquired
    var view = acquired["view"]
    var result: Dictionary = generate(view, tx, tz, lod, desired)
    var released: Error = source.release_tile_view(view)
    if released != OK:
        return {"error": released}
    return result

static func generate(source, tx: int, tz: int, lod: int, desired: Dictionary) -> Dictionary:
    if source == null or not source.is_open() or lod < 0 or lod > 2:
        return {"error": ERR_INVALID_PARAMETER}
    if tx < 0 or tz < 0 or (tx + 1) * TILE_CELLS > source.cells.x or (tz + 1) * TILE_CELLS > source.cells.y:
        return {"error": ERR_INVALID_PARAMETER}
    var stride: int = LOD_POLICY.sample_stride(lod)
    var width: int = int(TILE_CELLS / stride) + 1
    var spacing: float = source.spacing
    var vertices: PackedVector3Array = PackedVector3Array()
    var normals: PackedVector3Array = PackedVector3Array()
    var uv: PackedVector2Array = PackedVector2Array()
    var colors: PackedColorArray = PackedColorArray()
    var indices: PackedInt32Array = PackedInt32Array()
    var collision_heights: PackedFloat32Array = PackedFloat32Array()
    for z in range(width):
        for x in range(width):
            var sx: int = x * stride
            var sz: int = z * stride
            var value: Dictionary = _seam(source, tx, tz, sx, sz, lod, desired)
            if int(value.get("error", ERR_FILE_CORRUPT)) != OK:
                return {"error": int(value.get("error", ERR_FILE_CORRUPT))}
            var y: float = float(value["height"])
            vertices.append(Vector3(float(sx) * spacing, y, float(sz) * spacing))
            normals.append(Vector3.UP)
            uv.append(Vector2(float(tx * TILE_CELLS + sx), float(tz * TILE_CELLS + sz)) * spacing * 0.125)
            colors.append(Color.WHITE)
            if lod == 0:
                collision_heights.append(y / spacing)

    # Parity with TerraForgeTerrain._rebuild_tile(): use RENDERED heights,
    # centered across shared same-LOD borders. Never invent missing data.
    var cell_world: float = spacing * float(stride)
    var grass: Color = Color(0.27, 0.39, 0.22)
    var stone: Color = Color(0.48, 0.46, 0.41)
    var west_same: bool = int(desired.get(Vector2i(tx - 1, tz), -1)) == lod
    var east_same: bool = int(desired.get(Vector2i(tx + 1, tz), -1)) == lod
    var north_same: bool = int(desired.get(Vector2i(tx, tz - 1), -1)) == lod
    var south_same: bool = int(desired.get(Vector2i(tx, tz + 1), -1)) == lod
    for z in range(width):
        for x in range(width):
            var i: int = z * width + x
            var west: int = maxi(0, x - 1)
            var east: int = mini(width - 1, x + 1)
            var north: int = maxi(0, z - 1)
            var south: int = mini(width - 1, z + 1)
            var dx: float = (
                vertices[z * width + east].y - vertices[z * width + west].y
            ) / (float(east - west) * cell_world)
            var dz: float = (
                vertices[south * width + x].y - vertices[north * width + x].y
            ) / (float(south - north) * cell_world)
            var gx: int = tx * TILE_CELLS + x * stride
            var gz: int = tz * TILE_CELLS + z * stride
            var halo: Dictionary
            if x == 0 and west_same:
                halo = source.get_height(gx - stride, gz)
                if int(halo["error"]) != OK:
                    return {"error": int(halo["error"])}
                dx = (vertices[i + 1].y - float(halo["height"])) / (2.0 * cell_world)
            elif x == width - 1 and east_same:
                halo = source.get_height(gx + stride, gz)
                if int(halo["error"]) != OK:
                    return {"error": int(halo["error"])}
                dx = (float(halo["height"]) - vertices[i - 1].y) / (2.0 * cell_world)
            if z == 0 and north_same:
                halo = source.get_height(gx, gz - stride)
                if int(halo["error"]) != OK:
                    return {"error": int(halo["error"])}
                dz = (vertices[i + width].y - float(halo["height"])) / (2.0 * cell_world)
            elif z == width - 1 and south_same:
                halo = source.get_height(gx, gz + stride)
                if int(halo["error"]) != OK:
                    return {"error": int(halo["error"])}
                dz = (float(halo["height"]) - vertices[i - width].y) / (2.0 * cell_world)
            var normal: Vector3 = Vector3(-dx, 1.0, -dz).normalized()
            normals[i] = normal
            colors[i] = grass.lerp(stone, clampf((1.0 - normal.y) * 3.0, 0.0, 1.0))

    for z in range(width - 1):
        for x in range(width - 1):
            var a: int = z * width + x
            indices.append(a)
            indices.append(a + 1)
            indices.append(a + width)
            indices.append(a + 1)
            indices.append(a + width + 1)
            indices.append(a + width)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    return {
        "error": OK, "arrays": arrays,
        "collision_heights": collision_heights,
        "width": width, "vertex_count": vertices.size()
    }
