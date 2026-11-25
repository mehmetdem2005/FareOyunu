@tool
extends RefCounted
## Isolated opt-in prototype. Public methods main-thread only.
## Worker owns copied dense inputs and pure packed arrays, never a source
## reader, cache lease, scene node, Mesh resource or Physics server object.
const G = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const PUB = preload("res://addons/terra_forge/core/publication_accounting.gd")
const TOPOLOGY = preload("res://addons/terra_forge/core/tile_topology_cache.gd")
const DENSE = preload("res://addons/terra_forge/core/tile_dense_buffer.gd")
const LOD = preload("res://addons/terra_forge/core/lod_policy.gd")
const LATENCY=preload("res://addons/terra_forge/core/geometry_latency_profile.gd")
const INPUT_CAP: int = 4900
# Conservative payload reservation supports double precision vector builds.
# Does not include Variant/container overhead or caller-owned results.
const OUTPUT_CAP: int = 131072
const SLOT_BYTES: int = INPUT_CAP + OUTPUT_CAP
var _thread: Thread
var _mutex: Mutex = Mutex.new()
var _wake: Semaphore = Semaphore.new()
var _open: bool = false
var _stop: bool = false
var _armed: bool = false
var _source_id: int = 0
var _serial: int = 0
var _snapshot: String = ""
var _epoch: int = 0
var _cap: int = 2
var _scalar_sampling: bool = false
var _topology
var _topology_payload: int=0
var _topology_setup_us: int=0
var _next_id: int = 0
var _pending: Array[Dictionary] = []
var _finished: Array[Dictionary] = []
var _inflight: int = 0
var _running_id: int = 0
var _running_lod: int=-1
var _running_since_us: int=0
var _dedup_enabled: bool=false
var _dedup_running: Dictionary={}
var _coalesced: int=0

# Caller holds mutex. Session and snapshot were verified by _context.
# Epoch is deliberately part of the identity; no cross-generation reuse.
func _same_request(job: Dictionary,key: Vector2i,lod: int,levels: Array,halo: int) -> bool:
    return not job.is_empty() and job["epoch"]==_epoch and job["key"]==key and job["lod"]==lod and job["levels"]==levels and job["halo_mask"]==halo

func _existing_request(key: Vector2i,lod: int,levels: Array,halo: int) -> int:
    if _same_request(_dedup_running,key,lod,levels,halo):
        return int(_dedup_running["id"])
    for job in _pending:
        if _same_request(job,key,lod,levels,halo):
            return int(job["id"])
    for job in _finished:
        if _same_request(job,key,lod,levels,halo):
            return int(job["id"])
    return 0
var _latency_profile
var _reserve_critical: bool=false
var _reservation_deferrals: int=0
var _lend_critical: bool=false
var _critical_demand: bool=true
var _demand_changes: int=0
var _loan_admissions: int=0
var _critical_full_denials: int=0
var _submitted: int = 0
var _delivered: int = 0
var _dropped: int = 0
var _peak_slots: int = 0
var _pruned_pending: int = 0
var _pruned_finished: int = 0
# d0: reason accounting only. Updated under the existing ownership mutex.
# No timer calls added to the hot loop; reuse measured copy/build wall times.
var _epoch_pending_drops: int=0
var _epoch_finished_drops: int=0
var _epoch_running_drops: int=0
var _poll_stale_drops: int=0
var _discarded_copy_us: int=0
var _discarded_build_us: int=0
var _discard_identity: Dictionary={"removed_key":0,"changed_lod":0,"changed_neighbors":0,"invalid_signature":0,"same_geometry_at_epoch":0,"unknown":0}

# Diagnostic identity only: a matching cardinal signature is not yet
# permission to publish across epochs. Running work has unknown identity here.
func _record_discard(job: Dictionary,desired: Variant=null,cells: Vector2i=Vector2i.ZERO,checked: Dictionary={}) -> void:
    _discarded_copy_us+=int(job.get("copy_elapsed_us",0))
    _discarded_build_us+=int(job.get("build_elapsed_us",0))
    var reason: String="unknown"
    if desired is Dictionary:
        if not desired.has(job["key"]):
            reason="removed_key"
        elif desired[job["key"]]!=job["lod"]:
            reason="changed_lod"
        else:
            var sig: Dictionary=checked if not checked.is_empty() else signature(job["key"],job["lod"],desired,cells)
            if sig.get("error",FAILED)!=OK:
                reason="invalid_signature"
            elif sig["levels"]!=job["levels"]:
                reason="changed_neighbors"
            else:
                reason="same_geometry_at_epoch"
    _discard_identity[reason]+=1

