@tool
extends "res://addons/terra_forge/core/async_region_source.gd"
## F3 isolated ordered admission experiment. Same per-page jobs, hashes,
## worker, cap, generation and binary wake. No disk-read aggregation.
## Main thread only. One mutex acquisition for at most eight page requests.
const MAX_BATCH: int=8

func request_pages(keys: Array[Vector2i]) -> Dictionary:
    if keys.is_empty() or keys.size()>MAX_BATCH:
        return {"error":ERR_INVALID_PARAMETER}
    var statuses: Array[int]=[]
    var added: int=0
    var notify: bool=false
    _mutex.lock()
    var outstanding: int=_pending.size()+_inflight+_finished.size()
    var generation: int=_generation
    for key in keys:
        if not _valid_page(key) or (_root_v2==null and not _manifest_hashes.has(key)):
            statuses.append(ERR_INVALID_PARAMETER)
            continue
        if _cache.has(key):
            _cache_hits+=1
            _touch(key)
            statuses.append(OK)
            continue
        var terminal: Error=_terminal_error(key)
        if terminal!=OK:
            statuses.append(terminal)
            continue
        if _reserved.has(key):
            statuses.append(OK)
            continue
        if outstanding>=_job_limit or _stop:
            statuses.append(ERR_BUSY)
            continue
        var job: Dictionary={"key":key,"generation":generation,"path":"%s/r_%05d_%05d.tfr"%[_directory,key.x,key.y],"sha256":str(_manifest_hashes.get(key,"")),"snapshot":_snapshot_id,"cells":cells,"spacing":spacing,"submitted_us":Time.get_ticks_usec(),"profile":collect_io_profile}
        _pending.append(job)
        _reserved[key]=generation
        _submitted+=1
        outstanding+=1
        added+=1
        statuses.append(OK)
        if not _wake_armed:
            _wake_armed=true
            _wake_posts+=1
            notify=true
    _mutex.unlock()
    if notify:
        _wake.post()
    return {"error":OK,"statuses":statuses,"added":added}
