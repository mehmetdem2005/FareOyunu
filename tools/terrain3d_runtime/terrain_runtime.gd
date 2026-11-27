extends Node3D
## One Terrain3D backend; no legacy tile pump, CPU mesh builder or custom LOD.
## Import is explicitly a setup operation, never part of a camera frame.
const REGION_SIZE := 256
const MAX_REGIONS := 64
var terrain: Node3D
var render_profile := "lean"
var region_size := REGION_SIZE
var startup_phases_us: Dictionary = {}
# Metadata only; stable coordinates, never native texture-layer IDs.
var _region_index: Dictionary = {}
var _surface_source_bytes := 0
var _memory_inventory: Dictionary = {}
var _verification_thread: Thread
var _prepared_index: Dictionary = {}
var _prepared_region_size := 0
var _prepared_spacing := 0.0
var startup_io: Dictionary = {}

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
					pixels = read_source_png(kind)
				if pixels == null or pixels.is_empty() or (baked and not pixels.has_mipmaps()):
					terrain.free()
					terrain = null
					return ERR_CANT_CREATE
				if not baked:
					pixels.generate_mipmaps()
				startup_phases_us[kind+"_image_load"] = Time.get_ticks_usec()-phase
				phase = Time.get_ticks_usec()
				_surface_source_bytes += pixels.get_data_size()
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

## JSON numbers may be floats; never silently truncate malformed coordinates.
static func _is_grid_integer(value: Variant, low: int, high: int) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return is_finite(number) and number >= low and number <= high and number == floorf(number)

## Pure metadata validation. Current format is a complete origin-zero square,
## not a sparse world or arbitrary signed-coordinate streaming format.
## Empty result means invalid. All descriptors and the map itself are read-only.
static func build_region_index(manifest: Dictionary, expected_size: int, expected_spacing: float) -> Dictionary:
	if expected_size not in [256,512] or not is_finite(expected_spacing) or expected_spacing <= 0.0:
		return {}
	if not _is_grid_integer(manifest.get("region_samples"),expected_size,expected_size):
		return {}
	if not _is_grid_integer(manifest.get("samples"),expected_size,expected_size*16):
		return {}
	var spacing: Variant = manifest.get("spacing_m")
	if not (spacing is int or spacing is float) or float(spacing) != expected_spacing:
		return {}
	var side := int(manifest["samples"])
	if side % expected_size != 0:
		return {}
	var width := int(side / expected_size)
	var entries: Variant = manifest.get("native_regions")
	if not entries is Array or entries.size() != width*width or entries.size() > MAX_REGIONS:
		return {}
	if not _is_grid_integer(manifest.get("regions"),entries.size(),entries.size()):
		return {}
	var index := {}
	for item: Variant in entries:
		if not item is Dictionary:
			return {}
		if not _is_grid_integer(item.get("x"),0,width-1) or not _is_grid_integer(item.get("z"),0,width-1):
			return {}
		var loc := Vector2i(int(item["x"]),int(item["z"]))
		if index.has(loc):
			return {}
		var filename := "terrain3d_%02d_%02d.res" % [loc.x,loc.y]
		var digest: Variant = item.get("sha256")
		if item.get("file") != filename or not digest is String:
			return {}
		if digest.length() != 64 or digest != digest.to_lower():
			return {}
		for digit: String in digest:
			if not "0123456789abcdef".contains(digit):
				return {}
		var descriptor := {"file":filename,"sha256":digest}
		descriptor.make_read_only()
		index[loc] = descriptor
	index.make_read_only()
	return index

## No native resource reference is exposed or retained by this metadata lookup.
func region_descriptor(location: Vector2i) -> Dictionary:
	var descriptor: Dictionary = _region_index.get(location,{})
	return descriptor

func indexed_region_count() -> int:
	return _region_index.size()

