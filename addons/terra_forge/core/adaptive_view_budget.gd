@tool
extends RefCounted
## Frame interval pressure policy, NOT GPU telemetry or measured device FPS.
## Only far candidate admission changes. No precision or resource cap changes.
const ALPHA: float=0.125
const COOLDOWN: int=30
const HIGH_STREAK: int=8
const LOW_STREAK: int=20
var target_fps: int=30
var auto: bool=true
var tier: int=0
var mean_ms: float=0.0
var samples: int=0
var transitions: int=0
var cooldown: int=0
var high: int=0
var low: int=0

func configure(fps: int) -> Error:
    if fps!=30 and fps!=60:
        return ERR_INVALID_PARAMETER
    target_fps=fps
    auto=true
    tier=0
    mean_ms=0.0
    samples=0
    transitions=0
    cooldown=0
    high=0
    low=0
    return OK

func set_auto(enabled: bool) -> bool:
    if auto==enabled:
        return false
    auto=enabled
    var changed: bool=tier!=0
    if changed:
        transitions+=1
    tier=0
    mean_ms=0.0
    high=0
    low=0
    cooldown=0
    return changed

func observe(frame_ms: float) -> Error:
    if not is_finite(frame_ms) or frame_ms<=0.0 or frame_ms>1000.0:
        return ERR_INVALID_PARAMETER
    if not auto:
        return OK
    mean_ms=frame_ms if mean_ms==0.0 else lerpf(mean_ms,frame_ms,ALPHA)
    samples+=1
    if cooldown>0:
        cooldown-=1
        high=0
        low=0
        return OK
    var target: float=1000.0/float(target_fps)
    high=high+1 if mean_ms>target*1.1 else 0
    low=low+1 if mean_ms<target*0.85 else 0
    var previous: int=tier
    if high>=HIGH_STREAK:
        tier=mini(2,tier+1)
        high=0
    elif low>=LOW_STREAK:
        tier=maxi(0,tier-1)
        low=0
    if tier!=previous:
        transitions+=1
        cooldown=COOLDOWN
        high=0
        low=0
    return OK

func far_limit(count: int) -> int:
    if count<=0:
        return 0
    # A positive far set retains at least one candidate. Critical keys
    # never consume this optional budget.
    return count if tier==0 else ceili(float(count)/float(1<<tier))

func report() -> Dictionary:
    return {"target_fps":target_fps,"auto":auto,"tier":tier,"mean_frame_interval_ms":mean_ms,"samples":samples,"transitions":transitions,"cooldown":cooldown,"high_streak":high,"low_streak":low}
