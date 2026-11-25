extends Node
const CAPTURE = preload("res://capture.gd")
const PROFILE = preload("res://addons/terra_forge/profiling/profile_scene.gd")
const ADAPTER = preload("res://test_adapter.gd")
const REPORT_A = "user://tf_android_report_a.json"
const REPORT_B = "user://tf_android_report_b.json"
const FULL_DIR = "user://tf_android_details"
var _log = CAPTURE.new()
var _inventory: Dictionary
var _report: Dictionary
var _status: Label
var _progress: ProgressBar
var _copy: Button
var _export_dialog_open := false
var _restart_requested := false
var _retry_requested := false
var _export_path: String = ""
var _stop: Button
var _restart: Button
var _detail: Label
var _layer: CanvasLayer
var _paused := false
var _busy := false
var _ci := false
var _smoke := false
var _seq := 0
var _names: Array = []
var _shard := 0
var _phase := "tests"
var _last_sample: int = 0
var _rss_peak: int = 0
var _static_peak: int = 0

func _init() -> void:
    OS.add_logger(_log)

func _ready() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    _ci = args.has("--ci") or args.has("--smoke")
    _smoke = args.has("--smoke")
    for arg in args:
        if arg.begins_with("--shard="):
            _shard = int(arg.get_slice("=",1))
    _make_ui()
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://suite.json"))
    if not parsed is Dictionary:
        _status.text = "Test envanteri okunamadı."
        if _ci:
            get_tree().quit(1)
        return
    _inventory = parsed
    _names = _inventory["tests"].duplicate()
    if _smoke:
        _names = ["test_height_store","test_data_safety","test_guarded_capsule"]
    elif _shard > 0:
        var selected: Array = []
        for i in range(_names.size()):
            if i % 3 == _shard - 1:
                selected.append(_names[i])
        _names = selected
    DirAccess.make_dir_recursive_absolute(FULL_DIR)
    if _ci:
        _report = _new_report()
    else:
        _report = _load_checkpoint()
        if _report.is_empty():
            _report = _new_report()
        # Keep old checkpoints from the first package when terrain and inventory match.
        if not _report.has("interruptions"):
            _report["interruptions"] = []
        if not _report.has("runner_builds"):
            _report["runner_builds"] = [_report.get("build_commit","")]
        if not _report["runner_builds"].has(_inventory["build_commit"]):
            _report["runner_builds"].append(_inventory["build_commit"])
        _report["build_commit"] = _inventory["build_commit"]
        if _report.get("active_test","") != "":
            var interrupted: String = _report["active_test"]
            _report["interruptions"].append({"name":interrupted,"reason":"Previous process ended before completion","utc":Time.get_datetime_string_from_system(true)})
            _report["active_test"] = ""
        if _report.get("active_profile","") != "":
            _report["profile_interruptions"].append(_report["active_profile"])
            _report["active_profile"] = ""
    if not _ci:
        # Migrate old interrupted records to the retry queue, retaining evidence.
        var retained: Array = []
        for t in _report["tests"]:
            if t.get("status","") == "interrupted":
                _report["interruptions"].append(t)
                _report["state"]="running"
            else:
                retained.append(t)
        _report["tests"]=retained
    _save()
    if _report.get("state","") == "complete":
        _status.text = "Test tamamlandı. JSON kopyala."
        _update_ui()
        return
    call_deferred("_run_all")

func _new_report() -> Dictionary:
    return {"schema":"TF_ANDROID_SUITE_1","build_commit":_inventory["build_commit"],"terrain_commit":_inventory["terrain_commit"],"started_utc":Time.get_datetime_string_from_system(true),"device":{"model":OS.get_model_name(),"os":OS.get_name(),"os_version":OS.get_version(),"cpu":OS.get_processor_name(),"cores":OS.get_processor_count(),"godot":Engine.get_version_info().get("string",""),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"headless":DisplayServer.get_name()=="headless","viewport":[get_viewport().size.x,get_viewport().size.y],"physics_hz":Engine.physics_ticks_per_second},"planned_tests":_names.size(),"tests":[],"profiles":[],"profile_interruptions":[],"active_test":"","active_profile":"","state":"running","sequence":0,"notes":"SceneTree tests adapted to Node; shared process, not independent headless CI. Real renderer profiles separate. Timing includes scheduling, not GPU timestamp. Memory is sampled. No device identifier or game data."}

