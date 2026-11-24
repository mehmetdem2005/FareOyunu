extends SceneTree
const PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const FIXTURE = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const GEOMETRY = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")

# Independent analytical source for comparison, never used as a fallback.
class Reference:
    extends RefCounted
    var cells: Vector2i = Vector2i(576,576)
    var spacing: float = 1.0
    func is_open() -> bool:
        return true
    func get_height(x: int,z: int) -> Dictionary:
        if x < 0 or z < 0 or x > cells.x or z > cells.y:
            return {"error": ERR_INVALID_PARAMETER}
        return {"error": OK, "height": FIXTURE.sample(x,z)}

func _initialize() -> void:
    var b = FIXTURE.new()
    var p = PREVIEW.new()
    if b.start(Vector2i(576,576)) != OK:
        _fail("fixture start",p,b)
        return
    var result: Dictionary = {}
    var deadline: int = Time.get_ticks_msec() + 30000
    while Time.get_ticks_msec() < deadline:
        result = b.take_result()
        if result["error"] != ERR_BUSY:
            break
        OS.delay_msec(2)
    if result.get("error",FAILED) != OK:
        _fail("fixture generation",p,b)
        return
    var folder: String = result["directory"]
    var root_hash: String = FileAccess.get_sha256(folder.path_join("manifest.tfm2"))
    if p.region_index_format != 0 or p.preview_enabled or p.start_preview(folder,16,4) == OK:
        _fail("default not TFM1/opt-in",p,b)
        return
    p.region_index_format = 1
    p.resident_shard_limit = 2
    p.max_visible_tiles = 4
    p.high_detail_distance = 180.0
    p.verify_pages_on_demand = false
    if p.start_preview(folder,16,4) != OK or not p.stats()["source"]["verified_at_open"]:
        _fail("strict preview",p,b)
        return
    p.stop_preview()
    p.verify_pages_on_demand = true
    if p.start_preview(folder,16,4) != OK or p.stats()["source"]["verified_at_open"] or p.stats()["index_format"] != "TFM2":
        _fail("lazy preview",p,b)
        return
    p.set_stream_center(Vector3(512,30,512))
    var keys: Array[Vector2i] = [Vector2i(15,15),Vector2i(16,15),Vector2i(15,16),Vector2i(16,16)]
    for attempt in range(4000):
        p.pump_stream()
        if p._tiles.size() == 4 and p._pending_tiles.is_empty():
            break
        OS.delay_msec(1)
    var reference = Reference.new()
    for key in keys:
        if not p._tiles.has(key):
            _fail("missing real corner tile " + str(key),p,b)
            return
        var tile: Dictionary = p._tiles[key]
        var actual: Array = (tile["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
        var expected: Dictionary = GEOMETRY.generate(reference,key.x,key.y,0,p._desired_tiles)
        if expected["error"] != OK or tile["lod"] != 0 or not _arrays_match(actual,expected["arrays"],true):
            _fail("actual ArrayMesh parity " + str(key),p,b)
            return
        var shape: HeightMapShape3D = (tile["collision"] as CollisionShape3D).shape
        if shape == null or shape.map_width != 33 or shape.map_depth != 33 or shape.map_data != expected["collision_heights"] or not p.has_collision_at(Vector3(key.x*32+16,0,key.y*32+16)):
            _fail("actual collision parity",p,b)
            return
    var left: Array = (p._tiles[keys[0]]["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
    var right: Array = (p._tiles[keys[1]]["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
    var bottom: Array = (p._tiles[keys[2]]["visual"] as MeshInstance3D).mesh.surface_get_arrays(0)
    for j in range(33):
        if left[Mesh.ARRAY_VERTEX][j*33+32].y != right[Mesh.ARRAY_VERTEX][j*33].y or left[Mesh.ARRAY_VERTEX][32*33+j].y != bottom[Mesh.ARRAY_VERTEX][j].y:
            _fail("shared seam height",p,b)
            return
        if j > 0 and j < 32:
            if left[Mesh.ARRAY_NORMAL][j*33+32].distance_to(right[Mesh.ARRAY_NORMAL][j*33]) > 0.00005 or left[Mesh.ARRAY_NORMAL][32*33+j].distance_to(bottom[Mesh.ARRAY_NORMAL][j]) > 0.00005:
                _fail("shared seam normal",p,b)
                return
    # Compare pure arrays against the analytical source at all LODs, plus
    # an explicit mixed LOD0/2 edge crossing the TFS2 shard boundary.
    for lod in [0,1,2]:
        var desired: Dictionary = {keys[0]:lod,keys[1]:lod,keys[2]:lod,keys[3]:lod}
        if not _geometry_parity(p._reader,reference,keys[0],lod,desired):
            _fail("LOD parity "+str(lod),p,b)
            return
    var mixed: Dictionary = {keys[0]:0,keys[1]:2,keys[2]:0,keys[3]:2}
    if not _geometry_parity(p._reader,reference,keys[0],0,mixed) or not _geometry_parity(p._reader,reference,keys[1],2,mixed):
        _fail("mixed seam parity",p,b)
        return
    var fine: Dictionary = GEOMETRY.generate(reference,15,15,0,mixed)
    var coarse: Dictionary = GEOMETRY.generate(reference,16,15,2,mixed)
    for j in range(33):
        var lo: int = mini(j/4,7)
        var t: float = float(j-lo*4)/4.0
        var y: float = lerpf(coarse["arrays"][Mesh.ARRAY_VERTEX][lo*9].y,coarse["arrays"][Mesh.ARRAY_VERTEX][(lo+1)*9].y,t)
        if absf(fine["arrays"][Mesh.ARRAY_VERTEX][j*33+32].y-y)>0.00002:
            _fail("mixed edge gap",p,b)
            return
    # Preserve a real last-good tile when a required cold page vanishes.
    var old_mesh: Mesh = (p._tiles[keys[0]]["visual"] as MeshInstance3D).mesh
    var old_shape: Shape3D = (p._tiles[keys[0]]["collision"] as CollisionShape3D).shape
    var path: String = folder.path_join("r_00015_00015.tfr")
    if p._reader.release_outside(Vector2i.ZERO,Vector2i.ZERO) != OK or DirAccess.remove_absolute(path) != OK:
        _fail("force cold failure",p,b)
        return
    p._pending_tiles[keys[0]]=true
    for attempt in range(3000):
        p.pump_stream()
        if p._blocked_tiles.has(keys[0]):
            break
        OS.delay_msec(1)
    if not p._blocked_tiles.has(keys[0]) or (p._tiles[keys[0]]["visual"] as MeshInstance3D).mesh != old_mesh or (p._tiles[keys[0]]["collision"] as CollisionShape3D).shape != old_shape:
        _fail("last-good preservation",p,b)
        return
    # Move into a healthy unrelated region; no stale job may prevent it.
    p.max_visible_tiles=1
    p.set_stream_center(Vector3(16,20,16))
    for attempt in range(3000):
        p.pump_stream()
        if p._tiles.has(Vector2i.ZERO):
            break
        OS.delay_msec(1)
    if not p._tiles.has(Vector2i.ZERO) or not p.has_collision_at(Vector3(16,0,16)) or p.stats()["camera_cancellations"] < 1:
        _fail("healthy region recovery",p,b)
        return
    var stats: Dictionary = p.stats()
    if stats["source"]["resident"] > 16 or stats["source"]["shard_resident"] > 2 or stats["writable"] or p.save_data()!=ERR_UNAVAILABLE or p.paint_at(Vector3.ZERO,0,8.0,1.0)!=ERR_UNAVAILABLE or FileAccess.get_sha256(folder.path_join("manifest.tfm2"))!=root_hash:
        _fail("bounds/read-only",p,b)
        return
    p.stop_preview()
    p.free()
    b.close()
    print("PASS: real TFM2 ArrayMesh and collision across four interior shards, LOD0/1/2 and mixed seams, last-good retention, camera recovery")
    quit(0)

func _geometry_parity(reader, reference, key: Vector2i, lod: int, desired: Dictionary) -> bool:
    var pages: Array[Vector2i] = GEOMETRY.required_pages(reader,key.x,key.y,lod)
    var ready: bool = false
    for attempt in range(2500):
        reader.poll_results(4)
        reader.prioritize_resident(pages)
        ready=true
        for page in pages:
            var status: Error=reader.page_status(page)
            if status == ERR_BUSY:
                ready=false
                reader.request_page(page)
            elif status != OK:
                return false
        if ready:
            break
        OS.delay_msec(1)
    if not ready:
        return false
    var actual: Dictionary=GEOMETRY.generate(reader,key.x,key.y,lod,desired)
    var expected: Dictionary=GEOMETRY.generate(reference,key.x,key.y,lod,desired)
    return actual["error"]==OK and expected["error"]==OK and _arrays_match(actual["arrays"],expected["arrays"],false) and actual["collision_heights"]==expected["collision_heights"]

func _arrays_match(actual: Array, expected: Array, packed: bool) -> bool:
    if packed:
        var mesh: ArrayMesh=ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,expected)
        expected=mesh.surface_get_arrays(0)
    if actual[Mesh.ARRAY_INDEX]!=expected[Mesh.ARRAY_INDEX] or actual[Mesh.ARRAY_VERTEX]!=expected[Mesh.ARRAY_VERTEX]:
        return false
    var normals: PackedVector3Array=actual[Mesh.ARRAY_NORMAL]
    var other: PackedVector3Array=expected[Mesh.ARRAY_NORMAL]
    if normals.size()!=other.size():
        return false
    for i in range(normals.size()):
        if normals[i].distance_to(other[i])>0.00005:
            return false
    return true

func _fail(msg: String,p,b) -> void:
    p.stop_preview()
    p.free()
    b.close()
    push_error("TFM2 preview: "+msg)
    quit(1)
