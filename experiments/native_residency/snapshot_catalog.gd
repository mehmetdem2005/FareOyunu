extends RefCounted
## Inactive S2 prototype. Read-only snapshot catalog; never invokes native mutations.
## Explicit opening and explicit verification only, not per-frame IO.
const MAX_REGIONS := 1024
const MAX_MANIFEST_BYTES := 2097152
const MAX_REGION_FILE_BYTES := 67108864
const MAP_KEYS := ["get_height_map","get_control_map","get_color_map"]
var generation: String = ""
var directory: String = ""
var region_size: int = 0
var spacing: float = 0.0
var entries: Dictionary = {}
var error: String = ""

static func _sha_ok(v: Variant) -> bool:
	if not v is String or v.length()!=64:
		return false
	for ch in v:
		if not "0123456789abcdef".contains(ch):
			return false
	return true

static func _int_field(v: Variant) -> bool:
	if typeof(v)==TYPE_INT:
		return true
	return typeof(v)==TYPE_FLOAT and is_finite(v) and v==floor(v) and absf(v)<=2147483647.0

static func _filename(loc: Vector2i) -> String:
	var x := "_%02d"%loc.x if loc.x>=0 else "%03d"%loc.x
	var z := "_%02d"%loc.y if loc.y>=0 else "%03d"%loc.y
	return "terrain3d"+x+z+".res"

func _fail(message: String) -> bool:
	entries.clear()
	generation=""
	directory=""
	region_size=0
	spacing=0.0
	error=message
	return false

func open_snapshot(folder: String) -> bool:
	_fail("")
	# Only explicit backup folders inside this project's data root.
	# A path from the manifest is never used to escape that folder.
	if not folder.begins_with("res://terraforge_data/backups/native_") or folder.contains("..") or folder.get_base_dir()!="res://terraforge_data/backups":
		return _fail("invalid_snapshot_folder")
	var path := folder.path_join("snapshot.json")
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<=0 or file.get_length()>MAX_MANIFEST_BYTES:
		return _fail("manifest_missing_or_too_large")
	var raw := file.get_buffer(file.get_length())
	var ctx := HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256)!=OK or ctx.update(raw)!=OK:
		return _fail("manifest_hash_failed")
	var identity := ctx.finish().hex_encode()
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not parsed is Dictionary:
		return _fail("invalid_manifest")
	var doc: Dictionary=parsed
	if doc.get("schema")!=1 or not _int_field(doc.get("region_size")) or not doc.get("regions") is Array:
		return _fail("unsupported_manifest")
	var size := int(doc["region_size"])
	if size not in [64,128,256,512,1024,2048]:
		return _fail("unsupported_region_size")
	var step: Variant=doc.get("spacing")
	if typeof(step) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(step)) or float(step)<0.25 or float(step)>100.0:
		return _fail("invalid_spacing")
	var rows: Array=doc["regions"]
	if rows.is_empty() or rows.size()>MAX_REGIONS:
		return _fail("invalid_region_count")
	var built := {}
	for row in rows:
		if not row is Dictionary or not _int_field(row.get("x")) or not _int_field(row.get("z")):
			return _fail("invalid_region_entry")
		var loc := Vector2i(int(row["x"]),int(row["z"]))
		if loc.x< -16 or loc.x>15 or loc.y< -16 or loc.y>15 or built.has(loc):
			return _fail("invalid_or_duplicate_coordinate")
		if row.get("file")!=_filename(loc) or not _sha_ok(row.get("sha256")) or not row.get("maps") is Dictionary:
			return _fail("invalid_region_identity")
		var maps: Dictionary=row["maps"]
		if maps.size()!=3:
			return _fail("invalid_map_count")
		var bytes := 0
		for key in MAP_KEYS:
			var m: Variant=maps.get(key)
			if not m is Array or m.size()!=3 or not _int_field(m[0]) or typeof(m[1])!=TYPE_BOOL or not _sha_ok(m[2]):
				return _fail("invalid_map_metadata")
			var fmt := int(m[0])
			if key=="get_color_map":
				if fmt!=Image.FORMAT_RGBA8:
					return _fail("unsupported_color_format")
			elif fmt!=Image.FORMAT_RF or m[1]:
				return _fail("unsupported_rf_format")
			var side := size
			while true:
				bytes+=side*side*4
				if not m[1] or side==1:
					break
				side=side>>1
		built[loc]={"file":row["file"],"sha256":row["sha256"],"maps":maps.duplicate(true),"bytes":bytes,"verified":false}
	directory=folder
	generation=identity
	region_size=size
	spacing=float(step)
	entries=built
	return true

# A successful hash is evidence for this exact snapshot generation, not permanent
# permission to use a path. Consumers must re-check after decoding and before commit.
func verify_source(loc: Vector2i, expected_generation: String) -> bool:
	if generation.is_empty() or generation!=expected_generation or not entries.has(loc):
		error="stale_generation_or_unknown_region"
		return false
	var entry: Dictionary=entries[loc]
	entry["verified"]=false
	var path := directory.path_join(entry["file"])
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<=0 or file.get_length()>MAX_REGION_FILE_BYTES:
		error="missing_or_oversized_region"
		return false
	file.close()
	if FileAccess.get_sha256(path)!=entry["sha256"]:
		error="region_sha256_mismatch"
		return false
	entry["verified"]=true
	error=""
	return true

# Metadata copy only; no retained Image data or implicit disk reads.
func planner_catalog() -> Dictionary:
	var out := {}
	for loc in entries:
		out[loc]={"bytes":entries[loc]["bytes"],"verified":entries[loc]["verified"]}
	return out

func ticket(loc: Vector2i) -> Dictionary:
	if not entries.has(loc) or not entries[loc]["verified"]:
		return {}
	return {"generation":generation,"loc":loc,"path":directory.path_join(entries[loc]["file"]),"sha256":entries[loc]["sha256"]}

func ticket_current(t: Dictionary) -> bool:
	if t.get("generation")!=generation or not entries.has(t.get("loc")):
		return false
	var loc: Vector2i=t["loc"]
	return t.get("path")==directory.path_join(entries[loc]["file"]) and t.get("sha256")==entries[loc]["sha256"] and verify_source(loc,generation)
