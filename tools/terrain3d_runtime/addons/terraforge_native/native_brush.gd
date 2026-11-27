@tool
extends RefCounted
## Native RF maps are authoritative; no legacy terrain copy or mesh worker.
const Landform = preload("res://addons/terraforge_native/native_landform.gd")
const Weather = preload("res://addons/terraforge_native/native_weather.gd")
const WeatherWorker = preload("res://addons/terraforge_native/native_weather_worker.gd")
var _weather_worker := WeatherWorker.new()
var _weather_snapshot: Dictionary = {}
var last_weather_capture_us := 0
var last_weather_worker_us := 0
var last_weather_commit_us := 0
const MAX_DAB_CELLS := 85000 # 36m at .25m: at most 290x290 candidate cells
const MAX_STROKE_CELLS := 131072
const HISTORY_LIMIT := 8
const HISTORY_CELL_LIMIT := 262144
var terrain: Node3D
var before: Dictionary = {}
var after: Dictionary = {}
var history: Array[Dictionary] = []
var redo_history: Array[Dictionary] = []
var last_hit := Vector2(INF,INF)
var flatten_height := NAN
var last_changed_cells := 0
var last_weather_mass_error := 0.0
var last_weather_moved := 0.0
var region_error := ""
var last_snapshot_path := ""
var last_snapshot_hashes: Dictionary = {}
var last_dab_ms := -100000
var last_dab_duration_ms := 0
var last_plan_us := 0
var last_write_us := 0
var last_write_profile: Dictionary = {}
var last_filter_half_width_m := 0.0

func attach(node: Node3D) -> void:
	cancel_weather()
	terrain = node
	last_snapshot_path = ""
	last_snapshot_hashes.clear()
	before.clear()
	after.clear()
	history.clear()
	redo_history.clear()

# Resolve live native resources through the native active-region list. The
# engine, not a GDScript Image copy, owns the height map and its grid size.
func _regions() -> Dictionary:
	region_error = ""
	var result := {}
	if not is_instance_valid(terrain):
		region_error = "No native terrain attached."
		return result
	var data: Object = terrain.get("data")
	if data == null:
		region_error = "Native data object missing."
		return result
	var count := int(data.call("get_region_count"))
	if count < 1 or count > 64:
		region_error = "Native region count %d outside 1..64." % count
		return result
	var active: Array = data.call("get_regions_active",false,false)
	if active.size()!=count:
		region_error = "Native active list %d != count %d." % [active.size(),count]
		return {}
	var size := int(terrain.call("get_region_size"))
	for reg in active:
		if not is_instance_valid(reg) or not reg.has_method("get_location"):
			region_error = "Native active region resource missing."
			return {}
		var loc: Vector2i = reg.call("get_location")
		if result.has(loc):
			region_error = "Duplicate native location %s." % str(loc)
			return {}
		var img: Image = reg.call("get_height_map")
		var control: Image = reg.call("get_control_map")
		if img == null or img.get_format()!=Image.FORMAT_RF or img.get_size()!=Vector2i(size,size) or control==null or control.get_format()!=Image.FORMAT_RF or control.get_size()!=Vector2i(size,size):
			region_error = "RF source invalid at %s; do not edit converted data." % str(loc)
			return {}
		result[loc]={"region":reg,"image":img}
	return result

func _loc(p: Vector2i, size: int) -> Vector2i:
	return Vector2i(floori(float(p.x)/size),floori(float(p.y)/size))

func _world(p: Vector2i, spacing: float) -> Vector3:
	return Vector3(p.x*spacing,0,p.y*spacing)

func _sample(regions: Dictionary, p: Vector2i, size: int, spacing: float, data: Object) -> float:
	var loc := _loc(p,size)
	if not regions.has(loc):
		return NAN
	var pos := _world(p,spacing)
	if bool(data.call("get_control_hole",pos)):
		return NAN
	var img: Image = regions[loc]["image"]
	return img.get_pixelv(p-loc*size).r

func begin() -> void:
	before = {}
	after = {}
	last_hit = Vector2(INF,INF)
	flatten_height = NAN
	last_dab_ms = -100000
	last_dab_duration_ms = 0

