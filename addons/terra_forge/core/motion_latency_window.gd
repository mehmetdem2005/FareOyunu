@tool
extends RefCounted
## Selected-to-first LOD0 publication latency, not physics readiness.
const MIN_SECONDS: float=0.125
const MAX_SECONDS: float=0.5
const INITIAL_SECONDS: float=0.25
var horizon: float=INITIAL_SECONDS
var mean_seconds: float=0.0
var samples: int=0
var changes: int=0

func observe(elapsed_ticks: int,ticks_per_second: int) -> Error:
    if elapsed_ticks<0 or ticks_per_second<1 or ticks_per_second>1000:
        return ERR_INVALID_PARAMETER
    var measured: float=minf(MAX_SECONDS,float(elapsed_ticks)/float(ticks_per_second))
    mean_seconds=measured if samples==0 else lerpf(mean_seconds,measured,0.25)
    samples+=1
    var step: float=1.0/float(ticks_per_second)
    var target: float=clampf(ceilf((mean_seconds*1.5+2.0*step)/step)*step,MIN_SECONDS,MAX_SECONDS)
    if absf(target-horizon)>=step:
        horizon=target
        changes+=1
    return OK

func report() -> Dictionary:
    return {"horizon_seconds":horizon,"mean_publication_seconds":mean_seconds,"samples":samples,"changes":changes}
