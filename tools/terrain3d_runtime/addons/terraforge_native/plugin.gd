@tool
extends EditorPlugin
## Mobile-first editor controls: only a tiny button remains in the 3D toolbar.
## Settings appear in a dismissible popup rather than a permanent bottom panel.
const Brush = preload("res://addons/terraforge_native/native_brush.gd")
var _brush := Brush.new()
const StrokeSampler = preload("res://addons/terraforge_native/native_stroke_sampler.gd")
var _stroke_sampler := StrokeSampler.new()
var _basic_accepting := false
var _basic_dabs := 0
var _basic_max_us := 0
var _basic_error := ""

var _toolbar: HBoxContainer
var _menu_button: Button
var _brush_button: CheckButton
var _popup: PopupPanel
var _status: Label
var _stats_label: Label
var _tool_select: OptionButton
var _tool_help: Label
var _radius: HSlider
var _strength: HSlider
var _profile_select: OptionButton
var _layer_row: HBoxContainer
var _layer_enable: Button
var _layer_select: OptionButton
var _layer_add: Button
var _layer_visible: CheckButton
var _layer_restore: Button
var _advanced_row: HBoxContainer
var _advanced_label: Label
var _stamp_preset: OptionButton
var _smooth_mode: OptionButton
var _smooth_mode_at_press := 0
var _weather_mode: OptionButton
var _weather_mode_at_press := 0
var _ramp_rise: SpinBox
var _current_tool: int = 0
var _ramp_setting: float = 5.0
var _weather_setting: float = 3.0
var _radius_display: Label
var _strength_display: Label
var _active: Node3D
var _stroke_active: bool = false
var _touch_session: bool = false
var _last_touch_ms: int = -100000
var _last_stats_update_ms: int = -100000
var _input_count := 0
var _hit_count := 0
var _changed_count := 0
var _last_input_result := "Brush OFF"
var _raw_status := ""
var _drop_button: Button
var _drop_active := false
var _drop_started := 0
var _drop_previous_frame := 0
var _drop_rows: Array = []
var _drop_meta: Dictionary = {}
var _drop_ray_count := 0
var _drop_ray_us := 0
var _drop_ray_max_us := 0
var _drop_input_us := 0
var _drop_input_count := 0
var _drop_pump_us := 0
var _drop_advanced_us := 0
var _drop_status_us := 0
const DROP_LIMIT := 3600
const DROP_COLUMNS := ["t_us","frame_interval_us","plugin_process_us","input_count","input_us","ray_count","ray_us","ray_max_us","pump_us","advanced_poll_us","status_us","native_write_count","native_write_us","publish_cpu_us","layer_bytes_est","changed_samples","history_merge_us","tool","radius_m","stroke_active","worker_busy","brush_enabled","pending_dabs","draw_calls","render_objects","physics_process_s"]
var _touch_index := -1
var _multi_touch := false
var _corridor_points: Array[Vector2] = []
var _corridor_error := ""
var _corridor_length := 0.0
var _corridor_tool := -1
var _corridor_radius := 0.0
var _corridor_power := 0.0