func dab(hit: Vector3, tool: int, radius: float, power: float, scheduled: bool = false) -> String:
	last_changed_cells = 0
	if tool<0 or tool>3 or not hit.is_finite() or not is_finite(radius) or radius<=0 or not is_finite(power):
		return "Unsupported native brush."
	var regions := _regions()
	if regions.is_empty():
		return region_error
	var size := int(terrain.call("get_region_size"))
	var spacing := float(terrain.get("vertex_spacing"))
	var data: Object = terrain.get("data")
	if size <= 0 or not is_finite(spacing) or spacing <= 0.0:
		return "Native grid invalid: %d / %.3f." % [size,spacing]
	var center := Vector2(hit.x,hit.z)
	if not scheduled and last_hit.is_finite() and center.distance_to(last_hit)<maxf(spacing,radius*0.2):
		return ""
	var grid := center/spacing
	var r := radius/spacing
	var low := Vector2i(floori(grid.x-r),floori(grid.y-r))
	var high := Vector2i(ceili(grid.x+r),ceili(grid.y+r))
	var cells := (high.x-low.x+1)*(high.y-low.y+1)
	if cells>MAX_DAB_CELLS:
		return "Brush footprint exceeds grid budget; reduce radius for this spacing."
	# No queued backlog. Large dabs are spaced by measured previous cost;
	# the first dab always runs, and full-resolution footprint is preserved.
	var now := Time.get_ticks_msec()
	if not scheduled and cells>16384 and now-last_dab_ms<maxi(75,last_dab_duration_ms*2):
		return ""
	var started := now
	# Only Flatten needs a fixed target. Other tools may have a valid footprint
	# even when the nearest grid vertex is outside a region or a hole.
	if tool == 3 and not is_finite(flatten_height):
		flatten_height = _sample(regions,Vector2i(roundi(grid.x),roundi(grid.y)),size,spacing,data)
		if not is_finite(flatten_height):
			return "Flatten target is outside editable terrain."
	if not data.has_method("tf_plan_brush") or not data.has_method("tf_write_brush"):
		return "Native batch extension missing; install matching package."
	var plan_started := Time.get_ticks_usec()
	var planned: Dictionary = data.call("tf_plan_brush",center,tool,radius,power,flatten_height)
	last_plan_us=Time.get_ticks_usec()-plan_started
	last_filter_half_width_m=float(planned.get("filter_half_width_m",0.0))
	if not str(planned["error"]).is_empty():
		return str(planned["error"])
	var changes: Dictionary = planned["changes"]
	var originals: Dictionary = planned["originals"]
	# Original heights belong to the earliest dab of the current undo segment.
	var already := 0
	for key in originals:
		if before.has(key):
			already+=1
	if before.size()+originals.size()-already>MAX_STROKE_CELLS:
		_commit_segment()
	if not changes.is_empty():
		var write_error := _write(regions,changes,size,true)
		if not write_error.is_empty():
			return write_error
		before.merge(originals,false)
	last_dab_ms = Time.get_ticks_msec()
	last_dab_duration_ms = last_dab_ms-started
	last_hit = center
	if changes.is_empty() and tool == 0:
		return "Raise: no editable samples at %.2f, %.2f (grid %d / %.2fm)." % [hit.x,hit.z,size,spacing]
	return ""

# One complete corridor transaction; no repeated dab accumulation.
func apply_corridor(points: Array[Vector2], tool: int, radius: float, power: float) -> String:
	last_changed_cells=0
	if tool not in [4,5] or not is_finite(power) or power<=0.0 or power>12.0:
		return "Invalid corridor tool or power."
	var regions := _regions()
	if regions.is_empty():
		return region_error
	var size := int(terrain.call("get_region_size"))
	var spacing := float(terrain.get("vertex_spacing"))
	var data: Object=terrain.get("data")
	var result := Landform.build(points,radius,spacing,tool==5)
	if not str(result["error"]).is_empty():
		return str(result["error"])
	var changes := {}
	var originals := {}
	var amplitude := power*0.42*(-1.0 if tool==5 else 1.0)
	for key: Vector2i in result["weights"]:
		var old := _sample(regions,key,size,spacing,data)
		if not is_finite(old):
			continue
		var value := old+amplitude*float(result["weights"][key])
		if not is_finite(value) or absf(value)>1000000.0:
			return "Corridor height out of bounds; no changes made."
		if value!=old:
			originals[key]=old
			changes[key]=value
	if changes.is_empty():
		return "Corridor has no editable samples."
	# The kernel caps the whole action to the existing history segment budget.
	begin()
	before=originals
	var error := _write(regions,changes,size,true)
	end()
	return error

