extends RefCounted
## Android OS thermal status, not CPU/battery temperature or a throttling diagnosis.
## Optional platform capability. No Java callbacks, worker, filesystem or per-frame polling.
const SAMPLE_INTERVAL_US := 30000000
const QUERY_COST_LIMIT_US := 5000
var status := -1
var source := "uninitialized"
var _wrapper
var _power
var _next_us := 0
var _initialized := false
var _disabled := false

func _initialize_bridge() -> void:
	_initialized = true
	source = "unavailable"
	if OS.get_name() != "Android":
		source = "non_android"
		return
	if not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):
		source = "android_bridge_missing"
		return
	_wrapper = Engine.get_singleton("JavaClassWrapper")
	var version = _wrapper.wrap("android.os.Build$VERSION")
	if version == null or _wrapper.get_exception() != null:
		source = "android_version_unavailable"
		return
	var sdk = version.SDK_INT
	if typeof(sdk) != TYPE_INT or sdk < 29:
		source = "android_api_unsupported"
		return
	var runtime = Engine.get_singleton("AndroidRuntime")
	var context = runtime.getApplicationContext()
	if context == null:
		source = "android_context_missing"
		return
	_power = context.getSystemService("power")
	if _power == null or _wrapper.get_exception() != null:
		_power = null
		source = "power_service_unavailable"
		return
	source = "android_power_manager"

## Call only from existing one-second UI update when preview is foreground and ready.
## Empty dictionary = no sample due; never block on another task or retry in a loop.
func sample_if_due(now_us: int) -> Dictionary:
	if _disabled or now_us < _next_us:
		return {}
	_next_us = now_us + SAMPLE_INTERVAL_US
	var started := Time.get_ticks_usec()
	var initial := not _initialized
	if initial:
		_initialize_bridge()
	if _power == null:
		_disabled = true
		return {"status":-1,"source":source,"sample_us":Time.get_ticks_usec()-started,"polling_disabled":true}
	var value = _power.getCurrentThermalStatus()
	if _wrapper.get_exception() != null or typeof(value) != TYPE_INT or value < 0 or value > 6:
		status = -1
		source = "android_thermal_query_failed"
		_disabled = true
		_power = null
		return {"status":status,"source":source,"sample_us":Time.get_ticks_usec()-started,"polling_disabled":true}
	status = int(value)
	var elapsed := Time.get_ticks_usec()-started
	# Setup can cost more than later calls; do not disable on the initial bridge setup
	# alone, but stop if a steady-state query itself exceeds the advisory budget.
	if not initial and elapsed > QUERY_COST_LIMIT_US:
		_disabled = true
		_power = null
	return {"status":status,"source":source,"sample_us":elapsed,"initial_bridge_setup":initial,"polling_disabled":_disabled,"status_is_temperature":false}

func label() -> String:
	match status:
		0: return "normal"
		1: return "hafif"
		2: return "orta"
		3: return "ciddi"
		4: return "kritik"
		5: return "acil"
		6: return "kapanma"
	return "bilinmiyor"

func is_currently_reportable() -> bool:
	return status >= 0 and not _disabled
