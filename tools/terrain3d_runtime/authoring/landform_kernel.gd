extends RefCounted
## Reusable world-space landform stamp, independent of any fixture or renderer.
## All values are metres. Negative relief creates a valley; positive creates a ridge.
## Bounded work area, single output RF image, no normalized/8-bit source.
const MAX_SIDE := 1024
var side := 0
var spacing := 0.25
var relief := 0.0
var width := 1.0
var bend := 0.0
var seed_value := 0
var image: Image
var next_row := 0
var min_height := INF
var max_height := -INF
var _noise := FastNoiseLite.new()

func begin(samples: int, metres_per_sample: float, relief_m: float, half_width_m: float, bend_m: float, seed_number: int) -> Error:
	if samples < 32 or samples > MAX_SIDE or not is_finite(metres_per_sample) or metres_per_sample < 0.25 or metres_per_sample > 100.0:
		return ERR_INVALID_PARAMETER
	if not is_finite(relief_m) or absf(relief_m) > 1000.0 or not is_finite(half_width_m) or half_width_m < metres_per_sample*2.0 or not is_finite(bend_m) or bend_m < 0.0:
		return ERR_INVALID_PARAMETER
	var extent := (samples-1)*metres_per_sample
	if half_width_m+bend_m >= extent*0.5:
		return ERR_INVALID_PARAMETER
	side = samples
	spacing = metres_per_sample
	relief = relief_m
	width = half_width_m
	bend = bend_m
	seed_value = seed_number
	_noise.seed = seed_number
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0/maxf(extent*0.35,spacing)
	_noise.fractal_octaves = 2
	image = Image.create_empty(side,side,false,Image.FORMAT_RF)
	if image == null or image.is_empty():
		return ERR_OUT_OF_MEMORY
	next_row = 0
	min_height = INF
	max_height = -INF
	return OK

## Process at least one row, then yield when caller's time budget is reached.
## No work unless explicitly requested by the authoring UI.
func step(budget_us: int = 3000) -> bool:
	if image == null or next_row >= side:
		return true
	var deadline := Time.get_ticks_usec()+maxi(budget_us,1)
	var extent := (side-1)*spacing
	while next_row < side:
		var z := next_row*spacing
		var t := z/extent
		var center := extent*0.5+bend*_noise.get_noise_1d(z)
		# Both longitudinal ends taper to exactly zero; lateral support is compact.
		var end_weight := smoothstep(0.0,0.15,t)*(1.0-smoothstep(0.85,1.0,t))
		for x in range(side):
			var d := absf(x*spacing-center)/width
			var weight := 1.0-smoothstep(0.0,1.0,d)
			var h := relief*weight*end_weight
			image.set_pixel(x,next_row,Color(h,0.0,0.0,1.0))
			min_height = minf(min_height,h)
			max_height = maxf(max_height,h)
		next_row += 1
		if Time.get_ticks_usec() >= deadline:
			break
	return next_row >= side

func completed() -> bool:
	return image != null and next_row == side

func metadata() -> Dictionary:
	return {"samples":side,"spacing_m":spacing,"extent_m":(side-1)*spacing,"relief_m":relief,"half_width_m":width,"bend_m":bend,"seed":seed_value,"height_format":"float32_le_meters","kind":"compact_ridge_valley_stamp","min_m":min_height,"max_m":max_height}
