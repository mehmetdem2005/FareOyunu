@tool
extends Resource
class_name WorldPreviewLayout

## Provisional editor-only placements, not authoritative world coordinates.
@export var northwest_position: Vector3 = Vector3(-650, 0, -420):
    set(value):
        northwest_position = value
        emit_changed()
@export var southwest_position: Vector3 = Vector3(-650, 0, 420):
    set(value):
        southwest_position = value
        emit_changed()
@export var north_position: Vector3 = Vector3(290, 0, -440):
    set(value):
        north_position = value
        emit_changed()
@export var southeast_position: Vector3 = Vector3(320, 0, 420):
    set(value):
        southeast_position = value
        emit_changed()
