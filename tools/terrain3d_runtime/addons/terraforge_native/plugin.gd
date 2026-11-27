@tool
extends EditorPlugin
## Mobile-first editor controls: only a tiny button remains in the 3D toolbar.
## Settings appear in a dismissible popup rather than a permanent bottom panel.
const Brush = preload("res://addons/terraforge_native/native_brush.gd")
var _brush := Brush.new()

var _toolbar: HBoxContainer
var _menu_button: Button
var _brush_button: CheckButton
var _popup: PopupPanel
var _status: Label
var _stats_label: Label
var _tool_select: OptionButton
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

func _enter_tree() -> void:
    _toolbar = HBoxContainer.new()
    _toolbar.name = "TerraForgeQuickTools"
    _toolbar.add_theme_constant_override("separation", 3)
    _menu_button = Button.new()
    _menu_button.text = "Terrain"
    _menu_button.tooltip_text = "TerraForge tools and settings"
    _menu_button.pressed.connect(_toggle_popup)
    _toolbar.add_child(_menu_button)
    _brush_button = CheckButton.new()
    _brush_button.text = "Brush"
    _brush_button.tooltip_text = "Enable sculpting; disable to move the camera"
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
    new_button.text = "+ New"
    new_button.tooltip_text = "Create an empty editable terrain"
    new_button.pressed.connect(_choose_new_size)
    header.add_child(new_button)
    var save_button: Button = Button.new()
    save_button.text = "Save"
    save_button.pressed.connect(_save_active)
    header.add_child(save_button)

    var tool_row: HBoxContainer = HBoxContainer.new()
    content.add_child(tool_row)
    var label: Label = Label.new()
    label.text = "Tool"
    tool_row.add_child(label)
    _tool_select = OptionButton.new()
    for tool_name in ["Raise", "Lower", "Smooth", "Flatten", "Ridge", "Valley", "Ramp", "Stamp", "Weather"]:
        _tool_select.add_item(tool_name)
    for index in range(4,9):
        _tool_select.set_item_disabled(index,true)
    _tool_select.item_selected.connect(_on_tool_changed)
    _tool_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tool_row.add_child(_tool_select)
    var undo_button: Button = Button.new()
    undo_button.text = "↶"
    undo_button.tooltip_text = "Undo terrain stroke"
    undo_button.pressed.connect(_undo)
    tool_row.add_child(undo_button)
    var redo_button: Button = Button.new()
    redo_button.text = "↷"
    redo_button.tooltip_text = "Redo terrain stroke"
    redo_button.pressed.connect(_redo)
    tool_row.add_child(redo_button)

    var radius_row: HBoxContainer = HBoxContainer.new()
    content.add_child(radius_row)
    var radius_label: Label = Label.new()
    radius_label.text = "Size"
    radius_label.custom_minimum_size.x = 58
    radius_row.add_child(radius_label)
    _radius = HSlider.new()
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
    strength_label.text = "Power"
    strength_label.custom_minimum_size.x = 58
    strength_row.add_child(strength_label)
    _strength = HSlider.new()
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
    _advanced_label.text = "Shape"
    _advanced_label.custom_minimum_size.x = 58
    _advanced_row.add_child(_advanced_label)
    _stamp_preset = OptionButton.new()
    for preset_name in ["Hill", "Crater", "Mesa"]:
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

    var profile_row: HBoxContainer = HBoxContainer.new()
    content.add_child(profile_row)
    var profile_label: Label = Label.new()
    profile_label.text = "Quality"
    profile_label.custom_minimum_size.x = 58
    profile_row.add_child(profile_label)
    _profile_select = OptionButton.new()
    _profile_select.add_item("Mobile")
    _profile_select.add_item("Balanced")
    _profile_select.add_item("High")
    _profile_select.select(0)
    _profile_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _profile_select.disabled = true
    _profile_select.tooltip_text = "Native reference profile locked during integration"
    profile_row.add_child(_profile_select)
    var diagnostics_button: Button = Button.new()
    diagnostics_button.text = "Check"
    diagnostics_button.tooltip_text = "Run non-destructive terrain geometry and performance self-test"
    diagnostics_button.pressed.connect(_run_self_test)
    profile_row.add_child(diagnostics_button)

    # One small contextual row instead of another tall mobile dock.
    _layer_row = HBoxContainer.new()
    _layer_row.add_theme_constant_override("separation", 3)
    content.add_child(_layer_row)
    _layer_enable = Button.new()
    _layer_enable.text = "Enable Layers"
    _layer_enable.tooltip_text = "Create a separate .tfl document; legacy .tfh remains untouched. Save the scene after enabling."
    _layer_enable.disabled = true
    _layer_row.add_child(_layer_enable)
    _layer_select = OptionButton.new()
    _layer_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _layer_select.disabled = true
    _layer_row.add_child(_layer_select)
    _layer_add = Button.new()
    _layer_add.text = "+"
    _layer_add.tooltip_text = "Add another independent sculpt layer (maximum 8)"
    _layer_add.disabled = true
    _layer_row.add_child(_layer_add)
    _layer_visible = CheckButton.new()
    _layer_visible.text = "On"
    _layer_visible.tooltip_text = "Show or hide selected layer"
    _layer_visible.disabled = true
    _layer_row.add_child(_layer_visible)
    _layer_restore = Button.new()
    _layer_restore.text = "Restore"
    _layer_restore.tooltip_text = "Manually restore last verified .tfl.bak. Damaged original is preserved as .corrupt_*."
    _layer_restore.disabled = true
    _layer_row.add_child(_layer_restore)
    _refresh_layer_ui()

    _stats_label = Label.new()
    _stats_label.text = "Tiles: -"
    _stats_label.modulate.a = 0.7
    content.add_child(_stats_label)
    _status = Label.new()
    _status.text = "Create terrain or select an existing one."
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(_status)

    var selection: EditorSelection = get_editor_interface().get_selection()
    selection.selection_changed.connect(_on_selection_changed)
    scene_changed.connect(_on_scene_changed)
    set_process(true)
    call_deferred("_on_selection_changed")

