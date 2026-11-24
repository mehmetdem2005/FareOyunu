extends SceneTree
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const PREVIEW=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")

func _initialize() -> void:
    var probe=PREVIEW.new()
    if probe.resolved_sampling_strategy()!=0:
        probe.free()
        _fail("default")
        return
    probe.use_tile_read_view=true
    if probe.resolved_sampling_strategy()!=1:
        probe.free()
        _fail("legacy bool")
        return
    probe.sampling_strategy=0
    if probe.resolved_sampling_strategy()!=0:
        probe.free()
        _fail("explicit precedence")
        return
    probe.free()
    print("TRACE_ENV ",JSON.stringify({"os":OS.get_name(),"cpu":OS.get_processor_name(),"godot":Engine.get_version_info().get("string",""),"headless":true,"notes":"off-tree fixed pump trace, real async IO, no renderer frame or physics raycast; RSS process-wide sampled; no OS cache flush"}))
    for format in [0,1]:
        var b: Variant=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            b.close()
            _fail("fixture start")
            return
        var made: Dictionary={}
        var deadline: int=Time.get_ticks_msec()+30000
        while Time.get_ticks_msec()<deadline:
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            b.close()
            _fail("fixture")
            return
        var folder: String=made["directory"]
        var manifest: String=folder.path_join("manifest.tfm" if format==0 else "manifest.tfm2")
        var original: String=FileAccess.get_sha256(manifest)
        for cache in [9,16]:
            var order: Array=[0,1,2] if (format==0)==(cache==9) else [2,1,0]
            for mode in order:
                var result: Dictionary=TRACE.run(folder,format,mode,cache)
                if result.get("error",FAILED)!=OK:
                    b.close()
                    _fail(str(result))
                    return
                print("TRACE_CASE ",JSON.stringify(result))
        if FileAccess.get_sha256(manifest)!=original:
            b.close()
            _fail("manifest changed")
            return
        if format==1:
            for mode in [1,2]:
                if not _failure_case(folder,mode):
                    b.close()
                    _fail("TFM2 failure isolation mode "+str(mode))
                    return
        b.close()
    print("PASS: 12 fixed A/B/C async stream traces, legacy mode compatibility, bounds, collision recovery, TFM2 B/C cold-page isolation and last-good retention")
    quit(0)

func _pump_until(p,key: Vector2i) -> bool:
    for step in range(2400):
        p.pump_stream()
        if p._tiles.has(key):
            return true
        OS.delay_msec(1)
    return false

func _failure_case(folder: String,mode: int) -> bool:
    var p=PREVIEW.new()
    p.region_index_format=1
    p.sampling_strategy=mode
    p.max_visible_tiles=1
    p.high_detail_distance=180.0
    if p.start_preview(folder,9,4)!=OK:
        p.free()
        return false
    var key=Vector2i(15,15)
    p.set_stream_center(Vector3(496,20,496))
    if not _pump_until(p,key):
        p.stop_preview()
        p.free()
        return false
    var old_mesh: Mesh=p._tiles[key]["visual"].mesh
    var old_shape: Shape3D=p._tiles[key]["collision"].shape
    var path: String=folder.path_join("r_00015_00015.tfr")
    var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
    var ok: bool=p._reader.release_outside(Vector2i.ZERO,Vector2i.ZERO)==OK and DirAccess.remove_absolute(path)==OK
    if ok:
        p._pending_tiles[key]=true
        for step in range(2400):
            p.pump_stream()
            if p._blocked_tiles.has(key):
                break
            OS.delay_msec(1)
        ok=p._blocked_tiles.has(key) and p._tiles[key]["visual"].mesh==old_mesh and p._tiles[key]["collision"].shape==old_shape
        p.set_stream_center(Vector3(16,20,16))
        ok=_pump_until(p,Vector2i.ZERO) and ok and p.has_collision_at(Vector3(16,0,16)) and not p._tiles.has(key)
    p.stop_preview()
    p.free()
    # Restore disposable fixture before next strategy; never touch user data.
    var restored: FileAccess=FileAccess.open(path,FileAccess.WRITE)
    if restored==null:
        return false
    restored.store_buffer(bytes)
    restored.close()
    return ok and FileAccess.get_file_as_bytes(path)==bytes

func _fail(msg: String) -> void:
    push_error("Sampling stream trace: "+msg)
    quit(1)