## Worker entry: immutable metadata and independent FileAccess calls only.
## No scene, ResourceLoader, native terrain, rendering or physics access here.
static func _verify_region_files(index: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	for loc: Vector2i in index:
		var descriptor: Dictionary = index[loc]
		var path := "res://world/native".path_join(str(descriptor["file"]))
		if not FileAccess.file_exists(path):
			return {"error":ERR_FILE_NOT_FOUND,"path":path}
		if FileAccess.get_sha256(path) != descriptor["sha256"]:
			return {"error":ERR_FILE_CORRUPT,"path":path}
	return {"error":OK,"worker_us":Time.get_ticks_usec()-started}

## Only while loading, before a native terrain exists. Single finite task.
## Join before publishing results; fall back to the original sync path if thread
## creation fails. There is no worker or poll loop in steady-state gameplay.
func prepare_baked_regions(manifest: Dictionary, expected_size: int, expected_spacing: float) -> Error:
	if terrain != null or _verification_thread != null or not _prepared_index.is_empty():
		return ERR_ALREADY_IN_USE
	var phase := Time.get_ticks_usec()
	var index := build_region_index(manifest,expected_size,expected_spacing)
	if index.is_empty():
		push_error("Invalid native region manifest index")
		return ERR_INVALID_DATA
	var result: Dictionary
	_verification_thread = Thread.new()
	var thread_error := _verification_thread.start(_verify_region_files.bind(index))
	if thread_error == OK:
		while _verification_thread != null and _verification_thread.is_alive():
			await get_tree().process_frame
			if not is_inside_tree():
				return ERR_UNAVAILABLE
		if _verification_thread == null:
			return ERR_UNAVAILABLE
		result = _verification_thread.wait_to_finish()
		_verification_thread = null
	else:
		_verification_thread = null
		result = _verify_region_files(index)
	var code: Error = result.get("error",FAILED)
	startup_phases_us["region_manifest_and_sha256"] = Time.get_ticks_usec()-phase
	startup_io = {"mode":"startup_thread" if thread_error == OK else "sync_fallback","verification_worker_us":int(result.get("worker_us",-1)),"regions":index.size()}
	if code != OK:
		push_error("Native region verification failed: " + str(result.get("path","")))
		return code
	_prepared_index = index
	_prepared_region_size = expected_size
	_prepared_spacing = expected_spacing
	return OK

func _exit_tree() -> void:
	# Thread is finite and does not call into the tree. Never free a live Thread.
	if _verification_thread != null:
		if _verification_thread.is_started():
			_verification_thread.wait_to_finish()
		_verification_thread = null

## Consume verified metadata exactly once on the main thread.
## Native load_region and the one batched map update remain main-thread only.
func load_baked_regions() -> Error:
	var phase := Time.get_ticks_usec()
	if terrain == null or _prepared_index.is_empty():
		return ERR_UNCONFIGURED
	var data: Object = terrain.get("data")
	if data == null or int(data.call("get_region_count")) != 0:
		return ERR_ALREADY_IN_USE
	if region_size != _prepared_region_size or float(terrain.get("vertex_spacing")) != _prepared_spacing:
		return ERR_INVALID_DATA
	var index := _prepared_index
	_prepared_index = {}
	var directory := "res://world/native"
	var height_bytes := 0
	var control_bytes := 0
	var active_color_bytes := 0
	var retained_color_bytes := 0
	# Preserve the manifest insertion order; native GPU IDs remain internal.
	for loc: Vector2i in index:
		data.call("load_region",loc,directory,false)
		var region: Object = data.call("get_region",loc)
		if region == null or int(region.call("get_region_size")) != region_size:
			push_error("Invalid native region: " + str(loc))
			return ERR_INVALID_DATA
		var heights: Image = region.call("get_height_map")
		if heights == null or heights.get_format() != Image.FORMAT_RF or heights.get_size() != Vector2i(region_size,region_size):
			return ERR_INVALID_DATA
		var control: Image = region.call("get_control_map")
		var color: Image = region.call("get_active_color_map")
		var uncompressed: Image = region.call("get_color_map")
		var compressed: Image = region.call("get_compressed_color_map")
		if control == null or control.is_empty() or color == null or color.is_empty():
			return ERR_INVALID_DATA
		# get_data_size does not allocate a duplicate pixel buffer.
		height_bytes += heights.get_data_size()
		control_bytes += control.get_data_size()
		active_color_bytes += color.get_data_size()
		if uncompressed != null:
			retained_color_bytes += uncompressed.get_data_size()
		if compressed != null and compressed != uncompressed:
			retained_color_bytes += compressed.get_data_size()
	startup_phases_us["region_decode_and_attach"] = Time.get_ticks_usec()-phase
	if int(terrain.call("get_region_size")) != region_size:
		return ERR_INVALID_DATA
	phase = Time.get_ticks_usec()
	# Default map_type TYPE_MAX: update all arrays in one batch.
	data.call("update_maps")
	startup_phases_us["native_map_update_submit"] = Time.get_ticks_usec()-phase
	if int(data.call("get_region_count")) != index.size():
		return ERR_INVALID_DATA
	if render_profile == "world":
		terrain.get("material").call("set_show_checkered",false)
	_region_index = index
	_memory_inventory = {
		"resident_regions":index.size(),
		"height_image_bytes":height_bytes,
		"control_image_bytes":control_bytes,
		"active_color_image_bytes":active_color_bytes,
		"retained_color_image_bytes":retained_color_bytes,
		"cpu_region_image_logical_bytes":height_bytes+control_bytes+retained_color_bytes,
		"gpu_region_array_source_logical_bytes":height_bytes+control_bytes+active_color_bytes,
		"surface_upload_source_bytes":_surface_source_bytes,
		"notes":"Logical image payload sums, not unique physical RAM or driver VRAM. Excludes allocator, staging, geometry, physics and other resources. Source RGB may expand on GPU."
	}
	_memory_inventory.make_read_only()
	return OK

func memory_inventory() -> Dictionary:
	return _memory_inventory

## Raw source only for offline baking / legacy non-baked profile.
## The Android playable path uses the verified precomputed Image resources.
static func read_source_png(kind: String) -> Image:
	var image := Image.new()
	var bytes := FileAccess.get_file_as_bytes("res://world/"+kind+".png")
	if bytes.is_empty() or image.load_png_from_buffer(bytes) != OK:
		return null
	return image
