@tool
extends RefCounted
## Isolated opt-in prototype. Public methods main-thread only.
## Worker owns copied dense inputs and pure packed arrays, never a source
## reader, cache lease, scene node, Mesh resource or Physics server object.
const G = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const DENSE = preload("res://addons/terra_forge/core/tile_dense_buffer.gd")
const LOD = preload("res://addons/terra_forge/core/lod_policy.gd")
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
var _next_id: int = 0
var _pending: Array[Dictionary] = []
var _finished: Array[Dictionary] = []
var _inflight: int = 0
var _running_id: int = 0
var _submitted: int = 0
var _delivered: int = 0
var _dropped: int = 0
var _peak_slots: int = 0
var _pruned_pending: int = 0
var _pruned_finished: int = 0

func start(source, cap: int=2) -> Error:
    close()
    if source==null or not source.is_open() or cap<1 or cap>4:
        return ERR_INVALID_PARAMETER
    var stats: Dictionary=source.stats()
    _source_id=source.get_instance_id()
    _serial=source.session_serial()
    _snapshot=stats["snapshot_id"]
    _epoch=stats["generation"]
    _cap=cap
    _stop=false
    _thread=Thread.new()
    var status: Error=_thread.start(Callable(self,"_loop"),Thread.PRIORITY_LOW)
    if status!=OK:
        _thread=null
        return status
    _open=true
    return OK

func _context(source) -> Error:
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

## Copy under a short main-thread lease, then release before enqueue.
## No caller receives the input object or can mutate worker-owned data.
func submit(source,key: Vector2i,lod: int,desired: Dictionary) -> Dictionary:
    var context: Error=_context(source)
    if context!=OK:
        return {"error":context}
    var sig: Dictionary=signature(key,lod,desired,source.cells)
    if sig["error"]!=OK:
        return sig
    _mutex.lock()
    var full: bool=_slots()>=_cap
    _mutex.unlock()
    if full:
        return {"error":ERR_BUSY}
    var copy_started: int=Time.get_ticks_usec()
    var acquired: Dictionary=source.acquire_tile_view(G.required_pages(source,key.x,key.y,lod))
    if acquired["error"]!=OK:
        return acquired
    var copied: Dictionary=DENSE.build(acquired["view"],key.x,key.y,LOD.sample_stride(lod))
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
    _next_id+=1
    var id: int=_next_id
    _pending.append({"id":id,"epoch":_epoch,"key":key,"lod":lod,"levels":sig["levels"],"desired":sig["desired"],"buffer":buffer,"input_bytes":buffer.payload_bytes(),"copy_elapsed_us":copy_elapsed,"queued_us":Time.get_ticks_usec()})
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
            _mutex.unlock()
            var key: Vector2i=job["key"]
            var started: int=Time.get_ticks_usec()
            job["queue_wait_us"]=started-int(job["queued_us"])
            var generated: Dictionary=G.generate(job["buffer"],key.x,key.y,job["lod"],job["desired"])
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
            if _stop or job["epoch"]!=_epoch:
                _dropped+=1
            else:
                _finished.append(job)
            # No retained local references after publishing.
            generated={}
            job={}
            _mutex.unlock()

## Experimental F: main-thread reconciliation of bounded queues.
## Never interrupt running computation or mutate its immutable input.
func reconcile(source,desired: Dictionary,priority: Dictionary) -> Error:
    var context: Error=_context(source)
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
    for i in range(_finished.size()-1,-1,-1):
        var job: Dictionary=_finished[i]
        var sig: Dictionary=signature(job["key"],job["lod"],desired,source.cells)
        if sig.get("error",FAILED)!=OK or sig["levels"]!=job["levels"]:
            _finished.remove_at(i)
            _dropped+=1
            _pruned_finished+=1
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
func poll(source,desired: Dictionary) -> Dictionary:
    var context: Error=_context(source)
    if context!=OK:
        return {"error":context}
    _mutex.lock()
    while not _finished.is_empty():
        var result: Dictionary=_finished.pop_front()
        var sig: Dictionary=signature(result["key"],result["lod"],desired,source.cells)
        if result["epoch"]!=_epoch or sig["error"]!=OK or sig["levels"]!=result["levels"]:
            _dropped+=1
            continue
        _delivered+=1
        result["snapshot"]=_snapshot
        result["source_serial"]=_serial
        result["delivery_wait_us"]=Time.get_ticks_usec()-int(result["completed_us"])
        _mutex.unlock()
        return {"error":OK,"result":result}
    _mutex.unlock()
    return {"error":ERR_BUSY}

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

func stats() -> Dictionary:
    _mutex.lock()
    var result: Dictionary={"open":_open,"pending":_pending.size(),"inflight":_inflight,"finished":_finished.size(),"slots":_slots(),"cap":_cap,"reserved_payload_bytes":_slots()*SLOT_BYTES,"payload_cap_bytes":_cap*SLOT_BYTES,"peak_slots":_peak_slots,"pruned_pending":_pruned_pending,"pruned_finished":_pruned_finished,"submitted":_submitted,"delivered":_delivered,"dropped":_dropped,"epoch":_epoch}
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
    _armed=false
    _wake=Semaphore.new()
    _inflight=0
    _running_id=0
    _submitted=0
    _delivered=0
    _dropped=0
    _peak_slots=0
    _pruned_pending=0
    _pruned_finished=0
    _next_id=0
    _source_id=0
    _serial=0
    _snapshot=""
    _epoch=0
