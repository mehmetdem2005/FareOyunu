extends Node
const CAPTURE = preload("res://capture.gd")
const PROFILE_PATH = "res://addons/terra_forge/profiling/profile_scene.gd"
var _run_dir: String = ""
var _start: Button
var _suite_choice: OptionButton
var _selected_suite: String="quick"
var _retry: Button
var _logger_installed := false
var _idle_smoke := false
var _starting := false
var _log = CAPTURE.new()
var _inventory: Dictionary
var _report: Dictionary
var _status: Label
var _progress: ProgressBar
var _copy: Button
var _full: Button
var _export_full: bool=false
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
var _profile_smoke := false
var _seq := 0
var _names: Array = []
var _shard := 0
var _phase := "tests"
var _last_sample: int = 0
var _rss_peak: int = 0
var _static_peak: int = 0

func _ready() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    _idle_smoke = args.has("--idle-smoke")
    _profile_smoke=args.has("--profile-smoke")
    _ci = args.has("--ci") or args.has("--smoke") or _idle_smoke or _profile_smoke
    _smoke = args.has("--smoke") or _idle_smoke
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
    if not _ci:
        _names=_inventory["quick_tests"].duplicate()
    if _profile_smoke:
        _selected_suite="full"
        _names=[]
        if DisplayServer.get_name().to_lower()=="headless" or RenderingServer.get_current_rendering_method()!="mobile":
            push_error("Profile smoke requires actual Mobile renderer")
            get_tree().quit(1)
            return
    elif _smoke:
        _names = ["test_height_store","test_data_safety","test_guarded_capsule"]
    elif _shard > 0:
        var selected: Array = []
        for i in range(_names.size()):
            if i % 3 == _shard - 1:
                selected.append(_names[i])
        _names = selected
    # No reads of historical reports. No fixture generation, logging or tests at launch.
    _report = {}
    _progress.max_value = _names.size()
    _progress.value = 0
    _status.text = "TerraForge M10 • Hazır"
    _detail.text = "0/%d | Başlat'a bas. Eski kayıtlar yüklenmez." % _names.size()
    _start.disabled = false
    _copy.disabled = true
    _full.disabled = true
    _stop.disabled = true
    _restart.disabled = true
    _retry.disabled = true
    print("ANDROID_MANUAL_IDLE")
    if _idle_smoke:
        call_deferred("_verify_idle")
    elif _ci:
        call_deferred("_start_fresh")

func _verify_idle() -> void:
    # CI seeds the legacy reports before launch. No startup progress is allowed.
    for i in range(8):
        await get_tree().process_frame
    if _busy or _starting or not _report.is_empty() or _progress.value != 0 or not _run_dir.is_empty():
        push_error("Manual startup read old data or started tests")
        get_tree().quit(1)
        return
    print("ANDROID_IDLE_VERIFIED")
    _start.pressed.emit()

func _start_fresh() -> void:
    if _busy or _starting or _inventory.is_empty():
        return
    if not _ci:
        _selected_suite="quick" if _suite_choice.selected==0 else "full"
        _names=_inventory["quick_tests" if _selected_suite=="quick" else "tests"].duplicate()
    _starting = true
    _suite_choice.disabled=true
    _start.disabled = true
    _copy.disabled = true
    _full.disabled = true
    _status.text = "Yeni test oturumu hazırlanıyor..."
    _progress.value = 0
    _detail.text = "0/%d" % _names.size()
    # Present the UI first; heavy scripts load only after the user starts.
    await get_tree().process_frame
    await get_tree().process_frame
    var token: String = str(Time.get_unix_time_from_system()).replace(".","_") + "_" + str(Time.get_ticks_usec())
    _run_dir = "user://tf_android_run_" + token
    if DirAccess.make_dir_absolute(_run_dir) != OK:
        _run_dir = ""
        _starting = false
        _suite_choice.disabled=false
        _start.disabled = false
        _status.text = "Yeni oturum klasörü açılamadı."
        return
    if DirAccess.make_dir_absolute(_run_dir.path_join("details")) != OK:
        _run_dir = ""
        _starting = false
        _suite_choice.disabled=false
        _start.disabled = false
        _status.text = "Ayrıntı klasörü açılamadı."
        return
    _seq = 0
    _paused = false
    _restart_requested = false
    _retry_requested = false
    _stop.text = "Sıradaki testte dur"
    _report = _new_report()
    _report["session_id"] = token
    _report["suite_mode"] = "ci" if _ci else _selected_suite
    _report["terrain_tree"] = _inventory.get("terrain_tree","")
    _report["planned_profiles"] = 0 if _ci and not _profile_smoke else _profile_plan(_selected_suite=="full").size()
    _report["qualification_note"] = "Quick is screening only. Full has 56 paired timing profiles plus four separate observer profiles; soak and actual OS lifecycle remain separate open gates."
    if not _logger_installed:
        OS.add_logger(_log)
        _logger_installed = true
    _save()
    _starting = false
    _run_all()

