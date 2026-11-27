extends RefCounted
## One preview-only controller. No native terrain, physics or resolution changes.
## Explicit opt-in, at most one reduction trial per selection, fail back to reference.
const BAD_WINDOWS := 5
const EVALUATION_WINDOWS := 8
const COOLDOWN_US := 5000000
const TRIAL_RATIO := 0.75
var base_far_m := 850.0
var mode := 0
var active_far_m := 850.0
var _last_end_us := -1
var _valid_after_us := 0
var _last_cap := -1
var _bad_count := 0
var _bad_sum := 0.0
var _bad_p95 := 0.0
var _bad_p99 := 0.0
var _trial_count := 0
var _trial_sum := 0.0
var _trial_p95 := 0.0
var _trial_p99 := 0.0
var _baseline_ms := 0.0
var _baseline_p95 := 0.0
var _baseline_p99 := 0.0
var _trial_started_us := 0
var _tried := false
var _evaluating := false
var last_evidence: Dictionary = {}

func configure(reference_far_m: float) -> void:
	if is_finite(reference_far_m) and reference_far_m > 0.0:
		base_far_m = reference_far_m
	select_mode(0)

func _clear_baseline() -> void:
	_bad_count = 0
	_bad_sum = 0.0
	_bad_p95 = 0.0
	_bad_p99 = 0.0

func select_mode(selected: int) -> void:
	mode = clampi(selected,0,2)
	active_far_m = base_far_m*TRIAL_RATIO if mode == 1 else base_far_m
	_last_end_us = -1
	_valid_after_us = Time.get_ticks_usec()
	_last_cap = -1
	_clear_baseline()
	_trial_count = 0
	_trial_sum = 0.0
	_trial_p95 = 0.0
	_trial_p99 = 0.0
	_baseline_ms = 0.0
	_baseline_p95 = 0.0
	_baseline_p99 = 0.0
	_tried = false
	_evaluating = false
	_trial_started_us = 0
	last_evidence = {}

## Settings and lifecycle boundaries invalidate comparisons immediately.
## A new automatic trial requires an explicit new mode selection, not a setting change.
func invalidate(now_us: int, restore_kept: bool = false) -> String:
	if mode != 2:
		return ""
	_valid_after_us = now_us
	_clear_baseline()
	_last_cap = -1
	if _evaluating or (restore_kept and active_far_m < base_far_m):
		_evaluating = false
		active_far_m = base_far_m
		last_evidence = {"decision":"context_invalidated","trial_windows":_trial_count}
		return "trial_context_restore"
	return ""

## Existing one-second summary only. A window must start AFTER its context boundary.
func observe(summary: Dictionary, eligible: bool, cap: int, now_us: int) -> String:
	if mode != 2 or (_tried and not _evaluating):
		return ""
	if not eligible:
		return invalidate(now_us)
	var end_us := int(summary.get("window_end_us",-1))
	if end_us <= _last_end_us:
		return ""
	var begin_us := int(summary.get("window_begin_us",-1))
	var contiguous := _last_end_us == begin_us
	_last_end_us = end_us
	var duration_us := end_us-begin_us
	var cap_changed := cap != _last_cap
	_last_cap = cap
	if begin_us < _valid_after_us:
		return ""
	var mean := float(summary.get("mean_ms",0.0))
	var p95 := float(summary.get("p95_ms",0.0))
	var p99 := float(summary.get("p99_ms",0.0))
	var valid := contiguous and not cap_changed and bool(summary.get("ground_ready",false)) and not bool(summary.get("menu_open",true)) and int(summary.get("fps_cap",-1)) == cap and (cap == 0 or cap >= 60) and int(summary.get("frames",0)) >= 15 and int(summary.get("over_100ms",0)) == 0 and int(summary.get("window_excluded_export_frames",0)) == 0 and duration_us >= 500000 and duration_us <= 1600000 and is_finite(mean) and mean > 0.0 and is_finite(p95) and p95 > 0.0 and is_finite(p99) and p99 > 0.0
	if not valid:
		_clear_baseline()
		if _evaluating:
			return invalidate(now_us)
		return ""
	if _evaluating:
		# Do not count a window straddling the cooldown boundary.
		if begin_us < _trial_started_us+COOLDOWN_US:
			return ""
		_trial_count += 1
		_trial_sum += mean
		_trial_p95 += p95
		_trial_p99 += p99
		if _trial_count < EVALUATION_WINDOWS:
			return ""
		_evaluating = false
		var avg := _trial_sum/EVALUATION_WINDOWS
		var tail95 := _trial_p95/EVALUATION_WINDOWS
		var tail99 := _trial_p99/EVALUATION_WINDOWS
		# Window averages, not pooled percentiles. A noisy route is not an A/B proof.
		var keep := avg <= _baseline_ms*0.95 and tail95 <= _baseline_p95 and tail99 <= _baseline_p99
		last_evidence = {"baseline_mean_ms":_baseline_ms,"trial_mean_ms":avg,"baseline_avg_window_p95_ms":_baseline_p95,"trial_avg_window_p95_ms":tail95,"baseline_avg_window_p99_ms":_baseline_p99,"trial_avg_window_p99_ms":tail99,"trial_windows":_trial_count,"controlled_benchmark":false,"decision":"keep" if keep else "restore"}
		if not keep:
			active_far_m = base_far_m
			return "trial_no_consistent_gain_restore"
		return "trial_observed_gain_keep"
	if mean > 20.0 and p95 > 22.0:
		_bad_count += 1
		_bad_sum += mean
		_bad_p95 += p95
		_bad_p99 += p99
	else:
		_clear_baseline()
	if _bad_count < BAD_WINDOWS:
		return ""
	_baseline_ms = _bad_sum/BAD_WINDOWS
	_baseline_p95 = _bad_p95/BAD_WINDOWS
	_baseline_p99 = _bad_p99/BAD_WINDOWS
	_tried = true
	_evaluating = true
	_trial_started_us = now_us
	active_far_m = base_far_m*TRIAL_RATIO
	last_evidence = {"baseline_mean_ms":_baseline_ms,"baseline_avg_window_p95_ms":_baseline_p95,"baseline_avg_window_p99_ms":_baseline_p99,"baseline_windows":BAD_WINDOWS,"controlled_benchmark":false}
	return "sustained_slow_trial"
