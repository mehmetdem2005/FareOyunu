extends "res://addons/terra_forge/terrain/paged_terrain_preview.gd"
const CANDIDATE=preload("res://addons/terra_forge/core/normal_cache_worker_candidate.gd")
var use_candidate: bool=false

func _make_geometry_worker():
    return CANDIDATE.new() if use_candidate else super._make_geometry_worker()
