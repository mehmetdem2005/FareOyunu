extends Node3D
## One Terrain3D backend; no legacy tile pump, CPU mesh builder or custom LOD.
## Import is explicitly a setup operation, never part of a camera frame.
const REGION_SIZE := 256
const MAX_REGIONS := 64
var terrain: Node3D
var render_profile := "lean"

func initialize(camera: Camera3D, collision_target: Node3D, spacing: float, profile: String = "lean") -> Error:
	if profile not in ["reference", "lean", "lean_lod4"]:
		return ERR_INVALID_PARAMETER
	render_profile = profile
	if terrain != null or not is_instance_valid(camera) or not is_instance_valid(collision_target):
		return ERR_INVALID_PARAMETER
	if not is_finite(spacing) or spacing < 0.1 or spacing > 100.0:
		return ERR_INVALID_PARAMETER
	if not ClassDB.class_exists("Terrain3D") or not ClassDB.can_instantiate("Terrain3D"):
		push_error("Terrain3D 1.1.0 native extension missing; no fallback terrain")
		return ERR_UNAVAILABLE
	terrain = ClassDB.instantiate("Terrain3D") as Node3D
	if terrain == null:
		return ERR_CANT_CREATE
	terrain.name = "Terrain3D"
	terrain.set("region_size", REGION_SIZE)
	terrain.set("vertex_spacing", spacing)
	terrain.set("mesh_size", 16)
	terrain.set("mesh_lods", 4 if profile == "lean_lod4" else 5)
	terrain.set("tessellation_level", 0)
	# Fixture has no texture asset resource on disk.
	terrain.set("free_editor_textures", false)
	terrain.set("save_16_bit", false)
	terrain.set("cast_shadows", 0)
	terrain.set("gi_mode", 0)
	terrain.set("collision_mode", 1)
	terrain.set("collision_radius", 32)
	terrain.set("collision_shape_size", 16)
	add_child(terrain)
	terrain.set("clipmap_target", camera)
	terrain.set("collision_target", collision_target)
	var material: Object = terrain.get("material")
	if material == null:
		terrain.free()
		terrain = null
		return ERR_UNCONFIGURED
	material.set("max_regions", MAX_REGIONS)
	if profile != "reference":
		material.set("world_background", 0)
		material.set("texture_filtering", 1)
		var shader := load("res://shaders/terrain3d_lightweight.gdshader") as Shader
		if shader == null:
			terrain.free()
			terrain = null
			return ERR_CANT_CREATE
		material.set("shader_override", shader)
		material.set("shader_override_enabled", true)
		material.call("set_shader_param", "textures_enabled", false)
		material.call("set_shader_param", "macro_variation_enabled", false)
	return OK

## Input is already in world height units. No normalization or 8-bit conversion.
## Restrict to complete region-aligned rectangles; other inputs are rejected.
## This initial adapter imports a single snapshot into a fresh runtime only.
func import_height_snapshot(image: Image, origin: Vector3 = Vector3.ZERO, control: Image = null) -> Error:
	if terrain == null or image == null or image.is_empty() or image.get_format() != Image.FORMAT_RF:
		return ERR_INVALID_PARAMETER
	var data: Object = terrain.get("data")
	if data == null or int(data.call("get_region_count")) != 0:
		return ERR_ALREADY_IN_USE
	var w: int = image.get_width()
	var h: int = image.get_height()
	if w % REGION_SIZE != 0 or h % REGION_SIZE != 0:
		return ERR_INVALID_PARAMETER
	if (w / REGION_SIZE) * (h / REGION_SIZE) > MAX_REGIONS:
		return ERR_OUT_OF_MEMORY
	var region_world: float = REGION_SIZE * float(terrain.get("vertex_spacing"))
	var rx: float = origin.x / region_world
	var rz: float = origin.z / region_world
	if not origin.is_finite() or origin.y != 0.0 or not is_equal_approx(rx, roundf(rx)) or not is_equal_approx(rz, roundf(rz)):
		return ERR_INVALID_PARAMETER
	if rx < -16 or rz < -16 or rx + float(w) / REGION_SIZE > 16 or rz + float(h) / REGION_SIZE > 16:
		return ERR_INVALID_PARAMETER
	for height in image.get_data().to_float32_array():
		if not is_finite(height):
			return ERR_INVALID_DATA
	if control != null and (control.get_format() != Image.FORMAT_RF or control.get_size() != image.get_size()):
		return ERR_INVALID_PARAMETER
	var maps: Array[Image] = [image, control, null]
	data.call("import_images", maps, origin, 0.0, 1.0)
	if int(data.call("get_region_count")) != (w / REGION_SIZE) * (h / REGION_SIZE):
		return ERR_INVALID_DATA
	return OK

func surface_height(position: Vector3) -> float:
	if terrain == null:
		return NAN
	var data: Object = terrain.get("data")
	if data == null:
		return NAN
	return float(data.call("get_surface_height", position))
