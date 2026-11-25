@tool
extends RefCounted
## Read-only terrain geometry builder. Identical height/LOD/normal/collision
## conventions to the legacy TerraForgeTerrain mesh, but NO full-world array.
## All reads are nonblocking from async_region_source.gd's resident cache.
const DENSE = preload("res://addons/terra_forge/core/tile_dense_buffer.gd")
const LOD_POLICY = preload("res://addons/terra_forge/core/lod_policy.gd")
const PAGE_WIDTH: int = 32
const TILE_CELLS: int = 32

static func normal_halo(key: Vector2i, lod: int, desired: Dictionary) -> int:
    var mask := 0
    const DIRECTIONS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
    for edge in range(DIRECTIONS.size()):
        if desired.get(key + DIRECTIONS[edge], -1) == lod:
            mask |= 1 << edge
    return mask

static func required_pages(source, tx: int, tz: int, lod: int, halo_mask: int = DENSE.FULL_HALO) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    if source == null or not source.is_open() or lod < 0 or lod > 2:
        return result
    var stride: int = LOD_POLICY.sample_stride(lod)
    var bounds := DENSE.sample_bounds(source.cells, Vector2i(tx, tz), stride, halo_mask)
    var first := bounds.position / PAGE_WIDTH
    var last := (bounds.end - Vector2i.ONE) / PAGE_WIDTH
    for pz in range(first.y, last.y + 1):
        for px in range(first.x, last.x + 1):
            result.append(Vector2i(px, pz))
    return result

static func _seam(source, tx: int, tz: int, x: int, z: int, lod: int,
        desired: Dictionary) -> Dictionary:
    var gx: int = tx * TILE_CELLS + x
    var gz: int = tz * TILE_CELLS + z
    var sample: Dictionary = source.get_height(gx, gz)
    if int(sample.get("error", ERR_FILE_CORRUPT)) != OK:
        return sample
    if x > 0 and x < TILE_CELLS and z > 0 and z < TILE_CELLS:
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

static func _seam_scalar(source, tx: int, tz: int, x: int, z: int, lod: int,
        desired: Dictionary) -> float:
    var gx: int = tx * TILE_CELLS + x
    var gz: int = tz * TILE_CELLS + z
    var sample: float = source.read_finite_or_nan(gx, gz)
    if not is_finite(sample):
        return NAN
    if x > 0 and x < TILE_CELLS and z > 0 and z < TILE_CELLS:
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
    var first: float
    var last: float
    if horizontal:
        first = source.read_finite_or_nan(tx * TILE_CELLS + start_along, gz)
        last = source.read_finite_or_nan(tx * TILE_CELLS + end_along, gz)
    else:
        first = source.read_finite_or_nan(gx, tz * TILE_CELLS + start_along)
        last = source.read_finite_or_nan(gx, tz * TILE_CELLS + end_along)
    if not is_finite(first) or not is_finite(last):
        return NAN
    return lerpf(first, last, float(along - start_along) / float(end_along - start_along))

## Experimental D: same B lease, scalar reads only inside geometry.
## All required pages were validated before entry. Invalid scalar reads
## fail closed; no NAN or fallback height may reach geometry arrays.
static func generate_with_scalar_view(source, tx: int, tz: int, lod: int, desired: Dictionary) -> Dictionary:
    if source == null or not source.is_open() or lod < 0 or lod > 2 or tx < 0 or tz < 0 or (tx+1)*TILE_CELLS > source.cells.x or (tz+1)*TILE_CELLS > source.cells.y:
        return {"error":ERR_INVALID_PARAMETER}
    var acquired: Dictionary = source.acquire_tile_view(required_pages(source,tx,tz,lod))
    if acquired["error"] != OK:
        return acquired
    var view = acquired["view"]
    var result: Dictionary = _generate(view,tx,tz,lod,desired,true)
    var released: Error = source.release_tile_view(view)
    if released != OK:
        return {"error":released}
    return result

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

