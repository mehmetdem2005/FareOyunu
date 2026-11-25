extends "res://addons/terra_forge/tests/test_motion_roundtrip.gd"
func _format() -> int:
    return 0
func _mode() -> int:
    return 6
func _cache_sizes() -> Array[int]:
    return [9]
func _halo_variants() -> Array[bool]:
    return [false,true]