func _enter_tree() -> void:
    # Forward viewport events even when the native node is locked/deselected.
    # The handler still passes all events through when Brush is off.
    set_input_event_forwarding_always_enabled()
    _toolbar = HBoxContainer.new()
    _toolbar.name = "TerraForgeQuickTools"
    _toolbar.add_theme_constant_override("separation", 3)
    _menu_button = Button.new()
    _menu_button.text = "Arazi"
    _menu_button.tooltip_text = "TerraForge araçları ve ayarları"
    _menu_button.pressed.connect(_toggle_popup)
    _toolbar.add_child(_menu_button)
    _brush_button = CheckButton.new()
    _brush_button.text = "Fırça"
    _brush_button.tooltip_text = "Araziyi şekillendirmek için aç; kamerayı hareket ettirmek için kapat."
    _brush_button.toggled.connect(_toggle_brush)
    _toolbar.add_child(_brush_button)
    # Godot's supported 3D toolbar container, NOT its large bottom panel.
    add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)

    _popup = PopupPanel.new()
    _popup.name = "TerraForgeTools"
    _toolbar.add_child(_popup)
    var content: VBoxContainer = VBoxContainer.new()
    content.custom_minimum_size = Vector2(290, 0)
    content.add_theme_constant_override("separation", 7)
    _popup.add_child(content)

    var header: HBoxContainer = HBoxContainer.new()
    content.add_child(header)
    var title: Label = Label.new()
    title.text = "TERRAFORGE"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var new_button: Button = Button.new()
    new_button.text = "+ Yeni"
    new_button.tooltip_text = "Düzenlenebilir boş arazi oluştur."
    new_button.pressed.connect(_choose_new_size)
    header.add_child(new_button)
    var save_button: Button = Button.new()
    save_button.text = "Kaydet"
    save_button.pressed.connect(_save_active)
    header.add_child(save_button)

    var tool_row: HBoxContainer = HBoxContainer.new()
    content.add_child(tool_row)
    var label: Label = Label.new()
    label.text = "Araç"
    tool_row.add_child(label)
    _tool_select = OptionButton.new()
    for tool_name in ["Yükselt", "Alçalt", "Yumuşat", "Düzleştir", "Dağ Sırtı", "Vadi", "Rampa", "Şekil Bas", "Aşındır"]:
        _tool_select.add_item(tool_name)
    var tool_tips := ["Yüzeyi yükselt.", "Yüzeyi alçalt.", "Yükseklik geçişlerini yumuşat.", "Başlangıç yüksekliğine doğru düzleştir.", "Hat çiz; bırakınca dağ sırtı oluşur.", "Hat çiz; bırakınca vadi açılır.", "Eğimli geçiş (henüz hazır değil).", "Hazır arazi biçimleri (henüz hazır değil).", "Yamaç veya su aşınması; dokun ve bırak."]
    for i in range(tool_tips.size()):
        _tool_select.get_popup().set_item_tooltip(i,tool_tips[i])
    for index in [6,7]:
        _tool_select.set_item_disabled(index,true)
    _tool_select.item_selected.connect(_on_tool_changed)
    _tool_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tool_row.add_child(_tool_select)
    var undo_button: Button = Button.new()
    undo_button.text = "↶"
    undo_button.tooltip_text = "Son arazi işlemini geri al."
    undo_button.pressed.connect(_undo)
    tool_row.add_child(undo_button)
    var redo_button: Button = Button.new()
    redo_button.text = "↷"
    redo_button.tooltip_text = "Geri alınan işlemi yinele."
    redo_button.pressed.connect(_redo)
    tool_row.add_child(redo_button)
    _tool_help = Label.new()
    _tool_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _tool_help.add_theme_font_size_override("font_size",13)
    _tool_help.modulate.a=0.85
    _tool_help.text=tool_tips[0]
    content.add_child(_tool_help)

    var radius_row: HBoxContainer = HBoxContainer.new()
    content.add_child(radius_row)
    var radius_label: Label = Label.new()
    radius_label.text = "Yarıçap"
    radius_label.custom_minimum_size.x = 58
    radius_row.add_child(radius_label)
    _radius = HSlider.new()
    _radius.tooltip_text = "Fırçanın metre cinsinden yarıçapı."
    _radius.min_value = 1.0
    _radius.max_value = 36.0
    _radius.step = 0.5
    _radius.value = 8.0
    _radius.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    radius_row.add_child(_radius)
    _radius_display = Label.new()
    _radius_display.text = "8m"
    _radius_display.custom_minimum_size.x = 40
    radius_row.add_child(_radius_display)
    _radius.value_changed.connect(_radius_changed)

    var strength_row: HBoxContainer = HBoxContainer.new()
    content.add_child(strength_row)
    var strength_label: Label = Label.new()
    strength_label.text = "Güç"
    strength_label.custom_minimum_size.x = 58
    strength_row.add_child(strength_label)
    _strength = HSlider.new()
    _strength.tooltip_text = "Seçili aracın etki gücü."
    _strength.min_value = 0.25
    _strength.max_value = 12.0
    _strength.step = 0.25
    _strength.value = 3.0
    _strength.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    strength_row.add_child(_strength)
    _strength_display = Label.new()
    _strength_display.text = "3.0"
    _strength_display.custom_minimum_size.x = 40
    strength_row.add_child(_strength_display)
    _strength.value_changed.connect(_strength_changed)

    _advanced_row = HBoxContainer.new()
    _advanced_row.visible = false
    content.add_child(_advanced_row)
    _advanced_label = Label.new()
    _advanced_label.text = "Şekil"
    _advanced_label.custom_minimum_size.x = 58
    _advanced_row.add_child(_advanced_label)
    _stamp_preset = OptionButton.new()
    for preset_name in ["Tepe", "Krater", "Düz tepeli dağ"]:
        _stamp_preset.add_item(preset_name)
    _stamp_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _advanced_row.add_child(_stamp_preset)
    _ramp_rise = SpinBox.new()
    _ramp_rise.min_value = -40.0
    _ramp_rise.max_value = 40.0
    _ramp_rise.step = 0.5
    _ramp_rise.value = 5.0
    _ramp_rise.suffix = "m"
    _ramp_rise.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _advanced_row.add_child(_ramp_rise)
    _ramp_rise.visible = false
    _smooth_mode = OptionButton.new()
    _smooth_mode.add_item("Klasik",0)
    _smooth_mode.add_item("Geniş ölçek",1)
    _smooth_mode.add_item("İnce pürüz",2)
    _smooth_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _advanced_row.add_child(_smooth_mode)
    _smooth_mode.visible = false
    _smooth_mode.get_popup().set_item_tooltip(0,"Genel yüzey yumuşatma.")
    _smooth_mode.get_popup().set_item_tooltip(1,"Ana arazi şeklini yumuşatır, küçük ayrıntıları korur. Daha ağır hesaplama.")
    _smooth_mode.get_popup().set_item_tooltip(2,"Küçük pürüzleri giderir, büyük arazi şeklini korur.")
    _smooth_mode.item_selected.connect(func(_index: int): _refresh_tool_help())
    _weather_mode = OptionButton.new()
    _weather_mode.add_item("Yamaç Aşınması",0)
    _weather_mode.add_item("Su Aşınması",1)
    _weather_mode.tooltip_text = "Yamaç: 3 aşınma geçişi. Su: D8 yönlü, kapalı alanlı tek tortu geçişi."
    _weather_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _advanced_row.add_child(_weather_mode)
    _weather_mode.visible = false
    _weather_mode.item_selected.connect(func(_index: int): _refresh_tool_help())
    _weather_mode.get_popup().set_item_tooltip(0,"Dik yamaçlardaki malzemeyi aşağı taşır.")
    _weather_mode.get_popup().set_item_tooltip(1,"Akış yönüne göre aşındırır ve tortu biriktirir.")

    var profile_row: HBoxContainer = HBoxContainer.new()
    content.add_child(profile_row)
    var profile_label: Label = Label.new()
    profile_label.text = "Görüş"
    profile_label.custom_minimum_size.x = 58
    profile_row.add_child(profile_label)
    _profile_select = OptionButton.new()
    _profile_select.add_item("Yakın",5)
    _profile_select.add_item("Orta",6)
    _profile_select.add_item("Tam",7)
    _profile_select.select(2)
    _profile_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _profile_select.disabled = true
    _profile_select.tooltip_text = "Görüş mesafesi LOD sayısını değiştirir; yükseklik verisi aynı kalır."
    _profile_select.item_selected.connect(_view_profile_changed)
    profile_row.add_child(_profile_select)
    var diagnostics_button: Button = Button.new()
    diagnostics_button.text = "Kontrol"
    diagnostics_button.tooltip_text = "Bölge, giriş, temas ve düzenleme bilgilerini göster."
    diagnostics_button.pressed.connect(_toggle_drop_trace)
    diagnostics_button.text = "Drop kaydı"
    diagnostics_button.tooltip_text = "30 saniyelik kare/fırça ölçümü başlat; yeniden dokunarak bitir. JSON kullanıcı klasörüne kaydedilir."
    _drop_button=diagnostics_button
    profile_row.add_child(diagnostics_button)

    # One small contextual row instead of another tall mobile dock.
    _layer_row = HBoxContainer.new()
    _layer_row.add_theme_constant_override("separation", 3)
    content.add_child(_layer_row)
    _layer_enable = Button.new()
    _layer_enable.text = "Katmanlar"
    _layer_enable.tooltip_text = "Katman sistemi henüz etkin değil."
    _layer_enable.disabled = true
    _layer_row.add_child(_layer_enable)
    _layer_select = OptionButton.new()
    _layer_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _layer_select.disabled = true
    _layer_row.add_child(_layer_select)
    _layer_add = Button.new()
    _layer_add.text = "+"
    _layer_add.tooltip_text = "Bağımsız şekillendirme katmanı ekle (en fazla 8)."
    _layer_add.disabled = true
    _layer_row.add_child(_layer_add)
    _layer_visible = CheckButton.new()
    _layer_visible.text = "Açık"
    _layer_visible.tooltip_text = "Seçilen katmanı göster veya gizle."
    _layer_visible.disabled = true
    _layer_row.add_child(_layer_visible)
    _layer_restore = Button.new()
    _layer_restore.text = "Kurtar"
    _layer_restore.tooltip_text = "Katman kurtarma henüz etkin değil."
    _layer_restore.disabled = true
    _layer_row.add_child(_layer_restore)
    _refresh_layer_ui()

    _stats_label = Label.new()
    _stats_label.text = "Bölge: -"
    _stats_label.modulate.a = 0.7
    content.add_child(_stats_label)
    _status = Label.new()
    _set_status("Create terrain or select an existing one.")
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(_status)

    var selection: EditorSelection = get_editor_interface().get_selection()
    selection.selection_changed.connect(_on_selection_changed)
    scene_changed.connect(_on_scene_changed)
    set_process(true)
    call_deferred("_on_selection_changed")

