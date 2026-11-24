@tool
extends EditorPlugin
## Mobile-first editor controls: only a tiny button remains in the 3D toolbar.
## Settings appear in a dismissible popup rather than a permanent bottom panel.
const TERRAIN_SCRIPT = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")
const PAGED_PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const SELF_TEST = preload("res://addons/terra_forge/core/self_test.gd")

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
var _active: TerraForgeTerrain
var _active_preview: Node3D
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
    new_button.pressed.connect(_create_terrain)
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
    _profile_select.item_selected.connect(_quality_changed)
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
    _layer_enable.pressed.connect(_enable_layer_mode)
    _layer_row.add_child(_layer_enable)
    _layer_select = OptionButton.new()
    _layer_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _layer_select.item_selected.connect(_choose_layer)
    _layer_row.add_child(_layer_select)
    _layer_add = Button.new()
    _layer_add.text = "+"
    _layer_add.tooltip_text = "Add another independent sculpt layer (maximum 8)"
    _layer_add.pressed.connect(_add_layer)
    _layer_row.add_child(_layer_add)
    _layer_visible = CheckButton.new()
    _layer_visible.text = "On"
    _layer_visible.tooltip_text = "Show or hide selected layer"
    _layer_visible.toggled.connect(_toggle_layer_visible)
    _layer_row.add_child(_layer_visible)
    _layer_restore = Button.new()
    _layer_restore.text = "Restore"
    _layer_restore.tooltip_text = "Manually restore last verified .tfl.bak. Damaged original is preserved as .corrupt_*."
    _layer_restore.pressed.connect(_restore_layer_backup)
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
    _active_preview = null

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
    var legacy: bool = is_instance_valid(_active)
    var paged: bool = is_instance_valid(_active_preview)
    if not legacy and not paged:
        return
    var now: int = Time.get_ticks_msec()
    if now - _last_stats_update_ms < 200:
        return
    _last_stats_update_ms = now
    var view: SubViewport = get_editor_interface().get_editor_viewport_3d(0)
    if view != null:
        var camera: Camera3D = view.get_camera_3d()
        if camera != null:
            if legacy:
                _active.set_stream_center(camera.global_position)
            elif paged:
                _active_preview.set_stream_center(camera.global_position)
    if not _popup.visible:
        return
    if paged:
        var preview_stats: Dictionary = _active_preview.stats()
        var source: Dictionary = preview_stats.get("source", {})
        var check_mode: String = (
            "ON-DEMAND" if str(source.get("verification_mode", "strict")) == "on_demand"
            else "FULL"
        )
        var checked: int = int(source.get("pages_verified_on_demand", 0))
        if check_mode == "FULL":
            checked = int(source.get("manifest_entries", 0))
        _stats_label.text = "READ-ONLY %s | Tiles %d / Pending %d\nRAM %d/%d pages | Checked %d/%d | IO max %.1fms" % [
            check_mode, int(preview_stats["tiles"]), int(preview_stats["pending_tiles"]),
            int(source.get("resident", 0)), int(source.get("limit", 0)),
            checked, int(source.get("manifest_entries", 0)),
            float(source.get("max_io_ms", 0.0))
        ]
    elif legacy:
        var stats: Dictionary = _active.get_stream_stats()
        _stats_label.text = "Tiles %d / Pending %d / Vertices %d\nMesh %.1fms (max %.1f) | Sculpt %.1fms (max %.1f)" % [
            stats["resident"], stats["pending"], stats["vertices"],
            stats["tile_last_ms"], stats["tile_max_ms"],
            stats["edit_last_ms"], stats["edit_max_ms"]
        ]