func start(source, cap: int=2, scalar_sampling: bool=false,reuse_topology: bool=false,reserve_critical: bool=false,lend_critical: bool=false,profile_latency: bool=false,deduplicate: bool=false) -> Error:
    close()
    if source==null or not source.is_open() or cap<1 or cap>4 or (reuse_topology and not scalar_sampling):
        return ERR_INVALID_PARAMETER
    var stats: Dictionary=source.stats()
    _source_id=source.get_instance_id()
    _serial=source.session_serial()
    _snapshot=stats["snapshot_id"]
    _epoch=stats["generation"]
    _cap=cap
    _reserve_critical=reserve_critical and cap>=2
    _lend_critical=lend_critical and _reserve_critical
    _latency_profile=LATENCY.new() if profile_latency else null
    _scalar_sampling=scalar_sampling
    _dedup_enabled=deduplicate
    if reuse_topology:
        var started: int=Time.get_ticks_usec()
        _topology=TOPOLOGY.new()
        var err: Error=_topology.initialize()
        if err!=OK:
            close()
            return err
        _topology_payload=_topology.payload_bytes()
        _topology_setup_us=Time.get_ticks_usec()-started
    _stop=false
    _thread=Thread.new()
    var status: Error=_thread.start(Callable(self,"_loop"),Thread.PRIORITY_LOW)
    if status!=OK:
        _thread=null
        close()
        return status
    _open=true
    return OK

func _context(source,desired: Variant=null) -> Error:
    if not _open or source==null or not source.is_open():
        return ERR_UNCONFIGURED
    if source.get_instance_id()!=_source_id or source.session_serial()!=_serial:
        return ERR_INVALID_DATA
    var stats: Dictionary=source.stats()
    if stats["snapshot_id"]!=_snapshot:
        return ERR_INVALID_DATA
    var epoch: int=stats["generation"]
    _mutex.lock()
    if epoch!=_epoch:
        _epoch=epoch
        _dropped+=_pending.size()+_finished.size()
        _epoch_pending_drops+=_pending.size()
        _epoch_finished_drops+=_finished.size()
        for job in _pending:
            _record_discard(job,desired,source.cells)
        for job in _finished:
            _record_discard(job,desired,source.cells)
        _pending.clear()
        _finished.clear()
    _mutex.unlock()
    return OK

## Only the four cardinal neighbors affect current seam/normal geometry.
static func signature(key: Vector2i,lod: int,desired: Dictionary,cells: Vector2i) -> Dictionary:
    if lod<0 or lod>2 or key.x<0 or key.y<0 or (key.x+1)*32>cells.x or (key.y+1)*32>cells.y or desired.get(key,-1)!=lod:
        return {"error":ERR_INVALID_PARAMETER}
    var neighbors: Dictionary={key:lod}
    var levels: Array[int]=[]
    for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
        var n: Vector2i=key+direction
        var level: int=int(desired.get(n,-1))
        if level < -1 or level>2 or (level>=0 and (n.x<0 or n.y<0 or (n.x+1)*32>cells.x or (n.y+1)*32>cells.y)):
            return {"error":ERR_INVALID_PARAMETER}
        levels.append(level)
        if level>=0:
            neighbors[n]=level
    return {"error":OK,"levels":levels,"desired":neighbors}

func _slots() -> int:
    return _pending.size()+_finished.size()+_inflight

## Called with mutex held. Count all three ownership stages, including
## the running job; the worker only moves jobs between these stages.
func _optional_slots() -> int:
    var count: int=1 if _inflight>0 and _running_lod>0 else 0
    for job in _pending:
        if int(job["lod"])>0:
            count+=1
    for job in _finished:
        if int(job["lod"])>0:
            count+=1
    return count

## Main-thread demand hint. Does not preempt running work, discard output,
## or change the hard capacity. False lends the otherwise reserved slot.
func set_critical_demand(source,demand: bool) -> Error:
    var context: Error=_context(source)
    if context!=OK:
        return context
    if not _lend_critical:
        return ERR_UNAVAILABLE
    _mutex.lock()
    if demand!=_critical_demand:
        _critical_demand=demand
        _demand_changes+=1
    _mutex.unlock()
    return OK

func _reservation_enforced() -> bool:
    return _reserve_critical and (not _lend_critical or _critical_demand)

