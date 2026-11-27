@tool
extends RefCounted
## Bounded closed brush footprint. Source immutable. Missing regions and holes
## have zero weight. Thermal: simultaneous conservative four-neighbor talus.
## Flow: single-pass D8 strictly downhill drainage and sediment, not water physics.
const MAX_CELLS := 85000
const CARDINAL := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
const D8 := [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]

static func run(source: PackedFloat64Array, weights: PackedFloat32Array, size: Vector2i, spacing: float, power: float, mode: int) -> Dictionary:
	var count := size.x*size.y
	if size.x<1 or size.y<1 or size.x>290 or size.y>290 or count>MAX_CELLS or source.size()!=count or weights.size()!=count or not is_finite(spacing) or spacing<0.25 or spacing>100.0 or not is_finite(power) or power<=0.0 or power>12.0 or mode not in [0,1]:
		return {"error":"Invalid Weather footprint.","values":PackedFloat32Array()}
	for i in range(count):
		if not is_finite(source[i]) or absf(source[i])>1000000.0 or not is_finite(weights[i]) or weights[i]<0.0 or weights[i]>1.0:
			return {"error":"Invalid Weather source.","values":PackedFloat32Array()}
	var current := source.duplicate()
	var mobility := power/12.0
	if mode==0:
		_thermal(current,weights,size,spacing,mobility)
	else:
		if not _flow(current,weights,size,spacing,mobility,power*0.05):
			return {"error":"Flow routing incomplete; no changes made.","values":PackedFloat32Array()}
	# Preserve mass while bounding concentrated basin deposition: scale the
	# whole conservative delta, never clip one cell independently.
	var scale := 1.0
	var limit := maxf(0.25,power)
	for i in range(count):
		var delta := current[i]-source[i]
		if not is_finite(delta):
			return {"error":"Weather relief limit exceeded; reduce Size or Power.","values":PackedFloat32Array()}
		if absf(delta)>limit:
			scale=minf(scale,limit/absf(delta))
	var result := PackedFloat32Array()
	result.resize(count)
	var mass_error := 0.0
	var moved := 0.0
	var max_rounding := 0.0
	for i in range(count):
		var value := source[i]+(current[i]-source[i])*scale
		if not is_finite(value) or absf(value)>1000000.0:
			return {"error":"Weather relief limit exceeded; reduce Size or Power.","values":PackedFloat32Array()}
		result[i]=value
		mass_error+=float(result[i])-source[i]
		moved+=absf(value-source[i])*0.5
		max_rounding+=absf(float(result[i])-value)
	if absf(mass_error)>max_rounding+maxf(0.000001,moved*0.00000001):
		return {"error":"Weather mass validation failed.","values":PackedFloat32Array()}
	return {"error":"","values":result,"mass_error":mass_error,"moved":moved}

static func _thermal(current: PackedFloat64Array, weights: PackedFloat32Array, size: Vector2i, spacing: float, mobility: float) -> void:
	var count := current.size()
	var talus := 0.6*spacing
	var change := PackedFloat64Array()
	change.resize(count)
	for iteration in range(3):
		change.fill(0.0)
		for i in range(count):
			if weights[i]<=0.0:
				continue
			var x := i%size.x
			var y := floori(float(i)/size.x)
			var total := 0.0
			var maximum := 0.0
			for off: Vector2i in CARDINAL:
				var nx := x+off.x
				var ny := y+off.y
				if nx<0 or nx>=size.x or ny<0 or ny>=size.y:
					continue
				var j := ny*size.x+nx
				if weights[j]<=0.0:
					continue
				var excess := maxf(0.0,current[i]-current[j]-talus)
				total+=excess*minf(weights[i],weights[j])
				maximum=maxf(maximum,excess)
			if total<=0.0:
				continue
			var amount := minf(maximum*0.24,total*0.22)*mobility
			for off: Vector2i in CARDINAL:
				var nx := x+off.x
				var ny := y+off.y
				if nx<0 or nx>=size.x or ny<0 or ny>=size.y:
					continue
				var j := ny*size.x+nx
				if weights[j]<=0.0:
					continue
				var potential := maxf(0.0,current[i]-current[j]-talus)*minf(weights[i],weights[j])
				var transfer := amount*potential/total
				change[i]-=transfer
				change[j]+=transfer
		for i in range(count):
			current[i]+=change[i]

static func _flow(current: PackedFloat64Array, weights: PackedFloat32Array, size: Vector2i, spacing: float, mobility: float, max_cut: float) -> bool:
	var count := current.size()
	var receiver := PackedInt32Array()
	var indegree := PackedInt32Array()
	var queue := PackedInt32Array()
	var area := PackedFloat64Array()
	var sediment := PackedFloat64Array()
	var slope := PackedFloat64Array()
	var change := PackedFloat64Array()
	receiver.resize(count)
	receiver.fill(-1)
	indegree.resize(count)
	queue.resize(count)
	area.resize(count)
	sediment.resize(count)
	slope.resize(count)
	change.resize(count)
	var active := 0
	for i in range(count):
		if weights[i]<=0.0:
			continue
		active+=1
		area[i]=1.0
		var x := i%size.x
		var y := floori(float(i)/size.x)
		var best := 0.0
		for off: Vector2i in D8:
			var nx := x+off.x
			var ny := y+off.y
			if nx<0 or nx>=size.x or ny<0 or ny>=size.y:
				continue
			var j := ny*size.x+nx
			if weights[j]<=0.0:
				continue
			# No diagonal routing through a blocked corner.
			if off.x!=0 and off.y!=0 and (weights[y*size.x+nx]<=0.0 or weights[ny*size.x+x]<=0.0):
				continue
			var dist := spacing*(sqrt(2.0) if off.x!=0 and off.y!=0 else 1.0)
			var gradient := (current[i]-current[j])/dist
			if gradient>best:
				best=gradient
				receiver[i]=j
		slope[i]=best
		if receiver[i]>=0:
			indegree[receiver[i]]+=1
	var tail := 0
	for i in range(count):
		if weights[i]>0.0 and indegree[i]==0:
			queue[tail]=i
			tail+=1
	var head := 0
	while head<tail:
		var i := queue[head]
		head+=1
		var j := receiver[i]
		var load := sediment[i]
		if j>=0:
			var edge := minf(weights[i],weights[j])
			var cut := minf(max_cut,minf((current[i]-current[j])*0.25,mobility*sqrt(area[i])*slope[i]*spacing))*edge
			var deposit := load*0.4/(1.0+slope[i])
			change[i]+=deposit-cut
			sediment[j]+=load-deposit+cut
			area[j]+=area[i]
			indegree[j]-=1
			if indegree[j]==0:
				queue[tail]=j
				tail+=1
		else:
			change[i]+=load
	if head!=active:
		return false
	for i in range(count):
		current[i]+=change[i]
	return true
