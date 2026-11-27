@tool
extends RefCounted
## Only immutable value inputs reach the worker; no Node, Image, RF or RID.
const Weather = preload("res://addons/terraforge_native/native_weather.gd")
var _thread: Thread
var _discard := false

static func _compute(source: PackedFloat64Array, weights: PackedFloat32Array, dim: Vector2i, spacing: float, power: float, mode: int) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := Weather.run(source,weights,dim,spacing,power,mode)
	result["worker_us"]=Time.get_ticks_usec()-started
	return result

func busy() -> bool:
	return _thread != null

func start(source: PackedFloat64Array, weights: PackedFloat32Array, dim: Vector2i, spacing: float, power: float, mode: int) -> Error:
	if busy():
		return ERR_BUSY
	_discard=false
	_thread=Thread.new()
	var error := _thread.start(_compute.bind(source.duplicate(),weights.duplicate(),dim,spacing,power,mode))
	if error!=OK:
		_thread=null
	return error

func cancel() -> void:
	_discard=true

func poll() -> Dictionary:
	if not busy() or _thread.is_alive():
		return {}
	var result: Variant = _thread.wait_to_finish()
	_thread=null
	if _discard:
		return {"error":"Aşındırma iptal edildi.","discarded":true}
	if not result is Dictionary:
		return {"error":"Weather worker returned invalid result."}
	return result

func shutdown() -> void:
	if busy():
		_discard=true
		_thread.wait_to_finish()
		_thread=null
