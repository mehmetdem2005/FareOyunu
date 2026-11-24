@tool
extends EditorPlugin
## Lightweight bottom-panel editor for the standalone terrain node.
const TERRAIN_SCRIPT = preload("res://addons/terra_forge/terrain/terra_forge_terrain.gd")

var _dock: VBoxContainer
var _status: Label
var _brush_button: CheckButton
var _tool_select: OptionButton
var _radius: HSlider
var _strength: HSlider
var _profile_select: OptionButton
var _stats_label: Label
var _last_stats_update_ms: int = -100000
var _active: TerraForgeTerrain
var _stroke_active: bool = false
var _touch_session: bool = false

func _enter_tree() -> void:
    _dock = VBoxContainer.new()
    _dock.name = "TerraForge"
    _dock.custom_minimum_size = Vector2(400, 158)
    _dock.add_theme_constant_override("separation", 6)

    var header: HBoxContainer = HBoxContainer.new()
    _dock.add_child(header)
    var title: Label = Label.new()
    title.text = "TERRAFORGE  /  MOBILE SCULPT"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var create_button: Button = Button.new()
    create_button.text = "Create Terrain"
    create_button.pressed.connect(_create_terrain)
    header.add_child(create_button)
    var save_button: Button = Button.new()
    save_button.text = "Save"
    save_button.pressed.connect(_save_active)
    header.add_child(save_button)

    var tool_row: HBoxContainer = HBoxContainer.new()
    _dock.add_child(tool_row)
    _brush_button = CheckButton.new()
    _brush_button.text = "Brush OFF"
    _brush_button.toggled.connect(_toggle_brush)
    tool_row.add_child(_brush_button)
    _tool_select = OptionButton.new()
    for name in ["Raise", "Lower", "Smooth", "Flatten"]:
        _tool_select.add_item(name)
    _tool_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tool_row.add_child(_tool_select)
    var undo_button: Button = Button.new()
    undo_button.text = "Undo"
    undo_button.pressed.connect(_undo)
    tool_row.add_child(undo_button)
    var redo_button: Button = Button.new()
    redo_button.text = "Redo"
    redo_button.pressed.connect(_redo)
    tool_row.add_child(redo_button)

    var radius_row: HBoxContainer = HBoxContainer.new()
    _dock.add_child(radius_row)
    var radius_label: Label = Label.new()
    radius_label.text = "Radius"
    radius_row.add_child(radius_label)
    _radius = HSlider.new()
    _radius.min_value = 1.0
    _radius.max_value = 36.0
    _radius.step = 0.5
    _radius.value = 8.0
    _radius.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    radius_row.add_child(_radius)
    var strength_label: Label = Label.new()
    strength_label.text = "Strength"
    radius_row.add_child(strength_label)
    _strength = HSlider.new()
    _strength.min_value = 0.25
    _strength.max_value = 12.0
    _strength.step = 0.25
    _strength.value = 3.0
    _strength.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    radius_row.add_child(_strength)

    var profile_row: HBoxContainer = HBoxContainer.new()
    _dock.add_child(profile_row)
    var quality_caption: Label = Label.new()
    quality_caption.text = "Streaming quality"
    profile_row.add_child(quality_caption)
    _profile_select = OptionButton.new()
    _profile_select.add_item("Mobile - light")
    _profile_select.add_item("Balanced")
    _profile_select.add_item("High detail")
    _profile_select.select(1)
    _profile_select.item_selected.connect(_quality_changed)
    _profile_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    profile_row.add_child(_profile_select)
    _stats_label = Label.new()
    _stats_label.text = "Resident: 0  |  Pending: 0"
    _dock.add_child(_stats_label)

    _status = Label.new()
    _status.text = "Open a 3D scene, then Create Terrain."
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _dock.add_child(_status)
    add_control_to_bottom_panel(_dock, "TerraForge")
    get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
    set_process(true)

func _process(_delta: float) -> void:
    if not is_instance_valid(_active):
        return
    var now: int = Time.get_ticks_msec()
    if now - _last_stats_update_ms < 180:
        return
    _last_stats_update_ms = now
    var editor_view: SubViewport = get_editor_interface().get_editor_viewport_3d(0)
    if editor_view != null:
        var editor_camera: Camera3D = editor_view.get_camera_3d()
        if editor_camera != null:
            _active.set_stream_center(editor_camera.global_position)
    if _stats_label != null:
        var stats: Dictionary = _active.get_stream_stats()
        _stats_label.text = "Tiles %d | Pending %d | LOD 0/1/2: %d/%d/%d" % [
            stats["resident"], stats["pending"],
            stats["lod0"], stats["lod1"], stats["lod2"]
        ]