func _on_tool_changed(tool: int) -> void:
    if _current_tool == 6:
        _ramp_setting = float(_ramp_rise.value)
    elif _current_tool == 8:
        _weather_setting = float(_ramp_rise.value)
    _current_tool = tool
    _advanced_row.visible = tool == 6 or tool == 7 or tool == 8
    _advanced_label.text = "Steps" if tool == 8 else ("Rise" if tool == 6 else "Shape")
    _ramp_rise.visible = tool == 6 or tool == 8
    _stamp_preset.visible = tool == 7
    if tool == 8:
        _ramp_rise.min_value = 1.0
        _ramp_rise.max_value = 6.0
        _ramp_rise.step = 1.0
        _ramp_rise.value = _weather_setting
        _ramp_rise.suffix = "passes"
    else:
        _ramp_rise.min_value = -40.0
        _ramp_rise.max_value = 40.0
        _ramp_rise.step = 0.5
        _ramp_rise.value = _ramp_setting
        _ramp_rise.suffix = "m"
    match tool:
        4:
            _set_status("Ridge: draw the entire crest, release to build.")
        5:
            _set_status("Valley: draw the complete drainage path, release to carve.")
        6:
            _set_status("Ramp: drag start to end; the gradient is applied when released.")
        7:
            _set_status("Stamp: one tap adds the selected terrain shape.")
        8:
            _set_status("Weather: tap a slope to move loose material downhill.")
        _:
            _set_status("Drag on the terrain with Brush ON.")
    if _popup.visible:
        _popup.hide()
        _toggle_popup()

func _refresh_layer_ui() -> void:
    if _layer_row == null:
        return
    var has_terrain: bool = is_instance_valid(_active)
    var enabled: bool = has_terrain and _active.layer_mode and _active._layer_stack != null
    var can_restore: bool = has_terrain and _active.can_restore_layer_backup()
    _layer_restore.visible = can_restore
    _layer_enable.visible = not enabled and not can_restore
    _layer_enable.disabled = not has_terrain or (has_terrain and _active._read_only_source)
    _layer_select.visible = enabled
    _layer_add.visible = enabled
    _layer_visible.visible = enabled
    if not enabled:
        return
    _layer_select.clear()
    for layer in _active._layer_stack.layers:
        _layer_select.add_item(str(layer["name"]))
    _layer_select.select(_active._active_layer)
    _layer_add.disabled = _active._read_only_source or _active._layer_stack.layers.size() >= 8
    _layer_visible.disabled = _active._read_only_source
    _layer_visible.set_pressed_no_signal(bool(_active._layer_stack.layers[_active._active_layer]["enabled"]))

func _restore_layer_backup() -> void:
    if not is_instance_valid(_active) or not _active.can_restore_layer_backup():
        return
    _finish_stroke()
    # This is a deliberate action. No automatic rollback occurs on load.
    var err: Error = _active.restore_layer_backup()
    if err == OK:
        _set_status("Recovered last verified backup. Corrupt primary preserved separately; save scene.")
    else:
        _set_status("Recovery failed: " + error_string(err))
    _refresh_layer_ui()

func _enable_layer_mode() -> void:
    if not is_instance_valid(_active):
        return
    _finish_stroke()
    var err: Error = _active.enable_layers()
    if err == OK:
        _set_status("Layers enabled: .tfh preserved, .tfl authoritative. Save the Godot scene!")
    else:
        _set_status("Cannot enable layers: " + error_string(err))
    _refresh_layer_ui()

func _add_layer() -> void:
    if not is_instance_valid(_active):
        return
    _finish_stroke()
    var count: int = _active._layer_stack.layers.size()
    var added: int = _active.add_edit_layer("Sculpt %d" % (count + 1))
    _set_status("New layer added; Save writes .tfl." if added >= 0 else "Layer limit reached.")
    _refresh_layer_ui()

func _choose_layer(index: int) -> void:
    if not is_instance_valid(_active):
        return
    _finish_stroke()
    var err: Error = _active.set_active_edit_layer(index)
    if err != OK:
        _set_status("Cannot select layer: " + error_string(err))
    elif not _active._layer_is_editable():
        _set_status("Layer is hidden or opacity is not 100%; enable it before sculpting.")
    else:
        _set_status("Sculpting layer: " + str(_active._layer_stack.layers[index]["name"]))
    _refresh_layer_ui()

