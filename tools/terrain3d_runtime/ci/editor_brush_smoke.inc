
# CI-only injection into disposable package copy; not shipped.
func _ci_editor_brush_smoke() -> void:
    get_editor_interface().open_scene_from_path("res://terraforge_workspace.tscn")
    for frame in range(12):
        await get_tree().process_frame
    var scene := get_editor_interface().get_edited_scene_root()
    if scene == null or scene.scene_file_path != "res://terraforge_workspace.tscn":
        push_error("NATIVE_EDITOR_BRUSH_FAIL: workspace not open")
        get_tree().quit(1)
        return
    if OS.get_environment("TF_EDITOR_REOPEN")=="1":
        await _ci_verify_reopened()
        return
    if _tool_select.get_item_text(0)!="Yükselt" or _tool_select.get_item_text(8)!="Aşındır" or _weather_mode.get_item_text(1)!="Su Aşınması" or _tool_select.get_item_text(4)!="Dağ Sırtı" or _tool_help.text.is_empty() or not _tool_select.is_item_disabled(6) or not _tool_select.is_item_disabled(7):
        push_error("NATIVE_EDITOR_BRUSH_FAIL: Turkish labels / tool IDs")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_TR_UI_OK")
    _create_terrain(4)
    await get_tree().process_frame
    if not is_instance_valid(_active):
        push_error("NATIVE_EDITOR_BRUSH_FAIL: create terrain: " + _status.text)
        get_tree().quit(1)
        return
    var data: Object = _active.get("data")
    if data == null or int(data.call("get_region_count")) != 16:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: native region count")
        get_tree().quit(1)
        return
    var center := Vector3(64,0,64)
    var hit: Vector3 = _active.call("get_intersection",center+Vector3.UP*20.0,Vector3.DOWN,false)
    if not hit.is_finite() or hit.distance_to(center)>0.01:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: intersection")
        get_tree().quit(1)
        return
    get_editor_interface().get_selection().clear()
    _toggle_brush(true)
    _brush.begin()
    var error := _brush.dab(hit,0,8.0,3.0)
    _brush.end()
    var height := float(data.call("get_height",center))
    if not error.is_empty() or _brush.last_changed_cells<=0 or absf(height-3.0)>0.00001:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: " + error + " height=" + str(height))
        get_tree().quit(1)
        return
    var changed := _brush.last_changed_cells
    if _brush.undo()!="Native undo applied." or not is_zero_approx(float(data.call("get_height",center))):
        push_error("NATIVE_EDITOR_BRUSH_FAIL: undo")
        get_tree().quit(1)
        return
    if _brush.redo()!="Native redo applied." or absf(float(data.call("get_height",center))-3.0)>0.00001:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: redo")
        get_tree().quit(1)
        return
    _brush.begin()
    var large_error := _brush.dab(Vector3(64,3,64),0,29.5,9.25)
    _brush.end()
    if not large_error.is_empty() or _brush.last_changed_cells<43000 or absf(float(data.call("get_height",center))-12.25)>0.00001:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: large 29.5m dab: "+large_error)
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_LARGE_BRUSH_OK radius=29.5 changed=",_brush.last_changed_cells)
    _brush.begin()
    large_error = _brush.dab(Vector3(64,12.25,64),0,36.0,1.0)
    _brush.end()
    if not large_error.is_empty() or _brush.last_changed_cells<64000 or absf(float(data.call("get_height",center))-13.25)>0.00001:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: 36m dab: "+large_error)
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_LARGE_BRUSH_OK radius=36 changed=",_brush.last_changed_cells)
    _toggle_brush(false)
    print("NATIVE_EDITOR_BRUSH_OK regions=16 radius=8 power=3 changed=",changed," height=",height)
    # Test actual panel save with a region boundary and a far-region sentinel.
    _brush.begin()
    var boundary_error := _brush.dab(Vector3(128,0,64),0,8.0,2.0)
    _brush.end()
    _brush.begin()
    var far_error := _brush.dab(Vector3(448,0,448),0,8.0,7.0)
    _brush.end()
    if not boundary_error.is_empty() or not far_error.is_empty() or absf(float(data.call("get_height",Vector3(128,0,64)))-2.0)>0.00001 or float(data.call("get_height",Vector3(127.75,0,64)))<=0.0:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: boundary or far edit")
        get_tree().quit(1)
        return
    # Ridge/Valley uses the same panel gesture commit path; cross-region path.
    var path: Array[Vector2] = [Vector2(120,96),Vector2(136,96)]
    var ridge_pos := Vector3(128,0,96)
    var prior := float(data.call("get_height",ridge_pos))
    _tool_select.select(4)
    _corridor_tool=4
    _corridor_radius=6.0
    _corridor_power=5.0
    _corridor_points.assign(path)
    _stroke_active=true
    _finish_stroke(true)
    if not _brush.corridor_busy() or float(data.call("get_height",ridge_pos))!=prior:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: async corridor dispatch")
        get_tree().quit(1)
        return
    var ridge_deadline := Time.get_ticks_msec()+10000
    while _brush.corridor_busy() and Time.get_ticks_msec()<ridge_deadline:
        await get_tree().process_frame
    if _brush.corridor_busy():
        push_error("NATIVE_EDITOR_BRUSH_FAIL: async ridge timeout")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_ASYNC_CORRIDOR_OK tool=4 worker_us=",_brush.last_corridor_worker_us," commit_us=",_brush.last_corridor_commit_us)
    var ridge_height := float(data.call("get_height",ridge_pos))
    if ridge_height<=prior or _brush.last_changed_cells<=0 or _brush.undo()!="Native undo applied." or float(data.call("get_height",ridge_pos))!=prior:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: Ridge corridor")
        get_tree().quit(1)
        return
    var valley_error := _brush.start_corridor(path,5,6.0,5.0)
    var valley_deadline := Time.get_ticks_msec()+10000
    while _brush.corridor_busy() and Time.get_ticks_msec()<valley_deadline:
        await get_tree().process_frame
    if not valley_error.is_empty() or _brush.corridor_busy() or float(data.call("get_height",ridge_pos))>=prior or _brush.undo()!="Native undo applied." or float(data.call("get_height",ridge_pos))!=prior:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: Valley corridor "+valley_error)
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_ASYNC_CORRIDOR_OK tool=5 worker_us=",_brush.last_corridor_worker_us," commit_us=",_brush.last_corridor_commit_us)
    if not _brush.start_corridor(path,4,6.0,5.0).is_empty():
        push_error("NATIVE_EDITOR_BRUSH_FAIL: corridor cancel setup")
        get_tree().quit(1)
        return
    if _brush.start_weather(Vector2(128,96),4.0,2.0,0).is_empty():
        push_error("NATIVE_EDITOR_BRUSH_FAIL: advanced mutual exclusion")
        get_tree().quit(1)
        return
    _brush.cancel_advanced()
    var corridor_cancel_deadline := Time.get_ticks_msec()+10000
    while _brush.corridor_busy() and Time.get_ticks_msec()<corridor_cancel_deadline:
        await get_tree().process_frame
    if _brush.advanced_busy() or float(data.call("get_height",ridge_pos))!=prior:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: cancelled corridor wrote")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_ASYNC_CORRIDOR_CANCEL_OK")
    print("NATIVE_EDITOR_RIDGE_VALLEY_OK signed=true undo=true")
    # One steep peak across region seam; each process is independently undoable.
    var weather_center := Vector3(128,0,112)
    _brush.begin()
    var peak_error := _brush.dab(weather_center,0,1.0,8.0)
    _brush.end()
    var peak := float(data.call("get_height",weather_center))
    if not peak_error.is_empty() or peak<7.9:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: Weather peak")
        get_tree().quit(1)
        return
    for mode in [0,1]:
        _tool_select.select(8)
        _on_tool_changed(8)
        _weather_mode.select(mode)
        _weather_mode_at_press=mode
        _corridor_tool=8
        _corridor_radius=4.0
        _corridor_power=2.0
        _corridor_points.assign([Vector2(128,112)])
        _stroke_active=true
        _finish_stroke(true)
        if not _brush.weather_busy() or float(data.call("get_height",weather_center))!=peak:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: async weather dispatch")
            get_tree().quit(1)
            return
        var deadline := Time.get_ticks_msec()+10000
        while _brush.weather_busy() and Time.get_ticks_msec()<deadline:
            await get_tree().process_frame
        if _brush.weather_busy():
            push_error("NATIVE_EDITOR_BRUSH_FAIL: async weather timeout")
            get_tree().quit(1)
            return
        print("NATIVE_EDITOR_ASYNC_WEATHER_OK mode=",mode," capture_us=",_brush.last_weather_capture_us," worker_us=",_brush.last_weather_worker_us," commit_us=",_brush.last_weather_commit_us)
        var changed_peak := float(data.call("get_height",weather_center))
        var count := _brush.last_changed_cells
        var mass := _brush.last_weather_mass_error
        var moved := _brush.last_weather_moved
        if count<=0 or changed_peak>=peak or moved<=0.0 or absf(mass)>0.001 or _brush.undo()!="Native undo applied." or float(data.call("get_height",weather_center))!=peak:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: Weather mode "+str(mode)+" "+_last_input_result)
            get_tree().quit(1)
            return
        print("NATIVE_EDITOR_WEATHER_OK mode=",mode," changed=",count," moved=",moved," mass_error=",mass)
    # Cancel a job and verify its result cannot mutate the live terrain.
    if not _brush.start_weather(Vector2(128,112),4.0,2.0,0).is_empty():
        push_error("NATIVE_EDITOR_BRUSH_FAIL: async cancel dispatch")
        get_tree().quit(1)
        return
    _brush.cancel_weather()
    var cancel_deadline := Time.get_ticks_msec()+10000
    while _brush.weather_busy() and Time.get_ticks_msec()<cancel_deadline:
        await get_tree().process_frame
    if _brush.weather_busy() or float(data.call("get_height",weather_center))!=peak:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: cancelled worker wrote live heights")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_ASYNC_CANCEL_OK")
    if _brush.undo()!="Native undo applied." or not is_zero_approx(float(data.call("get_height",weather_center))):
        push_error("NATIVE_EDITOR_BRUSH_FAIL: Weather setup undo")
        get_tree().quit(1)
        return
    # Native batch Smooth must visibly reduce a broad peak, not just average
    # four .25m neighbors. Compare same pre-edit hill and exact undo.
    var smooth_peak := float(data.call("get_height",center))
    _brush.begin()
    var smooth_error := _brush.dab(center,2,24.0,6.0)
    _brush.end()
    var smoothed := float(data.call("get_height",center))
    var filter_m := _brush.last_filter_half_width_m
    if not smooth_error.is_empty() or _brush.last_changed_cells<=0 or smooth_peak-smoothed<0.25 or filter_m<8.0 or _brush.undo()!="Native undo applied." or float(data.call("get_height",center))!=smooth_peak:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: scaled Smooth "+smooth_error+" peak "+str(smooth_peak)+" -> "+str(smoothed))
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_SMOOTH_OK before=",smooth_peak," after=",smoothed," filter_m=",filter_m," plan_us=",_brush.last_plan_us," write_us=",_brush.last_write_us)
    var target := Vector3(128,0,64)
    var original_target := float(data.call("get_height",target))
    _brush.begin()
    var lower_error := _brush.dab(target,1,8.0,1.0)
    _brush.end()
    if not lower_error.is_empty() or absf(float(data.call("get_height",target))-(original_target-1.0))>0.00001 or _brush.undo()!="Native undo applied.":
        push_error("NATIVE_EDITOR_BRUSH_FAIL: native Lower")
        get_tree().quit(1)
        return
    _brush.begin()
    var flatten_error := _brush.dab(target,3,8.0,12.0)
    _brush.end()
    if not flatten_error.is_empty() or _brush.last_changed_cells<=0 or float(data.call("get_height",target))!=original_target or _brush.undo()!="Native undo applied.":
        push_error("NATIVE_EDITOR_BRUSH_FAIL: native Flatten")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_NATIVE_BATCH_OK lower=true flatten=true undo=true")
    # Exercise the actual editor queue/pump/release lifecycle, including
    # the native scheduled bypass and one-dab-per-pump guarantee.
    var queue_a := Vector3(200,0,200)
    var queue_b := Vector3(208,0,200)
    var queue_before := float(data.call("get_height",queue_a))
    var queue_end_before := float(data.call("get_height",queue_b))
    _brush.begin()
    _corridor_tool=0
    _corridor_radius=4.0
    _corridor_power=1.0
    _stroke_active=true
    _begin_basic()
    _offer_basic(Vector2(queue_a.x,queue_a.z))
    _offer_basic(Vector2(queue_b.x,queue_b.z))
    if _stroke_sampler.pending_count()!=11 or float(data.call("get_height",queue_a))!=queue_before:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: queued input mutation or count")
        get_tree().quit(1)
        return
    _pump_basic()
    if _basic_dabs!=1 or _stroke_sampler.pending_count()!=10 or not _stroke_active:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: frame pump budget")
        get_tree().quit(1)
        return
    for frame in range(30):
        if _stroke_sampler.pending_count()==0:
            break
        await get_tree().process_frame
    _finish_stroke(true)
    if _stroke_active or _basic_dabs!=11 or float(data.call("get_height",queue_a))<=queue_before or float(data.call("get_height",queue_b))<=queue_end_before or _brush.undo()!="Native undo applied." or float(data.call("get_height",queue_a))!=queue_before or float(data.call("get_height",queue_b))!=queue_end_before:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: queued release / undo")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_STROKE_QUEUE_OK dabs=",_basic_dabs," max_dab_us=",_basic_max_us," undo=true")
    for release_tool in [0,1,3]:
        _brush.begin()
        _corridor_tool=release_tool
        _corridor_radius=4.0
        _corridor_power=1.0
        _stroke_active=true
        _begin_basic()
        _offer_basic(Vector2(queue_a.x,queue_a.z))
        _offer_basic(Vector2(queue_b.x,queue_b.z))
        _pump_basic()
        if _basic_dabs!=1 or _stroke_sampler.pending_count()!=10:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: release backlog setup")
            get_tree().quit(1)
            return
        var release_height := float(data.call("get_height",queue_a))
        var release_end := float(data.call("get_height",queue_b))
        var release_map := _brush.after.duplicate()
        var release_event := InputEventScreenTouch.new()
        release_event.index=7
        release_event.pressed=false
        _touch_index=7
        _touch_session=true
        _input(release_event)
        for frame in range(12):
            await get_tree().process_frame
        if _stroke_active or _stroke_sampler.pending_count()!=0 or _basic_dabs!=1 or float(data.call("get_height",queue_a))!=release_height or float(data.call("get_height",queue_b))!=release_end:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: late write after release")
            get_tree().quit(1)
            return
        if not release_map.is_empty():
            if _brush.history.back()["after"]!=release_map or _brush.undo()!="Native undo applied.":
                push_error("NATIVE_EDITOR_BRUSH_FAIL: release prefix history")
                get_tree().quit(1)
                return
        print("NATIVE_EDITOR_RELEASE_STOP_OK tool=",release_tool," pending=0 late_writes=0")
    # Small interior vs region seam: actual native transaction counters.
    var region_size := int(_active.call("get_region_size"))
    var spacing := float(_active.get("vertex_spacing"))
    var layer_bytes := region_size*region_size*4
    var centers := [Vector3(192,0,192),Vector3(256,0,192)]
    for i in range(centers.size()):
        var p: Vector3 = centers[i]
        var previous := float(data.call("get_height",p))
        _brush.begin()
        var profile_error := _brush.dab(p,0,2.0,1.0)
        _brush.end()
        var profile := _brush.last_write_profile
        var expected := i+1
        if not profile_error.is_empty() or not bool(profile.get("incremental_expected",false)) or int(profile.get("dirty_regions",0))!=expected or int(profile.get("layer_bytes_est",0))!=expected*layer_bytes or int(profile.get("changed_samples",0))<=0:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: upload profile "+str(profile)+" "+profile_error)
            get_tree().quit(1)
            return
        print("NATIVE_EDITOR_UPLOAD_PROFILE_OK case=",i," spacing=",spacing," profile=",JSON.stringify(profile))
        if _brush.undo()!="Native undo applied." or float(data.call("get_height",p))!=previous:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: upload profile undo")
            get_tree().quit(1)
            return
    # Q6d2: same native write dictionaries, scalar vs cached validation.
    # Compare exact readback/restore, reject invalid transaction without
    # touching a valid sample. Alternate order on the same runner.
    var write_centers := [Vector2(192,192),Vector2(256,256),Vector2(384,384)]
    var write_radii := [2.0,24.0,36.0]
    for write_case in range(3):
        var write_plan: Dictionary=data.call("tf_plan_brush",write_centers[write_case],0,write_radii[write_case],1.0,0.0)
        if not str(write_plan["error"]).is_empty() or write_plan["changes"].is_empty():
            push_error("NATIVE_EDITOR_BRUSH_FAIL: cached write fixture")
            get_tree().quit(1)
            return
        var old_times: Array[int]=[]
        var new_times: Array[int]=[]
        var old_total: Array[int]=[]
        var new_total: Array[int]=[]
        var resolved := 0
        for repetition in range(3):
            for use_cache in ([false,true] if repetition%2==0 else [true,false]):
                var write_started := Time.get_ticks_usec()
                var write_out: Dictionary=data.call("tf_write_brush",write_plan["changes"],use_cache)
                var total_us := Time.get_ticks_usec()-write_started
                var restore_out: Dictionary=data.call("tf_write_brush",write_plan["originals"],use_cache)
                if not str(write_out["error"]).is_empty() or not str(restore_out["error"]).is_empty() or write_out["actual"]!=write_plan["changes"] or restore_out["actual"]!=write_plan["originals"]:
                    push_error("NATIVE_EDITOR_BRUSH_FAIL: cached write parity "+str(write_case))
                    get_tree().quit(1)
                    return
                var validate_us := int(write_out["profile"]["validate_us"])
                if use_cache:
                    new_times.append(validate_us)
                    new_total.append(total_us)
                    resolved=int(write_out["profile"]["resolved_regions"])
                    if resolved!=int(write_out["profile"]["dirty_regions"]):
                        push_error("NATIVE_EDITOR_BRUSH_FAIL: cached write region count")
                        get_tree().quit(1)
                        return
                else:
                    old_times.append(validate_us)
                    old_total.append(total_us)
        old_times.sort()
        new_times.sort()
        old_total.sort()
        new_total.sort()
        print("NATIVE_EDITOR_WRITE_CACHE_OK case=",write_case," samples=",write_plan["changes"].size()," regions=",resolved," scalar_validate_us=",old_times[1]," cached_validate_us=",new_times[1]," scalar_total_us=",old_total[1]," cached_total_us=",new_total[1])
    var valid_key := Vector2i(768,768)
    var valid_pos := Vector3(192,0,192)
    var valid_height := float(data.call("get_height",valid_pos))
    for use_cache in [false,true]:
        var rejected: Dictionary=data.call("tf_write_brush",{valid_key:valid_height+1.0,Vector2i(-999999,-999999):1.0},use_cache)
        if str(rejected["error"]).is_empty() or float(data.call("get_height",valid_pos))!=valid_height:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: invalid cached transaction")
            get_tree().quit(1)
            return
    var blocked_pos := Vector3(192.25,0,192)
    var blocked_key := valid_key+Vector2i.RIGHT
    var control_before := int(data.call("get_control",blocked_pos))
    data.call("set_control_hole",blocked_pos,true)
    var blocked_out: Dictionary=data.call("tf_write_brush",{valid_key:valid_height+1.0,blocked_key:1.0},true)
    data.call("set_control",blocked_pos,control_before)
    if str(blocked_out["error"]).is_empty() or float(data.call("get_height",valid_pos))!=valid_height:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: cached transaction hole")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_WRITE_CACHE_REJECT_OK atomic=true hole=true")
    # Compare three native modes on identical Gaussian hill and micro-ripple.
    # Restore the isolated 273x273 fixture before the storage/reopen gate.
    var multi_center := Vector2(320,320)
    var multi_key := Vector2i(1280,1280)
    var multi_originals := {}
    var multi_hill := {}
    var multi_ripple := {}
    for z in range(-136,137):
        for x in range(-136,137):
            var key := multi_key+Vector2i(x,z)
            var pos := Vector3(key.x*0.25,0,key.y*0.25)
            multi_originals[key]=float(data.call("get_height",pos))
            var h := 13.25*exp(-float(x*x+z*z)*0.0625/128.0)
            multi_hill[key]=h
            multi_ripple[key]=h+0.2*cos(TAU*x/8.0)*cos(TAU*z/8.0)
    var peak_plain: Array[float] = []
    var peak_detail: Array[float] = []
    var mode_times: Array[int] = []
    for variant in [multi_hill,multi_ripple]:
        var setup: Dictionary = data.call("tf_write_brush",variant)
        if not str(setup["error"]).is_empty():
            push_error("NATIVE_EDITOR_BRUSH_FAIL: multiscale setup")
            get_tree().quit(1)
            return
        for mode in range(3):
            var start_us := Time.get_ticks_usec()
            var plan: Dictionary = data.call("tf_plan_brush",multi_center,2,24.0,6.0,0.0,mode)
            var elapsed := Time.get_ticks_usec()-start_us
            if not str(plan["error"]).is_empty() or not plan["changes"].has(multi_key):
                push_error("NATIVE_EDITOR_BRUSH_FAIL: multiscale plan "+str(mode)+" "+str(plan["error"]))
                get_tree().quit(1)
                return
            if variant==multi_hill:
                peak_plain.append(float(plan["changes"][multi_key]))
                mode_times.append(elapsed)
            else:
                peak_detail.append(float(plan["changes"][multi_key]))
    var restore: Dictionary = data.call("tf_write_brush",multi_originals)
    if not str(restore["error"]).is_empty():
        push_error("NATIVE_EDITOR_BRUSH_FAIL: multiscale restore")
        get_tree().quit(1)
        return
    var retention: Array[float] = []
    for mode in range(3):
        retention.append(absf(peak_detail[mode]-peak_plain[mode])/0.2)
    if retention[0]>0.15 or retention[1]<0.8 or retention[2]>0.15 or 13.25-peak_plain[1]<1.0 or absf(13.25-peak_plain[2])>0.25:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: multiscale metrics "+str(retention)+" "+str(peak_plain))
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_MULTISCALE_OK peaks=",peak_plain," retention=",retention," plan_us=",mode_times)
    # Actual panel selection -> captured gesture mode -> scheduler -> native write.
    _tool_select.select(2)
    _on_tool_changed(2)
    if not _advanced_row.visible or not _smooth_mode.visible or _weather_mode.visible or _smooth_mode.get_item_count()!=3:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: Smooth panel")
        get_tree().quit(1)
        return
    for mode in [0,1,2]:
        _smooth_mode.select(mode)
        _refresh_tool_help()
        if _tool_help.text.is_empty():
            push_error("NATIVE_EDITOR_BRUSH_FAIL: Smooth help")
            get_tree().quit(1)
            return
        var expected_plan: Dictionary = data.call("tf_plan_brush",Vector2(center.x,center.z),2,24.0,6.0,0.0,mode)
        var center_key := Vector2i(roundi(center.x/spacing),roundi(center.z/spacing))
        if not str(expected_plan["error"]).is_empty() or not expected_plan["changes"].has(center_key):
            push_error("NATIVE_EDITOR_BRUSH_FAIL: Smooth UI reference plan")
            get_tree().quit(1)
            return
        _brush.begin()
        _corridor_tool=2
        _corridor_radius=24.0
        _corridor_power=6.0
        _stroke_active=true
        _begin_basic()
        _smooth_mode.select((mode+1)%3)
        _offer_basic(Vector2(center.x,center.z))
        _pump_basic()
        if not _brush.smooth_busy() or float(data.call("get_height",center))!=smooth_peak:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: Smooth queue dispatch changed terrain")
            get_tree().quit(1)
            return
        var live_smooth_deadline := Time.get_ticks_msec()+10000
        while _brush.smooth_busy() and Time.get_ticks_msec()<live_smooth_deadline:
            await get_tree().process_frame
        _finish_stroke(true)
        print("NATIVE_EDITOR_SMOOTH_QUEUE_TIMING mode=",mode," capture_us=",_brush.last_smooth_capture_us," worker_us=",_brush.last_smooth_worker_us," verify_us=",_brush.last_smooth_verify_us," commit_us=",_brush.last_smooth_commit_us," max_pump_us=",_basic_max_us)
        if _stroke_active or _basic_dabs!=1 or float(data.call("get_height",center))!=float(expected_plan["changes"][center_key]) or _brush.undo()!="Native undo applied." or float(data.call("get_height",center))!=smooth_peak:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: Smooth UI mode "+str(mode))
            get_tree().quit(1)
            return
    _smooth_mode.select(0)
    _tool_select.select(8)
    _on_tool_changed(8)
    if _smooth_mode.visible or not _weather_mode.visible:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: Smooth shared row")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_SMOOTH_UI_OK modes=3 frozen=true undo=true")
    # Q6d1: compare scalar/bulk on identical live RF, including region seams,
    # missing negative-coordinate neighbor, and a temporary control-map hole.
    for bulk_pos in [Vector2(center.x,center.z),Vector2(128,128),Vector2(0,0)]:
        for bulk_mode in [0,1,2]:
            var scalar_times: Array[int]=[]
            var bulk_times: Array[int]=[]
            var scalar_verify_times: Array[int]=[]
            var bulk_verify_times: Array[int]=[]
            for repeat in range(3):
                # Alternate order to reduce warm-cache bias.
                for use_bulk in ([false,true] if repeat%2==0 else [true,false]):
                    var sample_start := Time.get_ticks_usec()
                    var sample: Dictionary=data.call("tf_capture_smooth",bulk_pos,24.0,6.0,bulk_mode,use_bulk)
                    var elapsed := Time.get_ticks_usec()-sample_start
                    if not str(sample["error"]).is_empty():
                        push_error("NATIVE_EDITOR_BRUSH_FAIL: bulk capture")
                        get_tree().quit(1)
                        return
                    var verification_start := Time.get_ticks_usec()
                    var verified := bool(data.call("tf_verify_smooth_snapshot",sample,use_bulk))
                    var verify_elapsed := Time.get_ticks_usec()-verification_start
                    if not verified or not bool(data.call("tf_verify_smooth_snapshot",sample,not use_bulk)):
                        push_error("NATIVE_EDITOR_BRUSH_FAIL: bulk/scalar mismatch "+str(bulk_pos))
                        get_tree().quit(1)
                        return
                    if use_bulk:
                        bulk_times.append(elapsed)
                        bulk_verify_times.append(verify_elapsed)
                    else:
                        scalar_times.append(elapsed)
                        scalar_verify_times.append(verify_elapsed)
            scalar_times.sort()
            bulk_times.sort()
            scalar_verify_times.sort()
            bulk_verify_times.sort()
            print("NATIVE_EDITOR_BULK_RF_OK pos=",bulk_pos," mode=",bulk_mode," scalar_capture_us=",scalar_times[1]," bulk_capture_us=",bulk_times[1]," scalar_verify_us=",scalar_verify_times[1]," bulk_verify_us=",bulk_verify_times[1])
    var test_hole_pos := Vector3(128,0,128)
    var original_control := int(data.call("get_control",test_hole_pos))
    var hole_before: Dictionary=data.call("tf_capture_smooth",Vector2(128,128),4.0,6.0,1)
    data.call("set_control_hole",test_hole_pos,true)
    var hole_after: Dictionary=data.call("tf_capture_smooth",Vector2(128,128),4.0,6.0,1)
    var hole_ok := bool(data.call("get_control_hole",test_hole_pos)) and not bool(data.call("tf_verify_smooth_snapshot",hole_before,true)) and bool(data.call("tf_verify_smooth_snapshot",hole_after,false))
    data.call("set_control",test_hole_pos,original_control)
    if not hole_ok or not bool(data.call("tf_verify_smooth_snapshot",hole_before,true)):
        push_error("NATIVE_EDITOR_BRUSH_FAIL: bulk hole parity")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_BULK_RF_HOLE_OK")
    # Q6c1: same native result on isolated worker, with full halo verification.
    var SmoothWorker = preload("res://addons/terraforge_native/native_smooth_worker.gd")
    var smooth_worker = SmoothWorker.new()
    for mode in [0,1,2]:
        var capture_start := Time.get_ticks_usec()
        var snap: Dictionary = data.call("tf_capture_smooth",Vector2(center.x,center.z),24.0,6.0,mode)
        var capture_us := Time.get_ticks_usec()-capture_start
        var reference: Dictionary = data.call("tf_plan_brush",Vector2(center.x,center.z),2,24.0,6.0,0.0,mode)
        if not str(snap["error"]).is_empty() or smooth_worker.start(snap)!=OK:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: smooth snapshot dispatch")
            smooth_worker.shutdown()
            get_tree().quit(1)
            return
        var outcome: Dictionary = {}
        var smooth_deadline := Time.get_ticks_msec()+10000
        while outcome.is_empty() and Time.get_ticks_msec()<smooth_deadline:
            await get_tree().process_frame
            outcome=smooth_worker.poll()
        var verify_start := Time.get_ticks_usec()
        var valid := bool(data.call("tf_verify_smooth_snapshot",snap))
        var verify_us := Time.get_ticks_usec()-verify_start
        if outcome.is_empty() or not str(outcome.get("error","invalid")).is_empty() or not valid or outcome["changes"]!=reference["changes"] or outcome["originals"]!=reference["originals"]:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: smooth worker parity "+str(mode))
            smooth_worker.shutdown()
            get_tree().quit(1)
            return
        print("NATIVE_EDITOR_ASYNC_SMOOTH_PARITY_OK mode=",mode," cells=",outcome["changes"].size()," capture_us=",capture_us," worker_us=",outcome["worker_us"]," verify_us=",verify_us)
    # Outside brush footprint, inside macro halo: must invalidate the result.
    var stale_snap: Dictionary = data.call("tf_capture_smooth",Vector2(center.x,center.z),24.0,6.0,1)
    var halo_key := Vector2i(roundi((center.x+27.0)/spacing),roundi(center.z/spacing))
    var halo_pos := Vector3(halo_key.x*spacing,0,halo_key.y*spacing)
    var halo_old := float(data.call("get_height",halo_pos))
    var altered: Dictionary = data.call("tf_write_brush",{halo_key:halo_old+1.0})
    var stale_rejected := not bool(data.call("tf_verify_smooth_snapshot",stale_snap))
    var halo_restore: Dictionary = data.call("tf_write_brush",{halo_key:halo_old})
    if not str(altered["error"]).is_empty() or not str(halo_restore["error"]).is_empty() or not stale_rejected or not bool(data.call("tf_verify_smooth_snapshot",stale_snap)):
        push_error("NATIVE_EDITOR_BRUSH_FAIL: stale Smooth halo")
        get_tree().quit(1)
        return
    if smooth_worker.start(stale_snap)!=OK:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: smooth cancel dispatch")
        get_tree().quit(1)
        return
    smooth_worker.cancel()
    var canceled: Dictionary = {}
    var smooth_cancel_deadline := Time.get_ticks_msec()+10000
    while canceled.is_empty() and Time.get_ticks_msec()<smooth_cancel_deadline:
        await get_tree().process_frame
        canceled=smooth_worker.poll()
    if canceled.get("error","")!="Yumuşatma iptal edildi." or float(data.call("get_height",center))!=smooth_peak:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: smooth cancel")
        smooth_worker.shutdown()
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_ASYNC_SMOOTH_STALE_CANCEL_OK halo=true")
    # Multiple dependent dabs: compare sequential sync reference and actual
    # queue; undo must restore every modified height, not merely the center.
    var seq_a := Vector2(center.x,center.z)
    var seq_b := seq_a+Vector2(2.0,0.0)
    _brush.begin()
    var seq_err_a := _brush.dab(Vector3(seq_a.x,0,seq_a.y),2,10.0,6.0,true,1)
    var seq_err_b := _brush.dab(Vector3(seq_b.x,0,seq_b.y),2,10.0,6.0,true,1)
    var seq_expected := _brush.after.duplicate()
    var seq_originals := _brush.before.duplicate()
    _brush.end()
    if not seq_err_a.is_empty() or not seq_err_b.is_empty() or seq_expected.is_empty() or _brush.undo()!="Native undo applied.":
        push_error("NATIVE_EDITOR_BRUSH_FAIL: sequential Smooth reference")
        get_tree().quit(1)
        return
    _tool_select.select(2)
    _on_tool_changed(2)
    _smooth_mode.select(1)
    _brush.begin()
    _corridor_tool=2
    _corridor_radius=10.0
    _corridor_power=6.0
    _stroke_active=true
    _begin_basic()
    _offer_basic(seq_a)
    _offer_basic(seq_b)
    var seq_deadline := Time.get_ticks_msec()+10000
    while (_stroke_sampler.pending_count()>0 or _brush.smooth_busy()) and Time.get_ticks_msec()<seq_deadline:
        await get_tree().process_frame
    _finish_stroke(true)
    if _stroke_active or _basic_dabs!=2 or _brush.history.is_empty() or _brush.history.back()["after"]!=seq_expected or _brush.history.back()["before"]!=seq_originals or _brush.undo()!="Native undo applied.":
        push_error("NATIVE_EDITOR_BRUSH_FAIL: sequential async Smooth equality")
        get_tree().quit(1)
        return
    # Cancel in-flight live queue before polling; no new history or writes.
    var history_before := _brush.history.size()
    _brush.begin()
    _corridor_tool=2
    _corridor_radius=24.0
    _corridor_power=6.0
    _stroke_active=true
    _begin_basic()
    _offer_basic(seq_a)
    _pump_basic()
    var smooth_release := InputEventMouseButton.new()
    smooth_release.button_index=MOUSE_BUTTON_LEFT
    smooth_release.pressed=false
    _input(smooth_release)
    var queue_cancel_deadline := Time.get_ticks_msec()+10000
    while _brush.smooth_busy() and Time.get_ticks_msec()<queue_cancel_deadline:
        await get_tree().process_frame
    if _brush.smooth_busy() or _brush.history.size()!=history_before or float(data.call("get_height",center))!=smooth_peak:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: live Smooth cancellation")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_RELEASE_STOP_OK tool=2 pending=0 late_writes=0")
    print("NATIVE_EDITOR_SMOOTH_QUEUE_OK sequential=true undo=true cancel=true")
    # Same ray/terrain on both pickers: exact Vector3 parity, including sky,
    # outside inward, outside outward, seams and the vertical shortcut.
    var ray_cases := [
        [Vector3(64,80,64),Vector3.DOWN],
        [Vector3(64,80,64),Vector3(0.3,-1,0.2)],
        [Vector3(64,80,64),Vector3(1,0.3,0)],
        [Vector3(-30,50,64),Vector3(1,-0.5,0)],
        [Vector3(-30,50,64),Vector3(-1,-0.5,0)],
        [Vector3(128,50,128),Vector3(-0.2,-1,0.3)],
        [Vector3(64,-5,64),Vector3(0.3,-1,0.2)],
        [Vector3(1000,80,1000),Vector3(1,0,1)],
        [Vector3(64,80,64),Vector3.UP]
    ]
    for ray_case in range(ray_cases.size()):
        var ray_origin: Vector3=ray_cases[ray_case][0]
        var ray_dir: Vector3=ray_cases[ray_case][1]
        var legacy_times: Array[int]=[]
        var broad_times: Array[int]=[]
        for repetition in range(5):
            var legacy_hit: Vector3
            var broad_hit: Vector3
            for broad in ([false,true] if repetition%2==0 else [true,false]):
                var ray_start := Time.get_ticks_usec()
                if broad:
                    broad_hit=data.call("tf_pick_brush",ray_origin,ray_dir)
                    broad_times.append(Time.get_ticks_usec()-ray_start)
                else:
                    legacy_hit=_active.call("get_intersection",ray_origin,ray_dir,false)
                    legacy_times.append(Time.get_ticks_usec()-ray_start)
            if legacy_hit!=broad_hit:
                push_error("NATIVE_EDITOR_BRUSH_FAIL: ray broadphase parity "+str(ray_case)+" "+str(legacy_hit)+" "+str(broad_hit))
                get_tree().quit(1)
                return
        legacy_times.sort()
        broad_times.sort()
        print("NATIVE_EDITOR_RAY_BROAD_OK case=",ray_case," legacy_us=",legacy_times[2]," broad_us=",broad_times[2])
    # Real shared ray path: vertical hit, oblique hit and sky miss; compare
    # measured CPU timings, no assumption about mobile GPU or frame budget.
    _start_drop_trace()
    var ray_probe: Array = []
    for direction in [Vector3.DOWN,Vector3(0.3,-1,0.2),Vector3(1,0.3,0)]:
        var ray_times: Array[int]=[]
        for repeat in range(5):
            var ray_started := Time.get_ticks_usec()
            _trace_ray(Vector3(64,80,64),direction)
            ray_times.append(Time.get_ticks_usec()-ray_started)
        ray_times.sort()
        ray_probe.append(ray_times[2])
    var probe_plan: Dictionary=data.call("tf_plan_brush",Vector2(192,192),0,2.0,1.0,0.0)
    _brush.begin()
    var probe_error := _brush.dab(Vector3(192,0,192),0,2.0,1.0)
    _brush.end()
    if not probe_error.is_empty() or _brush.undo()!="Native undo applied.":
        push_error("NATIVE_EDITOR_BRUSH_FAIL: drop trace write")
        get_tree().quit(1)
        return
    for frame in range(3):
        await get_tree().process_frame
    var trace_path := _stop_drop_trace()
    var trace_data: Variant=JSON.parse_string(FileAccess.get_file_as_string(trace_path)) if not trace_path.is_empty() else null
    if not trace_data is Dictionary or trace_data["rows"].size()<2 or trace_data["columns"].size()!=DROP_COLUMNS.size():
        push_error("NATIVE_EDITOR_BRUSH_FAIL: drop trace export")
        get_tree().quit(1)
        return
    var total_rays := 0
    var total_writes := 0
    for trace_row in trace_data["rows"]:
        total_rays+=int(trace_row[5])
        total_writes+=int(trace_row[11])
    if total_rays!=15 or total_writes<2:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: drop trace counters")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_DROP_TRACE_OK rays=",total_rays," writes=",total_writes," ray_median_us=",ray_probe)
    var previous_data_id: int = data.get_instance_id()
    var previous_directory := str(_active.get("data_directory"))
    _save_active()
    if not _raw_status.begins_with("Terrain and scene saved;") or _brush.last_snapshot_path.is_empty() or str(_active.get("data_directory"))!=previous_directory or _active.get("data").get_instance_id()!=previous_data_id:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: panel save / live data identity: "+_status.text)
        get_tree().quit(1)
        return
    var scene_bytes := FileAccess.get_file_as_bytes("res://terraforge_workspace.tscn").size()
    var saved_region_path := str(_active.get("data_directory")).path_join("terrain3d_00_00.res")
    var saved_region := ResourceLoader.load(saved_region_path,"Terrain3DRegion",ResourceLoader.CACHE_MODE_IGNORE)
    if scene_bytes>262144 or saved_region==null:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: scene storage "+str(scene_bytes))
        get_tree().quit(1)
        return
    var saved_height: Image = saved_region.call("get_height_map")
    if saved_height==null or saved_height.get_format()!=Image.FORMAT_RF or absf(saved_height.get_pixel(256,256).r-13.25)>0.00001:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: persisted RF height")
        get_tree().quit(1)
        return
    print("NATIVE_EDITOR_EXTERNAL_STORAGE_OK scene_bytes=",scene_bytes)
    print("NATIVE_EDITOR_SNAPSHOT_OK regions=16 no_reload=true")
    get_tree().quit(0)