func _load_checkpoint() -> Dictionary:
    var best: Dictionary = {}
    for path in [REPORT_A,REPORT_B]:
        if not FileAccess.file_exists(path):
            continue
        var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if data is Dictionary and data.get("terrain_commit","")==_inventory["terrain_commit"] and int(data.get("planned_tests",-1))==_names.size() and int(data.get("sequence",-1))>int(best.get("sequence",-1)):
            best = data
    _seq = int(best.get("sequence",0))
    return best

func _save() -> void:
    _seq += 1
    _report["sequence"] = _seq
    _report["updated_utc"] = Time.get_datetime_string_from_system(true)
    var path: String = REPORT_A if _seq % 2 == 0 else REPORT_B
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(_report))
        file.flush()
        file.close()

func _make_ui() -> void:
    _layer = CanvasLayer.new()
    _layer.layer = 100
    add_child(_layer)
    var margin := MarginContainer.new()
    _layer.add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    margin.add_theme_constant_override("margin_left",12)
    margin.add_theme_constant_override("margin_right",12)
    margin.add_theme_constant_override("margin_top",8)
    var panel := PanelContainer.new()
    margin.add_child(panel)
    var v := VBoxContainer.new()
    panel.add_child(v)
    _status = Label.new()
    _status.text = "TerraForge Android • otomatik test"
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(_status)
    _progress = ProgressBar.new()
    _progress.max_value=90
    v.add_child(_progress)
    _detail = Label.new()
    _detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(_detail)
    var row := HBoxContainer.new()
    v.add_child(row)
    _copy = Button.new()
    _copy.text = "JSON DOSYASINI KAYDET"
    _copy.custom_minimum_size.y=54
    _copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    row.add_child(_copy)
    _copy.pressed.connect(_export_json)
    _stop = Button.new()
    _stop.text="Sıradaki testte dur"
    _stop.custom_minimum_size.y=54
    row.add_child(_stop)
    _stop.pressed.connect(_toggle_pause)
    _restart = Button.new()
    _restart.text="Baştan başlat"
    _restart.disabled=false
    row.add_child(_restart)
    _restart.pressed.connect(_request_reset)
    var retry := Button.new()
    retry.text = "Hatalıları tekrar dene"
    retry.custom_minimum_size.y=44
    v.add_child(retry)
    retry.pressed.connect(_request_retry)

func _export_json() -> void:
    if _report.is_empty() or _export_dialog_open:
        return
    _save()
    var filename: String = "TerraForge_Android_" + Time.get_datetime_string_from_system().replace(":","-") + ".json"
    var downloads: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
    var target: String = downloads.path_join(filename) if not downloads.is_empty() else ""
    # Direct Download write where the Android editor already has access.
    if not target.is_empty() and _write_export(target):
        return
    # Android scoped storage: request just one destination through the native SAF picker.
    _export_dialog_open=true
    var status: Error=DisplayServer.file_dialog_show("TerraForge raporunu kaydet",downloads,filename,false,DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,PackedStringArray(["*.json ; JSON raporu"]),_export_selected)
    if status!=OK:
        _export_dialog_open=false
        _detail.text="Download yazılamadı; Godot dosya erişimini kontrol et. İç kayıt korundu."

func _export_selected(ok: bool, paths: PackedStringArray, _filter: int) -> void:
    _export_dialog_open=false
    if not ok or paths.is_empty():
        _detail.text="Kaydetme iptal edildi; test kayıtları korundu."
        return
    if not _write_export(paths[0]):
        _detail.text="Dosya yazılamadı. Android dosya seçicisinde Download seçip tekrar dene."

