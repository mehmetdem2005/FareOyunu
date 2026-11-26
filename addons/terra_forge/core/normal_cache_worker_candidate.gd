@tool
extends "res://addons/terra_forge/core/geometry_worker.gd"
## Isolated opt-in worker experiment. Real base queue/identity/poll gates.
## This cache is exclusively worker-owned; clear after superclass joins.
const CACHE=preload("res://addons/terra_forge/core/normal_base_cache_candidate.gd")
var _base_cache=CACHE.new()
var _cache_epoch: int=-1
var _token: String=""
var _full: int=0
var _partial: int=0
var _retain_fail: int=0

func close() -> void:
    super.close()
    _base_cache.clear()
    _cache_epoch=-1
    _token=""
    _full=0
    _partial=0
    _retain_fail=0

func _build_geometry(job: Dictionary) -> Dictionary:
    # Snapshot/reader serial validated by base worker before owned copy.
    # Cache is local to the worker and additionally fenced by job epoch.
    var epoch: int=job["epoch"]
    if epoch!=_cache_epoch:
        _cache_epoch=epoch
        _token=str(_source_id)+":"+str(_serial)+":"+_snapshot+":"+str(epoch)
        _base_cache.begin(_token,epoch)
    var key: Vector2i=job["key"]
    var lod: int=job["lod"]
    var source=job["buffer"]
    var desired: Dictionary=job["desired"]
    var result: Dictionary={}
    if _scalar_sampling:
        result=_base_cache.patch(_token,epoch,source,key,lod,desired)
    var hit: bool=result.get("error",FAILED)==OK
    if hit:
        _partial+=1
    else:
        result=super._build_geometry(job)
        _full+=1
    if result.get("error",FAILED)==OK and _scalar_sampling:
        if _base_cache.retain(_token,epoch,key,lod,source.spacing,source.cells,desired,result)!=OK:
            _retain_fail+=1
    # Copy counters into the job before base worker queues it; never read
    # mutable worker cache on main thread. Raw bound excludes transient copy.
    job["g1_candidate"]={"hit":hit,"full":_full,"partial":_partial,"retain_fail":_retain_fail,"cache":_base_cache.report()}
    return result
