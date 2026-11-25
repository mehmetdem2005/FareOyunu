extends "res://addons/terra_forge/tests/test_cold_shard_motion_f.gd"
func _mode() -> int:
    return 7
func _hybrid_motion_policy() -> Dictionary:
    return {"scalar":true,"topology":true,"crop":true}