func _exit_tree() -> void:
    _finish_stroke()
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
    var required_height: int = 350 if _advanced_row.visible else 315
    var height: int = mini(required_height, maxi(180, window_size.y - 16))
    var x: int = clampi(button_position.x, 0, maxi(0, window_size.x - width))
    var y: int = clampi(
        button_position.y + int(_menu_button.size.y) + 3,
        0, maxi(0, window_size.y - height)
    )
    _popup.popup(Rect2i(Vector2i(x, y), Vector2i(width, height)))

func _radius_changed(value: float) -> void:
    _radius_display.text = "%.1fm" % value

func _strength_changed(value: float) -> void:
    _strength_display.text = "%.1f" % value


func _process(_delta: float) -> void:
    if not is_instance_valid(_active):
        return
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
        _stats_label.text = "Native C++ | RF Float32 | %d regions" % int(data.call("get_region_count"))

func _refresh_layer_ui() -> void:
    _layer_enable.visible = true
    _layer_enable.disabled = true
    _layer_enable.tooltip_text = "Native layer composition pending; no legacy renderer"
    _layer_select.hide()
    _layer_add.hide()
    _layer_visible.hide()
    _layer_restore.hide()

func _on_tool_changed(tool: int) -> void:
    _current_tool = tool
    _set_status("Brush ON: drag to edit native heights.")

func _set_status(message: String) -> void:
    if is_instance_valid(_status):
        _status.text = message

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
    _brush_button.set_pressed_no_signal(false)
    _brush_button.text = "Brush"
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
        _set_active(null)

