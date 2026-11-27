extends Control

signal back_requested
signal reset_requested
signal save_requested
signal look_dragged(delta: Vector2)

const STICK_RADIUS := 51.0
const DEAD_ZONE := 0.15
const NO_POINTER := -1
const MOUSE_POINTER := -2

@onready var _safe: Control = $SafeArea
@onready var _actions: VBoxContainer = $SafeArea/Actions
@onready var _metrics: PanelContainer = $SafeArea/Metrics
@onready var _fps: Label = $SafeArea/Metrics/Readings/FPS
@onready var _summary: Label = $SafeArea/Metrics/Readings/Summary
@onready var _status: PanelContainer = $SafeArea/Status
@onready var _message: Label = $SafeArea/Status/Message
@onready var _hint: Label = $SafeArea/Hint
@onready var _back: Button = $SafeArea/Actions/Back
@onready var _reset: Button = $SafeArea/Actions/Reset
@onready var _save: Button = $SafeArea/Actions/Save

var _controls_enabled := false
var _move_pointer := NO_POINTER
var _look_pointer := NO_POINTER
var _stick_center := Vector2.ZERO
var _stick_offset := Vector2.ZERO

func _ready() -> void:
    _back.pressed.connect(func(): back_requested.emit())
    _reset.pressed.connect(func(): reset_requested.emit())
    _save.pressed.connect(func(): save_requested.emit())
    resized.connect(_fit_safe_area)
    _fit_safe_area()
    set_controls_enabled(false)

func _fit_safe_area() -> void:
    var frame := Rect2(Vector2.ZERO, size)
    if OS.get_name() == "Android":
        var screen_safe := Rect2(DisplayServer.get_display_safe_area())
        if screen_safe.has_area():
            var viewport_safe: Rect2 = get_viewport().get_screen_transform().affine_inverse() * screen_safe
            var available := frame.intersection(viewport_safe)
            if available.has_area():
                frame = available
    frame = frame.grow(-14.0)
    _safe.position = frame.position
    _safe.size = frame.size
    # Reanchor on content size changes as well as on rotation and resize.
    _place_panels()
    queue_redraw()

func _place_panels() -> void:
    _metrics.position = Vector2(_safe.size.x - _metrics.size.x, 0.0)
    _status.position = (_safe.size - _status.size) * 0.5
    _hint.position = _safe.size - _hint.size

func set_controls_enabled(enabled: bool) -> void:
    _controls_enabled = enabled
    _reset.disabled = not enabled
    _save.disabled = true
    _hint.visible = enabled
    if not enabled:
        clear_input()
    queue_redraw()

func show_status(message: String) -> void:
    _message.text = message
    _status.visible = not message.is_empty()
    _status.reset_size()
    _place_panels()

func show_metrics(live: int, average: float, seconds: float, p95_ms: float) -> void:
    _fps.text = "%d FPS" % live if seconds > 0.0 else "— FPS"
    _summary.text = "Ort. %.1f FPS   ·   p95 ≤ %.1f ms   ·   %d sn" % [average, p95_ms, int(seconds)] if seconds > 0.0 else "Ölçüm bekliyor"
    _metrics.reset_size()
    _place_panels()
    _save.disabled = not _controls_enabled or seconds < 1.0

func clear_input() -> void:
    _move_pointer = NO_POINTER
    _look_pointer = NO_POINTER
    _stick_offset = Vector2.ZERO
    queue_redraw()

func movement() -> Vector2:
    if not _controls_enabled:
        return Vector2.ZERO
    var strength := _stick_offset.length() / STICK_RADIUS
    var joystick := _stick_offset.normalized() * maxf(0.0, (strength - DEAD_ZONE) / (1.0 - DEAD_ZONE))
    var keyboard := Vector2(
        float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
        - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
        float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
        - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
    )
    return (joystick + keyboard).limit_length()

func _draw() -> void:
    if not _controls_enabled:
        return
    var home := Vector2(_safe.position.x + 64.0, _safe.position.y + _safe.size.y - 76.0)
    var center := _stick_center if _move_pointer != NO_POINTER else home
    draw_circle(center, STICK_RADIUS, Color(0.045, 0.085, 0.10, 0.64), true, -1.0, true)
    draw_arc(center, STICK_RADIUS, 0.0, TAU, 48, Color(0.78, 0.92, 0.86, 0.70), 2.0, true)
    draw_circle(center + _stick_offset, 22.0, Color(0.71, 0.94, 0.78, 0.86), true, -1.0, true)
    var font := get_theme_default_font()
    var label := "Hareket" if DisplayServer.is_touchscreen_available() else "Hareket · WASD"
    var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
    var start := home + Vector2(-width * 0.5, STICK_RADIUS + 21.0)
    draw_string(font, start + Vector2.ONE, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
    draw_string(font, start, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        back_requested.emit()
        get_viewport().set_input_as_handled()
        return
    if not _controls_enabled:
        return
    if event is InputEventScreenTouch:
        if _pointer_button(event.index, event.position, event.pressed and not event.canceled):
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        if _pointer_drag(event.index, event.position, event.relative):
            get_viewport().set_input_as_handled()
    # Keep real mouse controls on desktop. Android's emulated mouse can
    # still click buttons without also creating a second joystick or drag.
    elif event.device != InputEvent.DEVICE_ID_EMULATION:
        if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
            if _pointer_button(MOUSE_POINTER, event.position, event.pressed):
                get_viewport().set_input_as_handled()
        elif event is InputEventMouseMotion and _pointer_drag(MOUSE_POINTER, event.position, event.relative):
            get_viewport().set_input_as_handled()

func _pointer_button(index: int, point: Vector2, pressed: bool) -> bool:
    if not pressed:
        if index == _move_pointer:
            _move_pointer = NO_POINTER
            _stick_offset = Vector2.ZERO
            queue_redraw()
            return true
        if index == _look_pointer:
            _look_pointer = NO_POINTER
            return true
        return false
    if _actions.get_global_rect().has_point(point) or _metrics.get_global_rect().has_point(point):
        return false
    if point.x < size.x * 0.5:
        if _move_pointer != NO_POINTER:
            return false
        _move_pointer = index
        _stick_center = point
        _stick_offset = Vector2.ZERO
        queue_redraw()
        return true
    if _look_pointer != NO_POINTER:
        return false
    _look_pointer = index
    return true

func _pointer_drag(index: int, point: Vector2, delta: Vector2) -> bool:
    if index == _move_pointer:
        _stick_offset = (point - _stick_center).limit_length(STICK_RADIUS)
        queue_redraw()
        return true
    if index == _look_pointer:
        look_dragged.emit(delta)
        return true
    return false