func _write_export(path: String) -> bool:
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        return false
    var payload: String=JSON.stringify(_report,"  ")
    file.store_string(payload)
    file.flush()
    var status: Error=file.get_error()
    file.close()
    if status!=OK:
        return false
    _export_path=path
    _detail.text="JSON dosyası kaydedildi: "+path.get_file()
    return true

func _request_reset() -> void:
    var confirm := ConfirmationDialog.new()
    confirm.title="Baştan başlat"
    confirm.dialog_text="Mevcut sonuçlar önce dışa aktarılabilir. Tüm testler yeniden çalışsın mı?"
    confirm.confirmed.connect(func():
        if _busy:
            _restart_requested=true
            _paused=false
            _status.text="Mevcut test bitince baştan başlanacak."
        else:
            _reset()
        confirm.queue_free())
    confirm.canceled.connect(confirm.queue_free)
    add_child(confirm)
    confirm.popup_centered(Vector2i(540,180))

func _request_retry() -> void:
    if _busy:
        _retry_requested=true
        _paused=false
        _status.text="Mevcut test bitince hatalı testler yeniden denenecek."
    else:
        _retry_failed()

func _retry_failed() -> void:
    if _busy:
        return
    var retained: Array = []
    if not _report.has("previous_attempts"):
        _report["previous_attempts"]=[]
    for t in _report["tests"]:
        if t["status"]=="pass":
            retained.append(t)
        else:
            _report["previous_attempts"].append(t)
    _report["tests"]=retained
    _report["state"]="running"
    _paused=false
    _save()
    call_deferred("_run_all")


func _toggle_pause() -> void:
    _paused = not _paused
    _stop.text = "Devam et" if _paused else "Sıradaki testte dur"

func _reset() -> void:
    if _busy:
        return
    _report = _new_report()
    _paused=false
    _restart_requested=false
    _retry_requested=false
    _save()
    call_deferred("_run_all")

func _update_ui() -> void:
    _progress.max_value = _names.size()
    _progress.value = _report["tests"].size()
    var counts := {}
    for t in _report["tests"]:
        counts[t["status"]] = int(counts.get(t["status"],0))+1
    _detail.text = "%d/%d | PASS %d | FAIL %d | Kesildi %d | Profil %d" % [_report["tests"].size(),_names.size(),counts.get("pass",0),counts.get("fail",0),counts.get("interrupted",0),_report["profiles"].size()]
    _restart.disabled = false

func _sample_memory() -> void:
    var rss: Variant = PROFILE._rss()
    if rss != null:
        _rss_peak = maxi(_rss_peak,int(rss))
    _static_peak = maxi(_static_peak,int(Performance.get_monitor(Performance.MEMORY_STATIC)))

func _process(_dt: float) -> void:
    if _busy and Time.get_ticks_msec()-_last_sample>=500:
        _last_sample=Time.get_ticks_msec()
        _sample_memory()

