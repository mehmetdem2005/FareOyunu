extends "res://addons/terra_forge/core/geometry_worker.gd"
var entered:=Semaphore.new()
var release_gate:=Semaphore.new()
var _gated: bool=false

func _build_geometry(job: Dictionary) -> Dictionary:
    if not _gated:
        _gated=true
        entered.post()
        release_gate.wait()
    return super._build_geometry(job)