func _new_report() -> Dictionary:
    return {"schema":"TF_ANDROID_SUITE_1","build_commit":_inventory["build_commit"],"terrain_commit":_inventory["terrain_commit"],"started_utc":Time.get_datetime_string_from_system(true),"device":{"model":OS.get_model_name(),"os":OS.get_name(),"os_version":OS.get_version(),"cpu":OS.get_processor_name(),"cores":OS.get_processor_count(),"godot":Engine.get_version_info().get("string",""),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"headless":DisplayServer.get_name()=="headless","viewport":[get_viewport().size.x,get_viewport().size.y],"physics_hz":Engine.physics_ticks_per_second},"planned_tests":_names.size(),"tests":[],"profiles":[],"profile_interruptions":[],"diagnostic_scopes":[],"active_test":"","active_profile":"","state":"running","sequence":0,"notes":"SceneTree tests adapted to Node; shared process, not independent headless CI. Real renderer profiles separate. Timing includes scheduling, not GPU timestamp. Memory is sampled. No device identifier or game data."}

func _save() -> void:
    if _run_dir.is_empty() or _report.is_empty():
        return
    _seq += 1
    _report["sequence"] = _seq
    _report["updated_utc"] = Time.get_datetime_string_from_system(true)
    _report["diagnostic_integrity"]=_diagnostic_integrity()
    var path: String = _run_dir.path_join("report_a.json" if _seq % 2 == 0 else "report_b.json")
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
    _status.text = "TerraForge M10 • manuel başlangıç"
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(_status)
    _progress = ProgressBar.new()
    _progress.max_value=90
    v.add_child(_progress)
    _detail = Label.new()
    _detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(_detail)
    _suite_choice=OptionButton.new()
    _suite_choice.add_item("Hedefli: 4 M9 testi + 12 profil")
    _suite_choice.add_item("Tam: tüm regresyonlar + 60 profil")
    _suite_choice.select(0)
    _suite_choice.item_selected.connect(_select_suite)
    v.add_child(_suite_choice)
    _start = Button.new()
    _start.text = "BAŞLAT — SIFIRDAN"
    _start.custom_minimum_size.y = 64
    _start.disabled = true
    v.add_child(_start)
    _start.pressed.connect(_start_fresh)
    var row := HBoxContainer.new()
    v.add_child(row)
    _copy = Button.new()
    _copy.text = "JSON DOSYASINI KAYDET"
    _copy.custom_minimum_size.y=54
    _copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    row.add_child(_copy)
    _copy.pressed.connect(_export_json)
    _full = Button.new()
    _full.text="AYRINTILI JSON — DEBUGGER VE TÜM İZLER"
    _full.custom_minimum_size.y=44
    _full.disabled=true
    v.add_child(_full)
    _full.pressed.connect(func(): _export_json(true))
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
    _retry = Button.new()
    _retry.text = "Hatalıları tekrar dene (bu oturum)"
    _retry.custom_minimum_size.y=44
    v.add_child(_retry)
    _retry.pressed.connect(_request_retry)

func _select_suite(index:int) -> void:
    if _busy or _starting or _inventory.is_empty() or _ci:
        return
    if not _report.is_empty():
        _detail.text="Yeni seçim yalnız sıfırdan başlatınca uygulanır."
        return
    _names=_inventory["quick_tests" if index==0 else "tests"].duplicate()
    _progress.max_value=_names.size()
    _progress.value=0
    _detail.text="0/%d | Başlat yeni oturum açar." % _names.size()

