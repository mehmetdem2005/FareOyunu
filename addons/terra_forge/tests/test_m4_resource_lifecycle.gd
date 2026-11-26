extends SceneTree
## Test-only resource lifetime probe. Equal 24 real mesh/node creations,
## same visible scene, immediate release vs bounded detached retention (4).
## No render-thread or GPU timing attribution; include final drain.
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
const COUNT: int=24
const CAP: int=4
var _stage: Dictionary={}
var _peak_retired: int=0
var _retired: Array[MeshInstance3D]=[]
var _slow: Array[Dictionary]=[]
var _memory_peak: float=0.0
var _frame_hist=HIST.new()
func _initialize() -> void:
    call_deferred("_run")
func _mark(name: String,start: int,index: int) -> void:
    var elapsed: int=Time.get_ticks_usec()-start
    if not _stage.has(name):
        _stage[name]=HIST.new()
    _stage[name].add(float(elapsed)/1000.0)
    if elapsed>=8000:
        _slow.append({"stage":name,"index":index,"wall_us":elapsed,"frame":Engine.get_process_frames()})
        _slow.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return int(a["wall_us"])>int(b["wall_us"]))
        if _slow.size()>8:
            _slow.pop_back()
func _fail(message: String) -> void:
    for visual in _retired:
        visual.free()
    _retired.clear()
    push_error("M4 lifecycle: "+message)
    quit(1)
func _run() -> void:
    var arm: String=""
    var renderer: String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--arm="):
            arm=arg.get_slice("=",1)
        if arg.begins_with("--require-renderer="):
            renderer=arg.get_slice("=",1)
    if arm not in ["immediate","retain"] or renderer.is_empty() or DisplayServer.get_name().to_lower()=="headless" or RenderingServer.get_current_rendering_method()!=renderer:
        _fail("renderer or arm")
        return
    var cam=Camera3D.new()
    cam.projection=Camera3D.PROJECTION_ORTHOGONAL
    cam.size=4.0
    cam.position=Vector3(0,0,3)
    root.add_child(cam)
    cam.make_current()
    var total_start: int=Time.get_ticks_usec()
    var before: float=Performance.get_monitor(Performance.MEMORY_STATIC)
    var stamp: int=Time.get_ticks_usec()
    var mat=StandardMaterial3D.new()
    _mark("material_create",stamp,-1)
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color=Color(1,0,1,1)
    var freed: int=0
    for index in range(COUNT):
        var frame_start: int=Time.get_ticks_usec()
        stamp=Time.get_ticks_usec()
        var visual=MeshInstance3D.new()
        _mark("visual_new",stamp,index)
        stamp=Time.get_ticks_usec()
        visual.material_override=mat
        _mark("material_assign",stamp,index)
        stamp=Time.get_ticks_usec()
        var mesh=QuadMesh.new()
        mesh.size=Vector2(2,2)
        _mark("mesh_create",stamp,index)
        stamp=Time.get_ticks_usec()
        visual.mesh=mesh
        mesh=null
        _mark("mesh_assign",stamp,index)
        stamp=Time.get_ticks_usec()
        root.add_child(visual)
        _mark("attach",stamp,index)
        stamp=Time.get_ticks_usec()
        await process_frame
        await RenderingServer.frame_post_draw
        _mark("visible_draw_wait",stamp,index)
        var pixel: Color=root.get_texture().get_image().get_pixel(root.size.x/2,root.size.y/2)
        if pixel.r<0.8 or pixel.b<0.8 or pixel.g>0.2:
            visual.free()
            _fail("visible pixel "+str(pixel))
            return
        # Both arms detach before release. Retained nodes are never in tree.
        stamp=Time.get_ticks_usec()
        root.remove_child(visual)
        _mark("detach",stamp,index)
        if arm=="retain":
            if _retired.size()==CAP:
                stamp=Time.get_ticks_usec()
                var oldest: MeshInstance3D=_retired.pop_front()
                oldest.free()
                freed+=1
                _mark("retired_free",stamp,index)
            _retired.append(visual)
            _peak_retired=maxi(_peak_retired,_retired.size())
        else:
            stamp=Time.get_ticks_usec()
            visual.free()
            freed+=1
            _mark("retired_free",stamp,index)
        if _retired.size()>CAP:
            _fail("retired cap")
            return
        for node in _retired:
            if node.is_inside_tree():
                _fail("retired node visible")
                return
        stamp=Time.get_ticks_usec()
        await process_frame
        await RenderingServer.frame_post_draw
        _mark("empty_draw_wait",stamp,index)
        pixel=root.get_texture().get_image().get_pixel(root.size.x/2,root.size.y/2)
        if pixel.r>0.8 and pixel.b>0.8 and pixel.g<0.2:
            _fail("ghost pixel")
            return
        _frame_hist.add(float(Time.get_ticks_usec()-frame_start)/1000.0)
        _memory_peak=maxf(_memory_peak,Performance.get_monitor(Performance.MEMORY_STATIC))
    var drain_start: int=Time.get_ticks_usec()
    while not _retired.is_empty():
        stamp=Time.get_ticks_usec()
        var oldest: MeshInstance3D=_retired.pop_front()
        oldest.free()
        freed+=1
        _mark("drain_free",stamp,COUNT)
    mat=null
    await process_frame
    await RenderingServer.frame_post_draw
    var drain_us: int=Time.get_ticks_usec()-drain_start
    var total_us: int=Time.get_ticks_usec()-total_start
    if freed!=COUNT or not _retired.is_empty():
        _fail("ownership conservation")
        return
    var reports: Dictionary={}
    for name in _stage:
        reports[name]=_stage[name].report()
    print("M4_RESOURCE_LIFECYCLE ",JSON.stringify({"renderer":renderer,"arm":arm,"created":COUNT,"freed":freed,"visible_checks":COUNT,"ghost_checks":COUNT,"peak_retired":_peak_retired,"drain_us":drain_us,"total_us":total_us,"stages":reports,"slow_events":_slow,"cycle_wall_ms":_frame_hist.report(),"static_before_bytes":before,"static_peak_sampled_bytes":_memory_peak,"static_after_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"notes":"Synthetic quad, shared diagnostic material, readback waits included in cycle; fixed work, independent processes, persistent caches not flushed, retention is not reuse, no terrain collision or GPU time proof."}))
    cam.free()
    print("PASS: M4 lifecycle bounded detached ownership and rendered ghost rejection")
    quit(0)
