@tool
extends RefCounted
## F2 shadow candidate: bounded per-footprint empirical readiness quantile.
## Physics ticks, not wall-clock milliseconds; caller supplies only verified
## observations. No page pinning, movement authorization, or runtime wiring.
const CAP: int=16
const MIN_SAMPLES: int=4
const MIN_SECONDS: float=0.125
const MAX_SECONDS: float=0.5
var _samples: Dictionary={1:[],2:[],4:[]}

func observe(tiles: int,elapsed_ticks: int,rate: int) -> Error:
    if not _samples.has(tiles) or elapsed_ticks<0 or elapsed_ticks>1000000 or rate<1 or rate>1000:
        return ERR_INVALID_PARAMETER
    var bucket: Array=_samples[tiles]
    bucket.append(float(elapsed_ticks)/float(rate))
    if bucket.size()>CAP:
        bucket.pop_front()
    return OK

func recommend(tiles: int,rate: int,fallback: float) -> Dictionary:
    if not _samples.has(tiles) or rate<1 or rate>1000 or not is_finite(fallback) or fallback<MIN_SECONDS or fallback>MAX_SECONDS:
        return {"error":ERR_INVALID_PARAMETER}
    var bucket: Array=_samples[tiles].duplicate()
    if bucket.size()<MIN_SAMPLES:
        return {"error":OK,"horizon":fallback,"samples":bucket.size(),"qualified":false,"uncovered_seconds":0.0}
    bucket.sort()
    var q: float=bucket[ceili(0.9*bucket.size())-1]
    var requested: float=ceilf(q*rate+2.0)/float(rate)
    var horizon: float=clampf(requested,MIN_SECONDS,MAX_SECONDS)
    return {"error":OK,"horizon":horizon,"samples":bucket.size(),"qualified":true,"q90_seconds":q,"uncovered_seconds":maxf(0.0,requested-horizon)}
