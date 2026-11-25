extends "res://addons/terra_forge/tests/test_motion_roundtrip.gd"
func _format() -> int:
    return 1
func _mode() -> int:
    return 7
func _cache_sizes() -> Array[int]:
    return [9]
func _hybrid_motion_policy() -> Dictionary:
    return {"scalar":true,"topology":true,"crop":true}
