extends RefCounted
## Bounded, single-pass D8 drainage + conservative sediment redistribution.
## Not a time-dependent hydraulic solver. Closed boundary; sinks retain sediment.
## Explicit authoring job only; caller steps it, no worker or runtime polling.
const MAX_SIDE := 256
const OFFSETS := [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]
var w := 0
var h := 0
var spacing := 1.0
var strength := 0.0
var max_cut := 0.0
var deposit_fraction := 0.0
var image: Image
var source := PackedFloat64Array()
var receiver := PackedInt32Array()
var slope := PackedFloat64Array()
var incoming := PackedInt32Array()
var area := PackedFloat64Array()
var sediment := PackedFloat64Array()
var change := PackedFloat64Array()
var queue := PackedInt32Array()
var phase := 0
var cursor := 0
var tail := 0
var processed := 0
var failure := false
var source_sum := 0.0
var output_sum := 0.0
var eroded := 0.0
var deposited := 0.0
var sinks := 0

func begin(input: Image, spacing_m: float, erosion_strength: float, max_cut_m: float, fraction: float) -> Error:
	if phase != 0:
		return ERR_ALREADY_IN_USE
	if input == null or input.is_empty() or input.get_format() != Image.FORMAT_RF or input.has_mipmaps():
		return ERR_INVALID_PARAMETER
	var size := input.get_size()
	if size.x < 2 or size.y < 2 or size.x > MAX_SIDE or size.y > MAX_SIDE:
		return ERR_INVALID_PARAMETER
	if not is_finite(spacing_m) or spacing_m < 0.01 or spacing_m > 100.0 or not is_finite(erosion_strength) or erosion_strength < 0.0 or erosion_strength > 1.0 or not is_finite(max_cut_m) or max_cut_m < 0.0 or max_cut_m > 10.0 or not is_finite(fraction) or fraction < 0.0 or fraction > 1.0:
		return ERR_INVALID_PARAMETER
	w = size.x
	h = size.y
	spacing = spacing_m
	strength = erosion_strength
	max_cut = max_cut_m
	deposit_fraction = fraction
	var count := w*h
	# Copy source bytes into private RF image once: later caller edits cannot change job.
	var values := input.get_data().to_float32_array()
	source.resize(count)
	receiver.resize(count)
	receiver.fill(-1)
	slope.resize(count)
	incoming.resize(count)
	area.resize(count)
	area.fill(1.0)
	sediment.resize(count)
	change.resize(count)
	queue.resize(count)
	for i in range(count):
		var v: float = values[i]
		if not is_finite(v) or absf(v) > 100000.0:
			failure = true
			return ERR_INVALID_DATA
		source[i] = v
		source_sum += v
	image = Image.create_empty(w,h,false,Image.FORMAT_RF)
	if image == null or image.is_empty():
		failure = true
		return ERR_OUT_OF_MEMORY
	phase = 1
	return OK

func step(budget_us: int = 3000) -> bool:
	if failure or phase == 0 or phase == 5:
		return true
	var deadline := Time.get_ticks_usec()+maxi(1,budget_us)
	var count := w*h
	while phase < 5:
		if phase == 1:
			var x := cursor%w
			var y := floori(float(cursor)/w)
			var best := 0.0
			var target := -1
			for off: Vector2i in OFFSETS:
				var nx := x+off.x
				var ny := y+off.y
				if nx < 0 or nx >= w or ny < 0 or ny >= h:
					continue
				var j := ny*w+nx
				var dist := spacing*(sqrt(2.0) if off.x != 0 and off.y != 0 else 1.0)
				var gradient := (source[cursor]-source[j])/dist
				if gradient > best:
					best = gradient
					target = j
			receiver[cursor] = target
			slope[cursor] = best
			if target >= 0:
				incoming[target] += 1
			else:
				sinks += 1
			cursor += 1
			if cursor == count:
				cursor = 0
				phase = 2
		elif phase == 2:
			if incoming[cursor] == 0:
				queue[tail] = cursor
				tail += 1
			cursor += 1
			if cursor == count:
				cursor = 0
				phase = 3
		elif phase == 3:
			if cursor == tail:
				if processed != count:
					failure = true
					return true
				cursor = 0
				phase = 4
				continue
			var i := queue[cursor]
			var j := receiver[i]
			var load := sediment[i]
			if j >= 0:
				# Cut is bounded by local drop, so shallow slopes do not become deep pits.
				var cut := minf(max_cut,minf((source[i]-source[j])*0.25,strength*sqrt(area[i])*slope[i]*spacing))
				change[i] -= cut
				eroded += cut
				# Slower slopes retain more of incoming material; all terminal load deposits.
				var deposit := load*deposit_fraction/(1.0+slope[i])
				change[i] += deposit
				deposited += deposit
				sediment[j] += load-deposit+cut
				area[j] += area[i]
				incoming[j] -= 1
				if incoming[j] == 0:
					queue[tail] = j
					tail += 1
			else:
				change[i] += load
				deposited += load
			processed += 1
			cursor += 1
		else:
			var v := source[cursor]+change[cursor]
			if not is_finite(v):
				failure = true
				return true
			var x := cursor%w
			var y := int(cursor/w)
			image.set_pixel(x,y,Color(v,0,0,1))
			output_sum += image.get_pixel(x,y).r
			cursor += 1
			if cursor == count:
				phase = 5
		if Time.get_ticks_usec() >= deadline:
			break
	return phase == 5

func completed() -> bool:
	return phase == 5 and not failure

func metadata() -> Dictionary:
	return {"kind":"d8_closed_boundary_sediment_pass","width":w,"height":h,"spacing_m":spacing,"eroded_m_sum":eroded,"deposited_m_sum":deposited,"rf_mass_error_m_sum":output_sum-source_sum,"sinks":sinks,"processed":processed}
