extends RefCounted
## Test-only counterfactual model. Holds identity/size/time metadata, never
## geometry arrays, and cannot serve an output or alter production queues.
var _cap: int
var _entries: Dictionary={}
var _order: Array[String]=[]
var _bytes: int=0
var _peak: int=0
var _offers: int=0
var _evicted: int=0
var _lookups: int=0
var _hits: int=0
var _cross_epoch: int=0
var _hit_bytes: int=0
var _prior_build_us: int=0

func _init(cap: int) -> void:
    _cap=cap

func _erase(key: String) -> void:
    _bytes-=int(_entries[key]["bytes"])
    _entries.erase(key)
    _order.erase(key)

func offer(key: String,bytes: int,build_us: int,epoch: int) -> void:
    if bytes<=0 or bytes>_cap:
        return
    _offers+=1
    if _entries.has(key):
        _erase(key)
    while _bytes+bytes>_cap or _order.size()>=64:
        _erase(_order[0])
        _evicted+=1
    _entries[key]={"bytes":bytes,"build_us":build_us,"epoch":epoch}
    _order.append(key)
    _bytes+=bytes
    _peak=maxi(_peak,_bytes)

func lookup(key: String,epoch: int) -> bool:
    _lookups+=1
    if not _entries.has(key):
        return false
    var item: Dictionary=_entries[key]
    _hits+=1
    if item["epoch"]!=epoch:
        _cross_epoch+=1
    _hit_bytes+=int(item["bytes"])
    _prior_build_us+=int(item["build_us"])
    # Model transfer rather than indefinite retention.
    _erase(key)
    return true

func report() -> Dictionary:
    return {"budget_bytes":_cap,"modeled_peak_bytes":_peak,"modeled_resident_bytes":_bytes,"entries":_entries.size(),"offers":_offers,"evictions":_evicted,"lookups":_lookups,"hypothetical_hits":_hits,"cross_epoch_hits":_cross_epoch,"hit_payload_bytes":_hit_bytes,"prior_discarded_build_wall_us":_prior_build_us}
