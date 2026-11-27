extends Node3D
## Two render-only prototypes over the same fixed patch. No clipmap LOD rings.
const FIRST := 416
const TILE := 32
const SIDE := 6
const SHADER := preload("res://patch.gdshader")

func construct(displace: bool) -> Error:
    var mat := ShaderMaterial.new()
    mat.shader = SHADER
    mat.set_shader_parameter("displace", displace)
    mat.set_shader_parameter("atlas_first", Vector2(FIRST - 1, FIRST - 1))
    var atlas := load("res://baked/height.res") as Texture2D
    if atlas == null:
        return ERR_FILE_NOT_FOUND
    mat.set_shader_parameter("heights", atlas)
    var grid := load("res://baked/grid.res") as ArrayMesh
    for tz in range(SIDE):
        for tx in range(SIDE):
            var item := MeshInstance3D.new()
            item.mesh = grid if displace else load("res://baked/tile_%d_%d.res" % [tx, tz]) as ArrayMesh
            if item.mesh == null:
                item.free()
                return ERR_FILE_NOT_FOUND
            item.material_override = mat
            item.custom_aabb = AABB(Vector3.ZERO, Vector3(TILE, 32, TILE))
            item.position = Vector3(FIRST + tx * TILE, 0, FIRST + tz * TILE)
            add_child(item)
    return OK