## Copy under a short main-thread lease, then release before enqueue.
## No caller receives the input object or can mutate worker-owned data.
func submit(source,key: Vector2i,lod: int,desired: Dictionary, halo_mask: int = DENSE.FULL_HALO) -> Dictionary:
    var context: Error=_context(source,desired)
    if context!=OK:
        return {"error":context}
    var sig: Dictionary=signature(key,lod,desired,source.cells)
    if sig["error"]!=OK:
        return sig
    _mutex.lock()
    if _dedup_enabled:
        var existing: int=_existing_request(key,lod,sig["levels"],halo_mask)
        if existing!=0:
            _coalesced+=1
            _mutex.unlock()
            # One result for the original ID, not a second publication.
            # No lease acquisition, copy, slot or submitted increment.
            return {"error":OK,"id":existing,"coalesced":true,"copy_elapsed_us":0,"input_bytes":0}
    var full: bool=_slots()>=_cap
    var reserved: bool=_reservation_enforced() and lod>0 and _optional_slots()>=_cap-1
    if full and lod==0 and _lend_critical:
        _critical_full_denials+=1
    if reserved:
        _reservation_deferrals+=1
    _mutex.unlock()
    if full or reserved:
        return {"error":ERR_BUSY,"reserved_critical":reserved}
    var copy_started: int=Time.get_ticks_usec()
    var acquired: Dictionary=source.acquire_tile_view(G.required_pages(source,key.x,key.y,lod,halo_mask))
    if acquired["error"]!=OK:
        return acquired
    var copied: Dictionary=DENSE.build(acquired["view"],key.x,key.y,LOD.sample_stride(lod),halo_mask)
    var release: Error=source.release_tile_view(acquired["view"])
    if release!=OK:
        return {"error":release}
    if copied["error"]!=OK:
        return copied
    var buffer= copied["buffer"]
    if buffer.payload_bytes()>INPUT_CAP:
        return {"error":ERR_BUG}
    var copy_elapsed: int=Time.get_ticks_usec()-copy_started
    _mutex.lock()
    if _lend_critical and not _critical_demand and lod>0 and _optional_slots()>=_cap-1:
        _loan_admissions+=1
    _next_id+=1
    var id: int=_next_id
    var job: Dictionary={"id":id,"epoch":_epoch,"key":key,"lod":lod,"levels":sig["levels"],"halo_mask":halo_mask,"desired":sig["desired"],"buffer":buffer,"input_bytes":buffer.payload_bytes(),"copy_elapsed_us":copy_elapsed,"queued_us":Time.get_ticks_usec()}
    if _reserve_critical and lod==0:
        var index: int=0
        while index<_pending.size() and int(_pending[index]["lod"])==0:
            index+=1
        _pending.insert(index,job)
    else:
        _pending.append(job)
    _submitted+=1
    _peak_slots=maxi(_peak_slots,_slots())
    var wake: bool=not _armed
    _armed=true
    _mutex.unlock()
    if wake:
        _wake.post()
    return {"error":OK,"id":id,"copy_elapsed_us":copy_elapsed,"input_bytes":buffer.payload_bytes()}

func _loop() -> void:
    while true:
        _wake.wait()
        while true:
            _mutex.lock()
            if _stop:
                _mutex.unlock()
                return
            if _pending.is_empty():
                _armed=false
                _mutex.unlock()
                break
            var job: Dictionary=_pending.pop_front()
            _inflight=1
            _running_id=job["id"]
            _running_lod=int(job["lod"])
            _running_since_us=Time.get_ticks_usec()
            if _dedup_enabled:
                _dedup_running={"id":job["id"],"epoch":job["epoch"],"key":job["key"],"lod":job["lod"],"levels":job["levels"],"halo_mask":job["halo_mask"]}
            _mutex.unlock()
            var started: int=Time.get_ticks_usec()
            job["queue_wait_us"]=started-int(job["queued_us"])
            var generated: Dictionary=_build_geometry(job)
            var elapsed: int=Time.get_ticks_usec()-started
            var output_bytes: int=0
            if generated["error"]==OK:
                var arrays: Array=generated["arrays"]
                output_bytes=arrays[Mesh.ARRAY_VERTEX].size()*24+arrays[Mesh.ARRAY_NORMAL].size()*24+arrays[Mesh.ARRAY_TEX_UV].size()*16+arrays[Mesh.ARRAY_COLOR].size()*16+arrays[Mesh.ARRAY_INDEX].size()*4+generated["collision_heights"].size()*4
                if output_bytes>OUTPUT_CAP:
                    generated={"error":ERR_BUG}
                    output_bytes=0
            job.erase("buffer")
            job.erase("desired")
            job["geometry"]=generated
            job["output_reserved_payload_bytes"]=output_bytes
            job["build_elapsed_us"]=elapsed
            job["completed_us"]=Time.get_ticks_usec()
            _mutex.lock()
            _inflight=0
            _running_id=0
            _running_lod=-1
            _running_since_us=0
            _dedup_running={}
            if _stop or job["epoch"]!=_epoch:
                _dropped+=1
                if not _stop:
                    _epoch_running_drops+=1
                    _record_discard(job)
            else:
                _finished.append(job)
            # No retained local references after publishing.
            generated={}
            job={}
            _mutex.unlock()

