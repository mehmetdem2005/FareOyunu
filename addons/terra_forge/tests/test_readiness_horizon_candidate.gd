extends SceneTree
const Q=preload("res://addons/terra_forge/core/readiness_horizon_candidate.gd")
const OLD=preload("res://addons/terra_forge/core/motion_latency_window.gd")
const MOTION=preload("res://addons/terra_forge/core/motion_prefetch.gd")
const FOOT=preload("res://addons/terra_forge/core/collision_footprint.gd")
# Recorded F4 CI45707686900; inclusive elapsed simulation ticks, not wall time.
# 60 Hz is the replay assumption, not an Android measurement.
const SAMPLES=[[1,20],[4,28],[1,12],[4,28],[1,12],[4,22],[1,12],[4,22],[1,17],[4,28],[1,12],[4,28],[1,12],[4,22],[1,12],[4,22]]

func _initialize() -> void:
    var q=Q.new()
    var old=OLD.new()
    var misses: Array[int]=[0,0]
    var insufficient: int=0
    var qualified: int=0
    var saturated: int=0
    var old_sum: float=0.0
    var new_sum: float=0.0
    var compared: int=0
    for row in SAMPLES:
        var tiles: int=row[0]
        var ready_ticks: int=row[1]
        var horizon: float=old.horizon
        var rec: Dictionary=q.recommend(tiles,60,horizon)
        if rec["error"]!=OK:
            _fail("replay recommendation")
            return
        if rec["qualified"]:
            qualified+=1
            old_sum+=horizon
            new_sum+=rec["horizon"]
            compared+=1
            misses[0]+=int(horizon*60.0+0.00001<ready_ticks)
            misses[1]+=int(rec["horizon"]*60.0+0.00001<ready_ticks)
        else:
            insufficient+=1
            if rec["horizon"]!=horizon:
                _fail("cold fallback")
                return
        # Observe AFTER the prediction; never train on current target.
        if q.observe(tiles,ready_ticks,60)!=OK or old.observe(ready_ticks-1,60)!=OK:
            _fail("observation")
            return
    for i in range(64):
        if q.observe(4,120,60)!=OK:
            _fail("bounded history")
            return
    var limit: Dictionary=q.recommend(4,60,0.25)
    if limit["samples"]!=16 or limit["horizon"]!=0.5 or limit["uncovered_seconds"]<=0.0:
        _fail("saturation must be visible")
        return
    saturated+=1
    if q.observe(3,1,60)==OK or q.observe(1,-1,60)==OK or q.recommend(1,0,0.25)["error"]==OK:
        _fail("invalid inputs")
        return
    var point=Vector2(47.0,48.0)
    var plan: Dictionary=FOOT.plan(point,point,0.25,Vector2(128,128),32.0)
    var support: Array[Vector2i]=plan["tiles"]
    var cases: int=0
    for speed in [0.0,24.0,120.0]:
        for intent in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
            for h in [0.125,0.25,0.5]:
                var result: Dictionary=MOTION.predict(point,Vector2(-24,0),intent*speed,Vector2(-24,0),0.25,Vector2(128,128),32.0,support,h)
                if result["error"]!=OK or result["keys"].size()>2 or (speed==0.0 and not result["keys"].is_empty()):
                    _fail("corridor bound")
                    return
                for key in result["keys"]:
                    if support.has(key):
                        _fail("duplicate held tile")
                        return
                cases+=1
    print("F2_HORIZON_SHADOW ",JSON.stringify({"replay_samples":SAMPLES.size(),"qualified_predictions":qualified,"cold_fallback":insufficient,"old_short_predictions":misses[0],"new_short_predictions":misses[1],"old_mean_horizon_seconds":old_sum/maxi(1,compared),"new_mean_horizon_seconds":new_sum/maxi(1,compared),"saturation_checks":saturated,"corridor_cases":cases,"note":"Replay with identical observed ticks; no closed-loop gain or actual device claim"}))
    print("PASS: F2 bounded readiness quantile shadow, no lookahead leakage, cold fallback, saturation and corridor caps")
    quit(0)

func _fail(msg: String) -> void:
    push_error("F2 horizon shadow: "+msg)
    quit(1)