func _quality_changed(profile: int) -> void:
    if is_instance_valid(_active):
        _active.set_quality_profile(profile)
        _set_status("Streaming preset updated. Only visible tiles are kept.")

func _exit_tree() -> void:
    _finish_stroke()
    var selection: EditorSelection = get_editor_interface().get_selection()
    if selection.selection_changed.is_connected(_on_selection_changed):
        selection.selection_changed.disconnect(_on_selection_changed)
    remove_control_from_bottom_panel(_dock)
    _dock.queue_free()
    _active = null

func _handles(object: Object) -> bool:
    return object is TerraForgeTerrain

func _edit(object: Object) -> void:
    _set_active(object as TerraForgeTerrain)

func _on_selection_changed() -> void:
    var selected: Array[Node] = get_editor_interface().get_selection().get_selected_nodes()
    var found: TerraForgeTerrain = null
    for node in selected:
        if node is TerraForgeTerrain:
            found = node
            break
    _set_active(found)

func _set_active(terrain: TerraForgeTerrain) -> void:
    if _active == terrain:
        return
    _finish_stroke()
    _active = terrain
    if _brush_button != null:
        _brush_button.set_pressed_no_signal(false)
        _brush_button.text = "Brush OFF"
    if terrain == null:
        _set_status("Select a TerraForgeTerrain node to sculpt.")
    else:
        _set_status("Selected %s (%s x %s cells)." % [
            terrain.name, str(terrain.cells_x), str(terrain.cells_z)
        ])

func _set_status(value: String) -> void:
    if _status != null:
        _status.text = value

func _create_terrain() -> void:
    var scene_root: Node = get_editor_interface().get_edited_scene_root()
    if scene_root == null or not scene_root is Node3D:
        _set_status("Open a saved 3D scene first (Node3D root).")
        return
    var terrain: TerraForgeTerrain = TERRAIN_SCRIPT.new()
    terrain.name = "TerraForgeTerrain"
    var base: String = scene_root.name.to_snake_case()
    var suffix: String = str(Time.get_ticks_msec())
    terrain.data_file = "res://terraforge_data/%s_%s.tfh" % [base, suffix]
    scene_root.add_child(terrain)
    terrain.owner = scene_root
    var selection: EditorSelection = get_editor_interface().get_selection()
    selection.clear()
    selection.add_node(terrain)
    _set_active(terrain)
    _set_status("Terrain created. Enable Brush ON to sculpt. Save the scene too.")
    make_bottom_panel_item_visible(_dock)

func _toggle_brush(enabled: bool) -> void:
    if _brush_button == null:
        return
    if enabled and _active == null:
        _brush_button.set_pressed_no_signal(false)
        _set_status("Select a terrain first.")
        return
    if not enabled:
        _finish_stroke()
    _brush_button.text = "Brush ON" if enabled else "Brush OFF"
    if enabled:
        _set_status("Single touch / left drag = sculpt. Disable Brush to orbit camera.")

func _save_active() -> void:
    if not is_instance_valid(_active):
        _set_status("No terrain selected.")
        return
    _finish_stroke()
    var result: Error = _active.save_data()
    if result == OK:
        _set_status("Saved Float32 heights to %s" % _active.data_file)
    else:
        _set_status("Save failed: %s" % error_string(result))

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

func _paint_at(camera: Camera3D, screen_position: Vector2) -> void:
    if not is_instance_valid(_active):
        return
    var origin: Vector3 = camera.project_ray_origin(screen_position)
    var direction: Vector3 = camera.project_ray_normal(screen_position)
    var surface: Dictionary = _active.find_surface_from_ray(origin, direction)
    if surface.get("hit", false):
        _active.paint_at(
            surface["position"],
            _tool_select.selected,
            float(_radius.value),
            float(_strength.value)
        )

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
    if not is_instance_valid(_active) or not _brush_button.button_pressed:
        return EditorPlugin.AFTER_GUI_INPUT_PASS

    if event is InputEventScreenTouch:
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
        if _stroke_active and _touch_session:
            _paint_at(camera, event.position)
            return EditorPlugin.AFTER_GUI_INPUT_STOP
        return EditorPlugin.AFTER_GUI_INPUT_PASS

    # Touch devices may also synthesize mouse events; avoid double stamps.
    if _touch_session:
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
