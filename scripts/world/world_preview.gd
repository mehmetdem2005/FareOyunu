@tool
extends Node3D

## Combines four external island scenes; no heightmap data or geometry is generated.
@export var layout: WorldPreviewLayout

func _ready() -> void:
    if layout != null and not layout.changed.is_connected(_apply_layout):
        layout.changed.connect(_apply_layout)
    _apply_layout()

func _exit_tree() -> void:
    if layout != null and layout.changed.is_connected(_apply_layout):
        layout.changed.disconnect(_apply_layout)

func _apply_layout() -> void:
    if layout == null or not is_inside_tree():
        return
    var items: Dictionary = {
        "NorthwestIsland": layout.northwest_position,
        "SouthwestIsland": layout.southwest_position,
        "NorthernIsland": layout.north_position,
        "SoutheastIsland": layout.southeast_position,
    }
    for child_name in items:
        var island: Node3D = get_node_or_null(child_name) as Node3D
        if island != null:
            island.position = items[child_name]
