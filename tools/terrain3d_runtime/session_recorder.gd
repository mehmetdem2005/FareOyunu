extends RefCounted
# Lightweight frame logging: packed integer intervals, one summary per second.
# No sorting or disk writes each frame. Manual exports may stall; explicitly excluded.
const MAX_FRAMES := 1000000
var active := false
var start_us := 0
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
var file: FileAccess
var last_flush := 0
var skip_next := false
var dropped_frames := 0

func begin(info: Dictionary, load_ms: float) -> void:
	world = info.duplicate(true)
	startup_ms = load_ms
	start_us = Time.get_ticks_usec()
	last_second = start_us
	last_flush = start_us
	active = true
	session_name = "TerraForge_%d_%d" % [int(Time.get_unix_time_from_system()),start_us]
	file = FileAccess.open("user://"+session_name+".jsonl",FileAccess.WRITE)
	write_line({"type":"header","schema":2,"world":world,"startup_ms":startup_ms,"metadata":metadata()})

func metadata() -> Dictionary:
	return {"godot":Engine.get_version_info(),"platform":OS.get_name(),"device":OS.get_model_name(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"fps_cap":Engine.max_fps,"physics_ticks_per_second":Engine.physics_ticks_per_second,"screen":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"unix_start":Time.get_unix_time_from_system(),"notes":"Frame intervals include rendering, scheduling and caps, not GPU-only time. Physics script time excludes engine solver. RSS is sampled, not VRAM."}

func write_line(data: Dictionary) -> void:
	if file != null:
		file.store_line(JSON.stringify(data))

func event(name: String, value: Variant) -> void:
	if not active:
		return
	var e := {"type":"event","t_ms":float(Time.get_ticks_usec()-start_us)/1000.0,"name":name,"value":value}
	events.append(e)
	write_line(e)

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

func frame(interval: int, pos: Vector3, phys: int, distance: float, falls: int, checks: int, misses: int, speed: float, grounded_ready: bool, menu: bool) -> void:
	if not active:
		return
	if skip_next:
		skip_next = false
		return
	if raw.size()<MAX_FRAMES:
		raw.append(interval)
	else:
		dropped_frames += 1
	total_us += interval
	bucket.append(interval)
	bucket_physics_us += phys
	var now := Time.get_ticks_usec()
	if now-last_second<1000000:
		return
	var summary := summarize(bucket)
	summary.merge({"type":"second","t_ms":float(now-start_us)/1000.0,"pos":[pos.x,pos.y,pos.z],"distance_m":distance,"respawn_falls":falls,"ground_checks":checks,"ground_misses":misses,"ground_error_last_m":last_ground_error_m,"physics_script_us":bucket_physics_us,"speed_mps":speed,"ground_ready":grounded_ready,"menu_open":menu,"fps_cap":Engine.max_fps,"viewport":[int(Engine.get_main_loop().root.get_visible_rect().size.x),int(Engine.get_main_loop().root.get_visible_rect().size.y)],"rss_bytes":rss_bytes(),"static_bytes":OS.get_static_memory_usage(),"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),"primitives":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),"physics_process_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0})
	seconds.append(summary)
	var line := summary.duplicate()
	line["frame_us"] = Array(bucket)
	write_line(line)
	bucket.clear()
	bucket_physics_us = 0
	last_second = now
	if file != null and now-last_flush>=10000000:
		file.flush()
		last_flush = now

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
	return {"frames":n,"fps":1000000.0*n/maxi(sum,1),"mean_ms":float(sum)/n/1000.0,"p50_ms":sorted[ceili(n*0.5)-1]/1000.0,"p95_ms":sorted[ceili(n*0.95)-1]/1000.0,"p99_ms":sorted[ceili(n*0.99)-1]/1000.0,"max_ms":sorted[-1]/1000.0,"one_percent_low_fps":1000000.0*tail_count/maxi(tail_sum,1),"over_33ms":over33,"over_50ms":over50,"over_100ms":over100,"worst_slow_streak_ms":worst_streak/1000.0}

func save() -> String:
	event("manual_export_begin",raw.size())
	var report := {"schema":2,"world":world,"metadata":metadata(),"startup_ms":startup_ms,"elapsed_ms":float(Time.get_ticks_usec()-start_us)/1000.0,"recorded_interval_ms":total_us/1000.0,"raw_frames_dropped_from_memory":dropped_frames,"summary":summarize(raw),"per_second":seconds,"events":events,"frame_intervals_us":Array(raw),"recovery_jsonl":session_name+".jsonl"}
	var path := "user://"+session_name+".json"
	var output := FileAccess.open(path,FileAccess.WRITE)
	if output == null:
		return ""
	output.store_string(JSON.stringify(report))
	output.close()
	if file != null:
		file.flush()
	skip_next = true
	event("manual_export_end",raw.size())
	return path