# One bounded local process, committed only after the entire result is valid.
func _capture_weather(center: Vector2, radius: float, power: float, mode: int) -> Dictionary:
	last_changed_cells=0
	last_weather_mass_error=0.0
	last_weather_moved=0.0
	if not center.is_finite() or absf(center.x)>10000000.0 or absf(center.y)>10000000.0 or not is_finite(radius) or radius<1.0 or radius>36.0:
		return {"error":"Invalid Weather center or size."}
	var regions := _regions()
	if regions.is_empty():
		return {"error":region_error}
	var size := int(terrain.call("get_region_size"))
	var spacing := float(terrain.get("vertex_spacing"))
	var data: Object=terrain.get("data")
	if size<=0 or not is_finite(spacing) or spacing<0.25:
		return {"error":"Invalid Weather grid."}
	var grid := center/spacing
	var r := radius/spacing
	var low := Vector2i(floori(grid.x-r),floori(grid.y-r))
	var high := Vector2i(ceili(grid.x+r),ceili(grid.y+r))
	var dim := high-low+Vector2i.ONE
	var count := dim.x*dim.y
	if count>MAX_DAB_CELLS:
		return {"error":"Weather footprint exceeds grid budget."}
	var source := PackedFloat64Array()
	var weights := PackedFloat32Array()
	source.resize(count)
	weights.resize(count)
	for z in range(dim.y):
		for x in range(dim.x):
			var key := low+Vector2i(x,z)
			var distance := Vector2(key).distance_to(grid)/r
			if distance>=1.0:
				continue
			var old := _sample(regions,key,size,spacing,data)
			if not is_finite(old):
				continue
			var i := z*dim.x+x
			source[i]=old
			weights[i]=smoothstep(0.0,0.24,1.0-distance)
	return {"error":"","source":source,"weights":weights,"dim":dim,"low":low,"size":size,"spacing":spacing,"data_id":data.get_instance_id(),"terrain_id":terrain.get_instance_id(),"center":center,"radius":radius,"power":power,"mode":mode}

func weather_busy() -> bool:
	return _weather_worker.busy()

func start_weather(center: Vector2, radius: float, power: float, mode: int) -> String:
	if weather_busy():
		return "Aşındırma zaten hesaplanıyor."
	var started := Time.get_ticks_usec()
	var snapshot := _capture_weather(center,radius,power,mode)
	last_weather_capture_us=Time.get_ticks_usec()-started
	if not str(snapshot["error"]).is_empty():
		return str(snapshot["error"])
	last_weather_worker_us=0
	last_weather_commit_us=0
	var error := _weather_worker.start(snapshot["source"],snapshot["weights"],snapshot["dim"],snapshot["spacing"],power,mode)
	if error!=OK:
		return "Weather worker start failed: "+error_string(error)
	_weather_snapshot=snapshot
	return ""

func cancel_weather() -> void:
	_weather_worker.cancel()
	_weather_snapshot.clear()

func shutdown_weather() -> void:
	cancel_weather()
	_weather_worker.shutdown()

func poll_weather() -> Dictionary:
	var result := _weather_worker.poll()
	if result.is_empty():
		return {}
	var snapshot := _weather_snapshot
	_weather_snapshot={}
	last_weather_worker_us=int(result.get("worker_us",0))
	if not str(result["error"]).is_empty():
		return {"done":true,"error":str(result["error"])}
	var started := Time.get_ticks_usec()
	var error := _commit_weather(snapshot,result)
	last_weather_commit_us=Time.get_ticks_usec()-started
	return {"done":true,"error":error}

# Synchronous reference retained for tests and direct callers.
func apply_weather(center: Vector2, radius: float, power: float, mode: int) -> String:
	if weather_busy():
		return "Aşındırma zaten hesaplanıyor."
	var snapshot := _capture_weather(center,radius,power,mode)
	if not str(snapshot["error"]).is_empty():
		return str(snapshot["error"])
	var result := Weather.run(snapshot["source"],snapshot["weights"],snapshot["dim"],snapshot["spacing"],power,mode)
	return _commit_weather(snapshot,result)