func _export_json(full:bool=false) -> void:
    if _report.is_empty() or _export_dialog_open or (full and _busy):
        return
    _export_full=full
    _save()
    var filename: String = ("TerraForge_Diagnostics_" if full else "TerraForge_Android_") + Time.get_datetime_string_from_system().replace(":","-") + ".json"
    var downloads: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
    var target: String = downloads.path_join(filename) if not downloads.is_empty() else ""
    # Direct Download write where the Android editor already has access.
    if not target.is_empty() and _write_export(target,full):
        return
    # Android scoped storage: request just one destination through the native SAF picker.
    _export_dialog_open=true
    var status: Error=DisplayServer.file_dialog_show("TerraForge raporunu kaydet",downloads,filename,false,DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,PackedStringArray(["*.json ; JSON raporu"]),_export_selected)
    if status!=OK:
        _export_dialog_open=false
        _detail.text="Download yazılamadı; Godot dosya erişimini kontrol et. İç kayıt korundu."

## Test outcome and evidence integrity are independent. Historical failed
## attempts remain part of the evidence, even after a successful retry.
func _diagnostic_integrity() -> Dictionary:
    var total: int=0
    var incomplete: int=0
    var records_dropped: int=0
    var messages_dropped: int=0
    var unsaved: int=0
    for group in ["tests","previous_attempts","diagnostic_scopes"]:
        for item in _report.get(group,[]):
            total+=1
            records_dropped+=int(item.get("diagnostic_dropped",0))
            messages_dropped+=int(item.get("message_dropped",0))
            if not bool(item.get("detail_saved",false)):
                unsaved+=1
            if not bool(item.get("diagnostic_complete",false)):
                incomplete+=1
    return {"scopes":total,"incomplete_scopes":incomplete,"diagnostic_dropped":records_dropped,"message_dropped":messages_dropped,"unsaved_details":unsaved,"recorded_evidence_complete":incomplete==0 and unsaved==0,"session_complete":_report.get("state")=="complete","notes":"Recorded capture only; full export additionally checks detail files. Script backtrace counts, not full stack frames."}

## Stream each bounded detail separately rather than materializing the entire suite.
## Missing, corrupt or oversized detail is reported, never silently omitted.
func _write_diagnostics(path:String) -> bool:
    var file:=FileAccess.open(path,FileAccess.WRITE)
    if file==null:
        return false
    var summary: Dictionary=_report.duplicate(true)
    var integrity: Dictionary=_diagnostic_integrity()
    summary["diagnostic_integrity"]=integrity
    file.store_string('{"schema":"TF_ANDROID_DIAGNOSTICS_1","summary":'+JSON.stringify(summary)+',"details":[')
    var entries:Array=[]
    for group in ["tests","previous_attempts","diagnostic_scopes"]:
        for item in _report.get(group,[]):
            entries.append({"group":group,"item":item})
    var missing:int=0
    var emitted:int=0
    for entry in entries:
        var item:Dictionary=entry["item"]
        var source:String=str(item.get("details",""))
        var detail:Variant=null
        var issue:String=""
        if not source.begins_with(_run_dir.path_join("details")+"/") or not bool(item.get("detail_saved",false)):
            issue="detail not saved"
        else:
            var input:=FileAccess.open(source,FileAccess.READ)
            if input==null:
                issue="detail missing"
            elif input.get_length()>33554432:
                input.close()
                issue="detail exceeds 32 MiB export bound"
            else:
                var parser:=JSON.new()
                var status:Error=parser.parse(input.get_as_text())
                input.close()
                if status==OK and parser.data is Dictionary:
                    detail=parser.data
                else:
                    issue="detail invalid JSON"
        if not issue.is_empty():
            missing+=1
        if emitted>0:
            file.store_string(",")
        file.store_string(JSON.stringify({"group":entry["group"],"name":item.get("name",""),"source":source.get_file(),"issue":issue,"data":detail}))
        emitted+=1
    var export_complete: bool=missing==0 and bool(integrity["recorded_evidence_complete"])
    file.store_string('],"detail_count":'+str(emitted)+',"missing_detail_count":'+str(missing)+',"exported_evidence_complete":'+JSON.stringify(export_complete)+'}')
    file.flush()
    var status:Error=file.get_error()
    file.close()
    if status!=OK:
        return false
    _export_path=path
    _detail.text="Ayrıntılı JSON kaydedildi: "+path.get_file()+" | eksik ayrıntı: "+str(missing)+" | kayıt bütünlüğü: "+("tam" if export_complete else "eksik")
    return true