## Worker-thread pure compute seam. Test subclass can gate this operation
## without a runtime delay setting or a reference to source/scene objects.
func _build_geometry(job: Dictionary) -> Dictionary:
    var key: Vector2i=job["key"]
    return G.generate_owned_dense_scalar(job["buffer"],key.x,key.y,job["lod"],job["desired"],_topology) if _scalar_sampling else G.generate(job["buffer"],key.x,key.y,job["lod"],job["desired"])

## Experimental F: main-thread reconciliation of bounded queues.
## Never interrupt running computation or mutate its immutable input.
func reconcile(source,desired: Dictionary,priority: Dictionary) -> Error:
    var context: Error=_context(source,desired)
    if context!=OK:
        return context
    _mutex.lock()
    for i in range(_pending.size()-1,-1,-1):
        var job: Dictionary=_pending[i]
        var sig: Dictionary=signature(job["key"],job["lod"],desired,source.cells)
        if sig.get("error",FAILED)!=OK or sig["levels"]!=job["levels"]:
            _pending.remove_at(i)
            _dropped+=1
            _pruned_pending+=1
            _record_discard(job,desired,source.cells,sig)
    for i in range(_finished.size()-1,-1,-1):
        var job: Dictionary=_finished[i]
        var sig: Dictionary=signature(job["key"],job["lod"],desired,source.cells)
        if sig.get("error",FAILED)!=OK or sig["levels"]!=job["levels"]:
            _finished.remove_at(i)
            _dropped+=1
            _pruned_finished+=1
            _record_discard(job,desired,source.cells,sig)
    # Deterministic tie-break by unique job ID. Priority is main-owned
    # and never retained or read by worker outside this mutex.
    var less=func(a: Dictionary,b: Dictionary)->bool:
        var pa: int=int(priority.get(a["key"],2147483647))
        var pb: int=int(priority.get(b["key"],2147483647))
        return int(a["id"])<int(b["id"]) if pa==pb else pa<pb
    _pending.sort_custom(less)
    _finished.sort_custom(less)
    _mutex.unlock()
    return OK

## Only transfer one result per call. Recheck current source session,
## epoch, requested LOD and four-neighbor signature before delivery.
func poll(source,desired: Dictionary,max_source_bytes: int=-1,critical_only: bool=false) -> Dictionary:
    var context: Error=_context(source,desired)
    if context!=OK:
        return {"error":context}
    _mutex.lock()
    var index: int=0
    var deferred_optional: bool=false
    while index<_finished.size():
        var result: Dictionary=_finished[index]
        var sig: Dictionary=signature(result["key"],result["lod"],desired,source.cells)
        if result["epoch"]!=_epoch or sig["error"]!=OK or sig["levels"]!=result["levels"]:
            _finished.remove_at(index)
            _dropped+=1
            _poll_stale_drops+=1
            _record_discard(result,desired,source.cells,sig)
            continue
        # Keep optional outputs in existing bounded worker slots; scan
        # for a valid LOD0 result rather than blocking it behind a far one.
        if critical_only and int(result["lod"])!=0:
            deferred_optional=true
            index+=1
            continue
        if max_source_bytes>=0 and int(PUB.expected(result["lod"])["total_bytes"])>max_source_bytes:
            _mutex.unlock()
            return {"error":ERR_BUSY,"deferred_bytes":true,"deferred_optional":deferred_optional}
        _finished.remove_at(index)
        _delivered+=1
        result["snapshot"]=_snapshot
        result["source_serial"]=_serial
        result["delivery_wait_us"]=Time.get_ticks_usec()-int(result["completed_us"])
        _mutex.unlock()
        if _latency_profile!=null:
            _latency_profile.record(result)
        return {"error":OK,"result":result,"deferred_optional":deferred_optional}
    _mutex.unlock()
    return {"error":ERR_BUSY,"deferred_optional":deferred_optional}

## Main-thread snapshot of IDs still owned by worker. No result arrays.
func active_ids() -> Array[int]:
    _mutex.lock()
    var ids: Array[int]=[]
    for job in _pending:
        ids.append(int(job["id"]))
    for job in _finished:
        ids.append(int(job["id"]))
    if _running_id!=0:
        ids.append(_running_id)
    _mutex.unlock()
    return ids

