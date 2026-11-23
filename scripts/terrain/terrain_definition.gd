@tool
extends Resource
class_name TerrainDefinition

## Editable preview dimensions only, not canonical world scale or collision.
@export var island_id: String = ""
@export_file("*.exr") var source_exr: String = ""
@export var source_sha256: String = ""

@export_range(1.0, 20000.0, 1.0, "or_greater") var preview_width_units: float = 600.0:
    set(value):
        preview_width_units = maxf(value, 1.0)
        emit_changed()

@export_range(0.0, 2000.0, 0.5, "or_greater") var preview_height_units: float = 80.0:
    set(value):
        preview_height_units = maxf(value, 0.0)
        emit_changed()

@export_range(1.0, 20000.0, 1.0, "or_greater") var preview_depth_units: float = 600.0:
    set(value):
        preview_depth_units = maxf(value, 1.0)
        emit_changed()