func _toggle_layer_visible(visible: bool) -> void:
    if not is_instance_valid(_active) or not _active.layer_mode:
        return
    _finish_stroke()
    var err: Error = _active.set_edit_layer_visible(_active._active_layer, visible)
    if err == OK:
        _brush_button.set_pressed_no_signal(false)
        _brush_button.text = "Brush"
        _set_status("Layer visibility updated. Save .tfl to keep this change.")
    else:
        _set_status("Visibility error: " + error_string(err))
    _refresh_layer_ui()

func _run_self_test() -> void:
    _finish_stroke()
    _set_status("Checking Float32, geology and touch-independent paths...")
    var report: Dictionary = SELF_TEST.run()
    _set_status(str(report["summary"]))
    if bool(report["ok"]):
        print("[TerraForge self-test] ", report)
    else:
        push_error("[TerraForge self-test] " + str(report["summary"]))

func _quality_changed(profile: int) -> void:
    if is_instance_valid(_active):
        _active.set_quality_profile(profile)
        _set_status("Quality updated.")

func _handles(object: Object) -> bool:
    return object is TerraForgeTerrain or (object is Node3D and object.get_script() == PAGED_PREVIEW)

func _edit(object: Object) -> void:
    if object is TerraForgeTerrain:
        _set_active(object as TerraForgeTerrain)
    elif object is Node3D and object.get_script() == PAGED_PREVIEW:
        _set_active_preview(object as Node3D)

func _find_terrain(node: Node) -> TerraForgeTerrain:
    if node is TerraForgeTerrain:
        return node as TerraForgeTerrain
    for child in node.get_children():
        var found: TerraForgeTerrain = _find_terrain(child)
        if found != null:
            return found
    return null

func _find_preview(node: Node) -> Node3D:
    if node is Node3D and node.get_script() == PAGED_PREVIEW:
        return node as Node3D
    for child in node.get_children():
        var found: Node3D = _find_preview(child)
        if found != null:
            return found
    return null

func _on_scene_changed(_root: Node) -> void:
    _finish_stroke()
    _active_preview = null
    _active = null
    _brush_button.set_pressed_no_signal(false)
    _brush_button.text = "Brush"
    call_deferred("_on_selection_changed")

func _on_selection_changed() -> void:
    var selected: Array[Node] = get_editor_interface().get_selection().get_selected_nodes()
    for node in selected:
        if node is TerraForgeTerrain:
            _set_active(node as TerraForgeTerrain)
            return
        if node is Node3D and node.get_script() == PAGED_PREVIEW:
            _set_active_preview(node as Node3D)
            return
    if is_instance_valid(_active) or is_instance_valid(_active_preview):
        return  # Keep working even if user selects another node.
    var scene_root: Node = get_editor_interface().get_edited_scene_root()
    if scene_root != null:
        var legacy: TerraForgeTerrain = _find_terrain(scene_root)
        if legacy != null:
            _set_active(legacy)
        else:
            var paged: Node3D = _find_preview(scene_root)
            if paged != null:
                _set_active_preview(paged)
            else:
                _set_active(null)

func _set_active(terrain: TerraForgeTerrain) -> void:
    if _active == terrain and not is_instance_valid(_active_preview):
        return
    _finish_stroke()
    _active_preview = null
    _active = terrain
    _refresh_layer_ui()
    _brush_button.disabled = false
    _brush_button.set_pressed_no_signal(false)
    _brush_button.text = "Brush"
    if terrain == null:
        _set_status("Create terrain or select an existing one.")
    else:
        if terrain._read_only_source:
            _set_status("Height data missing/corrupt. Terrain is READ-ONLY; restore its .tfh file.")
        else:
            _set_status("Editing: %s" % terrain.name)
        terrain.set_quality_profile(_profile_select.selected)

func _set_active_preview(paged: Node3D) -> void:
    if _active_preview == paged and not is_instance_valid(_active):
        return
    _finish_stroke()
    _active = null
    _active_preview = paged
    _refresh_layer_ui()
    _brush_button.set_pressed_no_signal(false)
    _brush_button.disabled = true
    _brush_button.text = "Read-only"
    _set_status("Paged height preview is read-only. Camera streams regions; brush/save/Undo are disabled.")


func _set_status(message: String) -> void:
    if _status != null:
        _status.text = message