func _run_all() -> void:
    if _busy:
        return
    _busy = true
    _report["state"]="running"
    _update_ui()
    var done: Dictionary = {}
    for t in _report["tests"]:
        done[t["name"]]=true
    for name in _names:
        if done.has(name):
            continue
        while _paused or _export_dialog_open:
            _status.text="Duraklatıldı. Rapor kaydedebilir veya devam edebilirsin."
            await get_tree().process_frame
        _status.text = "Test: "+str(name)
        _report["active_test"]=name
        _save()
        await get_tree().process_frame
        var result: Dictionary = await _run_case(str(name))
        _report["tests"].append(result)
        _report["active_test"]=""
        _save()
        _update_ui()
        print("ANDROID_CASE ",JSON.stringify({"name":name,"status":result["status"],"ms":result["duration_ms"]}))
        await get_tree().process_frame
        if _restart_requested or _retry_requested:
            _busy=false
            if _restart_requested:
                _reset()
            else:
                _retry_requested=false
                _retry_failed()
            return
    if not _ci:
        await _run_profiles()
    if _restart_requested or _retry_requested:
        _busy=false
        if _restart_requested:
            _reset()
        else:
            _retry_requested=false
            _retry_failed()
        return
    _report["state"]="complete"
    _report["active_test"]=""
    _report["active_profile"]=""
    _save()
    _busy=false
    _status.text="Bitti. JSON DOSYASINI KAYDET'e bas."
    _update_ui()
    if _ci:
        var failures:=0
        for t in _report["tests"]:
            if t["status"]!="pass":
                failures+=1
        print("ANDROID_SUITE_COMPLETE ",JSON.stringify({"tests":_report["tests"].size(),"failures":failures}))
        get_tree().quit(1 if failures>0 or _report["tests"].size()!=_names.size() else 0)

func _user_entries() -> Dictionary:
    var found := {}
    var d := DirAccess.open("user://")
    if d != null:
        d.include_hidden=true
        for n in d.get_files():
            found[n]=true
        for n in d.get_directories():
            found[n]=true
    return found

func _remove_new(path: String) -> void:
    var d := DirAccess.open(path)
    if d == null:
        DirAccess.remove_absolute(path)
        return
    d.include_hidden=true
    for n in d.get_files():
        if not d.is_link(n):
            d.remove(n)
    for n in d.get_directories():
        if not d.is_link(n):
            _remove_new(path.path_join(n))
    DirAccess.remove_absolute(path)

func _clean_case_files(before: Dictionary) -> void:
    var d := DirAccess.open("user://")
    if d==null:
        return
    for n in _user_entries():
        # Only newly created scratch names in this separate project's user folder.
        if not before.has(n) and str(n).begins_with("tf_") and not str(n).begins_with("tf_android_") and not d.is_link(n):
            _remove_new("user://".path_join(n))

func _run_case(name: String) -> Dictionary:
    var before := _user_entries()
    var tree_root := get_tree().root
    var ids := {}
    for child in tree_root.get_children():
        ids[child.get_instance_id()]=true
    _rss_peak=0
    _static_peak=0
    _sample_memory()
    var start := Time.get_ticks_msec()
    _log.begin()
    var script: Resource = load("res://mobile_tests/"+name+".gd")
    var instance: Node = null
    var exit_code: int = -999
    if script is GDScript and script.can_instantiate():
        instance = script.new()
        add_child(instance)
        if instance.has_method("_initialize"):
            instance.call_deferred("_initialize")
            while is_instance_valid(instance) and int(instance.get("exit_code"))==-999 and Time.get_ticks_msec()-start<240000:
                await get_tree().process_frame
            if is_instance_valid(instance):
                exit_code=int(instance.get("exit_code"))
    # Let queued callbacks finish before cleanup and capture errors on teardown.
    await get_tree().process_frame
    if is_instance_valid(instance):
        instance.free()
    for child in tree_root.get_children():
        if not ids.has(child.get_instance_id()):
            child.free()
    await get_tree().process_frame
    _sample_memory()
    var capture: Dictionary = _log.take()
    var unexpected: Array = []
    for err in capture["errors"]:
        var e: String=str(err)
        if name in ["test_live_layers","test_layer_integrity"] and e.contains("TerraForge: Layer file missing/corrupt, terrain locked:"):
            continue
        if name=="test_data_safety" and e.contains("TerraForge: Height data is missing or unreadable."):
            continue
        unexpected.append(e)
    var traces: Array = []
    var compact: Array = []
    for message in capture["messages"]:
        for line in str(message).split("\n"):
            var cut: int=line.find(" {")
            if cut<=0:
                continue
            var tag: String=line.substr(0,cut)
            if not tag.contains("_"):
                continue
            var data: Variant=JSON.parse_string(line.substr(cut+1))
            if not data is Dictionary:
                continue
            traces.append({"tag":tag,"data":data})
            if tag in ["ROUNDTRIP_TRACE","LARGE_WORLD_TRACE","COLD_SHARD_TRACE"]:
                var m: Dictionary=data.get("metrics",{})
                var c: Dictionary={"tag":tag,"format":data.get("format"),"mode":data.get("mode"),"cache":data.get("cache"),"adaptive":data.get("adaptive")}
                for key in ["ticks","denied_ticks","longest_stall_ticks","missing_rays","airborne_ticks","disk_reads","builds","return_tick","peak_pages","peak_tiles","peak_jobs","peak_shards","moving_shard_loads","moving_shard_evictions","shard_loads","shard_evictions"]:
                    if m.has(key):
                        c[key]=m[key]
                for key in ["pump_ms","guard_ms","sample_ms"]:
                    if m.has(key):
                        c[key+"_p95"]=m[key].get("p95_upper_ms")
                compact.append(c)
    var detail_path: String=FULL_DIR.path_join(name+".json")
    var file := FileAccess.open(detail_path,FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"capture":capture,"traces":traces,"exit_code":exit_code}))
        file.flush()
        file.close()
    var success: bool=exit_code==0 and bool(capture["pass_marker"]) and unexpected.is_empty() and not bool(capture["truncated"])
    var result := {"name":name,"status":"pass" if success else "fail","exit_code":exit_code,"duration_ms":Time.get_ticks_msec()-start,"pass_marker":capture["pass_marker"],"unexpected_errors":unexpected,"capture_truncated":capture["truncated"],"rss_peak_sampled_bytes":_rss_peak if _rss_peak>0 else null,"static_peak_sampled_bytes":_static_peak,"trace_count":traces.size(),"motion_traces":compact,"details":detail_path}
    _clean_case_files(before)
    return result

