extends RefCounted
# Bounded in-memory recording. No filesystem, JSON encoding, flush, or worker during normal play.
const MAX_FRAMES := 1000000
const MAX_SECONDS := 18000
const MAX_EVENTS := 2048
const MAX_STALLS := 512
const STALL_US := 50000
var active := false
var start_us := 0
var unix_start := 0.0
var last_second := 0
var total_us := 0
var raw := PackedInt32Array()
var seconds: Array[Dictionary] = []
var events: Array[Dictionary] = []
var bucket := PackedInt32Array()
var bucket_physics_us := 0
var world: Dictionary = {}
var startup_ms := 0.0
var last_ground_error_m := -1.0
var session_name := ""
var stalls: Array[Dictionary] = []
var dropped_seconds := 0
var dropped_events := 0
var dropped_stalls := 0
var total_frames := 0
var excluded_export_frames := 0
var excluded_export_us := 0
var _window_excluded_export_frames := 0
var last_summary: Dictionary = {}
var bucket_max_physics_us := 0
var bucket_max_previous_process_us := 0
var session_metadata: Dictionary = {}
var skip_next := false
var dropped_frames := 0

func begin(info: Dictionary, load_ms: float) -> void:
	world = info.duplicate(true)
	startup_ms = load_ms
	start_us = Time.get_ticks_usec()
	unix_start = Time.get_unix_time_from_system()
	last_second = start_us
	active = true
	session_name = "TerraForge_%d_%d" % [int(Time.get_unix_time_from_system()),start_us]
	session_metadata = metadata()

func metadata() -> Dictionary:
	return {"godot":Engine.get_version_info(),"platform":OS.get_name(),"device":OS.get_model_name(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"fps_cap":Engine.max_fps,"physics_ticks_per_second":Engine.physics_ticks_per_second,"screen":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"unix_start":unix_start,"notes":"Frame intervals include rendering, scheduling and caps, not GPU-only time. Physics script time excludes engine solver. RSS sampled only on manual export, not VRAM. Script times are CPU wall times, not GPU timestamps. Stalls are correlations, not proven causes."}

func event(name: String, value: Variant) -> void:
	if not active:
		return
	if events.size() >= MAX_EVENTS:
		dropped_events += 1
		return
	events.append({"type":"event","t_ms":float(Time.get_ticks_usec()-start_us)/1000.0,"name":name,"value":value})

## Snapshots only during startup and explicit export. Unknown is -1, never zero.
static func memory_snapshot() -> Dictionary:
	var os_info := OS.get_memory_info()
	var texture_bytes := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))
	var buffer_bytes := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED))
	var video_bytes := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED))
	return {
		"system_physical_bytes":int(os_info.get("physical",-1)),
		"system_free_bytes":int(os_info.get("free",-1)),
		"system_available_bytes":int(os_info.get("available",-1)),
		"engine_static_bytes":OS.get_static_memory_usage(),
		"renderer_texture_bytes":texture_bytes if texture_bytes>0 else -1,
		"renderer_buffer_bytes":buffer_bytes if buffer_bytes>0 else -1,
		"renderer_video_bytes":video_bytes if video_bytes>0 else -1,
		"notes":"System-wide memory is not Android process budget. Renderer counters are engine accounting, not verified physical VRAM. Zero or unsupported renderer counters reported unknown."
	}

func rss_bytes() -> int:
	var f := FileAccess.open("/proc/self/status",FileAccess.READ)
	if f == null:
		return -1
	for i in range(128):
		var line := f.get_line()
		if line.begins_with("VmRSS:"):
			return line.trim_prefix("VmRSS:").strip_edges().get_slice(" ",0).to_int()*1024
		if f.eof_reached():
			break
	return -1

