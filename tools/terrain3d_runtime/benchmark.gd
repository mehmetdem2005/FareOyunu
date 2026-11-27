extends Node3D
const Runtime = preload("res://terrain_runtime.gd")
const SIZE := 512
const SPACING := 0.25
const WARM_US := 4000000
const RUN_US := 12000000
var mode := "moving"
var route_started := false
var backend: Runtime
var camera: Camera3D
var target: Node3D
var frames := PackedFloat64Array()
var physics_frames := 0
var missing_rays := 0
var max_ray_error := 0.0
var started := 0
var previous := 0
var first := 0
var last_rss_at := 0
var rss_peak := -1
var static_peak := 0
var draw_peak := 0
var primitives_peak := 0
var import_ms := 0.0
var active := false
var finished := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
	if mode not in ["empty", "static", "moving", "moving_no_collision", "camera_only", "collision_only"]:
		_fail("invalid mode")
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.far = 400.0
	target = Node3D.new()
	add_child(target)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.shadow_enabled = false
	add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.1, 0.17, 0.24)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.7
	add_child(world)
	_move(0.0)
	if mode != "empty":
		var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
		for z in range(SIZE):
			for x in range(SIZE):
				image.set_pixel(x, z, Color(_height(x, z), 0, 0, 1))
		backend = Runtime.new()
		add_child(backend)
		var begin := Time.get_ticks_usec()
		if backend.initialize(camera, target, SPACING) != OK:
			_fail("native initialization")
			return
		if mode == "moving_no_collision":
			backend.terrain.set("collision_mode", 0)
		if backend.import_height_snapshot(image) != OK:
			_fail("height import")
			return
		import_ms = (Time.get_ticks_usec() - begin) / 1000.0
		for xy in [Vector2i(40,40), Vector2i(255,255), Vector2i(256,256), Vector2i(400,400)]:
			var h: float = backend.surface_height(Vector3(xy.x * SPACING, 0, xy.y * SPACING))
			if not is_finite(h) or absf(h - _height(xy.x,xy.y)) > 0.001:
				_fail("height parity")
				return
	started = Time.get_ticks_usec()
	active = true

func _height(x: int, z: int) -> float:
	return 2.0 + 0.8 * sin(float(x) * 0.045) + 0.4 * cos(float(z) * 0.07)

func _move(t: float) -> void:
	var x := lerpf(20.0, 108.0, t)
	var z := 64.0 + 24.0 * sin(t * TAU)
	var focus := Vector3(x, 3, z)
	if not route_started or mode != "camera_only":
		target.position = focus
	if not route_started or mode != "collision_only":
		camera.position = focus + Vector3(0, 13, 15)
		camera.look_at(focus, Vector3.UP)

func _process(_delta: float) -> void:
	if not active or finished:
		return
	var now := Time.get_ticks_usec()
	var age := now - started
	if age < WARM_US:
		return
	if first == 0:
		first = now
		route_started = true
		previous = now
		_sample_memory()
		return
	frames.append((now - previous) / 1000.0)
	previous = now
	if mode != "static":
		_move(clampf(float(age - WARM_US) / RUN_US, 0.0, 1.0))
	if now - last_rss_at >= 500000:
		_sample_memory()
	if age >= WARM_US + RUN_US:
		finished = true
		call_deferred("_finish")

func _physics_process(_delta: float) -> void:
	if not active or finished or first == 0 or mode not in ["static","moving","camera_only","collision_only"]:
		return
	physics_frames += 1
	var p := target.global_position
	var expected := backend.surface_height(p)
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,20,p.z),Vector3(p.x,-20,p.z),1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not is_finite(expected):
		missing_rays += 1
		return
	max_ray_error = maxf(max_ray_error,absf(float(hit.position.y)-expected))

func _sample_memory() -> void:
	last_rss_at = Time.get_ticks_usec()
	static_peak = maxi(static_peak,OS.get_static_memory_usage())
	draw_peak = maxi(draw_peak,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	primitives_peak = maxi(primitives_peak,int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	if FileAccess.file_exists("/proc/self/status"):
		var file := FileAccess.open("/proc/self/status",FileAccess.READ)
		if file != null:
			for i in range(128):
				var line := file.get_line()
				if line.begins_with("VmRSS:"):
					var kb := line.trim_prefix("VmRSS:").strip_edges().get_slice(" ",0).to_int()
					if kb > 0:
						rss_peak = maxi(rss_peak,kb * 1024)
					break
				if file.eof_reached():
					break

func _percentile(sorted: PackedFloat64Array, p: float) -> float:
	return sorted[clampi(ceili(p * sorted.size())-1,0,sorted.size()-1)]

func _finish() -> void:
	if frames.size() < 10:
		_fail("insufficient frames")
		return
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	var slow33 := 0
	var slow50 := 0
	var slow100 := 0
	var worst_streak := 0.0
	var streak := 0.0
	for ms in frames:
		total += ms
		if ms > 33.333:
			slow33 += 1
			streak += ms
			worst_streak = maxf(worst_streak,streak)
		else:
			streak = 0.0
		if ms > 50.0:
			slow50 += 1
		if ms > 100.0:
			slow100 += 1
	var tail_count := maxi(1,ceili(sorted.size()*0.01))
	var tail_sum := 0.0
	for i in range(sorted.size()-tail_count,sorted.size()):
		tail_sum += sorted[i]
	var dims := get_viewport().get_visible_rect().size
	var row := {"mode":mode,"software_driver_threads":OS.get_environment("LP_NUM_THREADS"),"renderer":RenderingServer.get_current_rendering_method(),"device":OS.get_model_name(),"adapter":RenderingServer.get_video_adapter_name(),"viewport":[int(dims.x),int(dims.y)],"frames":frames.size(),"duration_ms":total,"fps":1000.0*frames.size()/total,"mean_ms":total/frames.size(),"p50_ms":_percentile(sorted,0.5),"p95_ms":_percentile(sorted,0.95),"p99_ms":_percentile(sorted,0.99),"max_ms":sorted[-1],"one_percent_low_fps":1000.0*tail_count/tail_sum,"over_33ms":slow33,"over_50ms":slow50,"over_100ms":slow100,"worst_slow_streak_ms":worst_streak,"sampled_rss_peak_bytes":rss_peak,"sampled_static_peak_bytes":static_peak,"sampled_draw_calls_peak":draw_peak,"sampled_primitives_peak":primitives_peak,"import_ms":import_ms,"physics_samples":physics_frames,"missing_rays":missing_rays,"max_ray_error_m":max_ray_error,"region_count":0 if mode=="empty" else 4}
	var file := FileAccess.open("user://terrain3d-bench-%s.json" % mode,FileAccess.WRITE)
	if file == null:
		_fail("cannot save results")
		return
	file.store_string(JSON.stringify({"summary":row,"frame_intervals_ms":Array(frames)}))
	file.close()
	print("TERRAIN3D_BENCH ",JSON.stringify(row))
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("BENCH_FAIL "+reason)
	get_tree().quit(1)