func _export_selected(ok: bool, paths: PackedStringArray, _filter: int) -> void:
    _export_dialog_open=false
    if not ok or paths.is_empty():
        _detail.text="Kaydetme iptal edildi; test kayıtları korundu."
        return
    if not _write_export(paths[0],_export_full):
        _detail.text="Dosya yazılamadı. Android dosya seçicisinde Download seçip tekrar dene."

func _write_export(path: String,full:bool=false) -> bool:
    if full:
        return _write_diagnostics(path)
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
    if _report.is_empty() or _starting:
        return
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
    if _busy or _starting:
        return
    _start_fresh()

func _update_ui() -> void:
    _progress.max_value = _names.size()
    _progress.value = _report["tests"].size()
    var counts := {}
    for t in _report["tests"]:
        counts[t["status"]] = int(counts.get(t["status"],0))+1
    _detail.text = "%d/%d | PASS %d | FAIL %d | Kesildi %d | Profil %d" % [_report["tests"].size(),_names.size(),counts.get("pass",0),counts.get("fail",0),counts.get("interrupted",0),_report["profiles"].size()]
    _start.disabled = _busy or _starting
    _suite_choice.disabled = _busy or _starting or _ci
    _copy.disabled = _report.is_empty()
    _full.disabled = _busy or _starting or _report.is_empty()
    _stop.disabled = not _busy
    _restart.disabled = _starting
    _retry.disabled = _report.is_empty() or _starting

func _sample_memory() -> void:
    var rss: Variant = _read_rss()
    if rss != null:
        _rss_peak = maxi(_rss_peak,int(rss))
    _static_peak = maxi(_static_peak,int(Performance.get_monitor(Performance.MEMORY_STATIC)))

