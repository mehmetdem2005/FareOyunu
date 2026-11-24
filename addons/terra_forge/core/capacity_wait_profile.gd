@tool
extends RefCounted
## Bounded observational episodes, not precise hardware wait time.
## A sample begins at first observed full worker gate for an unowned
## candidate, ends at next observed non-full gate or cancellation.
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
const MAX_KEYS:int=128
var _epoch:int=-1
var _active:Dictionary={}
var _critical=HIST.new()
var _optional=HIST.new()
var _cancelled:int=0
var _peak:int=0
var _observations:int=0

func observe(epoch:int,eligible:Dictionary,full:bool,now_us:int) -> Error:
    if epoch<0 or now_us<0 or eligible.size()>MAX_KEYS:
        return ERR_INVALID_PARAMETER
    for key in eligible:
        if not key is Vector2i or not eligible[key] is int or int(eligible[key])<0 or int(eligible[key])>2:
            return ERR_INVALID_PARAMETER
    if epoch!=_epoch:
        _cancelled+=_active.size()
        _active.clear()
        _epoch=epoch
    # Invalidation takes precedence over a successful gate release.
    for key in _active.keys():
        var item:Dictionary=_active[key]
        if not eligible.has(key) or int(eligible[key])!=int(item["lod"]):
            _active.erase(key)
            _cancelled+=1
        elif not full:
            if now_us<int(item["since"]):
                _active.erase(key)
                _cancelled+=1
                continue
            var hist=_critical if int(item["lod"])==0 else _optional
            hist.add(float(now_us-int(item["since"]))/1000.0)
            _active.erase(key)
    if full:
        for key in eligible:
            if not _active.has(key):
                _active[key]={"lod":eligible[key],"since":now_us}
        _peak=maxi(_peak,_active.size())
    _observations+=1
    return OK

func report(now_us:int) -> Dictionary:
    var critical_age:int=0
    var optional_age:int=0
    for item in _active.values():
        var age:int=maxi(0,now_us-int(item["since"]))
        if int(item["lod"])==0:
            critical_age=maxi(critical_age,age)
        else:
            optional_age=maxi(optional_age,age)
    return {"scope":"observed_full_gate_episodes_not_io_or_submit_latency","critical_ms":_critical.report(),"optional_ms":_optional.report(),"active":_active.size(),"peak_active":_peak,"cancelled":_cancelled,"observations":_observations,"critical_oldest_us":critical_age,"optional_oldest_us":optional_age,"epoch":_epoch}