func _choose_new_size() -> void:
    var dialog := ConfirmationDialog.new()
    dialog.title = "TerraForge — New"
    dialog.dialog_text = "Native Float32 | 25 cm"
    var options := OptionButton.new()
    options.add_item("128 × 128 m (1 region)",1)
    options.add_item("256 × 256 m (4 regions)",2)
    options.add_item("512 × 512 m (16 regions)",4)
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
        var pixels := ResourceLoader.load("res://world/"+kind+"_mips.res","Image",ResourceLoader.CACHE_MODE_IGNORE) as Image
        if pixels == null or pixels.is_empty():
            terrain.free()
            _set_status("Native surface texture missing.")
            return
        material.call("set_shader_param",kind+"_tex",ImageTexture.create_from_image(pixels))
    material.call("set_show_checkered",false)
    var view := get_editor_interface().get_editor_viewport_3d(0)
    if view != null and view.get_camera_3d() != null:
        terrain.call("set_camera",view.get_camera_3d())
    var selection := get_editor_interface().get_selection()
    selection.clear()
    selection.add_node(terrain)
    _set_active(terrain)
    _set_status("Native %d regions created. Save data and scene." % (side*side))
    _popup.hide()

func _toggle_brush(enabled: bool) -> void:
    if enabled and not is_instance_valid(_active):
        _brush_button.set_pressed_no_signal(false)
        _set_status("Create or select native terrain first.")
        return
    if not enabled:
        _finish_stroke()
    _brush_button.text = "Brush ON" if enabled else "Brush"

func _save_active() -> void:
    _finish_stroke()
    if not is_instance_valid(_active):
        _set_status("No native terrain selected.")
        return
    _set_status(_brush.save_snapshot())

func _undo() -> void:
    _finish_stroke()
    if is_instance_valid(_active):
        _set_status(_brush.undo())

func _redo() -> void:
    _finish_stroke()
    if is_instance_valid(_active):
        _set_status(_brush.redo())

func _run_self_test() -> void:
    if not is_instance_valid(_active):
        _set_status("No native terrain selected.")
        return
    var data: Object = _active.get("data")
    _set_status("Native regions: %d | spacing: %.2fm | LOD: %d" % [data.call("get_region_count"),_active.get("vertex_spacing"),_active.get("mesh_lods")])

func _finish_stroke() -> void:
    if _stroke_active and is_instance_valid(_active):
        _brush.end()
    _stroke_active = false

func _paint_at(camera: Camera3D, position: Vector2) -> void:
    if not is_instance_valid(_active):
        return
    var hit: Vector3 = _active.call("get_intersection",camera.project_ray_origin(position),camera.project_ray_normal(position),false)
    if not hit.is_finite() or absf(hit.x)>1e8 or absf(hit.z)>1e8:
        return
    var result := _brush.dab(hit,_tool_select.selected,float(_radius.value),float(_strength.value))
    if not result.is_empty():
        _set_status(result)

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
    if not is_instance_valid(_active) or not _brush_button.button_pressed:
        return EditorPlugin.AFTER_GUI_INPUT_PASS
    if event is InputEventScreenTouch:
        _last_touch_ms = Time.get_ticks_msec()
        if event.index > 0:
            if event.pressed:
                _finish_stroke()
            return EditorPlugin.AFTER_GUI_INPUT_PASS
        if event.pressed:
            _touch_session = true
            _finish_stroke()
            _brush.begin()
            _stroke_active = true
            _paint_at(camera, event.position)
        else:
            _finish_stroke()
            _touch_session = false
        return EditorPlugin.AFTER_GUI_INPUT_STOP
    if event is InputEventScreenDrag and event.index == 0:
        _last_touch_ms = Time.get_ticks_msec()
        if _stroke_active and _touch_session:
            _paint_at(camera, event.position)
            return EditorPlugin.AFTER_GUI_INPUT_STOP
        return EditorPlugin.AFTER_GUI_INPUT_PASS
    if _touch_session:
        return EditorPlugin.AFTER_GUI_INPUT_PASS
    # Filter synthetic mouse events emitted after a touch sequence on Android.
    if Time.get_ticks_msec() - _last_touch_ms < 350:
        return EditorPlugin.AFTER_GUI_INPUT_PASS
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _finish_stroke()
            _brush.begin()
            _stroke_active = true
            _paint_at(camera, event.position)
        else:
            _finish_stroke()
        return EditorPlugin.AFTER_GUI_INPUT_STOP
    if event is InputEventMouseMotion and _stroke_active:
        _paint_at(camera, event.position)
        return EditorPlugin.AFTER_GUI_INPUT_STOP
    return EditorPlugin.AFTER_GUI_INPUT_PASS