func frame(interval: int, pos: Vector3, phys: int, distance: float, falls: int, checks: int, misses: int, speed: float, grounded_ready: bool, menu: bool, viewport_size: Vector2, previous_process_us: int = 0, max_physics_tick_us: int = 0, physics_ticks: int = 0) -> void:
	if not active:
		return
	if skip_next:
		skip_next = false
		excluded_export_frames += 1
		_window_excluded_export_frames += 1
		excluded_export_us += interval
		return
	total_frames += 1
	if raw.size()<MAX_FRAMES:
		raw.append(interval)
	else:
		dropped_frames += 1
	total_us += interval
	bucket.append(interval)
	bucket_physics_us += phys
	bucket_max_physics_us = maxi(bucket_max_physics_us,max_physics_tick_us)
	bucket_max_previous_process_us = maxi(bucket_max_previous_process_us,previous_process_us)
	var now := Time.get_ticks_usec()
	if interval >= STALL_US:
		if stalls.size() < MAX_STALLS:
			stalls.append({"t_ms":float(now-start_us)/1000.0,"interval_us":interval,"pos":[pos.x,pos.y,pos.z],"physics_script_total_us":phys,"physics_script_max_tick_us":max_physics_tick_us,"physics_ticks":physics_ticks,"previous_process_script_us":previous_process_us,"ground_ready":grounded_ready,"menu_open":menu,"distance_m":distance,"fps_cap":Engine.max_fps,"ground_misses":misses})
		else:
			dropped_stalls += 1
	if now-last_second<1000000:
		return
	var summary := summarize(bucket)
	summary.merge({"type":"second","window_begin_us":last_second,"window_end_us":now,"window_excluded_export_frames":_window_excluded_export_frames,"t_ms":float(now-start_us)/1000.0,"pos":[pos.x,pos.y,pos.z],"distance_m":distance,"respawn_falls":falls,"ground_checks":checks,"ground_misses":misses,"ground_error_last_m":last_ground_error_m,"physics_script_us":bucket_physics_us,"speed_mps":speed,"ground_ready":grounded_ready,"menu_open":menu,"fps_cap":Engine.max_fps,"viewport":[int(viewport_size.x),int(viewport_size.y)],"rss_bytes":-1,"max_physics_tick_us":bucket_max_physics_us,"max_previous_process_script_us":bucket_max_previous_process_us,"static_bytes":OS.get_static_memory_usage(),"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),"primitives":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),"physics_process_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0})
	last_summary = summary
	if seconds.size() < MAX_SECONDS:
		seconds.append(summary)
	else:
		dropped_seconds += 1
	bucket.clear()
	bucket_physics_us = 0
	bucket_max_physics_us = 0
	bucket_max_previous_process_us = 0
	_window_excluded_export_frames = 0
	last_second = now

func summarize(values: PackedInt32Array) -> Dictionary:
	if values.is_empty():
		return {"frames":0}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0
	var over33 := 0
	var over50 := 0
	var over100 := 0
	var streak := 0
	var worst_streak := 0
	for us in values:
		sum += us
		if us>33333:
			over33 += 1
			streak += us
			worst_streak = maxi(worst_streak,streak)
		else:
			streak = 0
		if us>50000: over50 += 1
		if us>100000: over100 += 1
	var n := sorted.size()
	var tail_count := maxi(1,ceili(float(n)*0.01))
	var tail_sum := 0
	for i in range(n-tail_count,n):
		tail_sum += sorted[i]
	return {"frames":n,"fps":1000000.0*n/maxi(sum,1),"mean_ms":float(sum)/n/1000.0,"p50_ms":sorted[ceili(n*0.5)-1]/1000.0,"p95_ms":sorted[ceili(n*0.95)-1]/1000.0,"p99_ms":sorted[ceili(n*0.99)-1]/1000.0,"p999_ms":sorted[ceili(n*0.999)-1]/1000.0,"max_ms":sorted[-1]/1000.0,"one_percent_low_fps":1000000.0*tail_count/maxi(tail_sum,1),"over_33ms":over33,"over_50ms":over50,"over_100ms":over100,"worst_slow_streak_ms":worst_streak/1000.0}

func save() -> String:
	event("manual_export_begin",raw.size())
	var report := {"schema":3,"world":world,"metadata":session_metadata,"startup_ms":startup_ms,"elapsed_ms":float(Time.get_ticks_usec()-start_us)/1000.0,"recorded_interval_ms":total_us/1000.0,"total_frames":total_frames,"raw_frames_dropped_from_memory":dropped_frames,"seconds_dropped":dropped_seconds,"events_dropped":dropped_events,"stalls_dropped":dropped_stalls,"excluded_export_frames":excluded_export_frames,"excluded_export_us":excluded_export_us,"summary_scope":"retained raw frames only","summary":summarize(raw),"per_second":seconds,"partial_second":summarize(bucket),"events":events,"stalls":stalls,"frame_intervals_us":Array(raw),"rss_bytes_at_export":rss_bytes(),"memory_at_export":memory_snapshot(),"recovery_jsonl":null,"recording_mode":"bounded_memory_manual_export"}
	var path := "user://"+session_name+".json"
	var output := FileAccess.open(path,FileAccess.WRITE)
	if output == null:
		return ""
	output.store_string(JSON.stringify(report))
	output.close()
	event("manual_export_end",raw.size())
	return path
