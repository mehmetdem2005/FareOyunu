extends RefCounted
## Inactive pure planning prototype. No IO, Terrain3D mutation, worker or image refs.
## Costs are caller-supplied logical bytes, not physical RSS/driver memory.
## Catalog: Vector2i -> {"bytes": positive int, "verified": bool}.
## Resident: Vector2i -> true. Pins: Vector2i -> true (dirty/history/stroke/physics).
## All distances are XZ metres to the region rectangle, not to its centre.
const MAX_COORD := 16
const MAX_ACTIVE := 64
const MAX_CATALOG := 1024

static func _valid_key(key: Variant) -> bool:
	if typeof(key) != TYPE_VECTOR2I:
		return false
	return key.x >= -MAX_COORD and key.x < MAX_COORD and key.y >= -MAX_COORD and key.y < MAX_COORD

static func _distance_squared(key: Vector2i, anchor: Vector2, region_m: float) -> float:
	var lo := Vector2(key)*region_m
	var hi := lo+Vector2.ONE*region_m
	var nearest := Vector2(clampf(anchor.x,lo.x,hi.x),clampf(anchor.y,lo.y,hi.y))
	return anchor.distance_squared_to(nearest)

static func _empty(reason: String) -> Dictionary:
	return {"valid":false,"reason":reason,"load":[],"evict":[],"protected":[],"missing_protected":[],"resident_bytes":0,"projected_bytes":0,"capacity_blocked":false,"mutates_data":false}

## At most one candidate transaction per call. A load is suggested only if its
## caller-declared staging cost fits BEFORE any eviction; no speculative credit.
## Actual atomic native slot replacement is deliberately not implemented.
static func plan(catalog: Dictionary, resident: Dictionary, pins: Dictionary, anchor: Vector2, region_m: float, near_m: float, load_m: float, unload_m: float, byte_budget: int, staging_bytes: int, slot_budget: int = MAX_ACTIVE) -> Dictionary:
	if not anchor.is_finite() or not is_finite(region_m) or not is_finite(near_m) or not is_finite(load_m) or not is_finite(unload_m) or region_m <= 0.0 or near_m < 0.0 or load_m < near_m or unload_m <= load_m or byte_budget <= 0 or staging_bytes < 0 or slot_budget < 1 or slot_budget > MAX_ACTIVE:
		return _empty("invalid_policy")
	if catalog.size()>MAX_CATALOG or resident.size()>MAX_ACTIVE or pins.size()>MAX_CATALOG:
		return _empty("invalid_inventory_size")
	var distances := {}
	var costs := {}
	for key in catalog:
		if not _valid_key(key) or not catalog[key] is Dictionary:
			return _empty("invalid_catalog_key")
		var desc: Dictionary = catalog[key]
		var bytes: Variant = desc.get("bytes")
		# Bound arithmetic and reject absent or guessed cost values.
		if typeof(bytes)!=TYPE_INT or bytes<=0 or bytes>1099511627776:
			return _empty("invalid_cost")
		if typeof(desc.get("verified"))!=TYPE_BOOL:
			return _empty("invalid_verification_state")
		costs[key]=bytes
		distances[key]=_distance_squared(key,anchor,region_m)
	var used := 0
	for key in resident:
		if not catalog.has(key) or resident[key]!=true:
			return _empty("unknown_resident")
		used+=int(costs[key])
	for key in pins:
		if not catalog.has(key) or pins[key]!=true:
			return _empty("unknown_pin")
	var result := _empty("")
	result["valid"]=true
	result["resident_bytes"]=used
	result["projected_bytes"]=used
	var protected: Array[Vector2i]=[]
	var missing: Array[Vector2i]=[]
	var loads: Array[Vector2i]=[]
	var evicts: Array[Vector2i]=[]
	for key: Vector2i in catalog:
		var distance: float=distances[key]
		var pinned := pins.has(key) or distance<=near_m*near_m
		if pinned:
			protected.append(key)
			if not resident.has(key):
				missing.append(key)
		if resident.has(key):
			# Never nominate dirty/history/active/near data or unverified sources.
			if not pinned and distance>unload_m*unload_m and catalog[key]["verified"]:
				evicts.append(key)
		elif (pinned or distance<=load_m*load_m) and catalog[key]["verified"]:
			loads.append(key)
	result["protected"]=protected
	result["missing_protected"]=missing
	loads.sort_custom(func(a: Vector2i,b: Vector2i)->bool:
		var pa := pins.has(a) or float(distances[a])<=near_m*near_m
		var pb := pins.has(b) or float(distances[b])<=near_m*near_m
		if pa!=pb:
			return pa
		if distances[a]!=distances[b]:
			return distances[a]<distances[b]
		return a.x<b.x or (a.x==b.x and a.y<b.y))
	evicts.sort_custom(func(a: Vector2i,b: Vector2i)->bool:
		if distances[a]!=distances[b]:
			return distances[a]>distances[b]
		return a.x<b.x or (a.x==b.x and a.y<b.y))
	# Missing unverified protected region is a hard stop for edit readiness.
	for key in missing:
		if not catalog[key]["verified"]:
			result["reason"]="protected_source_unverified"
			return result
	if not loads.is_empty():
		var next: Vector2i=loads[0]
		var cost: int=costs[next]
		if resident.size()<slot_budget and used<=byte_budget and cost<=byte_budget-used and staging_bytes<=byte_budget-used-cost:
			result["load"]=[next]
			result["projected_bytes"]=used+cost
			result["reason"]="load_candidate"
			return result
		result["capacity_blocked"]=true
	# An eviction is a proposal only, not permission to delete or save_region.
	# If there is no pressure and no missing load, keep existing resources.
	if used>byte_budget or resident.size()>slot_budget or result["capacity_blocked"]:
		if not evicts.is_empty():
			var next: Vector2i=evicts[0]
			result["evict"]=[next]
			result["projected_bytes"]=used-int(costs[next])
			result["reason"]="eviction_candidate_requires_native_transaction"
		else:
			result["capacity_blocked"]=true
			result["reason"]="budget_blocked_protected_or_hysteresis"
	else:
		result["reason"]="no_change"
	return result
