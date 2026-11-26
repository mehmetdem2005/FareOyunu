extends Node
## Bridge SceneTree test entry/exit without terminating the app.
var exit_code: int = -999
var root: Window:
    get:
        return get_tree().root
var physics_frame: Signal:
    get:
        return get_tree().physics_frame
var process_frame: Signal:
    get:
        return get_tree().process_frame
func get_root() -> Window:
    return get_tree().root
func get_frame() -> int:
    return get_tree().get_frame()
func create_timer(seconds: float, process_always: bool = true, process_in_physics: bool = false, ignore_time_scale: bool = false) -> SceneTreeTimer:
    return get_tree().create_timer(seconds, process_always, process_in_physics, ignore_time_scale)
func quit(code: int = 0) -> void:
    if exit_code == -999:
        exit_code = code
