@tool
extends RefCounted
## Native RF corridor kernel, no legacy terrain store or renderer.
## Computes maximum influence once per sample. No mutation until caller commits.
const MAX_POINTS := 128
const MAX_LENGTH := 256.0
const MAX_VISITS := 600000
const MAX_CELLS := 131072

static func build(points: Array[Vector2], radius: float, spacing: float, valley: bool) -> Dictionary:
	if points.is_empty() or points.size()>MAX_POINTS or not is_finite(radius) or radius<1.0 or radius>36.0 or not is_finite(spacing) or spacing<0.25:
		return {"error":"Invalid corridor parameters.","weights":{}}
	var distance := 0.0
	for i in range(points.size()):
		if not points[i].is_finite() or absf(points[i].x)>10000000.0 or absf(points[i].y)>10000000.0:
			return {"error":"Invalid corridor point.","weights":{}}
		if i>0:
			distance+=points[i].distance_to(points[i-1])
	if distance>MAX_LENGTH:
		return {"error":"Corridor exceeds 256m; draw shorter paths.","weights":{}}
	var weights := {}
	var visits := 0
	var noise := FastNoiseLite.new()
	noise.seed=137
	noise.frequency=1.0/maxf(28.0,radius*7.0)
	noise.fractal_octaves=2
	for i in range(maxi(1,points.size()-1)):
		var a := points[i]
		var b := points[mini(i+1,points.size()-1)]
		var delta := b-a
		var length_sq := delta.length_squared()
		var direction := delta.normalized() if length_sq>0.000001 else Vector2.RIGHT
		var reach := radius*1.36
		var low := Vector2i(floori((minf(a.x,b.x)-reach)/spacing),floori((minf(a.y,b.y)-reach)/spacing))
		var high := Vector2i(ceili((maxf(a.x,b.x)+reach)/spacing),ceili((maxf(a.y,b.y)+reach)/spacing))
		visits+=(high.x-low.x+1)*(high.y-low.y+1)
		if visits>MAX_VISITS:
			return {"error":"Corridor work budget exceeded; use a shorter or narrower path.","weights":{}}
		for z in range(low.y,high.y+1):
			for x in range(low.x,high.x+1):
				var key := Vector2i(x,z)
				var world := Vector2(key)*spacing
				var warped := world+Vector2(noise.get_noise_2d(world.x,world.y),noise.get_noise_2d(world.x+113.17,world.y-91.73))*radius*0.14
				var t := clampf((warped-a).dot(delta)/maxf(length_sq,0.000001),0.0,1.0)
				var offset := warped-(a+delta*t)
				var width := radius*(1.14 if direction.cross(offset)>=0.0 else 0.86)
				var u := offset.length()/width
				if u>=1.0:
					continue
				var weight := pow(1.0-u,2.5 if valley else 4.0)
				if weight>float(weights.get(key,0.0)):
					weights[key]=weight
				if weights.size()>MAX_CELLS:
					return {"error":"Corridor sample budget exceeded; draw shorter paths.","weights":{}}
	return {"error":"","weights":weights}
