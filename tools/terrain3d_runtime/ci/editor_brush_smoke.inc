
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
    _create_terrain(1)
    await get_tree().process_frame
    if not is_instance_valid(_active):
        push_error("NATIVE_EDITOR_BRUSH_FAIL: create terrain: " + _status.text)
        get_tree().quit(1)
        return
    var data: Object = _active.get("data")
    if data == null or int(data.call("get_region_count")) != 1:
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
    _toggle_brush(false)
    print("NATIVE_EDITOR_BRUSH_OK regions=1 radius=8 power=3 changed=",changed," height=",height)
    # Never save the disposable scene.
    get_tree().quit(0)
