@tool
extends RefCounted
## Native RF maps are authoritative; no legacy terrain copy or mesh worker.
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
var region_error := ""
var last_dab_ms := -100000
var last_dab_duration_ms := 0

func attach(node: Node3D) -> void:
	terrain = node
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
		if img == null or img.get_format()!=Image.FORMAT_RF or img.get_size()!=Vector2i(size,size):
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

func dab(hit: Vector3, tool: int, radius: float, power: float) -> String:
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
	if last_hit.is_finite() and center.distance_to(last_hit)<maxf(spacing,radius*0.2):
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
	if cells>16384 and now-last_dab_ms<maxi(75,last_dab_duration_ms*2):
		return ""
	var started := now
	# Only Flatten needs a fixed target. Other tools may have a valid footprint
	# even when the nearest grid vertex is outside a region or a hole.
	if tool == 3 and not is_finite(flatten_height):
		flatten_height = _sample(regions,Vector2i(roundi(grid.x),roundi(grid.y)),size,spacing,data)
		if not is_finite(flatten_height):
			return "Flatten target is outside editable terrain."
	var changes := {}
	var originals := {}
	# Compute all new values before any writes, including cross-region smoothing.
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var p := Vector2i(x,z)
			var d := Vector2(p).distance_to(grid)/r
			if d>=1.0:
				continue
			var h := _sample(regions,p,size,spacing,data)
			if not is_finite(h):
				continue
			var weight := 1.0-smoothstep(0.0,1.0,d)
			var value := h
			match tool:
				0: value = h+power*weight
				1: value = h-power*weight
				2:
					var total := 0.0
					var count := 0
					for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						var neighbor := _sample(regions,p+offset,size,spacing,data)
						if is_finite(neighbor):
							total+=neighbor
							count+=1
					if count>0:
						value = lerpf(h,total/count,clampf(power/12.0*weight,0.0,1.0))
				3: value = lerpf(h,flatten_height,clampf(power/12.0*weight,0.0,1.0))
			if not is_finite(value) or absf(value)>1000000.0:
				return "Height out of bounds; dab rejected."
			if value!=h:
				changes[p]=value
				if not before.has(p):
					originals[p]=h
	if before.size()+originals.size()>MAX_STROKE_CELLS:
		# Commit a bounded history segment and continue the same gesture.
		# Rebuild originals from the current pre-dab values, not older segment.
		_commit_segment()
		originals.clear()
		for p: Vector2i in changes:
			originals[p]=_sample(regions,p,size,spacing,data)
	before.merge(originals)
	if not changes.is_empty():
		var write_error := _write(regions,changes,size,true)
		if not write_error.is_empty():
			return write_error
	last_dab_ms = Time.get_ticks_msec()
	last_dab_duration_ms = last_dab_ms-started
	last_hit = center
	if changes.is_empty() and tool == 0:
		return "Raise: no editable samples at %.2f, %.2f (grid %d / %.2fm)." % [hit.x,hit.z,size,spacing]
	return ""

func _write(regions: Dictionary, values: Dictionary, size: int, record: bool) -> String:
	var bounds := {}
	var data: Object = terrain.get("data")
	var spacing := float(terrain.get("vertex_spacing"))
	var write_failures := 0
	var written := 0
	for p: Vector2i in values:
		var loc := _loc(p,size)
		var img: Image = regions[loc]["image"]
		var pixel := p-loc*size
		var old := img.get_pixelv(pixel).r
		img.set_pixelv(pixel,Color(float(values[p]),0,0,1))
		var height := img.get_pixelv(pixel).r
		# RF rounds to float32. Validate actual native readback, not planned edits.
		if not is_finite(height) or not is_equal_approx(height,float(values[p])):
			write_failures += 1
		if not is_finite(height) or height==old:
			continue
		written += 1
		if record:
			after[p]=height
		var reg: Resource = regions[loc]["region"]
		var limits: Vector2 = bounds[loc] if bounds.has(loc) else reg.call("get_height_range")
		bounds[loc]=Vector2(minf(limits.x,height),maxf(limits.y,height))
	if not bounds.is_empty():
		for loc: Vector2i in bounds:
			var reg: Resource = regions[loc]["region"]
			reg.call("set_height_range",bounds[loc])
			reg.call("set_modified",true)
			reg.call("set_edited",true)
		data.call("calc_height_range",false)
		data.call("update_maps",0,false,false)
		for loc: Vector2i in bounds:
			regions[loc]["region"].call("set_edited",false)
		terrain.call("snap")
	if record:
		last_changed_cells = written
	if write_failures>0:
		return "Native write readback mismatch: %d/%d." % [write_failures,values.size()]
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

func save_snapshot() -> String:
	var regions := _regions()
	if regions.is_empty():
		return region_error
	var folder := "res://terraforge_data/native_"+Crypto.new().generate_random_bytes(12).hex_encode()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		return "Cannot create snapshot folder."
	# Manual operation. Preserve previous directory; no destructive overwrite.
	for loc: Vector2i in regions:
		var reg: Resource = regions[loc]["region"]
		var source: Image = reg.call("get_height_map")
		if source == null or source.get_format()!=Image.FORMAT_RF or source.get_size()!=Vector2i(int(terrain.call("get_region_size")),int(terrain.call("get_region_size"))):
			return "Save blocked: native RF image metadata mismatch at %s." % str(loc)
		reg.call("calc_height_range")
		var path := folder.path_join(_filename(loc))
		var err := ResourceSaver.save(reg,path,ResourceSaver.FLAG_COMPRESS)
		if err!=OK:
			return "Native save failed: "+error_string(err)
		var saved := ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
		if saved==null or not saved.has_method("get_height_map"):
			return "Snapshot readback failed; old directory untouched."
		for getter: String in ["get_height_map","get_control_map","get_color_map"]:
			var current: Image = reg.call(getter)
			var check: Image = saved.call(getter)
			if current==null or check==null or check.get_format()!=current.get_format() or check.get_size()!=current.get_size() or check.get_data()!=current.get_data():
				return "Snapshot verification failed; old directory untouched."
	var data: Object = terrain.get("data")
	data.call("calc_height_range",false)
	# Only verified snapshots become the scene's native data directory.
	# Native directory reload is synchronous; Android reopen behavior still needs validation.
	var expected := regions.size()
	terrain.call("set_data_directory",folder)
	terrain.get("material").call("set_show_checkered",false)
	var reopened := _regions()
	if reopened.size()!=expected:
		return "Saved data verified on disk, native reload incomplete: "+folder
	for loc: Vector2i in regions:
		if not reopened.has(loc):
			return "Saved data verified, native location reload mismatch: "+folder
	return "Native RF saved (%d regions). Save scene separately."%expected