# Lightweight RSS sampling; no terrain/profile script preload at startup.
func _read_rss() -> Variant:
    if OS.get_name() not in ["Linux","Android"]:
        return null
    var f := FileAccess.open("/proc/self/status",FileAccess.READ)
    if f == null:
        return null
    for i in range(128):
        var line: String = f.get_line()
        if line.begins_with("VmRSS:"):
            f.close()
            var parts := line.substr(6).strip_edges().replace("\t"," ").split(" ",false)
            if parts.size()==2 and parts[0].is_valid_int() and parts[1]=="kB":
                return int(parts[0])*1024
            return null
        if f.eof_reached():
            break
    f.close()
    return null

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
    if not _ci or _profile_smoke:
        await _run_profiles()
    if _restart_requested or _retry_requested:
        _busy=false
        if _restart_requested:
            _reset()
        else:
            _retry_requested=false
            _retry_failed()
        return
    var complete: bool=_report["tests"].size()==_names.size() and (_report["profiles"].size()==int(_report["planned_profiles"]) and _report["profile_interruptions"].is_empty())
    _report["state"]="complete" if complete else "incomplete"
    _report["active_test"]=""
    _report["active_profile"]=""
    _save()
    _busy=false
    _status.text=("Bitti." if complete else "Eksik oturum.")+" JSON DOSYASINI KAYDET'e bas."
    _update_ui()
    if _ci:
        var failures:=0
        for t in _report["tests"]:
            if t["status"]!="pass":
                failures+=1
        if _profile_smoke:
            if not complete:
                failures+=1
            var expected_plan: Array[Dictionary]=_profile_plan(true)
            var snapshot: String=""
            var settings_reference: Dictionary={}
            var counts: Dictionary={}
            var index: int=0
            for profile in _report["profiles"]:
                if index>=expected_plan.size():
                    failures+=1
                    break
                var spec: Dictionary=expected_plan[index]
                var arm: String=str(spec["arm"])
                var settings: Dictionary=profile.get("settings",{}).duplicate(true)
                var expected_mode: int=4 if arm=="F" else 7
                var expected_effective: int=4 if arm=="F" else (5 if arm=="I-G cropped" else 6)
                if profile.get("comparison_arm","")!=arm or profile.get("sequence_index",0)!=index+1 or profile.get("comparison_block",0)!=spec["block"] or profile.get("comparison_page_cap",0)!=spec["pages"] or profile.get("diagnostic_observer_block",null)!=spec["diagnostic"] or profile.get("error",FAILED)!=OK or profile.get("frame_interval_ms",{}).get("count",0)<=0 or profile.get("mesh_builds",0)<=0 or profile.get("worker_errors",-1)!=0:
                    failures+=1
                if settings.get("sampling_strategy",-1)!=expected_mode or settings.get("effective_sampling_strategy",-1)!=expected_effective or settings.get("hybrid_scalar_sampling")!=(arm!="F") or settings.get("hybrid_topology_cache")!=(arm=="I-H cropped") or settings.get("hybrid_cropped_halo")!=(arm!="F") or settings.get("page_limit",0)!=spec["pages"] or settings.get("publication_micro",null)!=spec["observer"] or settings.get("pump_micro",null)!=spec["observer"] or profile.get("route","")!="normalized_sine_v1" or profile.get("requested_seconds",0)!=5.0 or float(profile.get("actual_stream_seconds",0))<5.0 or profile.get("index_format","")!="TFM2" or profile.get("first_focus_collision_ms_from_open_start")==null:
                    failures+=1
                var current_snapshot: String=str(profile.get("snapshot_id",""))
                if index==0:
                    snapshot=current_snapshot
                if current_snapshot.is_empty() or current_snapshot!=snapshot:
                    failures+=1
                for key in ["sampling_strategy","effective_sampling_strategy","hybrid_scalar_sampling","hybrid_topology_cache","hybrid_cropped_halo","page_limit","publication_micro","pump_micro"]:
                    settings.erase(key)
                if index==0:
                    settings_reference=settings
                elif settings!=settings_reference:
                    failures+=1
                var label: String=str(spec["code"])
                counts[label]=int(counts.get(label,0))+1
                print("ANDROID_PROFILE_SMOKE_ARM ",JSON.stringify({"index":index+1,"arm":arm,"pages":spec["pages"],"block":spec["block"],"observer":spec["observer"],"diagnostic":spec["diagnostic"],"mesh_builds":profile.get("mesh_builds"),"frame_samples":profile.get("frame_interval_ms",{}).get("count"),"stream_seconds":profile.get("actual_stream_seconds")}))
                index+=1
            if index!=60 or counts!={"0":12,"1":14,"2":8,"3":8,"4":8,"5":8,"6":2} or not _report["diagnostic_integrity"].get("recorded_evidence_complete",false):
                failures+=1
            var destination: String=_run_dir.path_join("profile_smoke_export.json")
            if not _write_diagnostics(destination):
                failures+=1
            else:
                var exported: Variant=JSON.parse_string(FileAccess.get_file_as_string(destination))
                if not exported is Dictionary or not exported.get("exported_evidence_complete",false) or exported.get("missing_detail_count",-1)!=0:
                    failures+=1
            if failures==0:
                print("ANDROID_PROFILE_SMOKE_VERIFIED ",JSON.stringify({"profiles":index,"renderer":RenderingServer.get_current_rendering_method(),"arms":counts,"diagnostics_export":true,"seconds_per_profile":5}))
        if _smoke:
            if not _diagnostics_negative_smoke():
                failures+=1
            var destination:String=_run_dir.path_join("diagnostics_smoke.json")
            if not _write_diagnostics(destination):
                failures+=1
            else:
                var exported:Variant=JSON.parse_string(FileAccess.get_file_as_string(destination))
                if not exported is Dictionary or exported.get("detail_count",-1)!=_names.size() or exported.get("missing_detail_count",-1)!=0 or not exported.get("exported_evidence_complete",false):
                    failures+=1
                else:
                    print("ANDROID_DIAGNOSTICS_EXPORT_VERIFIED")
        print("ANDROID_SUITE_COMPLETE ",JSON.stringify({"tests":_report["tests"].size(),"failures":failures}))
        get_tree().quit(1 if failures>0 or _report["tests"].size()!=_names.size() else 0)