func _run_profiles() -> void:
    # Independent visible camera/terrain rendering, same fixture and AB-style order.
    _phase="profiles"
    var before := _user_entries()
    var p = PROFILE.new()
    p.duration_seconds=20.0
    p.page_limit=16
    p.shard_limit=4
    add_child(p)
    p._format.select(1)
    p._refresh_sizes()
    p._fixture_size.select(p._fixture_size.get_item_index(1024))
    p._refresh_estimate()
    _status.text="Mobile Renderer: test arazisi hazırlanıyor."
    p._make_fixture()
    var start := Time.get_ticks_msec()
    while p._fixture!=null and Time.get_ticks_msec()-start<180000:
        await get_tree().process_frame
    if p._fixture!=null or p._path.text.is_empty():
        _report["profile_interruptions"].append("fixture failed or timeout")
        p.free()
        _clean_case_files(before)
        return
    for child in p.get_children():
        if child is CanvasLayer:
            child.visible=false
    var order: Array[int]=[0,3,4,5,6,0]
    for i in range(order.size()):
        if i<_report["profiles"].size():
            continue
        while _paused or _export_dialog_open:
            await get_tree().process_frame
        _status.text="Gerçek render profili %d/6 • strateji %d" % [i+1,order[i]]
        _report["active_profile"]=str(i+1)
        _save()
        p.sampling_strategy=order[i]
        p._begin(true)
        var deadline:=Time.get_ticks_msec()+90000
        while p._running and Time.get_ticks_msec()<deadline:
            await get_tree().process_frame
        if p._running or p._reports.is_empty():
            _report["profile_interruptions"].append("profile timeout "+str(i+1))
            break
        var data: Dictionary=p._reports.back().duplicate(true)
        data["sequence_index"]=i+1
        _report["profiles"].append(data)
        _report["active_profile"]=""
        _save()
        _update_ui()
        await get_tree().create_timer(1.0).timeout
        if _restart_requested or _retry_requested:
            break
    p.free()
    _clean_case_files(before)
