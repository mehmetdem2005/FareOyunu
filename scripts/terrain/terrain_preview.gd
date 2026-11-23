@tool
extends Node3D

## Only adjusts an external GLB's visual scale. No terrain data is embedded.
## No RPC, chunk, collision, multiplayer or procedural world state.
@export var definition: TerrainDefinition

func _ready() -> void:
    if definition != null and not definition.changed.is_connected(_sync_preview):
        definition.changed.connect(_sync_preview)
    _sync_preview()

func _exit_tree() -> void:
    if definition != null and definition.changed.is_connected(_sync_preview):
        definition.changed.disconnect(_sync_preview)

func _sync_preview() -> void:
    if not is_inside_tree() or definition == null:
        return
    var preview_node: Node3D = get_node_or_null("PreviewModel") as Node3D
    if preview_node == null:
        push_warning("PreviewModel external GLB instance is missing")
        return
    preview_node.scale = Vector3(
        definition.preview_width_units,
        definition.preview_height_units,
        definition.preview_depth_units
    )