# CI-only deterministic failure and overflow checks. Never injected in a
# user's timed run or added to their real diagnostic records.
func _diagnostics_negative_smoke() -> bool:
    var capture=CAPTURE.new()
    var backtraces: Array[ScriptBacktrace]=[]
    capture.begin()
    capture._log_error("seed","fixture",1,"seed_error","expected synthetic error",false,0,backtraces)
    for i in range(513):
        capture._log_error("seed","fixture",i,"seed_warning","expected synthetic warning",false,1,backtraces)
    capture._log_message("PASS: seed",false)
    capture._log_message("x".repeat(8000000),false)
    var result: Dictionary=capture.take()
    if result["error_type_counts"].get("0",0)!=1 or result["error_type_counts"].get("1",0)!=513 or result["diagnostics"].size()!=512 or result["diagnostic_dropped"]!=2 or result["errors"].size()!=1 or result["message_dropped"]!=1 or not result["truncated"] or not result["pass_marker"]:
        push_error("Diagnostic capture synthetic limits failed")
        return false
    if result["diagnostic_complete"]:
        return false
    capture.begin()
    for i in range(513):
        capture._log_error("seed","fixture",i,"seed_warning","warning only",false,1,backtraces)
    capture._log_message("PASS: seed",false)
    var warnings: Dictionary=capture.take()
    # Legacy pass semantics remain untouched, but evidence is incomplete.
    if warnings["diagnostic_dropped"]!=1 or warnings["truncated"] or warnings["diagnostic_complete"] or not warnings["errors"].is_empty() or not warnings["pass_marker"]:
        push_error("Warning-only loss not visible")
        return false
    capture.begin()
    var reset: Dictionary=capture.take()
    if not reset["diagnostics"].is_empty() or not reset["errors"].is_empty() or not reset["messages"].is_empty() or not reset["error_type_counts"].is_empty() or reset["diagnostic_dropped"]!=0 or reset["message_dropped"]!=0 or reset["truncated"] or reset["pass_marker"] or not reset["diagnostic_complete"]:
        push_error("Diagnostic scope did not reset")
        return false
    # Verify a real Godot warning traverses the registered Logger as well.
    _log.begin()
    push_warning("TF_DIAGNOSTIC_SMOKE_WARNING")
    var actual: Dictionary=_log.take()
    var observed: bool=false
    for entry in actual["diagnostics"]:
        if int(entry["type"])==1 and JSON.stringify(entry).contains("TF_DIAGNOSTIC_SMOKE_WARNING"):
            observed=true
    if not observed or not actual["errors"].is_empty():
        push_error("Godot warning capture failed")
        return false
    var old_export: String=_export_path
    var invalid_path: String=_run_dir.path_join("nonexistent_smoke_parent").path_join("report.json")
    if _write_export(invalid_path,false) or _write_export(invalid_path,true) or _export_path!=old_export:
        push_error("Invalid destination falsely reported success")
        return false
    # Exercise partial exports without changing the original session report.
    var saved_report: Dictionary=_report
    _report=saved_report.duplicate(true)
    _report["diagnostic_scopes"].append({"name":"synthetic_missing","details":_run_dir.path_join("details").path_join("nonexistent_smoke.json"),"detail_saved":true})
    var negative_path: String=_run_dir.path_join("diagnostics_negative_smoke.json")
    var written: bool=_write_diagnostics(negative_path)
    _report=saved_report
    _export_path=old_export
    if not written:
        return false
    var exported: Variant=JSON.parse_string(FileAccess.get_file_as_string(negative_path))
    if not exported is Dictionary or exported.get("missing_detail_count",-1)!=1 or exported.get("detail_count",-1)!=_names.size()+1 or exported.get("exported_evidence_complete",true):
        push_error("Missing detail was not represented accurately")
        return false
    var last: Dictionary=exported["details"][-1]
    if last.get("issue")!="detail missing" or last.get("data")!=null:
        push_error("Missing detail substituted fabricated data")
        return false
    print("ANDROID_DIAGNOSTICS_NEGATIVE_VERIFIED")
    return true

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
    var expected: Array = []
    for err in capture["errors"]:
        var e: String=str(err)
        if name in ["test_live_layers","test_layer_integrity"] and e.contains("TerraForge: Layer file missing/corrupt, terrain locked:"):
            expected.append(e)
            continue
        if name=="test_data_safety" and e.contains("TerraForge: Height data is missing or unreadable."):
            expected.append(e)
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
            if tag in ["ROUNDTRIP_TRACE","LARGE_WORLD_TRACE","COLD_SHARD_TRACE","I0_INTEGRATED_ROUTE","H3_CAPACITY_TRACE"]:
                var m: Dictionary=data.get("metrics",{})
                var c: Dictionary={"tag":tag,"format":data.get("format"),"mode":data.get("mode"),"cache":data.get("cache"),"adaptive":data.get("adaptive"),"arm":data.get("arm"),"cap":data.get("cap")}
                for key in ["ticks","denied_ticks","longest_stall_ticks","missing_rays","airborne_ticks","disk_reads","builds","return_tick","peak_pages","peak_tiles","peak_jobs","peak_shards","moving_shard_loads","moving_shard_evictions","shard_loads","shard_evictions","mesh_builds","source_reads","peak_reserved_payload_bytes","shutdown_clean","crop_submissions"]:
                    if m.has(key):
                        c[key]=m[key]
                for key in ["pump_ms","guard_ms","sample_ms"]:
                    if m.has(key):
                        c[key+"_p95"]=m[key].get("p95_upper_ms")
                if tag in ["I0_INTEGRATED_ROUTE","H3_CAPACITY_TRACE"]:
                    c["worker"]=m.get("worker_final",{})
                    c["source_disk_reads"]=m.get("source",{}).get("disk_reads",m.get("source_reads"))
                    c["pump_ms"]=m.get("pump_ms",{})
                compact.append(c)
    var detail_path: String=_run_dir.path_join("details").path_join("%s_%d.json" % [name,_seq])
    var detail_saved: bool=_store_detail(detail_path,{"capture":capture,"traces":traces,"exit_code":exit_code,"expected_errors":expected,"unexpected_errors":unexpected})
    var success: bool=exit_code==0 and bool(capture["pass_marker"]) and unexpected.is_empty() and not bool(capture["truncated"])
    var result := {"name":name,"status":"pass" if success else "fail","exit_code":exit_code,"duration_ms":Time.get_ticks_msec()-start,"pass_marker":capture["pass_marker"],"unexpected_errors":unexpected,"expected_errors":expected,"error_type_counts":capture["error_type_counts"],"diagnostic_dropped":capture["diagnostic_dropped"],"message_dropped":capture["message_dropped"],"detail_saved":detail_saved,"diagnostic_complete":capture["diagnostic_complete"] and detail_saved,"capture_truncated":capture["truncated"],"rss_peak_sampled_bytes":_rss_peak if _rss_peak>0 else null,"static_peak_sampled_bytes":_static_peak,"trace_count":traces.size(),"motion_traces":compact,"details":detail_path}
    _clean_case_files(before)
    return result

