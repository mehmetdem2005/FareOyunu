extends "res://addons/terra_forge/core/geometry_worker.gd"
const MODEL=preload("res://addons/terra_forge/tests/fixtures/discard_cache_shadow.gd")
var _models: Array=[]
var _ready_offers: int=0

func configure_shadow() -> void:
    _models=[MODEL.new(131072),MODEL.new(262144),MODEL.new(524288)]
    _ready_offers=0

static func _identity(key: Vector2i,lod: int,levels: Array) -> String:
    return str([key,lod,levels])

func _record_discard(job: Dictionary,desired: Variant=null,cells: Vector2i=Vector2i.ZERO,checked: Dictionary={}) -> void:
    super._record_discard(job,desired,cells,checked)
    # Under inherited mutex. Only successful completed outputs qualify.
    # The base worker verifies source instance/session/snapshot and uses a
    # fixed backend. A matching key is a hypothesis, not permission to reuse.
    if not job.has("geometry") or job["geometry"].get("error",FAILED)!=OK:
        return
    var bytes: int=int(job.get("output_reserved_payload_bytes",0))
    if bytes<=0 or bytes>OUTPUT_CAP:
        return
    _ready_offers+=1
    var identity: String=_identity(job["key"],job["lod"],job["levels"])
    for model in _models:
        model.offer(identity,bytes,int(job.get("build_elapsed_us",0)),int(job["epoch"]))

func submit(source,key: Vector2i,lod: int,desired: Dictionary,halo_mask: int=DENSE.FULL_HALO) -> Dictionary:
    var accepted: Dictionary=super.submit(source,key,lod,desired,halo_mask)
    if accepted.get("error",FAILED)==OK:
        var sig: Dictionary=signature(key,lod,desired,source.cells)
        _mutex.lock()
        for model in _models:
            model.lookup(_identity(key,lod,sig["levels"]),_epoch)
        _mutex.unlock()
    return accepted

func shadow_report() -> Dictionary:
    _mutex.lock()
    var reports: Array=[]
    for model in _models:
        reports.append(model.report())
    var result: Dictionary={"ready_offers":_ready_offers,"models":reports}
    _mutex.unlock()
    return result

func close() -> void:
    super.close()
    _models.clear()
    _ready_offers=0
