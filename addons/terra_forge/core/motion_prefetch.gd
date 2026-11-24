@tool
extends RefCounted
## Bounded local-space player motion corridor; no IO, scene or clock access.
## Intent can prime a cold destination even while actual velocity is zero.
## Actual velocity is smoothed, but never predicts behind current intent.
const FOOT=preload("res://addons/terra_forge/core/collision_footprint.gd")
const MAX_AHEAD: int=2
const LOOKAHEAD_SECONDS: float=0.5
const ALPHA: float=0.25
const DEAD_ZONE: float=0.01

static func predict(point: Vector2,actual: Vector2,intent: Vector2,previous: Vector2,radius: float,extent: Vector2,tile_size: float,support: Array[Vector2i]) -> Dictionary:
    if not point.is_finite() or not actual.is_finite() or not intent.is_finite() or not previous.is_finite() or not is_finite(tile_size) or tile_size<=0.0:
        return {"error":ERR_INVALID_PARAMETER}
    var current: Dictionary=FOOT.plan(point,point,radius,extent,tile_size)
    if not current["ready"] or current["tiles"]!=support:
        return {"error":ERR_INVALID_PARAMETER}
    var result: Array[Vector2i]=[]
    if intent.length_squared()<=DEAD_ZONE*DEAD_ZONE:
        return {"error":OK,"keys":result,"velocity":Vector2.ZERO}
    var direction: Vector2=intent.normalized()
    var max_speed: float=tile_size/LOOKAHEAD_SECONDS
    var sample: Vector2=actual.limit_length(max_speed)
    var smooth: Vector2=previous.limit_length(max_speed).lerp(sample,ALPHA)
    if smooth.dot(direction)<0.0:
        smooth=Vector2.ZERO
    # Intent is a bounded hint, not an authority to move. Use actual EWMA
    # only along requested direction; no lateral extrapolation.
    var speed: float=minf(max_speed,maxf(intent.length(),smooth.dot(direction)))
    var distance: float=minf(tile_size*0.5,speed*LOOKAHEAD_SECONDS)
    var corridor: Dictionary=FOOT.plan(point,point+direction*distance,radius,extent,tile_size)
    if not corridor["ready"]:
        return {"error":OK,"keys":result,"velocity":smooth}
    var candidates: Array[Vector2i]=corridor["tiles"]
    candidates.sort_custom(func(a: Vector2i,b: Vector2i)->bool:
        var da: float=((Vector2(a)+Vector2(0.5,0.5))*tile_size).distance_squared_to(point)
        var db: float=((Vector2(b)+Vector2(0.5,0.5))*tile_size).distance_squared_to(point)
        return (a.y<b.y if a.y!=b.y else a.x<b.x) if da==db else da<db
    )
    for key in candidates:
        if not support.has(key):
            result.append(key)
            if result.size()>=MAX_AHEAD:
                break
    return {"error":OK,"keys":result,"velocity":smooth}
