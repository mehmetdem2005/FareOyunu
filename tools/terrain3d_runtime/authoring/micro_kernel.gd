extends RefCounted
## Compact, rotated elliptical bump/hollow/trench stamp in physical metres.
## Source is immutable; output RF. Outside footprint remains bit-identical.
## No noise or hidden work outside explicit calls; use one job per stamp.
const MAX_SIDE := 1024
var image: Image
var x0 := 0
var x1 := -1
var y0 := 0
var y1 := -1
var x := 0
var y := 0
var spacing := 1.0
var center := Vector2.ZERO
var radii := Vector2.ONE
var height := 0.0
var cosine := 1.0
var sine := 0.0
var ready := false
var done := false
var changed := 0

func begin(input: Image, spacing_m: float, center_m: Vector2, radii_m: Vector2, height_m: float, angle_rad: float) -> Error:
	if ready:
		return ERR_ALREADY_IN_USE
	if input == null or input.is_empty() or input.get_format() != Image.FORMAT_RF or input.has_mipmaps():
		return ERR_INVALID_PARAMETER
	var size := input.get_size()
	if size.x < 2 or size.y < 2 or size.x > MAX_SIDE or size.y > MAX_SIDE:
		return ERR_INVALID_PARAMETER
	if not is_finite(spacing_m) or spacing_m < 0.01 or spacing_m > 100.0 or not center_m.is_finite() or not radii_m.is_finite() or not is_finite(height_m) or not is_finite(angle_rad):
		return ERR_INVALID_PARAMETER
	if minf(radii_m.x,radii_m.y) < spacing_m*2.0 or maxf(radii_m.x,radii_m.y) > 10000.0 or absf(height_m) > 100.0:
		return ERR_INVALID_PARAMETER
	if center_m.x < 0.0 or center_m.y < 0.0 or center_m.x > (size.x-1)*spacing_m or center_m.y > (size.y-1)*spacing_m:
		return ERR_INVALID_PARAMETER
	spacing = spacing_m
	center = center_m
	radii = radii_m
	height = height_m
	cosine = cos(angle_rad)
	sine = sin(angle_rad)
	var rx := sqrt(pow(radii.x*cosine,2.0)+pow(radii.y*sine,2.0))
	var ry := sqrt(pow(radii.x*sine,2.0)+pow(radii.y*cosine,2.0))
	x0 = clampi(floori((center.x-rx)/spacing),0,size.x-1)
	x1 = clampi(ceili((center.x+rx)/spacing),0,size.x-1)
	y0 = clampi(floori((center.y-ry)/spacing),0,size.y-1)
	y1 = clampi(ceili((center.y+ry)/spacing),0,size.y-1)
	x = x0
	y = y0
	image = input.duplicate() as Image
	if image == null:
		return ERR_OUT_OF_MEMORY
	ready = true
	return OK

func step(budget_us: int = 3000) -> bool:
	if not ready or done:
		return true
	var deadline := Time.get_ticks_usec()+maxi(1,budget_us)
	while y <= y1:
		var p := Vector2(x*spacing,y*spacing)-center
		var u := (p.x*cosine+p.y*sine)/radii.x
		var v := (-p.x*sine+p.y*cosine)/radii.y
		var r2 := u*u+v*v
		if r2 < 1.0 and height != 0.0:
			# Quartic compact profile, zero first derivative at perimeter.
			var t := 1.0-r2
			var old := image.get_pixel(x,y).r
			if not is_finite(old) or absf(old) > 100000.0:
				image = null
				ready = false
				return true
			image.set_pixel(x,y,Color(old+height*t*t,0,0,1))
			if image.get_pixel(x,y).r != old:
				changed += 1
		x += 1
		if x > x1:
			x = x0
			y += 1
		if Time.get_ticks_usec() >= deadline:
			break
	done = y > y1
	return done

func completed() -> bool:
	return ready and done
