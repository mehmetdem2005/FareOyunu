extends RefCounted
# Offline conversion only. No old terrain renderer or worker.
const TFH = preload("res://addons/terra_forge/core/height_store.gd")
const MAN = preload("res://addons/terra_forge/core/region_manifest.gd")
const IDX = preload("res://addons/terra_forge/core/region_index_v2.gd")
const CODEC = preload("res://addons/terra_forge/core/region_page_codec.gd")
const V2 = preload("res://addons/terra_forge/core/region_read_v2.gd")
const REGION := 256
const LIMIT := 64
var cells := Vector2i.ZERO
var spacing := 0.25
var dims := Vector2i.ZERO
var heights := PackedFloat32Array()
var error_message := ""

func fail(message: String) -> Error:
	error_message = message
	return ERR_INVALID_DATA

func allocate() -> Error:
	if cells.x < 32 or cells.y < 32 or not is_finite(spacing) or spacing < 0.1 or spacing > 100.0:
		return fail("Boyut veya vertex spacing desteklenmiyor (0.1–100 m).")
	dims = Vector2i(ceili(float(cells.x + 1) / REGION) * REGION, ceili(float(cells.y + 1) / REGION) * REGION)
	if dims.x / REGION > 16 or dims.y / REGION > 16 or (dims.x / REGION) * (dims.y / REGION) > LIMIT:
		return fail("Dünya 64 Terrain3D bölge sınırını aşıyor; kesilmeyecek veya küçültülmeyecek.")
	heights.resize(dims.x * dims.y)
	return OK

func load_source(path: String) -> Error:
	if FileAccess.file_exists(path) and path.get_extension().to_lower() == "tfh":
		var store = TFH.new()
		if store.load_file(path) != OK:
			return fail("TFH okunamadı.")
		cells = store.cells
		spacing = store.spacing
		if allocate() != OK:
			return ERR_INVALID_DATA
		for z in range(cells.y + 1):
			for x in range(cells.x + 1):
				heights[z*dims.x+x] = store.heights[z*(cells.x+1)+x]
		return OK
	if FileAccess.file_exists(path):
		path = path.get_base_dir()
	if FileAccess.file_exists(path.path_join("manifest.tfm")):
		var manifest: Dictionary = MAN.load(path, false)
		if int(manifest.get("error", ERR_INVALID_DATA)) != OK:
			return fail("TFM1 manifest geçersiz.")
		var doc: Dictionary = manifest["document"]
		cells = Vector2i(int(doc["cells_x"]),int(doc["cells_z"]))
		spacing = float(doc["spacing"])
		if allocate() != OK:
			return ERR_INVALID_DATA
		for item in doc["pages"]:
			var key := Vector2i(int(item["x"]),int(item["z"]))
			var expected: PackedByteArray = str(item["sha256"]).hex_decode()
			var page: Dictionary = CODEC.load_page(path.path_join("r_%05d_%05d.tfr" % [key.x,key.y]),cells,spacing,key,expected,false)
			if int(page.get("error", ERR_INVALID_DATA)) != OK:
				return fail("TFM1 sayfa doğrulaması başarısız: " + str(key))
			copy_page(key,page["values"])
		return OK
	var loaded: Dictionary = V2.open_root(path)
	if int(loaded.get("error", ERR_INVALID_DATA)) != OK:
		return fail("TFH veya geçerli TFM1/TFM2 dünya klasörü bulunamadı.")
	var world = loaded["index"]
	cells = world.cells()
	spacing = world.spacing()
	if allocate() != OK:
		return ERR_INVALID_DATA
	var count: Vector2i = world.shard_count()
	for z in range(count.y):
		for x in range(count.x):
			var sk := Vector2i(x,z)
			var result: Dictionary = IDX.load_shard(path,world,sk)
			if int(result.get("error",ERR_INVALID_DATA)) != OK:
				return fail("TFM2 shard doğrulanamadı: " + str(sk))
			var shard = result["index"]
			var edge: Vector2i = shard.extent()
			for lz in range(edge.y):
				for lx in range(edge.x):
					var key := sk*16+Vector2i(lx,lz)
					var page: Dictionary = V2.read_from_shard(path,world,shard,key)
					if int(page.get("error",ERR_INVALID_DATA)) != OK:
						return fail("TFM2 sayfa doğrulanamadı: " + str(key))
					copy_page(key,page["values"])
	return OK

func copy_page(key: Vector2i, values: PackedFloat32Array) -> void:
	for z in range(32):
		var gz := key.y*32+z
		if gz > cells.y:
			break
		for x in range(32):
			var gx := key.x*32+x
			if gx > cells.x:
				break
			heights[gz*dims.x+gx] = values[z*32+x]

func demo() -> Error:
	cells = Vector2i(511,511)
	spacing = 0.25
	if allocate() != OK:
		return ERR_INVALID_DATA
	var noise := FastNoiseLite.new()
	noise.seed = 271126
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	for z in range(dims.y):
		for x in range(dims.x):
			var p := Vector2(float(x)/511.0,float(z)/511.0)
			var d := p.distance_to(Vector2(0.5,0.5))
			heights[z*dims.x+x] = 5.0 * noise.get_noise_2d(x,z) + 9.0 * maxf(0.0,1.0-d*2.0) - 2.0
	return OK

func height_image() -> Image:
	return Image.create_from_data(dims.x,dims.y,false,Image.FORMAT_RF,heights.to_byte_array())

func control_image() -> Image:
	# Terrain3D control map is a 32-bit bitfield: auto-shader bit 0, hole bit 2.
	# Preserve every original endpoint; padded samples are holes and cannot be walked on.
	var raw := PackedByteArray()
	raw.resize(dims.x*dims.y*4)
	for z in range(dims.y):
		for x in range(dims.x):
			raw.encode_u32((z*dims.x+x)*4,1 if x<=cells.x and z<=cells.y else 5)
	return Image.create_from_data(dims.x,dims.y,false,Image.FORMAT_RF,raw)