func _store_detail(path:String,data:Dictionary) -> bool:
    var file:=FileAccess.open(path,FileAccess.WRITE)
    if file==null:
        return false
    file.store_string(JSON.stringify(data))
    file.flush()
    var status:Error=file.get_error()
    file.close()
    return status==OK

func _finish_scope(scope:String) -> void:
    var captured:Dictionary=_log.take()
    var path:String=_run_dir.path_join("details").path_join("scope_%s_%d.json" % [scope,_seq])
    var saved:bool=_store_detail(path,{"capture":captured,"scope":scope})
    _report["diagnostic_scopes"].append({"name":scope,"details":path,"detail_saved":saved,"diagnostic_complete":captured["diagnostic_complete"] and saved,"error_type_counts":captured["error_type_counts"],"unexpected_errors":captured["errors"],"diagnostic_dropped":captured["diagnostic_dropped"],"message_dropped":captured["message_dropped"],"capture_truncated":captured["truncated"]})

# Frozen paired profile schedule. 0/1 F16/32, 2/3 I-G16/32, 4/5 I-H16/32.
# 6 is F32 with observers, never counted as a normal timing arm.
func _profile_plan(full: bool) -> Array[Dictionary]:
    var pairs: Array = [[0,1],[1,3],[1,5]]
    if full:
        pairs=[[0,1],[2,3],[4,5],[0,2],[0,4],[1,3],[1,5]]
    var plan: Array[Dictionary]=[]
    var block: int=0
    for pass_index in range(2 if full else 1):
        for pair_index in range(pairs.size()):
            var pair: Array=pairs[pair_index if pass_index==0 else pairs.size()-1-pair_index]
            var a: int=pair[0]
            var b: int=pair[1]
            block+=1
            var order: Array[int]=[]
            if pass_index==0:
                order.assign([a,b,b,a])
            else:
                order.assign([b,a,a,b])
            for code in order:
                plan.append(_profile_spec(code,block,false))
    if full:
        block+=1
        for code in [1,6,6,1]:
            plan.append(_profile_spec(code,block,true))
    return plan

