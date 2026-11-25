extends "res://addons/terra_forge/tests/test_large_world_v2_e.gd"
## Force a one-shard cache while crossing the verified 16-page boundary.
## Reader worker owns the cache; never mutate its LRU from the test.
func _shard_limit() -> int:
    return 1

func _require_cold_shard() -> bool:
    return true
