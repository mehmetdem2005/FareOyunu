extends "res://addons/terra_forge/tests/test_i1_rendered_terrain.gd"
## M9 rendered interaction: diagnostic pixels, actual capsule and bounded ownership.
## Same fixed worker cap2; no production changes or FPS claim.
var _pages: int=16

func _route_page_cap() -> int:
    return _pages

func _run() -> void:
    var expected: String=""
    var selected_format: int=-1
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--require-renderer="):
            expected=arg.get_slice("=",1)
        elif arg.begins_with("--format="):
            selected_format=int(arg.get_slice("=",1))
    if DisplayServer.get_name().to_lower()=="headless" or expected.is_empty() or RenderingServer.get_current_rendering_method()!=expected or selected_format not in [0,1]:
        _fail("M9 rendered requires exact renderer and format")
        return
    _camera=Camera3D.new()
    _camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    _camera.size=4.0
    root.add_child(_camera)
    _camera.make_current()
    var format: int=selected_format
    _builder=V1.new() if format==0 else V2.new()
    var err: Error=_builder.start(Vector2i(576,576),true) if format==0 else _builder.start(Vector2i(576,576))
    if err!=OK:
        _fail("M9 rendered fixture")
        return
    var made: Dictionary={}
    for attempt in range(15000):
        made=_builder.take_result()
        if made["error"]!=ERR_BUSY:
            break
        OS.delay_msec(2)
    if made.get("error",FAILED)!=OK:
        _fail("M9 rendered fixture result")
        return
    var directory: String=made["directory"]
    var manifest: String=directory.path_join("manifest.tfm" if format==0 else "manifest.tfm2")
    var hash: String=FileAccess.get_sha256(manifest)
    var caps: Array[int]=[16,32]
    if (format==1)!=(expected=="mobile"):
        caps.reverse()
    var count: int=0
    for cap in caps:
        _pages=cap
        var order: Array[int]=[4,5,6]
        if (cap==32)!=(format==1):
            order.reverse()
        for arm in order:
            var r: Dictionary=await _route(directory,format,arm,2)
            if r.get("error",FAILED)!=OK or r.get("page_cap",0)!=cap or r.get("job_cap",0)!=2 or r.get("physical_contact_samples",0)!=720:
                _fail("M9 rendered route "+str([format,cap,arm,r]))
                return
            if r["missing_rays"]!=0 or r["airborne_ticks"]!=0 or r["checkpoints"].size()!=5 or r["post_stop_pixels"]["total_magenta"]!=0 or r["peak_pages"]>cap or r["source_float_bytes"]>cap*4096 or r["source_reads"]<=0 or r["mesh_builds"]<=0:
                _fail("M9 rendered invariant "+str([format,cap,arm,r]))
                return
            for pixels in r["checkpoints"]:
                if pixels.get("center_magenta",-1)!=256:
                    _fail("M9 rendered checkpoint")
                    return
            count+=1
            print("M9_RENDERED_INTERACTION ",JSON.stringify({"renderer":expected,"format":format+1,"page_cap":cap,"arm":arm,"reads_per_build":float(r["source_reads"])/float(r["mesh_builds"]),"metrics":r,"note":"Matched target route and fixed cap2; goal timing and optional work may differ, extra draw waits; not device FPS or GPU timing."}))
    if count!=6 or hash.is_empty() or FileAccess.get_sha256(manifest)!=hash:
        _fail("M9 rendered completeness or source changed")
        return
    _builder.close()
    _builder=null
    _camera.free()
    _camera=null
    print("PASS: M9 rendered interaction 6 routes")
    quit(0)
