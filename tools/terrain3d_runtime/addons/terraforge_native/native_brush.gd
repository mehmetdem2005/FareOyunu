@tool
extends RefCounted
## One native RF region during initial migration. No legacy meshes, scheduler or height store.
const MAX_DAB_CELLS := 16384
const MAX_STROKE_CELLS := 65536
const HISTORY_LIMIT := 8
var terrain: Node3D
var before: Dictionary = {}
var after: Dictionary = {}
var history: Array[Dictionary] = []
var redo_history: Array[Dictionary] = []
var last_hit := Vector2(INF,INF)
var flatten_height := NAN

func attach(node: Node3D) -> void:
	terrain = node
	before.clear()
	after.clear()
	history.clear()
	redo_history.clear()

func region() -> Resource:
	if not is_instance_valid(terrain):
		return null
	var data: Object = terrain.get("data")
	if data == null or int(data.call("get_region_count")) != 1:
		return null
	var locations: Array = data.call("get_region_locations")
	if locations.size()!=1 or locations[0]!=Vector2i.ZERO:
		return null
	return data.call("get_region",Vector2i.ZERO) as Resource

func begin() -> void:
	before = {}
	after = {}
	last_hit = Vector2(INF,INF)
	flatten_height = NAN

func dab(hit: Vector3, tool: int, radius: float, power: float) -> String:
	var reg := region()
	if reg == null or tool < 0 or tool > 3:
		return "Native integration: one editable region, basic tools only."
	var image: Image = reg.call("get_height_map")
	if image == null or image.get_format()!=Image.FORMAT_RF:
		return "Invalid native RF map."
	var spacing := float(terrain.get("vertex_spacing"))
	var center := Vector2(hit.x,hit.z)
	if last_hit.is_finite() and center.distance_to(last_hit)<maxf(spacing,radius*0.2):
		return ""
	var grid := center/spacing
	var r := radius/spacing
	if (2*ceili(r)+1)*(2*ceili(r)+1)>MAX_DAB_CELLS:
		return "Brush too large for current native edit budget."
	var low := Vector2i(maxi(0,floori(grid.x-r)),maxi(0,floori(grid.y-r)))
	var high := Vector2i(mini(image.get_width()-1,ceili(grid.x+r)),mini(image.get_height()-1,ceili(grid.y+r)))
	if low.x>high.x or low.y>high.y:
		return ""
	if before.size()+(high.x-low.x+1)*(high.y-low.y+1)>MAX_STROKE_CELLS:
		return "Stroke budget reached; release and continue."
	if not is_finite(flatten_height):
		flatten_height = image.get_pixel(clampi(roundi(grid.x),0,image.get_width()-1),clampi(roundi(grid.y),0,image.get_height()-1)).r
	var changes := {}
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var point := Vector2i(x,z)
			var d := Vector2(point).distance_to(grid)/r
			if d>=1.0:
				continue
			var weight := 1.0-smoothstep(0.0,1.0,d)
			var h := image.get_pixelv(point).r
			var value := h
			match tool:
				0: value = h+power*weight
				1: value = h-power*weight
				2:
					var total := 0.0
					var count := 0
					for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						var p := point+offset
						if p.x>=0 and p.y>=0 and p.x<image.get_width() and p.y<image.get_height():
							total+=image.get_pixelv(p).r
							count+=1
					if count>0:
						value = lerpf(h,total/count,clampf(power/12.0*weight,0.0,1.0))
				3: value = lerpf(h,flatten_height,clampf(power/12.0*weight,0.0,1.0))
			if not is_finite(value):
				return "Invalid height; dab rejected."
			if value!=h:
				changes[point]=value
				if not before.has(point):
					before[point]=h
	for point: Vector2i in changes:
		image.set_pixelv(point,Color(changes[point],0,0,1))
		after[point]=image.get_pixelv(point).r
	last_hit = center
	if not changes.is_empty():
		_publish(reg)
	return ""

func _publish(reg: Resource) -> void:
	var data: Object = terrain.get("data")
	reg.call("calc_height_range")
	data.call("calc_height_range",false)
	reg.call("set_modified",true)
	reg.call("set_edited",true)
	data.call("update_maps",0,false,false)
	reg.call("set_edited",false)

func end() -> void:
	if not after.is_empty():
		history.append({"before":before,"after":after})
		if history.size()>HISTORY_LIMIT:
			history.pop_front()
		redo_history.clear()
	before = {}
	after = {}

func _apply(values: Dictionary) -> bool:
	var reg := region()
	if reg == null:
		return false
	var img: Image = reg.call("get_height_map")
	for p: Vector2i in values:
		img.set_pixelv(p,Color(values[p],0,0,1))
	_publish(reg)
	return true

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

func save_snapshot() -> String:
	var reg := region()
	if reg == null:
		return "No supported native region."
	var folder := "res://terraforge_data/native_"+Crypto.new().generate_random_bytes(12).hex_encode()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		return "Cannot create snapshot folder."
	var path := folder.path_join("terrain3d_00_00.res")
	reg.call("set_modified",true)
	var err: int = reg.call("save",path,false,0)
	if err!=OK:
		reg.call("set_modified",true)
		return "Native save failed: "+error_string(err)
	var saved := ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
	var current: Image = reg.call("get_height_map")
	if saved==null or not saved.has_method("get_height_map"):
		reg.call("set_modified",true)
		return "Snapshot readback failed."
	var check: Image = saved.call("get_height_map")
	if check==null or check.get_format()!=Image.FORMAT_RF or check.get_size()!=current.get_size() or check.get_data()!=current.get_data():
		reg.call("set_modified",true)
		return "Snapshot height verification failed."
	# Switch only after verified write, old saved directory remains untouched.
	terrain.call("set_data_directory",folder)
	terrain.get("material").call("set_show_checkered",false)
	return "Native RF saved. Save scene separately."
