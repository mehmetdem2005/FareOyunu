extends "res://addons/terra_forge/core/geometry_worker.gd"
## Test-only gate, first optional build waits for explicit release.
## Test must post before close on every exit, including failure.
var gate: Semaphore=Semaphore.new()
var _gated: bool=false

func _build_geometry(job: Dictionary) -> Dictionary:
    if int(job["lod"])>0 and not _gated:
        _gated=true
        gate.wait()
    return super._build_geometry(job)
