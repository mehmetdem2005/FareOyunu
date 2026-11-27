extends SceneTree

const PATCH := preload("res://patch.gd")
const FIXTURE := preload("res://addons/terra_forge/core/region_fixture_v2.gd")

func _initialize() -> void:
    var size := PATCH.TILE * PATCH.SIDE + 3
    var img := Image.create_empty(size, size, false, Image.FORMAT_RF)
    for z in range(size):
        for x in range(size):
            var y := FIXTURE.sample(x + PATCH.FIRST - 1, z + PATCH.FIRST - 1)
            img.set_pixel(x, z, Color(y, 0, 0))
    if ResourceSaver.save(ImageTexture.create_from_image(img), "res://baked/height.res") != OK:
        quit(1)
        return
    for tz in range(PATCH.SIDE):
        for tx in range(PATCH.SIDE):
            if _mesh(tx, tz, false) != OK:
                quit(1)
                return
    quit(0 if _mesh(0, 0, true) == OK else 1)

func _mesh(tx: int, tz: int, flat: bool) -> Error:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    var width := PATCH.TILE + 1
    for z in range(width):
        for x in range(width):
            var gx := PATCH.FIRST + tx * PATCH.TILE + x
            var gz := PATCH.FIRST + tz * PATCH.TILE + z
            var dx := FIXTURE.sample(gx + 1, gz) - FIXTURE.sample(gx - 1, gz)
            var dz := FIXTURE.sample(gx, gz + 1) - FIXTURE.sample(gx, gz - 1)
            vertices.append(Vector3(x, 0.0 if flat else FIXTURE.sample(gx, gz), z))
            normals.append(Vector3.UP if flat else Vector3(-dx * 0.5, 1, -dz * 0.5).normalized())
            if x < PATCH.TILE and z < PATCH.TILE:
                var a := z * width + x
                indices.append_array(PackedInt32Array([a,a+1,a+width,a+1,a+width+1,a+width]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return ResourceSaver.save(mesh, "res://baked/grid.res" if flat else "res://baked/tile_%d_%d.res" % [tx,tz], ResourceSaver.FLAG_COMPRESS)
