extends RefCounted
## Same camera, same 36 m out-and-back path for every arm. The first lap warms
## terrain and pipelines. Each measured arm has a settling interval and idle control.
const SCALES := ["native", "native", "540p", "540p", "native"]
const LEG_METERS := 36.0

var arm := 0
var phase := "settle"
var origin: Vector2
var finish: Vector2
var returning := false
var lap_done := false
var idle: Dictionary
var runs: Array[Dictionary] = []

func _init(start: Vector2, extent: Vector2) -> void:
    origin = start
    var direction := 1.0 if start.x < extent.x * 0.5 else -1.0
    finish = start + Vector2(direction * LEG_METERS, 0.0)

func direction(point: Vector2, max_step: float) -> Vector2:
    if phase != "walk" or lap_done:
        return Vector2.ZERO
    var offset := (origin if returning else finish) - point
    if offset.length() <= 0.08:
        if returning:
            lap_done = true
            return Vector2.ZERO
        returning = true
        offset = origin - point
    return offset.limit_length(max_step) / max_step

func next_arm() -> void:
    arm += 1
    phase = "settle"
    lap_done = false
    returning = false

func label() -> String:
    if arm == 0:
        return "Rota ısınıyor…"
    return "%d/4 · %s · %s" % [arm, "Doğal" if SCALES[arm] == "native" else "540p",
        "Yürüyüş" if phase == "walk" else "Sabit kamera"]