func _create_terrain() -> void:
    var root: Node = get_editor_interface().get_edited_scene_root()
    if root == null or not root is Node3D:
        _set_status("Open a scene with a Node3D root first.")
        return
    var terrain: TerraForgeTerrain = TERRAIN_SCRIPT.new()
    terrain.name = "TerraForgeTerrain"
    terrain.allow_data_creation = true
    terrain.data_file = "res://terraforge_data/%s_%s.tfh" % [
        root.name.to_snake_case(), Crypto.new().generate_random_bytes(12).hex_encode()
    ]
    terrain.position = Vector3(
        -float(terrain.cells_x) * terrain.sample_spacing * 0.5,
        0.0,
        -float(terrain.cells_z) * terrain.sample_spacing * 0.5
    )
    root.add_child(terrain)
    terrain.owner = root
    # A new terrain must not reference a missing .tfh if the scene is saved.
    var data_error: Error = terrain.save_data()
    if data_error != OK:
        _set_status("Terrain was created but the height file could not be saved: " + error_string(data_error))
    var selection: EditorSelection = get_editor_interface().get_selection()
    selection.clear()
    selection.add_node(terrain)
    _set_active(terrain)
    if data_error == OK:
        _set_status("Terrain ready at scene origin. Save the scene with Godot.")
    _popup.hide()

func _toggle_brush(enabled: bool) -> void:
    if enabled and is_instance_valid(_active) and (
            _active._read_only_source or not _active._layer_is_editable()
        ):
        _brush_button.set_pressed_no_signal(false)
        _brush_button.text = "Brush"
        _set_status("Cannot sculpt: height source is locked or selected layer is hidden.")
        return
    if enabled and not is_instance_valid(_active):
        _brush_button.set_pressed_no_signal(false)
        _set_status("Create or select a terrain.")
        _toggle_popup_if_closed()
        return
    if not enabled:
        _finish_stroke()
    _brush_button.text = "Brush ON" if enabled else "Brush"

func _toggle_popup_if_closed() -> void:
    if not _popup.visible:
        _toggle_popup()

func _save_active() -> void:
    if is_instance_valid(_active_preview):
        _set_status("Paged preview is read-only. Original TFH/TFL data is unchanged.")
        return
    if not is_instance_valid(_active):
        _set_status("No terrain found.")
        return
    _finish_stroke()
    var result: Error = _active.save_data()
    _set_status(
        ("Layer document saved. Save the scene separately." if _active.layer_mode else "Heights saved. Save the scene separately.")
        if result == OK else "Save error: " + error_string(result)
    )

func _save_external_data() -> void:
    if is_instance_valid(_active):
        _finish_stroke()
        _active.save_data()

func _undo() -> void:
    if is_instance_valid(_active):
        _finish_stroke()
        _active.undo_stroke()

func _redo() -> void:
    if is_instance_valid(_active):
        _finish_stroke()
        _active.redo_stroke()

func _finish_stroke() -> void:
    if _stroke_active and is_instance_valid(_active):
        _active.end_stroke()
    _stroke_active = false

func _paint_at(camera: Camera3D, position: Vector2) -> void:
    if not is_instance_valid(_active):
        return
    var origin: Vector3 = camera.project_ray_origin(position)
    var direction: Vector3 = camera.project_ray_normal(position)
    var surface: Dictionary = _active.find_surface_from_ray(origin, direction)
    if surface.get("hit", false):
        _active.paint_at(
            surface["position"],
            _tool_select.selected,
            float(_radius.value),
            float(_strength.value),
            _stamp_preset.selected,
            float(_ramp_rise.value)
        )

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
            _active.begin_stroke()
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
            _active.begin_stroke()
            _stroke_active = true
            _paint_at(camera, event.position)
        else:
            _finish_stroke()
        return EditorPlugin.AFTER_GUI_INPUT_STOP
    if event is InputEventMouseMotion and _stroke_active:
        _paint_at(camera, event.position)
        return EditorPlugin.AFTER_GUI_INPUT_STOP
    return EditorPlugin.AFTER_GUI_INPUT_PASS