func _exit_tree() -> void:
    if _drop_active:
        _stop_drop_trace()
    _finish_stroke()
    _brush.shutdown_advanced()
    var selection: EditorSelection = get_editor_interface().get_selection()
    if selection.selection_changed.is_connected(_on_selection_changed):
        selection.selection_changed.disconnect(_on_selection_changed)
    if scene_changed.is_connected(_on_scene_changed):
        scene_changed.disconnect(_on_scene_changed)
    if _toolbar != null:
        remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
        _toolbar.queue_free()
    _active = null

func _toggle_popup() -> void:
    if _popup.visible:
        _popup.hide()
        return
    var window_size: Vector2i = get_editor_interface().get_base_control().get_window().size
    var button_position: Vector2i = Vector2i(_menu_button.get_screen_position())
    var width: int = mini(300, maxi(240, window_size.x - 16))
    var required_height: int = 390 if _advanced_row.visible else 355
    var height: int = mini(required_height, maxi(180, window_size.y - 16))
    var x: int = clampi(button_position.x, 0, maxi(0, window_size.x - width))
    var y: int = clampi(
        button_position.y + int(_menu_button.size.y) + 3,
        0, maxi(0, window_size.y - height)
    )
    # The popup can consume the release event; close any active stroke first.
    _finish_stroke()
    _touch_session = false
    _touch_index = -1
    _multi_touch = false
    _sync_view_profile()
    _popup.popup(Rect2i(Vector2i(x, y), Vector2i(width, height)))

func _radius_changed(value: float) -> void:
    _radius_display.text = "%.1fm" % value

func _strength_changed(value: float) -> void:
    _strength_display.text = "%.1f" % value


func _process(delta: float) -> void:
    if not _drop_active:
        _process_body(delta)
        return
    var started := Time.get_ticks_usec()
    var interval := started-_drop_previous_frame if _drop_previous_frame>0 else 0
    _drop_previous_frame=started
    _process_body(delta)
    var process_us := Time.get_ticks_usec()-started
    _drop_rows.append([started-_drop_started,interval,process_us,_drop_input_count,_drop_input_us,_drop_ray_count,_drop_ray_us,_drop_ray_max_us,_drop_pump_us,_drop_advanced_us,_drop_status_us,_brush.trace_write_count,_brush.trace_write_us,_brush.trace_publish_us,_brush.trace_payload_bytes,_brush.trace_samples,_brush.trace_history_us,_corridor_tool,_corridor_radius,int(_stroke_active),int(_brush.advanced_busy()),int(_brush_button.button_pressed),_stroke_sampler.pending_count(),int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)])
    _reset_drop_counters()
    if _drop_rows.size()>=DROP_LIMIT or started-_drop_started>=30000000:
        _stop_drop_trace()

func _reset_drop_counters() -> void:
    _drop_ray_count=0
    _drop_ray_us=0
    _drop_ray_max_us=0
    _drop_input_us=0
    _drop_input_count=0
    _drop_pump_us=0
    _drop_advanced_us=0
    _drop_status_us=0
    _brush.reset_trace_counters()

func _toggle_drop_trace() -> void:
    if _drop_active:
        _stop_drop_trace()
    else:
        _start_drop_trace()
    _popup.hide()