## Experimental benchmark-only C. Copy cost is inside the measured call.
static func generate_with_dense(source, tx: int, tz: int, lod: int, desired: Dictionary) -> Dictionary:
    if source == null or not source.is_open() or lod < 0 or lod > 2 or tx < 0 or tz < 0 or (tx+1)*TILE_CELLS > source.cells.x or (tz+1)*TILE_CELLS > source.cells.y:
        return {"error":ERR_INVALID_PARAMETER}
    var acquired: Dictionary = source.acquire_tile_view(required_pages(source,tx,tz,lod))
    if acquired["error"] != OK:
        return acquired
    var view = acquired["view"]
    var copied: Dictionary = DENSE.build(view,tx,tz,LOD_POLICY.sample_stride(lod))
    var released: Error = source.release_tile_view(view)
    if released != OK:
        return {"error":released}
    if copied["error"] != OK:
        return copied
    var buffer = copied["buffer"]
    var result: Dictionary = generate(buffer,tx,tz,lod,desired)
    result["dense_payload_bytes"] = buffer.payload_bytes()
    return result

## Worker-owned dense buffer, no reader or lease involved.
static func generate_owned_dense_scalar(buffer,tx: int,tz: int,lod: int,desired: Dictionary,topology=null) -> Dictionary:
    return _generate(buffer,tx,tz,lod,desired,true,topology)

static func generate(source, tx: int, tz: int, lod: int, desired: Dictionary) -> Dictionary:
    return _generate(source,tx,tz,lod,desired,false)

static func _generate(source, tx: int, tz: int, lod: int, desired: Dictionary, scalar: bool,topology=null) -> Dictionary:
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
    normals.resize(width * width)
    colors.resize(width * width)
    for z in range(width):
        for x in range(width):
            var sx: int = x * stride
            var sz: int = z * stride
            var y: float
            if scalar:
                y = _seam_scalar(source,tx,tz,sx,sz,lod,desired)
                if not is_finite(y):
                    return {"error":ERR_FILE_CORRUPT}
            else:
                var value: Dictionary = _seam(source, tx, tz, sx, sz, lod, desired)
                if int(value.get("error", ERR_FILE_CORRUPT)) != OK:
                    return {"error": int(value.get("error", ERR_FILE_CORRUPT))}
                y = float(value["height"])
            vertices.append(Vector3(float(sx) * spacing, y, float(sz) * spacing))
            uv.append(Vector2(float(tx * TILE_CELLS + sx), float(tz * TILE_CELLS + sz)) * spacing * 0.125)
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
            var halo_value: float
            if x == 0 and west_same:
                if scalar:
                    halo_value = source.read_finite_or_nan(gx - stride, gz)
                    if not is_finite(halo_value):
                        return {"error":ERR_FILE_CORRUPT}
                else:
                    halo = source.get_height(gx - stride, gz)
                    if int(halo["error"]) != OK:
                        return {"error": int(halo["error"])}
                    halo_value = float(halo["height"])
                dx = (vertices[i + 1].y - halo_value) / (2.0 * cell_world)
            elif x == width - 1 and east_same:
                if scalar:
                    halo_value = source.read_finite_or_nan(gx + stride, gz)
                    if not is_finite(halo_value):
                        return {"error":ERR_FILE_CORRUPT}
                else:
                    halo = source.get_height(gx + stride, gz)
                    if int(halo["error"]) != OK:
                        return {"error": int(halo["error"])}
                    halo_value = float(halo["height"])
                dx = (halo_value - vertices[i - 1].y) / (2.0 * cell_world)
            if z == 0 and north_same:
                if scalar:
                    halo_value = source.read_finite_or_nan(gx, gz - stride)
                    if not is_finite(halo_value):
                        return {"error":ERR_FILE_CORRUPT}
                else:
                    halo = source.get_height(gx, gz - stride)
                    if int(halo["error"]) != OK:
                        return {"error": int(halo["error"])}
                    halo_value = float(halo["height"])
                dz = (vertices[i + width].y - halo_value) / (2.0 * cell_world)
            elif z == width - 1 and south_same:
                if scalar:
                    halo_value = source.read_finite_or_nan(gx, gz + stride)
                    if not is_finite(halo_value):
                        return {"error":ERR_FILE_CORRUPT}
                else:
                    halo = source.get_height(gx, gz + stride)
                    if int(halo["error"]) != OK:
                        return {"error": int(halo["error"])}
                    halo_value = float(halo["height"])
                dz = (halo_value - vertices[i - width].y) / (2.0 * cell_world)
            var normal: Vector3 = Vector3(-dx, 1.0, -dz).normalized()
            normals[i] = normal
            colors[i] = grass.lerp(stone, clampf((1.0 - normal.y) * 3.0, 0.0, 1.0))

    if topology!=null:
        indices=topology.copy_indices(lod)
        if indices.size()!=(width-1)*(width-1)*6:
            return {"error":ERR_INVALID_DATA}
    else:
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
