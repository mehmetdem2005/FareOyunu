@tool
extends RefCounted
## Optional geometry admission only, not a hard real-time or GPU guarantee.
## Counts main-thread build attempts, worker submissions and publications.
var tier: int=0
var soft_us: int=0
var optional_limit: int=0
var pump_optional: int=0
var pump_critical: int=0
var pumps: int=0
var restricted_pumps: int=0
var optional_attempts: int=0
var critical_attempts: int=0
var deferrals: int=0
var restricted_peak_optional: int=0
var tier2_peak_optional: int=0
var first_progress_exceptions: int=0

func begin_pump(level: int,base_us: int) -> void:
    tier=clampi(level,0,2)
    soft_us=maxi(1,int(float(base_us)/float(1<<tier)))
    optional_limit=2147483647 if tier==0 else (2 if tier==1 else 1)
    pump_optional=0
    pump_critical=0
    pumps+=1
    if tier>0:
        restricted_pumps+=1

func allows_optional(elapsed_us: int) -> bool:
    if tier==0:
        return true
    if pump_optional>=optional_limit:
        return false
    # At least one optional item may progress on an otherwise idle pump.
    # The caller's original soft deadline and all hard caps still apply.
    return elapsed_us<soft_us or (pump_optional==0 and pump_critical==0)

func record(lod: int,elapsed_us: int) -> void:
    if lod==0:
        pump_critical+=1
        critical_attempts+=1
        return
    if tier>0 and elapsed_us>=soft_us and pump_optional==0 and pump_critical==0:
        first_progress_exceptions+=1
    pump_optional+=1
    optional_attempts+=1
    if tier>0:
        restricted_peak_optional=maxi(restricted_peak_optional,pump_optional)
    if tier==2:
        tier2_peak_optional=maxi(tier2_peak_optional,pump_optional)

func note_deferral() -> void:
    deferrals+=1

func report() -> Dictionary:
    return {"tier":tier,"optional_soft_us":soft_us,"optional_limit":optional_limit,"pumps":pumps,"restricted_pumps":restricted_pumps,"optional_attempts":optional_attempts,"critical_attempts":critical_attempts,"deferrals":deferrals,"restricted_peak_optional":restricted_peak_optional,"tier2_peak_optional":tier2_peak_optional,"first_progress_exceptions":first_progress_exceptions}
