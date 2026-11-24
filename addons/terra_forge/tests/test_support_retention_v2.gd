extends "res://addons/terra_forge/tests/test_support_retention.gd"
## Separate process: each format gets its own existing 90-second test cap.
func _formats() -> Array[int]:
    return [1]
