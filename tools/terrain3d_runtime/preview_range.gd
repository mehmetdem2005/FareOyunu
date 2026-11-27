extends RefCounted
## Preview-only policy. Never changes native terrain, data, physics or resolution.
## Deliberate opt-in; one conservative trial per enable. No oscillation.
const BAD_WINDOWS := 5
const EVALUATION_WINDOWS := 8
const COOLDOWN_US := 5000000
const TRIAL_RATIO := 0.75
var base_far_m := 850.0
var mode := 0 # 0 reference, 1 manual reduced, 2 adaptive trial
var active_far_m := 850.0
var _last_t_ms := -1.0
var _last_cap := -1
var _bad_count := 0
var _bad_sum := 0.0
var _trial_count := 0
var _trial_sum := 0.0
var _baseline_ms := 0.0
var _trial_started_us := 0
var _tried := false
var _evaluating := false

func configure(reference_far_m: float) -> void:
	if is_finite(reference_far_m) and reference_far_m > 0.0:
		base_far_m = reference_far_m
	select_mode(0)

func select_mode(selected: int) -> void:
	mode = clampi(selected,0,2)
	active_far_m = base_far_m*TRIAL_RATIO if mode == 1 else base_far_m
	_last_t_ms = -1.0
	_last_cap = -1
	_bad_count = 0
	_bad_sum = 0.0
	_trial_count = 0
	_trial_sum = 0.0
	_baseline_ms = 0.0
	_tried = false
	_evaluating = false
	_trial_started_us = 0

## Called only from the existing one-second HUD update, not each frame.
## Return a decision only when the camera far plane actually needs to change.
func observe(summary: Dictionary, eligible: bool, cap: int, now_us: int) -> String:
	if mode != 2 or (_tried and not _evaluating):
		return ""
	var t := float(summary.get("t_ms",-1.0))
	if t <= _last_t_ms:
		return ""
	var dt := t-_last_t_ms
	_last_t_ms = t
	var cap_changed := cap != _last_cap
	_last_cap = cap
	var mean := float(summary.get("mean_ms",0.0))
	var p95 := float(summary.get("p95_ms",0.0))
	var valid := eligible and bool(summary.get("ground_ready",false)) and not bool(summary.get("menu_open",true)) and int(summary.get("fps_cap",-1)) == cap and (cap == 0 or cap >= 60) and int(summary.get("frames",0)) >= 15 and int(summary.get("over_100ms",0)) == 0 and dt >= 500.0 and dt <= 1600.0 and not cap_changed and is_finite(mean) and mean > 0.0 and is_finite(p95) and p95 > 0.0
	if not valid:
		_bad_count = 0
		_bad_sum = 0.0
		# Interrupted comparisons are inconclusive; restore rather than silently keep reduced range.
		if _evaluating:
			_evaluating = false
			active_far_m = base_far_m
			return "trial_interrupted_restore"
		return ""
	if _evaluating:
		if now_us-_trial_started_us < COOLDOWN_US:
			return ""
		_trial_count += 1
		_trial_sum += mean
		if _trial_count < EVALUATION_WINDOWS:
			return ""
		_evaluating = false
		# Not a controlled benchmark: a lack of observed improvement rejects the trial.
		if _trial_sum/EVALUATION_WINDOWS > _baseline_ms*0.95:
			active_far_m = base_far_m
			return "trial_no_observed_gain_restore"
		# Keep range only within this explicitly selected mode. Never decrease further.
		return ""
	if mean > 20.0 and p95 > 22.0:
		_bad_count += 1
		_bad_sum += mean
	else:
		_bad_count = 0
		_bad_sum = 0.0
	if _bad_count < BAD_WINDOWS:
		return ""
	_baseline_ms = _bad_sum/BAD_WINDOWS
	_tried = true
	_evaluating = true
	_trial_started_us = now_us
	active_far_m = base_far_m*TRIAL_RATIO
	return "sustained_slow_trial"