func _commit_weather(snapshot: Dictionary, result: Dictionary) -> String:
	last_changed_cells=0
	if not str(result["error"]).is_empty():
		return str(result["error"])
	if snapshot.is_empty() or not is_instance_valid(terrain) or terrain.get_instance_id()!=int(snapshot["terrain_id"]):
		return "Aşındırma iptal: arazi değişti."
	var data: Object=terrain.get("data")
	var size := int(terrain.call("get_region_size"))
	var spacing := float(terrain.get("vertex_spacing"))
	if data==null or data.get_instance_id()!=int(snapshot["data_id"]) or size!=int(snapshot["size"]) or spacing!=float(snapshot["spacing"]):
		return "Aşındırma iptal: arazi verisi değişti."
	var regions := _regions()
	if regions.is_empty():
		return region_error
	var source: PackedFloat64Array=snapshot["source"]
	var weights: PackedFloat32Array=snapshot["weights"]
	var dim: Vector2i=snapshot["dim"]
	var low: Vector2i=snapshot["low"]
	var center: Vector2=snapshot["center"]
	var radius: float=snapshot["radius"]
	var values: PackedFloat32Array=result["values"]
	if values.size()!=source.size():
		return "Weather result size mismatch."
	var changes := {}
	var originals := {}
	# Verify all in-footprint samples including previously invalid cells.
	# No stale worker result may overwrite another editor/native modification.
	for i in range(source.size()):
		var key := low+Vector2i(i%dim.x,floori(float(i)/dim.x))
		if (Vector2(key)-center/spacing).length()>=radius/spacing:
			continue
		var live := _sample(regions,key,size,spacing,data)
		if weights[i]<=0.0:
			if is_finite(live):
				return "Aşındırma iptal: yüzey maskesi değişti."
			continue
		if not is_finite(live) or live!=source[i]:
			return "Aşındırma iptal: yükseklik değişti."
		if float(values[i])!=source[i]:
			originals[key]=source[i]
			changes[key]=values[i]
	last_weather_mass_error=float(result["mass_error"])
	last_weather_moved=float(result["moved"])
	if changes.is_empty():
		return "Weather: no movable material at this slope."
	begin()
	var error := _write(regions,changes,size,true)
	if error.is_empty():
		before=originals
	end()
	return error

func _write(_regions_checked: Dictionary, values: Dictionary, _size: int, record: bool) -> String:
	var data: Object = terrain.get("data")
	if not data.has_method("tf_write_brush"):
		return "Native batch extension missing; install matching package."
	var started := Time.get_ticks_usec()
	var result: Dictionary = data.call("tf_write_brush",values)
	last_write_us=Time.get_ticks_usec()-started
	last_write_profile = result.get("profile",{})
	if not str(result["error"]).is_empty():
		return str(result["error"])
	var actual: Dictionary = result["actual"]
	if record:
		after.merge(actual,true)
		last_changed_cells=actual.size()
	return ""

func end() -> void:
	_commit_segment()

func _commit_segment() -> void:
	if not after.is_empty():
		history.append({"before":before,"after":after})
		redo_history.clear()
		var total := 0
		for action in history:
			total+=action["before"].size()
		while history.size()>HISTORY_LIMIT or total>HISTORY_CELL_LIMIT:
			total-=history[0]["before"].size()
			history.pop_front()
	before = {}
	after = {}

func _apply(values: Dictionary) -> bool:
	var regions := _regions()
	if regions.is_empty():
		return false
	var size := int(terrain.call("get_region_size"))
	var spacing := float(terrain.get("vertex_spacing"))
	var data: Object = terrain.get("data")
	# Validate every coordinate before the first write.
	for p: Vector2i in values:
		if not is_finite(_sample(regions,p,size,spacing,data)):
			return false
	return _write(regions,values,size,false).is_empty()

func undo() -> String:
	if history.is_empty():
		return "Nothing to undo."
	var action: Dictionary = history.back()
	if not _apply(action["before"]):
		return "Undo unavailable."
	history.pop_back()
	redo_history.append(action)
	return "Native undo applied."