func _profile_spec(code: int,block: int,diagnostic: bool) -> Dictionary:
    var arm: String="F" if code<2 or code==6 else ("I-G cropped" if code<4 else "I-H cropped")
    return {"arm":arm,"pages":32 if code==6 or code%2==1 else 16,"observer":code==6,"diagnostic":diagnostic,"block":block,"code":code}

func _run_profiles() -> void:
    # Independent visible camera/terrain rendering, same fixture and AB-style order.
    _phase="profiles"
    var before := _user_entries()
    _log.begin()
    var profile_script: Resource = load(PROFILE_PATH)
    if not profile_script is GDScript or not profile_script.can_instantiate():
        _report["profile_interruptions"].append("profile script unavailable")
        _finish_scope("fixture")
        return
    var p = profile_script.new()
    p.duration_seconds=5.0 if _profile_smoke else 20.0
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
        _finish_scope("fixture")
        _clean_case_files(before)
        return
    _finish_scope("fixture")
    for child in p.get_children():
        if child is CanvasLayer:
            child.visible=false
    var order: Array[Dictionary]=_profile_plan(_selected_suite=="full")
    for i in range(order.size()):
        if i<_report["profiles"].size():
            continue
        while _paused or _export_dialog_open:
            await get_tree().process_frame
        var spec: Dictionary=order[i]
        var arm: String=spec["arm"]
        _status.text="Gerçek render profili %d/%d • %s / %d sayfa" % [i+1,order.size(),arm,spec["pages"]]
        _report["active_profile"]=str(i+1)
        _save()
        p.page_limit=spec["pages"]
        p.sampling_strategy=4 if arm=="F" else 7
        p.hybrid_scalar_sampling=arm!="F"
        p.hybrid_topology_cache=arm=="I-H cropped"
        p.hybrid_cropped_halo=arm!="F"
        p.observe_publication_micro=spec["observer"]
        p.observe_pump_micro=spec["observer"]
        # Profile scene retains at most eight reports. The runner owns the
        # cumulative report; clear only its internal history before each run.
        p._reports.clear()
        _log.begin()
        p._begin(true)
        var deadline:=Time.get_ticks_msec()+90000
        while p._running and Time.get_ticks_msec()<deadline:
            await get_tree().process_frame
        _finish_scope("profile_"+str(i+1))
        if p._running or p._reports.size()!=1:
            _report["profile_interruptions"].append("profile timeout or no new report "+str(i+1))
            break
        var data: Dictionary=p._reports.back().duplicate(true)
        data["sequence_index"]=i+1
        data["comparison_arm"]=arm
        data["comparison_block"]=spec["block"]
        data["comparison_page_cap"]=spec["pages"]
        data["diagnostic_observer_block"]=spec["diagnostic"]
        data["diagnostic_material"]=false
        if data.get("error",FAILED)!=OK or data.get("frame_interval_ms",{}).get("count",0)<=0:
            _report["profile_interruptions"].append("profile failed or no frame samples "+str(i+1))
            break
        _report["profiles"].append(data)
        _report["active_profile"]=""
        _save()
        _update_ui()
        await get_tree().create_timer(1.0).timeout
        if _restart_requested or _retry_requested:
            break
    _log.begin()
    p.free()
    await get_tree().process_frame
    _finish_scope("profile_teardown")
    _clean_case_files(before)