func _start_drop_trace() -> void:
    _drop_rows=[]
    _drop_started=Time.get_ticks_usec()
    _drop_previous_frame=0
    _reset_drop_counters()
    _drop_meta={"schema":1,"device":OS.get_model_name(),"os":OS.get_name(),"godot":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":str(get_editor_interface().get_editor_viewport_3d(0).size),"scene":str(get_editor_interface().get_edited_scene_root().scene_file_path) if get_editor_interface().get_edited_scene_root()!=null else ""}
    if is_instance_valid(_active):
        _drop_meta["spacing"]=_active.get("vertex_spacing")
        _drop_meta["region_size"]=_active.call("get_region_size")
        _drop_meta["lods"]=_active.get("mesh_lods")
        _drop_meta["collision_mode"]=_active.get("collision_mode")
        _drop_meta["regions"]=_active.get("data").call("get_region_count")
    _drop_active=true
    _brush.trace_enabled=true
    _drop_button.text="Kaydı bitir"
    print("TerraForge drop trace started; 30 seconds maximum.")

func _stop_drop_trace() -> String:
    _drop_active=false
    _brush.trace_enabled=false
    _drop_button.text="Drop kaydı"
    var path := "user://TerraForge_Drop_%s.json" % str(Time.get_unix_time_from_system()).replace(".","_")
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file==null:
        push_warning("TerraForge drop trace write failed: "+error_string(FileAccess.get_open_error()))
        return ""
    file.store_string(JSON.stringify({"meta":_drop_meta,"columns":DROP_COLUMNS,"rows":_drop_rows,"notes":"Frame callback intervals, not GPU timings; event counters may precede frame, render/physics monitors editor-wide and may lag. Native upload bytes estimated. Trace overhead nonzero."}))
    file.close()
    print("TerraForge drop trace: "+ProjectSettings.globalize_path(path))
    _set_status("Drop kaydı kaydedildi: "+path.get_file())
    return path

func _process_body(_delta: float) -> void:
    var advanced_started := Time.get_ticks_usec() if _drop_active else 0
    # Drain discarded work even after a scene switch or interrupted gesture.
    if _brush.smooth_busy() and (not _stroke_active or _corridor_tool!=2 or not is_instance_valid(_active)):
        _brush.cancel_smooth()
        _brush.poll_smooth()
    var corridor := _brush.poll_corridor()
    if not corridor.is_empty():
        _changed_count += _brush.last_changed_cells if str(corridor["error"]).is_empty() else 0
        _last_input_result = str(corridor["error"]) if not str(corridor["error"]).is_empty() else "Corridor edited %d samples." % _brush.last_changed_cells
        _set_status(_last_input_result)
    var weather := _brush.poll_weather()
    if not weather.is_empty():
        _changed_count += _brush.last_changed_cells if str(weather["error"]).is_empty() else 0
        _last_input_result = str(weather["error"]) if not str(weather["error"]).is_empty() else "Weather edited %d samples." % _brush.last_changed_cells
        _set_status(_last_input_result)
    if _drop_active:
        _drop_advanced_us+=Time.get_ticks_usec()-advanced_started
    if not is_instance_valid(_active):
        return
    # A single native dab is an indivisible main-thread transaction for now.
    # Never catch up by executing multiple expensive dabs in one frame.
    var pump_started := Time.get_ticks_usec() if _drop_active else 0
    _pump_basic()
    if _drop_active:
        _drop_pump_us+=Time.get_ticks_usec()-pump_started
    var now := Time.get_ticks_msec()
    if now - _last_stats_update_ms < 200:
        return
    _last_stats_update_ms = now
    var view := get_editor_interface().get_editor_viewport_3d(0)
    if view != null:
        var camera := view.get_camera_3d()
        if camera != null and _active.call("get_camera") != camera:
            _active.call("set_camera",camera)
    if _popup.visible:
        var data: Object = _active.get("data")
        if data == null:
            return
        if _profile_select.get_selected_id() != int(_active.get("mesh_lods")):
            _sync_view_profile()
        _stats_label.text = "Float32 | %d bölge | %d LOD\nGirdi %d | Temas %d | Düzenleme %d" % [int(data.call("get_region_count")),int(_active.get("mesh_lods")),_input_count,_hit_count,_changed_count]
        if _brush_button.button_pressed:
            _status.text = _tr_status(_last_input_result)

func _refresh_layer_ui() -> void:
    _layer_enable.visible = true
    _layer_enable.disabled = true
    _layer_enable.tooltip_text = "Native katman sistemi henüz hazır değil."
    _layer_select.hide()
    _layer_add.hide()
    _layer_visible.hide()
    _layer_restore.hide()

func _sync_view_profile() -> void:
    if not is_instance_valid(_profile_select):
        return
    _profile_select.disabled = not is_instance_valid(_active)
    if not is_instance_valid(_active):
        return
    var mesh_size := int(_active.get("mesh_size"))
    var spacing := float(_active.get("vertex_spacing"))
    var lods := int(_active.get("mesh_lods"))
    for i in range(3):
        var levels := _profile_select.get_item_id(i)
        var half_width := (2.0*mesh_size+2.0)*spacing*pow(2.0,levels-1)
        var label := ["Yakın","Orta","Tam"][i] as String
        _profile_select.set_item_text(i,"%s %.0fm" % [label,half_width])
    var index := _profile_select.get_item_index(lods)
    if index >= 0:
        _profile_select.select(index)
    else:
        # Do not mutate a pre-existing custom profile just by selecting a node.
        _profile_select.select(-1)
    _profile_select.tooltip_text = "Yaklaşık görüş yarıçapı. Seçim sahnenin LOD sayısını değiştirir; yakın çözünürlük korunur."

func _view_profile_changed(index: int) -> void:
    if not is_instance_valid(_active) or index < 0 or index >= 3:
        return
    var levels := _profile_select.get_item_id(index)
    var old := int(_active.get("mesh_lods"))
    if old == levels:
        return
    _finish_stroke()
    _touch_session = false
    _touch_index = -1
    _multi_touch = false
    _brush_button.set_pressed_no_signal(false)
    _brush_button.text = "Fırça"
    # Undoable explicit scene property change; no automatic rebuilding on camera moves.
    var undo_redo := get_undo_redo()
    undo_redo.create_action("TerraForge görüş mesafesi",UndoRedo.MERGE_DISABLE,_active)
    undo_redo.add_do_property(_active,"mesh_lods",levels)
    undo_redo.add_undo_property(_active,"mesh_lods",old)
    undo_redo.commit_action()
    _sync_view_profile()
    _last_input_result = "View updated; Brush OFF. Near resolution unchanged."
    _set_status(_last_input_result)

func _on_tool_changed(tool: int) -> void:
    _finish_stroke()
    _current_tool = tool
    _advanced_row.visible = tool in [2,8]
    _advanced_label.text = "Yöntem" if tool in [2,8] else "Şekil"
    _stamp_preset.visible = false
    _ramp_rise.visible = false
    _weather_mode.visible = tool==8
    _smooth_mode.visible = tool==2
    _refresh_tool_help()
    if tool==8:
        _set_status("Weather: touch area, release to apply one pass.")
    else:
        _set_status("Ridge/Valley: draw a path, release to apply." if tool in [4,5] else "Brush ON: drag to edit native heights.")

func _refresh_tool_help() -> void:
    if not is_instance_valid(_tool_help):
        return
    var index := _tool_select.selected
    if index<0:
        _tool_help.text="Bir araç seç."
        return
    var description := _tool_select.get_popup().get_item_tooltip(index)
    if index==2 and is_instance_valid(_smooth_mode):
        description=_smooth_mode.get_popup().get_item_tooltip(clampi(_smooth_mode.selected,0,2))
        _smooth_mode.tooltip_text=description
    if index==8 and is_instance_valid(_weather_mode):
        description="Dokun ve bırak. "+_weather_mode.get_popup().get_item_tooltip(clampi(_weather_mode.selected,0,1))
    _tool_help.text=description
    _tool_select.tooltip_text=description

func _tr_status(message: String) -> String:
    # Presentation only: raw backend status and CI contracts stay unchanged.
    var exact := {
        "Brush OFF": "Fırça kapalı",
        "Brush ON: touch the terrain surface.": "Fırça açık: araziye dokun.",
        "Brush ON: drag to edit native heights.": "Fırça açık: sürükleyerek şekillendir.",
        "Create terrain or select an existing one.": "Arazi oluştur veya mevcut araziyi seç.",
        "Native terrain selected": "Arazi seçildi.",
        "View updated; Brush OFF. Near resolution unchanged.": "Görüş güncellendi; fırça kapalı. Yakın çözünürlük aynı.",
        "Ridge/Valley: draw a path, release to apply.": "Dağ sırtı / Vadi: hat çiz, bırakınca uygula.",
        "Weather: touch area, release to apply one pass.": "Aşındır: alana dokun, bırakınca bir işlem uygula.",
        "Open a Node3D scene; native extension required.": "Node3D sahnesi aç; native eklenti gerekli.",
        "Native extension unavailable.": "Native eklenti yüklenemedi.",
        "Native shader missing.": "Arazi shader dosyası eksik.",
        "Native initialization failed.": "Arazi başlatılamadı.",
        "Native region creation failed.": "Bölge oluşturulamadı.",
        "Native region count mismatch.": "Bölge sayısı uyuşmuyor.",
        "Cannot create native data directory.": "Arazi veri klasörü oluşturulamadı.",
        "Create or select native terrain first.": "Önce arazi oluştur veya seç.",
        "No native terrain selected.": "Arazi seçilmedi.",
        "Cannot create native data directory; scene not saved.": "Veri klasörü oluşturulamadı; sahne kaydedilmedi.",
        "Surface externalization failed; scene not saved.": "Dokular ayrı dosyaya taşınamadı; sahne kaydedilmedi.",
        "Terrain and scene saved; verified backup retained.": "Arazi ve sahne kaydedildi; doğrulanmış yedek korundu.",
        "Corridor cancelled.": "Hat işlemi iptal edildi.",
        "Weather cancelled.": "Aşındırma iptal edildi.",
        "Path too long; release and draw a shorter corridor.": "Hat çok uzun; bırakıp daha kısa bir hat çiz.",
        "Native data not ready.": "Arazi verisi hazır değil.",
        "Path left editable surface; action cancelled.": "Hat düzenlenebilir yüzeyin dışına çıktı; işlem iptal.",
        "Input received; terrain ray missed.": "Girdi alındı; araziye temas edilemedi.",
        "Weather: release to apply.": "Aşındır: uygulamak için bırak.",
        "Surface hit; no new height change (spacing/flat tool/edge).": "Yüzeye temas edildi; yeni yükseklik değişimi yok.",
        "No native terrain attached.": "Arazi bağlı değil.",
        "Native data object missing.": "Arazi veri nesnesi eksik.",
        "Native active region resource missing.": "Etkin bölge kaynağı eksik.",
        "Unsupported native brush.": "Desteklenmeyen fırça.",
        "Brush footprint exceeds grid budget; reduce radius for this spacing.": "Fırça işlem sınırını aştı; yarıçapı küçült.",
        "Flatten target is outside editable terrain.": "Düzleştirme hedefi düzenlenebilir alan dışında.",
        "Height out of bounds; dab rejected.": "Yükseklik sınır dışı; işlem reddedildi.",
        "Invalid corridor tool or power.": "Hat aracı veya gücü geçersiz.",
        "Corridor height out of bounds; no changes made.": "Hat yüksekliği sınır dışı; değişiklik yapılmadı.",
        "Corridor has no editable samples.": "Hatta düzenlenebilir örnek yok.",
        "Invalid Weather center or size.": "Aşındırma merkezi veya yarıçapı geçersiz.",
        "Invalid Weather grid.": "Aşındırma ızgarası geçersiz.",
        "Weather footprint exceeds grid budget.": "Aşındırma alanı işlem sınırını aştı.",
        "Weather: no movable material at this slope.": "Bu eğimde taşınabilir malzeme yok.",
        "Nothing to undo.": "Geri alınacak işlem yok.",
        "Undo unavailable.": "Geri alma yapılamadı.",
        "Native undo applied.": "İşlem geri alındı.",
        "Nothing to redo.": "Yinelenecek işlem yok.",
        "Redo unavailable.": "Yineleme yapılamadı.",
        "Native redo applied.": "İşlem yinelendi.",
        "Cannot create snapshot folder.": "Yedek klasörü oluşturulamadı.",
        "Backup manifest write failed; live directory untouched.": "Yedek manifesti yazılamadı; mevcut veriye dokunulmadı.",
        "No verified backup for current save.": "Bu kayıt için doğrulanmış yedek yok.",
        "Invalid corridor parameters.": "Hat ayarları geçersiz.",
        "Invalid corridor point.": "Hat noktası geçersiz.",
        "Corridor exceeds 256m; draw shorter paths.": "Hat 256 metreyi aştı; daha kısa çiz.",
        "Corridor work budget exceeded; use a shorter or narrower path.": "Hat işlem sınırını aştı; daha kısa veya dar çiz.",
        "Corridor sample budget exceeded; draw shorter paths.": "Hat örnek sınırını aştı; daha kısa çiz.",
        "Invalid Weather footprint.": "Aşındırma alanı geçersiz.",
        "Invalid Weather source.": "Aşındırma kaynak verisi geçersiz.",
        "Flow routing incomplete; no changes made.": "Akış hesabı tamamlanamadı; değişiklik yapılmadı.",
        "Weather relief limit exceeded; reduce Size or Power.": "Aşındırma yükseklik sınırı aşıldı; yarıçapı veya gücü azalt.",
        "Weather mass validation failed.": "Malzeme dengesi doğrulanamadı."
    }
    if exact.has(message):
        return str(exact[message])
    var result := message
    # Only known dynamic message families; preserve coordinates and paths.
    result = result.replace("External surface texture missing: ","Yüzey dokusu eksik: ")
    result = result.replace("Verified backup saved; scene save failed: ","Yedek doğrulandı; sahne kaydedilemedi: ")
    result = result.replace("Native region count ","Bölge sayısı ")
    result = result.replace(" outside 1..64."," 1–64 aralığı dışında.")
    result = result.replace("Native active list ","Etkin bölge listesi ")
    result = result.replace(" != count "," / beklenen ")
    result = result.replace("Duplicate native location ","Tekrarlanan bölge konumu ")
    result = result.replace("RF source invalid at ","Geçersiz Float32 kaynak: ")
    result = result.replace("; do not edit converted data.","; dönüştürülmüş veriyi düzenleme.")
    result = result.replace("Native grid invalid: ","Geçersiz arazi ızgarası: ")
    result = result.replace("Raise: no editable samples at ","Yükselt: düzenlenebilir örnek yok, konum ")
    result = result.replace(" (grid "," (ızgara ")
    result = result.replace("Native write readback mismatch: ","Yazılan veri doğrulanamadı: ")
    result = result.replace("Backup blocked: invalid RF map at ","Yedek engellendi; geçersiz Float32 harita: ")
    result = result.replace("Native backup failed: ","Arazi yedeği başarısız: ")
    result = result.replace("Backup readback failed at ","Yedek doğrulanamadı: ")
    result = result.replace("; live directory untouched.","; mevcut veriye dokunulmadı.")
    result = result.replace("Scene region write mismatch at ","Bölge kaydı uyuşmuyor: ")
    result = result.replace(". Verified backup: ",". Doğrulanmış yedek: ")
    result = result.replace("Corridor edited ","Hat işlemi: ")
    result = result.replace(" samples."," örnek değişti.")
    result = result.replace("Weather edited ","Aşındırma: ")
    result = result.replace("Edited ","Düzenlenen ")
    result = result.replace(" samples in last dab."," örnek (son dokunuş).")
    result = result.replace("Path ","Hat ")
    result = result.replace(" points | release to apply"," nokta | bırakınca uygula")
    result = result.replace(" regions created. Save terrain and scene."," bölge oluşturuldu. Araziyi ve sahneyi kaydet.")
    result = result.replace(" RF saved ("," Float32 kaydedildi (")
    result = result.replace(" regions). Backup: "," bölge). Yedek: ")
    return result

func _set_status(message: String) -> void:
    var started := Time.get_ticks_usec() if _drop_active else 0
    _raw_status = message
    if is_instance_valid(_status):
        var translated := _tr_status(message)
        if _status.text!=translated:
            _status.text=translated
    if _drop_active:
        _drop_status_us+=Time.get_ticks_usec()-started

func _handles(object: Object) -> bool:
    return object is Node3D and object.is_class("Terrain3D") and object.has_meta("terraforge_native_workspace")

func _edit(object: Object) -> void:
    if _handles(object):
        _set_active(object as Node3D)

func _set_active(node: Node3D) -> void:
    if _active == node:
        return
    _finish_stroke()
    _active = node
    _brush.attach(node)
    if is_instance_valid(node) and str(node.get("data_directory")).is_empty():
        if not _ensure_data_directory(node):
            push_warning("TerraForge: cannot assign native data directory; use panel Save before closing.")
    _sync_view_profile()
    _touch_session = false
    _touch_index = -1
    _multi_touch = false
    _input_count = 0
    _hit_count = 0
    _changed_count = 0
    _brush_button.set_pressed_no_signal(false)
    _brush_button.text = "Fırça"
    _set_status("Native terrain selected" if node != null else "Create terrain or select an existing one.")

func _on_scene_changed(_root: Node) -> void:
    _set_active(null)
    call_deferred("_on_selection_changed")

func _on_selection_changed() -> void:
    for node in get_editor_interface().get_selection().get_selected_nodes():
        if _handles(node):
            _set_active(node)
            return
    if not is_instance_valid(_active):
        var root := get_editor_interface().get_edited_scene_root()
        if root != null:
            var candidates: Array[Node3D] = []
            _find_workspaces(root,candidates)
            # Never silently select among multiple editable terrains.
            if candidates.size() == 1:
                _set_active(candidates[0])
                return
        _set_active(null)

func _find_workspaces(node: Node, result: Array[Node3D]) -> void:
    if _handles(node):
        result.append(node as Node3D)
    for child in node.get_children():
        _find_workspaces(child,result)

func _choose_new_size() -> void:
    var dialog := ConfirmationDialog.new()
    dialog.title = "TerraForge — Yeni arazi"
    dialog.dialog_text = "Float32 arazi | 25 cm"
    var options := OptionButton.new()
    options.add_item("128 × 128 m (1 bölge)",1)
    options.add_item("256 × 256 m (4 bölge)",2)
    options.add_item("512 × 512 m (16 bölge)",4)
    options.select(0)
    dialog.add_child(options)
    dialog.confirmed.connect(func():
        var side := options.get_selected_id()
        dialog.queue_free()
        _create_terrain(side)
    )
    dialog.canceled.connect(dialog.queue_free)
    get_editor_interface().get_base_control().add_child(dialog)
    dialog.popup_centered()
    
func _create_terrain(side: int) -> void:
    var root := get_editor_interface().get_edited_scene_root()
    if not root is Node3D or not ClassDB.can_instantiate("Terrain3D"):
        _set_status("Open a Node3D scene; native extension required.")
        return
    var terrain := ClassDB.instantiate("Terrain3D") as Node3D
    var material := ClassDB.instantiate("Terrain3DMaterial") as Resource
    if terrain == null or material == null:
        _set_status("Native extension unavailable.")
        return
    var shader := load("res://shaders/world_surface.gdshader") as Shader
    if shader == null:
        terrain.free()
        _set_status("Native shader missing.")
        return
    material.set("max_regions",64)
    material.set("world_background",0)
    material.set("texture_filtering",1)
    material.set("shader_override",shader)
    material.set("shader_override_enabled",true)
    terrain.set("material",material)
    terrain.set("vertex_spacing",0.25)
    terrain.set("mesh_size",16)
    terrain.set("mesh_lods",7)
    terrain.set("tessellation_level",0)
    terrain.set("cast_shadows",0)
    terrain.set("gi_mode",0)
    terrain.set("collision_mode",1)
    terrain.set("collision_radius",32)
    terrain.set("collision_shape_size",16)
    terrain.name = "TerraForgeTerrain"
    terrain.set_meta("terraforge_native_workspace",true)
    root.add_child(terrain,true)
    terrain.owner = root
    terrain.set("save_16_bit",false)
    if int(terrain.call("get_region_size")) != 512:
        terrain.call("change_region_size",512)
    var data: Object = terrain.get("data")
    if data == null or int(terrain.call("get_region_size")) != 512:
        terrain.free()
        _set_status("Native initialization failed.")
        return
    for z in range(side):
        for x in range(side):
            var region: Resource = data.call("add_region_blank",Vector2i(x,z),false)
            if region == null:
                terrain.free()
                _set_status("Native region creation failed.")
                return
    data.call("update_maps",3,true,false)
    if int(data.call("get_region_count")) != side*side:
        terrain.free()
        _set_status("Native region count mismatch.")
        return
    for kind: String in ["soil","rock","sand","grass"]:
        var texture := ResourceLoader.load("res://world/"+kind+"_texture.res","Texture2D") as Texture2D
        if texture == null:
            terrain.free()
            _set_status("External surface texture missing: "+kind)
            return
        material.call("set_shader_param",kind+"_tex",texture)
    if not _ensure_data_directory(terrain):
        terrain.free()
        _set_status("Cannot create native data directory.")
        return
    material.call("set_show_checkered",false)
    var view := get_editor_interface().get_editor_viewport_3d(0)
    if view != null and view.get_camera_3d() != null:
        terrain.call("set_camera",view.get_camera_3d())
    var selection := get_editor_interface().get_selection()
    selection.clear()
    selection.add_node(terrain)
    _set_active(terrain)
    _set_status("Native %d regions created. Save terrain and scene." % (side*side))
    _popup.hide()

# Native Terrain3D persists modified regions on Godot EDITOR_PRE_SAVE.
# A new empty directory retains current data (no destructive reload).
func _ensure_data_directory(node: Node3D) -> bool:
    if not str(node.get("data_directory")).is_empty():
        return true
    var folder := "res://terraforge_data/native_"+Crypto.new().generate_random_bytes(12).hex_encode()
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
        return false
    node.call("set_data_directory",folder)
    return str(node.get("data_directory"))==folder

# Migrate existing embedded surface textures without replacing custom pixels.
# Explicit Save only; never read GPU textures per frame.
func _externalize_surfaces(node: Node3D) -> bool:
    var material: Resource = node.get("material")
    if material == null:
        return false
    var folder := str(node.get("data_directory")).path_join("surfaces")
    for kind: String in ["soil","rock","sand","grass"]:
        var value: Variant = material.call("get_shader_param",kind+"_tex")
        var texture: Texture2D = value if value is Texture2D else null
        if texture == null:
            # Terrain3D property storage holds the actual resource if getter returns RID.
            var params: Dictionary = material.call("_get_shader_parameters")
            var stored: Variant = params.get(kind+"_tex")
            texture = stored if stored is Texture2D else null
        if texture == null:
            return false
        if not texture.resource_path.is_empty() and not texture.resource_path.contains("::"):
            continue
        if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
            return false
        var path := folder.path_join(kind+"_"+Crypto.new().generate_random_bytes(8).hex_encode()+".res")
        if ResourceSaver.save(texture,path,ResourceSaver.FLAG_COMPRESS) != OK:
            return false
        var saved := ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
        if saved == null or saved.get_size()!=texture.get_size():
            return false
        # Reload the exact saved resource rather than embed it in the scene.
        material.call("set_shader_param",kind+"_tex",saved)
    return true

func _toggle_brush(enabled: bool) -> void:
    if enabled and not is_instance_valid(_active):
        _on_selection_changed()
    if enabled and not is_instance_valid(_active):
        _brush_button.set_pressed_no_signal(false)
        _set_status("Create or select native terrain first.")
        return
    if not enabled:
        _finish_stroke()
        _brush.cancel_advanced()
        _touch_session = false
        _touch_index = -1
        _multi_touch = false
        _last_input_result = "Brush OFF"
    else:
        _brush_button.set_pressed_no_signal(true)
        _input_count = 0
        _hit_count = 0
        _changed_count = 0
        _last_input_result = "Brush ON: touch the terrain surface."
        _popup.hide()
    _brush_button.text = "Fırça açık" if enabled else "Fırça"

func _save_active() -> void:
    if _brush.advanced_busy():
        _set_status("Arazi işlemi hesaplanıyor; bitince yeniden dene.")
        return
    if _stroke_active and _is_basic() and _stroke_sampler.pending_count()>0:
        _set_status("Fırça işlemi sürüyor; tamamlanınca yeniden dene.")
        return
    _finish_stroke()
    if not is_instance_valid(_active):
        _set_status("No native terrain selected.")
        return
    if not _ensure_data_directory(_active):
        _set_status("Cannot create native data directory; scene not saved.")
        return
    if not _externalize_surfaces(_active):
        _set_status("Surface externalization failed; scene not saved.")
        return
    var result := _brush.save_snapshot()
    if not result.begins_with("Native RF saved"):
        _set_status(result)
        return
    # Native pre-save uses the live directory. Explicit backup already exists.
    _active.set("save_16_bit",false)
    var error := get_editor_interface().save_scene()
    if error!=OK:
        _set_status("Verified backup saved; scene save failed: "+error_string(error)+" | "+_brush.last_snapshot_path)
        return
    var verify_error := _brush.verify_scene_storage()
    if not verify_error.is_empty():
        _set_status(verify_error)
        return
    _last_input_result = "Terrain and scene saved; verified backup retained."
    _set_status(_last_input_result)

func _undo() -> void:
    if _brush.advanced_busy():
        _set_status("Arazi işlemi hesaplanıyor; bitince yeniden dene.")
        return
    if _stroke_active and _is_basic() and _stroke_sampler.pending_count()>0:
        _set_status("Fırça işlemi sürüyor; tamamlanınca yeniden dene.")
        return
    _finish_stroke()
    if is_instance_valid(_active):
        _set_status(_brush.undo())

func _redo() -> void:
    if _brush.advanced_busy():
        _set_status("Arazi işlemi hesaplanıyor; bitince yeniden dene.")
        return
    if _stroke_active and _is_basic() and _stroke_sampler.pending_count()>0:
        _set_status("Fırça işlemi sürüyor; tamamlanınca yeniden dene.")
        return
    _finish_stroke()
    if is_instance_valid(_active):
        _set_status(_brush.redo())

func _run_self_test() -> void:
    if not is_instance_valid(_active):
        _set_status("No native terrain selected.")
        return
    var data: Object = _active.get("data")
    _set_status("Float32 | %d bölge | %.2fm | %d LOD\nGirdi %d | Temas %d | Düzenleme %d\n%s" % [data.call("get_region_count"),_active.get("vertex_spacing"),_active.get("mesh_lods"),_input_count,_hit_count,_changed_count,_tr_status(_last_input_result)])

func _is_basic() -> bool:
    return _corridor_tool >= 0 and _corridor_tool <= 3

func _begin_basic() -> void:
    _basic_error = ""
    _basic_dabs = 0
    _basic_max_us = 0
    _smooth_mode_at_press = _smooth_mode.get_selected_id() if _corridor_tool==2 else 0
    _basic_accepting = _stroke_sampler.begin(maxf(float(_active.get("vertex_spacing")),_corridor_radius*0.2))

func _offer_basic(point: Vector2) -> void:
    if not _basic_accepting:
        return
    if not _stroke_sampler.offer(point):
        # Explicit backpressure: keep accepted samples; never silently bridge
        # over the rejected input or grow the queue without bound.
        _basic_accepting = false
        _basic_error = "Fırça kuyruğu doldu; kalan hareket alınmadı. Daha kısa çiz."
        _set_status(_basic_error)

func _pump_basic() -> void:
    if not _stroke_active or not _is_basic() or not is_instance_valid(_active):
        return
    # At most one Smooth job in flight. Commit and next capture never share
    # a pump; next snapshot sees the previous dab's committed heights.
    if _corridor_tool==2 and _brush.smooth_busy():
        var poll_started := Time.get_ticks_usec()
        var outcome := _brush.poll_smooth()
        _basic_max_us=maxi(_basic_max_us,Time.get_ticks_usec()-poll_started)
        if outcome.is_empty():
            return
        var failure := str(outcome["error"])
        if not failure.is_empty():
            _basic_error=failure
            _finish_stroke(false)
            return
        _basic_dabs+=1
        _changed_count+=_brush.last_changed_cells
        _last_input_result="Yumuşatma: %d örnek bekliyor." % _stroke_sampler.pending_count()
        _set_status(_last_input_result)
        return
    if _stroke_sampler.pending_count()>0:
        var point: Vector2 = _stroke_sampler.take_next()
        var started := Time.get_ticks_usec()
        if _corridor_tool==2:
            var dispatch_error := _brush.start_smooth(point,_corridor_radius,_corridor_power,_smooth_mode_at_press)
            _basic_max_us=maxi(_basic_max_us,Time.get_ticks_usec()-started)
            if not dispatch_error.is_empty():
                _basic_error=dispatch_error
                _finish_stroke(false)
            return
        var error := _brush.dab(Vector3(point.x,0.0,point.y),_corridor_tool,_corridor_radius,_corridor_power,true,_smooth_mode_at_press)
        _basic_max_us = maxi(_basic_max_us,Time.get_ticks_usec()-started)
        _basic_dabs += 1
        _changed_count += _brush.last_changed_cells
        if not error.is_empty():
            _basic_error = error
            _last_input_result = error
            _finish_stroke(false)
            return
        _last_input_result = _basic_error if not _basic_error.is_empty() else "Fırça: %d örnek bekliyor." % _stroke_sampler.pending_count()
    _set_status(_last_input_result)

func _finish_stroke(apply_path: bool = false) -> void:
    if _stroke_active and _is_basic():
        var dropped := _stroke_sampler.pending_count()
        if _corridor_tool==2 and _brush.smooth_busy():
            _brush.cancel_smooth()
            dropped+=1
        _stroke_sampler.cancel()
        _basic_accepting = false
        # Release: keep committed prefix; discard all uncommitted work.
        if not _basic_error.is_empty():
            _last_input_result = _basic_error
        elif dropped>0:
            _last_input_result = "Fırça durdu; %d gecikmiş örnek iptal." % dropped
        else:
            _last_input_result = "Fırça tamamlandı: %d uygulama." % _basic_dabs
        _set_status(_last_input_result)
    if _stroke_active and is_instance_valid(_active):
        if _corridor_tool in [4,5]:
            if apply_path and _corridor_error.is_empty() and not _corridor_points.is_empty():
                var result := _brush.start_corridor(_corridor_points,_corridor_tool,_corridor_radius,_corridor_power)
                _last_input_result = result if not result.is_empty() else "Dağ sırtı/vadi arka planda hesaplanıyor."
            elif not _corridor_error.is_empty():
                _last_input_result = _corridor_error
            else:
                _last_input_result = "Corridor cancelled."
            _set_status(_last_input_result)
        elif _corridor_tool==8:
            if apply_path and _corridor_error.is_empty() and not _corridor_points.is_empty():
                var result := _brush.start_weather(_corridor_points[0],_corridor_radius,_corridor_power,_weather_mode_at_press)
                _last_input_result=result if not result.is_empty() else "Aşındırma arka planda hesaplanıyor."
            else:
                _last_input_result="Weather cancelled."
            _set_status(_last_input_result)
        else:
            _brush.end()
    _corridor_points.clear()
    _corridor_error = ""
    _corridor_length = 0.0
    _corridor_tool = -1
    _stroke_active = false

func _collect_corridor(hit: Vector3) -> void:
    if not _corridor_error.is_empty():
        return
    var point := Vector2(hit.x,hit.z)
    if not _corridor_points.is_empty():
        var segment := point.distance_to(_corridor_points.back())
        if segment<maxf(0.5,_corridor_radius*0.35):
            return
        if _corridor_length+segment>256.0 or _corridor_points.size()>=128:
            _corridor_error = "Path too long; release and draw a shorter corridor."
            _set_status(_corridor_error)
            return
        _corridor_length+=segment
    _corridor_points.append(point)
    _last_input_result = "Path %d points | release to apply" % _corridor_points.size()
    _set_status(_last_input_result)

func _paint_at(camera: Camera3D, position: Vector2) -> void:
    if not is_instance_valid(_active) or not _stroke_active:
        return
    _input_count += 1
    # Weather is a single local action, not repeated per motion event.
    if _corridor_tool==8 and not _corridor_points.is_empty():
        return
    var data: Object = _active.get("data")
    if data == null:
        _last_input_result = "Native data not ready."
        return
    if _active.call("get_camera") != camera:
        _active.call("set_camera",camera)
    var hit := _trace_ray(camera.project_ray_origin(position),camera.project_ray_normal(position))
    if not hit.is_finite() or absf(hit.x)>1e8 or absf(hit.y)>1e8 or absf(hit.z)>1e8:
        if _corridor_tool in [4,5,8]:
            _corridor_error = "Path left editable surface; action cancelled."
        elif _is_basic():
            _stroke_sampler.break_path()
        _last_input_result = "Input received; terrain ray missed."
        _set_status(_last_input_result)
        return
    _hit_count += 1
    if _corridor_tool==8:
        if _corridor_error.is_empty():
            _corridor_points.append(Vector2(hit.x,hit.z))
            _set_status("Weather: release to apply.")
        return
    if _corridor_tool in [4,5]:
        _collect_corridor(hit)
        return
    if _is_basic():
        _offer_basic(Vector2(hit.x,hit.z))

func _start_stroke(camera: Camera3D, position: Vector2) -> void:
    if _brush.advanced_busy():
        _set_status("Arazi işlemi hesaplanıyor; bitince yeniden dene.")
        return
    _finish_stroke()
    _brush.begin()
    _corridor_tool = _tool_select.selected
    _corridor_radius = float(_radius.value)
    _corridor_power = float(_strength.value)
    _weather_mode_at_press = _weather_mode.selected
    _stroke_active = true
    if _is_basic():
        _begin_basic()
    _paint_at(camera,position)

func _trace_ray(origin: Vector3, direction: Vector3) -> Vector3:
    var started := Time.get_ticks_usec() if _drop_active else 0
    var hit: Vector3=_active.call("get_intersection",origin,direction,false)
    if _drop_active:
        var elapsed := Time.get_ticks_usec()-started
        _drop_ray_count+=1
        _drop_ray_us+=elapsed
        _drop_ray_max_us=maxi(_drop_ray_max_us,elapsed)
    return hit

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
    if not _drop_active:
        return _input_body(camera,event)
    var started := Time.get_ticks_usec()
    var result := _input_body(camera,event)
    _drop_input_count+=1
    _drop_input_us+=Time.get_ticks_usec()-started
    return result

# Release guard outside the viewport, for continuous brushes only.
func _input(event: InputEvent) -> void:
    if not _stroke_active or not _is_basic():
        return
    if event is InputEventScreenTouch and event.index==_touch_index and (not event.pressed or event.canceled):
        _finish_stroke(true)
        _touch_session=false
        _touch_index=-1
        _multi_touch=false
        _last_touch_ms=Time.get_ticks_msec()
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and not _touch_session:
        _finish_stroke(true)

func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT and _stroke_active:
        _finish_stroke(false)
        _touch_session=false
        _touch_index=-1
        _multi_touch=false

func _input_body(camera: Camera3D, event: InputEvent) -> int:
    if not is_instance_valid(_active) or not _brush_button.button_pressed or _popup.visible:
        return EditorPlugin.AFTER_GUI_INPUT_PASS
    var root := get_editor_interface().get_edited_scene_root()
    if root == null or (root != _active and not root.is_ancestor_of(_active)):
        return EditorPlugin.AFTER_GUI_INPUT_PASS
    if event is InputEventScreenTouch:
        _last_touch_ms = Time.get_ticks_msec()
        if event.canceled:
            if event.index==_touch_index:
                _finish_stroke(false)
                _touch_session=false
                _touch_index=-1
                _multi_touch=false
            return EditorPlugin.AFTER_GUI_INPUT_STOP
        if event.pressed:
            if _touch_index != -1 and event.index != _touch_index:
                _finish_stroke()
                _multi_touch = true
                return EditorPlugin.AFTER_GUI_INPUT_PASS
            if _multi_touch:
                return EditorPlugin.AFTER_GUI_INPUT_PASS
            _touch_index = event.index
            _touch_session = true
            _start_stroke(camera,event.position)
        elif event.index == _touch_index:
            _finish_stroke(not _multi_touch)
            _touch_session = false
            _touch_index = -1
            _multi_touch = false
        else:
            return EditorPlugin.AFTER_GUI_INPUT_PASS
        return EditorPlugin.AFTER_GUI_INPUT_STOP
    if event is InputEventScreenDrag:
        _last_touch_ms = Time.get_ticks_msec()
        if _stroke_active and _touch_session and not _multi_touch and event.index == _touch_index:
            _paint_at(camera,event.position)
            return EditorPlugin.AFTER_GUI_INPUT_STOP
        return EditorPlugin.AFTER_GUI_INPUT_PASS
    # Suppress paired touch-generated mouse events only after a real touch
    # reached this callback; pure mouse-emulated Android streams remain usable.
    if _touch_session or Time.get_ticks_msec()-_last_touch_ms<350:
        if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT) or event is InputEventMouseMotion:
            return EditorPlugin.AFTER_GUI_INPUT_STOP if not _multi_touch else EditorPlugin.AFTER_GUI_INPUT_PASS
        return EditorPlugin.AFTER_GUI_INPUT_PASS
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
        if event.pressed:
            _start_stroke(camera,event.position)
        else:
            _finish_stroke(true)
        return EditorPlugin.AFTER_GUI_INPUT_STOP
    if event is InputEventMouseMotion and _stroke_active:
        if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
            _finish_stroke()
            return EditorPlugin.AFTER_GUI_INPUT_PASS
        _paint_at(camera,event.position)
        return EditorPlugin.AFTER_GUI_INPUT_STOP
    return EditorPlugin.AFTER_GUI_INPUT_PASS