func _ci_verify_reopened() -> void:
    var root := get_editor_interface().get_edited_scene_root()
    var nodes: Array[Node3D] = []
    _find_workspaces(root,nodes)
    if nodes.size()!=1:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: reopened workspace missing")
        get_tree().quit(1)
        return
    var terrain := nodes[0]
    var data: Object = terrain.get("data")
    if data==null or int(data.call("get_region_count"))!=16:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: reopened region count")
        get_tree().quit(1)
        return
    for probe in [[Vector3(64,0,64),13.25],[Vector3(128,0,64),2.0],[Vector3(448,0,448),7.0]]:
        if absf(float(data.call("get_height",probe[0]))-float(probe[1]))>0.00001:
            push_error("NATIVE_EDITOR_BRUSH_FAIL: reopened height "+str(probe))
            get_tree().quit(1)
            return
    var live_folder := str(terrain.get("data_directory"))
    var backup_dirs := DirAccess.get_directories_at("res://terraforge_data/backups")
    if backup_dirs.size()!=1:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: backup count")
        get_tree().quit(1)
        return
    var backup_folder := "res://terraforge_data/backups".path_join(backup_dirs[0])
    var manifest := JSON.parse_string(FileAccess.get_file_as_string(backup_folder.path_join("snapshot.json"))) as Dictionary
    if not manifest.has("regions") or manifest["regions"].size()!=16:
        push_error("NATIVE_EDITOR_BRUSH_FAIL: backup manifest")
        get_tree().quit(1)
        return
    var verifier := Brush.new()
    for entry in manifest["regions"]:
        var loc := Vector2i(int(entry["x"]),int(entry["z"]))
        var live: Resource = data.call("get_region",loc)
        var backup_path := backup_folder.path_join(str(entry["file"]))
        var backup := ResourceLoader.load(backup_path,"Terrain3DRegion",ResourceLoader.CACHE_MODE_IGNORE)
        var disk := ResourceLoader.load(live_folder.path_join(str(entry["file"])),"Terrain3DRegion",ResourceLoader.CACHE_MODE_IGNORE)
        if live==null or backup==null or disk==null or FileAccess.get_sha256(backup_path)!=entry["sha256"] or verifier._map_hashes(live)!=verifier._map_hashes(backup) or verifier._map_hashes(disk)!=verifier._map_hashes(backup):
            push_error("NATIVE_EDITOR_BRUSH_FAIL: reopened map hash mismatch "+str(loc))
            get_tree().quit(1)
            return
    print("NATIVE_EDITOR_REOPEN_OK regions=16 exact_height_samples=4194304 maps_match=true")
    get_tree().quit(0)
