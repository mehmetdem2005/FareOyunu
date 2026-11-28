@tool
extends RefCounted
## Native static planner gets only a private, value-only snapshot. No terrain handle.
var _thread: Thread
var _discard := false

static func _compute(snapshot: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result: Variant=ClassDB.class_call_static("Terrain3DData","tf_plan_smooth_snapshot",snapshot)
	if not result is Dictionary:
		return {"error":"Smooth static planner unavailable."}
	result["worker_us"]=Time.get_ticks_usec()-started
	return result

func busy() -> bool:
	return _thread!=null

func start(snapshot: Dictionary) -> Error:
	if busy():
		return ERR_BUSY
	_discard=false
	_thread=Thread.new()
	# Deep duplicate dictionary; packed array explicitly duplicated.
	var copy := snapshot.duplicate(true)
	var samples: PackedFloat32Array=snapshot["samples"]
	copy["samples"]=samples.duplicate()
	var error := _thread.start(_compute.bind(copy))
	if error!=OK:
		_thread=null
	return error

func cancel() -> void:
	_discard=true

func poll() -> Dictionary:
	if not busy() or _thread.is_alive():
		return {}
	var result: Variant=_thread.wait_to_finish()
	_thread=null
	if _discard:
		return {"error":"Yumuşatma iptal edildi."}
	if not result is Dictionary:
		return {"error":"Smooth worker returned invalid result."}
	return result

func shutdown() -> void:
	if busy():
		_discard=true
		_thread.wait_to_finish()
		_thread=null