## Current outstanding ages are censored snapshots, not completed latency.
## Explicit diagnostic call; avoid constructing histograms in each pump.
func latency_profile() -> Dictionary:
    if _latency_profile==null:
        return {}
    var now: int=Time.get_ticks_usec()
    var ages: Dictionary={"critical":{"pending_us":0,"running_us":0,"finished_us":0},"optional":{"pending_us":0,"running_us":0,"finished_us":0}}
    _mutex.lock()
    for job in _pending:
        var group: Dictionary=ages["critical" if int(job["lod"])==0 else "optional"]
        group["pending_us"]=maxi(int(group["pending_us"]),maxi(0,now-int(job["queued_us"])))
    for job in _finished:
        var group: Dictionary=ages["critical" if int(job["lod"])==0 else "optional"]
        group["finished_us"]=maxi(int(group["finished_us"]),maxi(0,now-int(job["completed_us"])))
    if _inflight>0:
        ages["critical" if _running_lod==0 else "optional"]["running_us"]=maxi(0,now-_running_since_us)
    var counts: Dictionary={"submitted":_submitted,"delivered":_delivered,"dropped":_dropped,"owned":_slots()}
    _mutex.unlock()
    var report: Dictionary=_latency_profile.report()
    report["outstanding_age_us"]=ages
    report["ownership"]=counts
    return report

func stats() -> Dictionary:
    _mutex.lock()
    var result: Dictionary={"open":_open,"scalar_sampling":_scalar_sampling,"topology_cache_bytes":_topology_payload,"topology_setup_us":_topology_setup_us,"total_worker_payload_allowance_bytes":_cap*SLOT_BYTES+_topology_payload,"pending":_pending.size(),"inflight":_inflight,"finished":_finished.size(),"slots":_slots(),"cap":_cap,"critical_reservation":_reserve_critical,"reservation_enforced":_reservation_enforced(),"lend_critical":_lend_critical,"critical_demand":_critical_demand,"demand_changes":_demand_changes,"loan_admissions":_loan_admissions,"critical_full_denials":_critical_full_denials,"optional_slots":_optional_slots(),"reservation_deferrals":_reservation_deferrals,"reserved_payload_bytes":_slots()*SLOT_BYTES,"payload_cap_bytes":_cap*SLOT_BYTES,"peak_slots":_peak_slots,"pruned_pending":_pruned_pending,"pruned_finished":_pruned_finished,"submitted":_submitted,"delivered":_delivered,"dropped":_dropped,"epoch":_epoch}
    result["discard_accounting"]={"epoch_pending":_epoch_pending_drops,"epoch_finished":_epoch_finished_drops,"epoch_running":_epoch_running_drops,"reconcile_pending":_pruned_pending,"reconcile_finished":_pruned_finished,"poll_stale":_poll_stale_drops,"copy_wall_us":_discarded_copy_us,"build_wall_us":_discarded_build_us,"classified":_epoch_pending_drops+_epoch_finished_drops+_epoch_running_drops+_pruned_pending+_pruned_finished+_poll_stale_drops}
    result["discard_identity"]=_discard_identity.duplicate()
    result["deduplication"]={"enabled":_dedup_enabled,"coalesced":_coalesced}
    _mutex.unlock()
    return result

func close() -> void:
    _mutex.lock()
    _stop=true
    _dropped+=_pending.size()+_finished.size()
    _pending.clear()
    _finished.clear()
    _mutex.unlock()
    if _thread!=null and _thread.is_started():
        _wake.post()
        _thread.wait_to_finish()
    _thread=null
    _open=false
    _scalar_sampling=false
    _topology=null
    _topology_payload=0
    _topology_setup_us=0
    _armed=false
    _wake=Semaphore.new()
    _inflight=0
    _running_id=0
    _running_lod=-1
    _running_since_us=0
    _dedup_enabled=false
    _dedup_running={}
    _coalesced=0
    _latency_profile=null
    _reserve_critical=false
    _lend_critical=false
    _critical_demand=true
    _demand_changes=0
    _loan_admissions=0
    _critical_full_denials=0
    _reservation_deferrals=0
    _submitted=0
    _delivered=0
    _dropped=0
    _peak_slots=0
    _pruned_pending=0
    _pruned_finished=0
    _epoch_pending_drops=0
    _epoch_finished_drops=0
    _epoch_running_drops=0
    _poll_stale_drops=0
    _discarded_copy_us=0
    _discarded_build_us=0
    for reason in _discard_identity:
        _discard_identity[reason]=0
    _next_id=0
    _source_id=0
    _serial=0
    _snapshot=""
    _epoch=0
