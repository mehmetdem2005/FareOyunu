extends RefCounted

const HISTOGRAM = preload("res://addons/terra_forge/core/profile_histogram.gd")
const SLOW_US := 33333
const WORST_LIMIT := 8

var _pump = HISTOGRAM.new()
var _controller = HISTOGRAM.new()
var _render_cpu = HISTOGRAM.new()
var _render_gpu = HISTOGRAM.new()
var _slow_count := 0
var _worst: Array[Dictionary] = []
var _next_render_sample := 0
var _max_draw_calls := 0
var _max_primitives := 0

func frame(elapsed_us: int, pump_us: int, controller_us: int, ticks: int, pending: int) -> void:
    _pump.add(pump_us / 1000.0)
    _controller.add(controller_us / 1000.0)
    if elapsed_us <= SLOW_US:
        return
    _slow_count += 1
    if _worst.size() == WORST_LIMIT and elapsed_us <= int(_worst.back()["frame_us"]):
        return
    _worst.append({"frame_us": elapsed_us, "pump_us": pump_us, "controller_us": controller_us,
        "physics_ticks": ticks, "pending_tiles": pending})
    _worst.sort_custom(func(a: Dictionary, b: Dictionary): return a["frame_us"] > b["frame_us"])
    if _worst.size() > WORST_LIMIT:
        _worst.pop_back()

func sample_renderer(viewport: RID, now: int) -> void:
    if now < _next_render_sample:
        return
    _next_render_sample = now + 250000
    _max_draw_calls = maxi(_max_draw_calls, RenderingServer.viewport_get_render_info(viewport,
        RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
    _max_primitives = maxi(_max_primitives, RenderingServer.viewport_get_render_info(viewport,
        RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
    var cpu := RenderingServer.viewport_get_measured_render_time_cpu(viewport)
    var gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport)
    if cpu > 0.0 and is_finite(cpu):
        _render_cpu.add(cpu)
    if gpu > 0.0 and is_finite(gpu):
        _render_gpu.add(gpu)

func report() -> Dictionary:
    var cpu: Dictionary = _render_cpu.report()
    var gpu: Dictionary = _render_gpu.report()
    return {"stream_pump_ms": _pump.report(), "player_controller_ms_per_frame": _controller.report(),
        "render_cpu_ms_sampled": cpu if cpu["count"] else null,
        "render_gpu_ms_sampled": gpu if gpu["count"] else null,
        "draw_calls_peak_sampled": _max_draw_calls if _next_render_sample else null,
        "primitives_peak_sampled": _max_primitives if _next_render_sample else null,
        "frames_over_33_333_ms": _slow_count, "slowest_frames": _worst.duplicate(true)}
