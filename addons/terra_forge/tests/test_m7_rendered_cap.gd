extends "res://addons/terra_forge/tests/test_i1_rendered_terrain.gd"
## M7: one worker, variable outstanding capacity, real rendered support.
func _run() -> void:
    var expected: String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--require-renderer="):
            expected=arg.get_slice("=",1)
    if DisplayServer.get_name().to_lower()=="headless" or expected.is_empty() or RenderingServer.get_current_rendering_method()!=expected:
        _fail("M7 required renderer")
        return
    _camera=Camera3D.new()
    _camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    _camera.size=4.0
    root.add_child(_camera)
    _camera.make_current()
    for format in [0,1]:
        _builder=V1.new() if format==0 else V2.new()
        var err: Error=_builder.start(Vector2i(576,576),true) if format==0 else _builder.start(Vector2i(576,576))
        if err!=OK:
            _fail("M7 fixture")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=_builder.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("M7 fixture result")
            return
        var order: Array[int]=[1,2,4]
        if (format==1)!=(expected=="mobile"):
            order.reverse()
        var manifest: String=made["directory"].path_join("manifest.tfm" if format==0 else "manifest.tfm2")
        var hash: String=FileAccess.get_sha256(manifest)
        for cap in order:
            var result: Dictionary=await _route(made["directory"],format,4,cap)
            if result.get("error",FAILED)!=OK or result.get("job_cap",0)!=cap or result["physical_contact_samples"]!=720 or result["checkpoints"].size()!=5 or result["post_stop_pixels"]["total_magenta"]!=0:
                _fail("M7 "+str([format,cap,result]))
                return
            print("M7_RENDERED_CAP ",JSON.stringify({"renderer":expected,"format":format+1,"cap":cap,"metrics":result,"note":"One worker; cap is slots, not threads. Matched physical route, optional work may differ; extra draw waits, no Android FPS."}))
        if hash.is_empty() or FileAccess.get_sha256(manifest)!=hash:
            _fail("M7 source changed")
            return
        _builder.close()
        _builder=null
    _camera.free()
    _camera=null
    print("PASS: M7 rendered capacity matrix")
    quit(0)
