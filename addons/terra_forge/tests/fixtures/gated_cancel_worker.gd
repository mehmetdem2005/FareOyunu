extends "res://addons/terra_forge/core/geometry_worker.gd"
var entered:=Semaphore.new()
var release_gate:=Semaphore.new()
var _test_checks: int=0

func _cancel_checkpoint(epoch: int) -> bool:
    _test_checks+=1
    if _test_checks==2:
        entered.post()
        release_gate.wait()
    return super._cancel_checkpoint(epoch)
