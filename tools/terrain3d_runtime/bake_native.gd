extends Node3D
const Runtime = preload("res://terrain_runtime.gd")

func fail(message: String) -> void:
	push_error("NATIVE_BAKE_FAIL: " + message)
	get_tree().quit(1)

func _ready() -> void:
	var started := Time.get_ticks_msec()
	var path := "res://world/height.r32"
	var file := FileAccess.open("res://world/world.json",FileAccess.READ)
	if file == null:
		fail("manifest absent")
		return
	var doc: Variant = JSON.parse_string(file.get_as_text())
	if not doc is Dictionary or int(doc.get("samples",0)) != 4096 or int(doc.get("region_samples",0)) != 512:
		fail("manifest invalid")
		return
	if FileAccess.get_sha256(path) != str(doc.get("sha256","")):
		fail("source checksum mismatch")
		return
	var raw := FileAccess.get_file_as_bytes(path)
	if raw.size() != 4096*4096*4:
		fail("wrong byte count")
		return
	var image := Image.create_from_data(4096,4096,false,Image.FORMAT_RF,raw)
	raw = PackedByteArray()
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(512,20,512)
	camera.current = true
	var target := Node3D.new()
	add_child(target)
	target.position = camera.position
	var runtime := Runtime.new()
	add_child(runtime)
	# Bake uses the same native importer, region size and spacing as the working V2.
	var result := runtime.initialize(camera,target,0.25,"lean",512)
	if result == OK:
		result = runtime.import_height_snapshot(image)
	if result != OK:
		fail("import " + str(result))
		return
	var directory := "res://world/native"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		fail("mkdir")
		return
	var data: Object = runtime.terrain.get("data")
	data.call("save_directory",directory)
	var entries: Array[Dictionary] = []
	for z in range(8):
		for x in range(8):
			var filename := "terrain3d_%02d_%02d.res" % [x,z]
			var region_path := directory.path_join(filename)
			var resource := ResourceLoader.load(region_path,"Terrain3DRegion",ResourceLoader.CACHE_MODE_IGNORE)
			if resource == null or int(resource.call("get_region_size")) != 512:
				fail("region missing/invalid " + filename)
				return
			var h: Image = resource.call("get_height_map")
			if h == null or h.get_format() != Image.FORMAT_RF or h.get_size() != Vector2i(512,512):
				fail("invalid height format " + filename)
				return
			var source := image.get_region(Rect2i(x*512,z*512,512,512))
			# Bit-exact every Float32 sample after serialization; no half-float loss.
			if h.get_data() != source.get_data():
				fail("height bytes changed " + filename)
				return
			entries.append({"x":x,"z":z,"file":filename,"sha256":FileAccess.get_sha256(region_path)})
	# Precompute identical Godot mip chains offline. Keep original pixels and format.
	# Uncompressed Image resources: avoid PNG decode and mip generation on the phone.
	for kind in ["soil","rock","sand","grass"]:
		var pixels := Image.load_from_file("res://world/"+kind+".png")
		if pixels == null or pixels.is_empty() or pixels.generate_mipmaps() != OK:
			fail("surface mip generation "+kind)
			return
		var texture_path := "res://world/"+kind+"_mips.res"
		if ResourceSaver.save(pixels,texture_path) != OK:
			fail("surface save "+kind)
			return
		var saved := ResourceLoader.load(texture_path,"Image",ResourceLoader.CACHE_MODE_IGNORE) as Image
		if saved == null or saved.get_format() != pixels.get_format() or saved.get_size() != pixels.get_size() or not saved.has_mipmaps() or saved.get_data() != pixels.get_data():
			fail("surface mip bytes changed "+kind)
			return
	print("NATIVE_SURFACE_MIPS_OK count=4")
	doc["surface_mips"] = "godot_image_res_lossless"
	doc["native_regions"] = entries
	doc["storage"] = "terrain3d_native_res_float32_v1"
	doc["native_bake_ms"] = Time.get_ticks_msec()-started
	var output := FileAccess.open("res://world/world.json",FileAccess.WRITE)
	if output == null:
		fail("manifest write")
		return
	output.store_string(JSON.stringify(doc,"\t"))
	output.close()
	print("NATIVE_BAKE_OK regions=",entries.size()," exact_height_samples=",4096*4096," elapsed_ms=",doc["native_bake_ms"])
	get_tree().quit(0)
