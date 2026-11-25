extends "res://addons/terra_forge/tests/test_motion_roundtrip.gd"
## The original local route is translated without changing the analytic terrain:
## x offset is a multiple of 256, z offset a multiple of 192; both align to tiles.
## TFM2 x=1536 is a 16-page shard boundary, crossed twice by the capsule.
func _fixture_cells() -> Vector2i:
    return Vector2i(1600,1344)

func _route_offset() -> Vector2i:
    return Vector2i(1024,768)

func _cache_sizes() -> Array[int]:
    return [9]

func _format() -> int:
    return 0

func _mode() -> int:
    return 3
