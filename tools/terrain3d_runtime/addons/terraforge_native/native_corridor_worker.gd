@tool
extends RefCounted
## Geometry-only worker: private path and scalar parameters, no live terrain.
const Landform = preload("res://addons/terraforge_native/native_landform.gd")
var _thread: Thread
var _discard := false

static func _compute(points: Array[Vector2], radius: float, spacing: float, valley: bool) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := Landform.build(points,radius,spacing,valley)
	result["worker_us"]=Time.get_ticks_usec()-started
	return result

func busy() -> bool:
	return _thread!=null

func start(points: Array[Vector2], radius: float, spacing: float, valley: bool) -> Error:
	if busy():
		return ERR_BUSY
	_discard=false
	_thread=Thread.new()
	var copy: Array[Vector2]=[]
	copy.assign(points)
	var error := _thread.start(_compute.bind(copy,radius,spacing,valley))
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
		return {"error":"Dağ sırtı/vadi işlemi iptal edildi."}
	if not result is Dictionary:
		return {"error":"Corridor worker returned invalid result."}
	return result

func shutdown() -> void:
	if busy():
		_discard=true
		_thread.wait_to_finish()
		_thread=null
