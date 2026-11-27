
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
    var previous_data_id: int = data.get_instance_id()
    var previous_directory := str(_active.get("data_directory"))
    _save_active()
    if not _status.text.begins_with("Terrain and scene saved;") or _brush.last_snapshot_path.is_empty() or str(_active.get("data_directory"))!=previous_directory or _active.get("data").get_instance_id()!=previous_data_id:
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