func redo() -> String:
	if redo_history.is_empty():
		return "Nothing to redo."
	var action: Dictionary = redo_history.back()
	if not _apply(action["after"]):
		return "Redo unavailable."
	redo_history.pop_back()
	history.append(action)
	return "Native redo applied."

func _filename(loc: Vector2i) -> String:
	var x := "_%02d"%loc.x if loc.x>=0 else "%03d"%loc.x
	var z := "_%02d"%loc.y if loc.y>=0 else "%03d"%loc.y
	return "terrain3d"+x+z+".res"

# Manual backup: no changes to live data-directory or active native resource
# paths. Never use native remove_region/save_region as an eviction mechanism.
func _map_hashes(reg: Resource) -> Dictionary:
	var hashes := {}
	var size := int(reg.call("get_region_size"))
	for getter: String in ["get_height_map","get_control_map","get_color_map"]:
		var img: Image = reg.call(getter)
		if img==null or img.is_empty() or img.get_size()!=Vector2i(size,size):
			return {}
		if getter!="get_color_map" and img.get_format()!=Image.FORMAT_RF:
			return {}
		var ctx := HashingContext.new()
		if ctx.start(HashingContext.HASH_SHA256)!=OK or ctx.update(img.get_data())!=OK:
			return {}
		hashes[getter]=[int(img.get_format()),img.has_mipmaps(),ctx.finish().hex_encode()]
	return hashes

func save_snapshot() -> String:
	last_snapshot_path = ""
	last_snapshot_hashes.clear()
	var regions := _regions()
	if regions.is_empty():
		return region_error
	var folder := "res://terraforge_data/backups/native_"+Crypto.new().generate_random_bytes(12).hex_encode()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		return "Cannot create snapshot folder."
	var entries: Array[Dictionary] = []
	var expected := {}
	for loc: Vector2i in regions:
		var reg: Resource = regions[loc]["region"]
		var hashes := _map_hashes(reg)
		if hashes.is_empty():
			return "Backup blocked: invalid RF map at %s." % str(loc)
		reg.call("calc_height_range")
		var path := folder.path_join(_filename(loc))
		var err := ResourceSaver.save(reg,path,ResourceSaver.FLAG_COMPRESS)
		if err!=OK:
			return "Native backup failed: "+error_string(err)
		var saved := ResourceLoader.load(path,"Terrain3DRegion",ResourceLoader.CACHE_MODE_IGNORE)
		if saved==null or _map_hashes(saved)!=hashes:
			return "Backup readback failed at %s; live directory untouched." % str(loc)
		expected[loc]=hashes
		entries.append({"x":loc.x,"z":loc.y,"file":_filename(loc),"sha256":FileAccess.get_sha256(path),"maps":hashes})
	# Manifest written last: only complete, verified backups have this marker.
	var manifest := FileAccess.open(folder.path_join("snapshot.json"),FileAccess.WRITE)
	if manifest==null:
		return "Backup manifest write failed; live directory untouched."
	manifest.store_string(JSON.stringify({"schema":1,"region_size":int(terrain.call("get_region_size")),"spacing":float(terrain.get("vertex_spacing")),"regions":entries},"\t"))
	manifest.close()
	last_snapshot_path=folder
	last_snapshot_hashes=expected
	var data: Object=terrain.get("data")
	data.call("calc_height_range",false)
	# No directory swap, no reload or clipmap rebuild here.
	return "Native RF saved (%d regions). Backup: %s" % [regions.size(),folder]

func verify_scene_storage() -> String:
	if last_snapshot_hashes.is_empty() or not is_instance_valid(terrain):
		return "No verified backup for current save."
	var folder := str(terrain.get("data_directory"))
	for loc: Vector2i in last_snapshot_hashes:
		var path := folder.path_join(_filename(loc))
		var saved := ResourceLoader.load(path,"Terrain3DRegion",ResourceLoader.CACHE_MODE_IGNORE)
		if saved==null or _map_hashes(saved)!=last_snapshot_hashes[loc]:
			return "Scene region write mismatch at %s. Verified backup: %s" % [str(loc),last_snapshot_path]
	return ""
