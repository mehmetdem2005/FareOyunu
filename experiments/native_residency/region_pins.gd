extends RefCounted
## Inactive pure metadata helper; union of dirty, history and caller-owned physics pins.
## History dictionaries contain Vector2i global vertex indices, not region IDs.
static func _valid_loc(loc: Variant) -> bool:
	return typeof(loc)==TYPE_VECTOR2I and loc.x>=-16 and loc.x<16 and loc.y>=-16 and loc.y<16

static func _region(p: Vector2i, size: int) -> Vector2i:
	return Vector2i(floori(float(p.x)/size),floori(float(p.y)/size))

static func _add_history(result: Dictionary, values: Dictionary, size: int) -> bool:
	for p in values:
		if typeof(p)!=TYPE_VECTOR2I:
			return false
		var loc := _region(p,size)
		if not _valid_loc(loc):
			return false
		result[loc]=true
	return true

static func build(size: int, dirty: Dictionary, history: Array, redo_history: Array, active_before: Dictionary, active_after: Dictionary, physics: Dictionary, footprint: Rect2i, smooth_halo: bool) -> Dictionary:
	if size not in [64,128,256,512,1024,2048] or history.size()+redo_history.size()>16:
		return {"valid":false,"pins":{},"reason":"invalid_grid_or_history"}
	var out := {}
	for group in [dirty,physics]:
		for loc in group:
			if not _valid_loc(loc) or group[loc]!=true:
				return {"valid":false,"pins":{},"reason":"invalid_pin"}
			out[loc]=true
	for actions in [history,redo_history]:
		for action in actions:
			if not action is Dictionary or not action.get("before") is Dictionary or not action.get("after") is Dictionary:
				return {"valid":false,"pins":{},"reason":"invalid_history"}
			if not _add_history(out,action["before"],size) or not _add_history(out,action["after"],size):
				return {"valid":false,"pins":{},"reason":"invalid_history_coordinate"}
	if not _add_history(out,active_before,size) or not _add_history(out,active_after,size):
		return {"valid":false,"pins":{},"reason":"invalid_stroke"}
	if footprint.size.x<0 or footprint.size.y<0:
		return {"valid":false,"pins":{},"reason":"invalid_footprint"}
	if footprint.has_area():
		var rect := footprint.grow(1) if smooth_halo else footprint
		var lo := _region(rect.position,size)
		var hi := _region(rect.end-Vector2i.ONE,size)
		# Out-of-world brush halo is clipped, not invented as a region.
		for y in range(maxi(lo.y,-16),mini(hi.y,15)+1):
			for x in range(maxi(lo.x,-16),mini(hi.x,15)+1):
				out[Vector2i(x,y)]=true
	return {"valid":true,"pins":out,"reason":""}
