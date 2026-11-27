extends Node3D
## One Terrain3D backend; no legacy tile pump, CPU mesh builder or custom LOD.
## Import is explicitly a setup operation, never part of a camera frame.
const REGION_SIZE := 256
const MAX_REGIONS := 64
var terrain: Node3D
var render_profile := "lean"
var region_size := REGION_SIZE
var startup_phases_us: Dictionary = {}

func initialize(camera: Camera3D, collision_target: Node3D, spacing: float, profile: String = "lean", region_samples: int = REGION_SIZE, baked: bool = false) -> Error:
	var phase := Time.get_ticks_usec()
	if profile not in ["reference", "lean", "lean_lod4", "world"]:
		return ERR_INVALID_PARAMETER
	render_profile = profile
	if region_samples not in [256,512]:
		return ERR_INVALID_PARAMETER
	region_size = region_samples
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
	terrain.set("vertex_spacing", spacing)
	terrain.set("mesh_size", 16)
	terrain.set("mesh_lods", 7 if profile == "world" else (4 if profile == "lean_lod4" else 5))
	terrain.set("tessellation_level", 0)
	# Fixture has no texture asset resource on disk.
	terrain.set("free_editor_textures", false)
	terrain.set("save_16_bit", false)
	terrain.set("cast_shadows", 0)
	terrain.set("gi_mode", 0)
	terrain.set("collision_mode", 1)
	terrain.set("collision_radius", 32)
	terrain.set("collision_shape_size", 16)
	if profile == "world":
		# Configure the resource before native initialization. Setters store settings
		# while uninitialized, and Terrain3D initializes the final shader on entry.
		var prepared := ClassDB.instantiate("Terrain3DMaterial") as Resource
		var world_shader := load("res://shaders/world_surface.gdshader") as Shader
		if prepared == null or world_shader == null:
			terrain.free()
			terrain = null
			return ERR_CANT_CREATE
		prepared.set("max_regions", MAX_REGIONS)
		prepared.set("world_background", 0)
		prepared.set("texture_filtering", 1)
		prepared.set("shader_override", world_shader)
		prepared.set("shader_override_enabled", true)
		terrain.set("material", prepared)
		startup_phases_us["material_preconfigure"] = Time.get_ticks_usec()-phase
		phase = Time.get_ticks_usec()
	add_child(terrain)
	startup_phases_us["native_node_init"] = Time.get_ticks_usec()-phase
	phase = Time.get_ticks_usec()
	# Native load_region sets the first region size itself. Avoid rebuilding empty maps.
	# Keep the explicit resize for raw snapshots and the offline baker.
	if not baked and int(terrain.call("get_region_size")) != region_size:
		terrain.call("change_region_size", region_size)
	if not baked and int(terrain.call("get_region_size")) != region_size:
		push_error("Native region size mismatch: requested %d, got %d" % [region_size, int(terrain.call("get_region_size"))])
		terrain.free()
		terrain = null
		return ERR_UNCONFIGURED
	startup_phases_us["empty_region_setup"] = Time.get_ticks_usec()-phase
	phase = Time.get_ticks_usec()
	terrain.set("clipmap_target", camera)
	terrain.set("collision_target", collision_target)
	var material: Object = terrain.get("material")
	if material == null:
		terrain.free()
		terrain = null
		return ERR_UNCONFIGURED
	if profile != "world":
		material.set("max_regions", MAX_REGIONS)
	if profile != "reference":
		if profile != "world":
			material.set("world_background", 0)
			material.set("texture_filtering", 1)
			var shader := load("res://shaders/terrain3d_lightweight.gdshader") as Shader
			if shader == null:
				terrain.free()
				terrain = null
				return ERR_CANT_CREATE
			material.call("set_show_checkered", false)
			material.set("shader_override", shader)
			material.set("shader_override_enabled", true)
		startup_phases_us["material_setup"] = Time.get_ticks_usec()-phase
		if profile == "world":
			material.call("set_shader_param", "textures_enabled", false)
			# Native empty-asset checker may be enabled during map updates.
			# Disable it once after the real maps are submitted, not before each update.
			for kind: String in ["soil","rock","sand","grass"]:
				phase = Time.get_ticks_usec()
				var pixels: Image
				if baked:
					pixels = ResourceLoader.load("res://world/"+kind+"_mips.res", "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image
				else:
					pixels = Image.load_from_file("res://world/"+kind+".png")
				if pixels == null or pixels.is_empty() or (baked and not pixels.has_mipmaps()):
					terrain.free()
					terrain = null
					return ERR_CANT_CREATE
				if not baked:
					pixels.generate_mipmaps()
				startup_phases_us[kind+"_image_load"] = Time.get_ticks_usec()-phase
				phase = Time.get_ticks_usec()
				var tex := ImageTexture.create_from_image(pixels)
				material.call("set_shader_param", kind+"_tex", tex)
				startup_phases_us[kind+"_texture_create_submit"] = Time.get_ticks_usec()-phase
		else:
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
	if int(terrain.call("get_region_size")) != region_size:
		push_error("Native region size changed before import")
		return ERR_UNCONFIGURED
	var w: int = image.get_width()
	var h: int = image.get_height()
	if w % region_size != 0 or h % region_size != 0:
		return ERR_INVALID_PARAMETER
	if (w / region_size) * (h / region_size) > MAX_REGIONS:
		return ERR_OUT_OF_MEMORY
	var region_world: float = region_size * float(terrain.get("vertex_spacing"))
	var rx: float = origin.x / region_world
	var rz: float = origin.z / region_world
	if not origin.is_finite() or origin.y != 0.0 or not is_equal_approx(rx, roundf(rx)) or not is_equal_approx(rz, roundf(rz)):
		return ERR_INVALID_PARAMETER
	if rx < -16 or rz < -16 or rx + float(w) / region_size > 16 or rz + float(h) / region_size > 16:
		return ERR_INVALID_PARAMETER
	for height in image.get_data().to_float32_array():
		if not is_finite(height):
			return ERR_INVALID_DATA
	if control != null and (control.get_format() != Image.FORMAT_RF or control.get_size() != image.get_size()):
		return ERR_INVALID_PARAMETER
	var maps: Array[Image] = [image, control, null]
	data.call("import_images", maps, origin, 0.0, 1.0)
	var expected_count := (w / region_size) * (h / region_size)
	var actual_count := int(data.call("get_region_count"))
	if actual_count != expected_count:
		push_error("Terrain3D import incomplete: expected %d regions, got %d; native region size %d" % [expected_count, actual_count, int(terrain.call("get_region_size"))])
		return ERR_INVALID_DATA
	if render_profile == "world":
		var material: Object = terrain.get("material")
		material.call("set_show_checkered", false)
	return OK

func surface_height(position: Vector3) -> float:
	if terrain == null:
		return NAN
	var data: Object = terrain.get("data")
	if data == null:
		return NAN
	return float(data.call("get_surface_height", position))

## Load pre-baked native regions once. Explicit filenames avoid Android directory enumeration.
## Verify all files before mutating native data; upload maps once after all regions are loaded.
func load_baked_regions(manifest: Dictionary) -> Error:
	var phase := Time.get_ticks_usec()
	if terrain == null:
		return ERR_UNCONFIGURED
	var data: Object = terrain.get("data")
	if data == null or int(data.call("get_region_count")) != 0:
		return ERR_ALREADY_IN_USE
	var entries: Array = manifest.get("native_regions", [])
	var side := int(manifest.get("samples",0))
	var width := int(side / region_size)
	if width <= 0 or side % region_size != 0 or entries.size() != width * width or entries.size() > MAX_REGIONS:
		return ERR_INVALID_DATA
	var directory := "res://world/native"
	var seen := {}
	for item in entries:
		if not item is Dictionary:
			return ERR_INVALID_DATA
		var x := int(item.get("x",-1))
		var z := int(item.get("z",-1))
		var loc := Vector2i(x,z)
		if x < 0 or z < 0 or x >= width or z >= width or seen.has(loc):
			return ERR_INVALID_DATA
		seen[loc] = true
		var filename := "terrain3d_%02d_%02d.res" % [x,z]
		var path := directory.path_join(filename)
		if str(item.get("file","")) != filename or not FileAccess.file_exists(path):
			push_error("Missing native region: " + path)
			return ERR_FILE_NOT_FOUND
		if FileAccess.get_sha256(path) != str(item.get("sha256","")):
			push_error("Native region checksum mismatch: " + path)
			return ERR_FILE_CORRUPT
	startup_phases_us["region_manifest_and_sha256"] = Time.get_ticks_usec()-phase
	phase = Time.get_ticks_usec()
	for item in entries:
		var loc := Vector2i(int(item["x"]),int(item["z"]))
		data.call("load_region",loc,directory,false)
		var region: Object = data.call("get_region",loc)
		if region == null or int(region.call("get_region_size")) != region_size:
			push_error("Invalid native region: " + str(loc))
			return ERR_INVALID_DATA
		var heights: Image = region.call("get_height_map")
		if heights == null or heights.get_format() != Image.FORMAT_RF or heights.get_size() != Vector2i(region_size,region_size):
			return ERR_INVALID_DATA
	startup_phases_us["region_decode_and_attach"] = Time.get_ticks_usec()-phase
	if int(terrain.call("get_region_size")) != region_size:
		return ERR_INVALID_DATA
	phase = Time.get_ticks_usec()
	# Default map_type TYPE_MAX: update all arrays in one batch.
	data.call("update_maps")
	startup_phases_us["native_map_update_submit"] = Time.get_ticks_usec()-phase
	if int(data.call("get_region_count")) != entries.size():
		return ERR_INVALID_DATA
	if render_profile == "world":
		terrain.get("material").call("set_show_checkered",false)
	return OK
