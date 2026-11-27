extends Node3D
const Runtime = preload("res://terrain_runtime.gd")
const Recorder = preload("res://session_recorder.gd")
const PreviewRange = preload("res://preview_range.gd")
var preview_range := PreviewRange.new()
var range_label: Label
var far_material_skip := false
const PREVIEW_RENDER_SCALES := [1.0,0.90,0.85]
var render_scale_options: OptionButton
var recorder := Recorder.new()
var report_path := ""
var load_begin := 0
var first_ground_ms := -1.0
var physics_us := 0
var max_physics_tick_us := 0
var physics_ticks := 0
var previous_process_us := 0
var ground_misses := 0
var ground_checks := 0
var last_probe := 0
var traveled := 0.0
var previous_position := Vector3.ZERO
var has_previous_position := false
var world_info: Dictionary = {}
var backend: Runtime
var player: CharacterBody3D
var camera: Camera3D
var status: Label
var source_label: Label
var menu: PanelContainer
var extent := Vector2.ZERO
var spawn := Vector3.ZERO
var yaw := 0.0
var pitch := -0.20
var speed := 2.5
const GROUND_GATE_TIMEOUT_US := 3000000
const GROUND_GATE_TOLERANCE_M := 0.10
const SPAWN_CLEARANCE_M := 0.20
var ready_to_walk := false
var ground_gate_begin_us := 0
var ground_gate_attempts := 0
var ground_gate_failed := false
var loading := false
var stick := Vector2.ZERO
var stick_id := -1
var look_id := -1
var stick_origin := Vector2.ZERO
var overlay: StickOverlay
var last_frame := 0
var last_hud := 0
var gaps := 0
var _camera_pose_valid := false
var _camera_last_player := Vector3.ZERO
var _camera_last_yaw := 0.0
var _camera_last_pitch := 0.0

class StickOverlay extends Control:
	var center := Vector2.ZERO
	var offset := Vector2.ZERO
	var engaged := false
	func _draw() -> void:
		var c := center if engaged else Vector2(90,size.y-100)
		draw_circle(c,54,Color(0.12,0.16,0.18,0.42))
		draw_arc(c,54,0,TAU,48,Color(1,1,1,0.5),2.0,true)
		draw_circle(c+offset*44.0,21,Color(0.85,0.9,0.95,0.7))

func _ready() -> void:
	Engine.max_fps = 60
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = 1.0
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-35,0)
	light.shadow_enabled = false
	add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.32,0.47,0.60)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.7
	add_child(world)
	player = CharacterBody3D.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_snap_length = 0.08
	player.floor_max_angle = deg_to_rad(55)
	add_child(player)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.055
	capsule.height = 0.20
	shape.shape = capsule
	player.add_child(shape)
	camera = Camera3D.new()
	camera.far = 850
	camera.near = 0.025
	preview_range.configure(camera.far)
	add_child(camera)
	camera.current = true
	make_ui()
	menu.hide()
	load_begin = Time.get_ticks_usec()
	request_load()

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay = StickOverlay.new()
	ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := VBoxContainer.new()
	ui.add_child(top)
	top.position = Vector2(12,8)
	status = Label.new()
	status.add_theme_font_size_override("font_size",18)
	status.add_theme_color_override("font_shadow_color",Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x",2)
	status.add_theme_constant_override("shadow_offset_y",2)
	top.add_child(status)
	source_label = Label.new()
	top.add_child(source_label)
	var bar := HBoxContainer.new()
	top.add_child(bar)
	var open := Button.new()
	open.text = "Ayarlar"
	open.pressed.connect(func(): menu.visible = not menu.visible; reset_touch())
	bar.add_child(open)
	var reset := Button.new()
	reset.text = "Başa dön"
	reset.pressed.connect(respawn)
	bar.add_child(reset)
	var report := Button.new()
	report.text = "Rapor kaydet"
	report.pressed.connect(save_report)
	bar.add_child(report)
	menu = PanelContainer.new()
	ui.add_child(menu)
	menu.position = Vector2(12,104)
	menu.custom_minimum_size = Vector2(440,0)
	var box := VBoxContainer.new()
	menu.add_child(box)
	var hint := Label.new()
	hint.text = "1024 m × 1024 m | 64 native region | Float32"
	box.add_child(hint)
	var cap := CheckButton.new()
	cap.text = "60 FPS sınırı"
	cap.button_pressed = true
	cap.toggled.connect(func(on: bool): Engine.max_fps = 60 if on else 0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED); recorder.event("fps_cap",Engine.max_fps); recorder.event("vsync_mode",DisplayServer.window_get_vsync_mode()))
	box.add_child(cap)
	var speed_label := Label.new()
	speed_label.text = "Hareket hızı: 2.5 m/s"
	box.add_child(speed_label)
	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 12.0
	slider.step = 0.5
	slider.value = speed
	slider.value_changed.connect(func(v: float): speed = v; speed_label.text = "Hareket hızı: %.1f m/s" % v; recorder.event("speed_mps",v))
	box.add_child(slider)
	range_label = Label.new()
	range_label.text = "Önizleme görüşü: %.0f m" % camera.far
	box.add_child(range_label)
	var range_options := OptionButton.new()
	range_options.add_item("Referans (sabit)",0)
	range_options.add_item("Kısa görüş (isteğe bağlı)",1)
	range_options.add_item("Adaptif görüş (deneysel)",2)
	range_options.select(0)
	range_options.item_selected.connect(func(selected: int):
		preview_range.select_mode(selected)
		apply_preview_range("manual_selection")
	)
	box.add_child(range_options)
	var far_skip := CheckButton.new()
	far_skip.text = "Uzak doku tasarrufu (deneysel)"
	far_skip.toggled.connect(func(enabled: bool):
		far_material_skip = enabled
		if backend != null:
			backend.terrain.get("material").call("set_shader_param","far_exact_texture_skip",enabled)
		recorder.event("far_texture_skip",enabled)
	)
	box.add_child(far_skip)
	render_scale_options = OptionButton.new()
	render_scale_options.add_item("3B çözünürlük: %100",0)
	render_scale_options.add_item("3B çözünürlük: %90 (deneysel)",1)
	render_scale_options.add_item("3B çözünürlük: %85 (deneysel)",2)
	render_scale_options.select(0)
	render_scale_options.item_selected.connect(apply_preview_render_scale)
	box.add_child(render_scale_options)

## Preview-only user action, never part of an automatic quality loop.
## 2D interface stays native; near 3D image can soften, so default stays 1.0.
func apply_preview_render_scale(selected: int) -> void:
	if selected < 0 or selected >= PREVIEW_RENDER_SCALES.size():
		return
	if loading or backend == null or not menu.visible:
		var current := get_viewport().scaling_3d_scale
		for i in range(PREVIEW_RENDER_SCALES.size()):
			if is_equal_approx(current,PREVIEW_RENDER_SCALES[i]):
				render_scale_options.select(i)
				break
		return
	var viewport := get_viewport()
	var requested: float = PREVIEW_RENDER_SCALES[selected]
	var old_scale := viewport.scaling_3d_scale
	if is_equal_approx(old_scale,requested):
		return
	# Bilinear is available on the current GL Compatibility renderer.
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = requested
	recorder.event("preview_render_scale",{"reason":"manual_menu_selection","old_scale":old_scale,"requested_scale":requested,"property_scale":viewport.scaling_3d_scale,"viewport_size":[int(viewport.get_visible_rect().size.x),int(viewport.get_visible_rect().size.y)],"automatic":false,"notes":"Property value is not a measured framebuffer size; render target reallocation may stall."})
	# Restart an explicitly selected range trial at its reference so samples
	# collected under different pixel workloads are not compared.
	if preview_range.mode == 2:
		preview_range.select_mode(2)
		apply_preview_range("render_scale_changed_reset_trial")

func apply_preview_range(reason: String) -> void:
	var old_far := camera.far
	camera.far = preview_range.active_far_m
	range_label.text = "Önizleme görüşü: %.0f m" % camera.far
	recorder.event("preview_range",{"reason":reason,"mode":preview_range.mode,"old_far_m":old_far,"far_m":camera.far,"native_mesh_unchanged":true})

func request_load() -> void:
	loading = true
	source_label.text = "Dünya hazırlanıyor..."
	await get_tree().process_frame
	await get_tree().process_frame
	var manifest_start := Time.get_ticks_usec()
	var manifest := FileAccess.open("res://world/world.json",FileAccess.READ)
	if manifest == null:
		fail_load("Dünya manifesti eksik")
		return
	var parsed: Variant = JSON.parse_string(manifest.get_as_text())
	if not parsed is Dictionary:
		fail_load("Dünya manifesti geçersiz")
		return
	world_info = parsed
	var side := int(world_info.get("samples",0))
	var spacing := float(world_info.get("spacing_m",0))
	if side != 4096 or spacing != 0.25 or int(world_info.get("region_samples",0)) != 512:
		fail_load("Dünya boyutu veya verisi geçersiz")
		return
	if not world_info.has("native_regions"):
		fail_load("Hazır native bölgeler eksik; doğru paketi yükle")
		return
	extent = Vector2(side-1,side-1)*spacing
	var start: Variant = world_info.get("spawn_m")
	if not start is Array or start.size() != 2:
		fail_load("Başlangıç koordinatı geçersiz")
		return
	for axis: Variant in start:
		if not (axis is int or axis is float) or not is_finite(float(axis)):
			fail_load("Başlangıç koordinatı geçersiz")
			return
	var sx := float(start[0])
	var sz := float(start[1])
	if sx < 0.15 or sz < 0.15 or sx > extent.x-0.15 or sz > extent.y-0.15:
		fail_load("Başlangıç dünya sınırları dışında")
		return
	player.position = Vector3(sx,0,sz)
	update_camera()
	var manifest_us := Time.get_ticks_usec()-manifest_start
	var memory_before := Recorder.memory_snapshot()
	var next := Runtime.new()
	add_child(next)
	source_label.text = "Arazi dosyaları doğrulanıyor..."
	var result: Error = await next.prepare_baked_regions(world_info,512,spacing)
	if result == OK:
		source_label.text = "Native arazi hazırlanıyor..."
		result = next.initialize(camera,player,spacing,"world",512,true)
	if result == OK:
		result = next.load_baked_regions()
	if result != OK:
		next.free()
		fail_load("Terrain3D aktarımı başarısız: " + str(result))
		return
	var height: float = next.surface_height(player.position)
	if not is_finite(height):
		next.free()
		fail_load("Başlangıç yüksekliği okunamadı")
		return
	backend = next
	backend.terrain.get("material").call("set_shader_param","far_exact_texture_skip",far_material_skip)
	spawn = Vector3(player.position.x,height+SPAWN_CLEARANCE_M,player.position.z)
	respawn()
	loading = false
	gaps = 0
	last_frame = 0
	recorder.begin(world_info, float(Time.get_ticks_usec()-load_begin)/1000.0)
	recorder.event("fps_cap",Engine.max_fps)
	var phases := backend.startup_phases_us.duplicate()
	phases["manifest_and_spawn_setup"] = manifest_us
	# CPU wall-clock calls, not GPU completion timestamps. Recorded once, not per frame.
	recorder.event("startup_phases_us",phases)
	recorder.event("startup_io",backend.startup_io)
	recorder.event("far_texture_skip",far_material_skip)
	recorder.event("preview_render_scale",{"reason":"initial_reference","property_scale":get_viewport().scaling_3d_scale,"automatic":false})
	# Analytical clipmap tile coverage, not a visibility or GPU timing measurement.
	var lod_count := int(backend.terrain.get("mesh_lods"))
	var tile_size := int(backend.terrain.get("mesh_size"))
	var sample_spacing := float(backend.terrain.get("vertex_spacing"))
	var outer_spacing := sample_spacing*pow(2.0,lod_count-1)
	recorder.event("render_coverage",{"camera_far_m":camera.far,"mesh_lods":lod_count,"mesh_size":tile_size,"near_spacing_m":sample_spacing,"outer_spacing_m":outer_spacing,"nominal_outer_tile_half_width_m":(2*tile_size+2)*outer_spacing,"notes":"Square tile extent around snapped target; edge strips, geomorph, frustum and occlusion affect visible coverage. Camera range may change only by explicit preview mode."})
	recorder.event("memory_budget",{"policy":"resident_advisory_no_automatic_eviction","before_native_load":memory_before,"after_native_submit":Recorder.memory_snapshot(),"inventory":backend.memory_inventory(),"process_safe_budget_bytes":-1,"gpu_safe_budget_bytes":-1,"notes":"Device safe limits not established; no automatic quality changes. After-submit counters may lag renderer completion."})

func fail_load(message: String) -> void:
	source_label.text = message
	loading = false
	ready_to_walk = false

func reset_touch() -> void:
	stick = Vector2.ZERO
	stick_id = -1
	look_id = -1
	overlay.engaged = false
	overlay.offset = Vector2.ZERO
	overlay.queue_redraw()

func save_report() -> void:
	if not recorder.active:
		return
	reset_touch()
	report_path = recorder.save()
	# Exclude explicit user-requested export stalls even if file creation fails.
	recorder.skip_next = true
	if report_path.is_empty():
		source_label.text = "Rapor yazılamadı"
		return
	var report_dir := ProjectSettings.globalize_path("res://reports")
	var mkdir := DirAccess.make_dir_recursive_absolute(report_dir)
	var project_copy := report_dir.path_join(report_path.get_file())
	if mkdir == OK and DirAccess.copy_absolute(ProjectSettings.globalize_path(report_path),project_copy) == OK:
		source_label.text = "Rapor kaydedildi: reports/" + report_path.get_file()
	else:
		source_label.text = "Rapor: " + ProjectSettings.globalize_path(report_path)
	# No FileDialog / filesystem enumeration on Android.
	recorder.skip_next = true

func respawn() -> void:
	if backend == null:
		return
	player.position = spawn
	has_previous_position = false
	recorder.event("respawn", [spawn.x,spawn.y,spawn.z])
	player.velocity = Vector3.ZERO
	ready_to_walk = false
	ground_gate_failed = false
	ground_gate_begin_us = Time.get_ticks_usec()
	ground_gate_attempts = 0
	reset_touch()
	source_label.text = "Fiziksel zemin doğrulanıyor..."
	update_camera()

func _input(event: InputEvent) -> void:
	if menu == null or menu.visible or loading:
		return
	var size := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and event.position.y > size.y*0.28:
			if event.position.x < size.x*0.48 and stick_id == -1:
				stick_id = event.index
				stick_origin = event.position
				overlay.center = stick_origin
				overlay.engaged = true
			elif look_id == -1:
				look_id = event.index
		elif not event.pressed:
			if event.index == stick_id:
				stick_id = -1
				stick = Vector2.ZERO
				overlay.engaged = false
			if event.index == look_id:
				look_id = -1
	elif event is InputEventScreenDrag:
		if event.index == stick_id:
			stick = ((event.position-stick_origin)/54.0).limit_length()
		elif event.index == look_id:
			yaw -= event.relative.x*0.006
			pitch = clampf(pitch-event.relative.y*0.004,-0.9,0.35)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x*0.006
		pitch = clampf(pitch-event.relative.y*0.004,-0.9,0.35)
	overlay.offset = stick
	overlay.queue_redraw()

func _physics_process(delta: float) -> void:
	if backend == null or loading or ground_gate_failed:
		return
	var tick := Time.get_ticks_usec()
	if not ready_to_walk:
		# One existing startup/respawn ray, no new per-tick work during normal play.
		# The expected ground height was sampled once at spawn.
		var expected := spawn.y-SPAWN_CLEARANCE_M
		var center := Vector3(spawn.x,expected,spawn.z)
		var ray := PhysicsRayQueryParameters3D.create(center+Vector3.UP,center-Vector3.UP,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		ground_gate_attempts += 1
		var valid := false
		var error_m := -1.0
		if not hit.is_empty():
			var hit_position: Vector3 = hit["position"]
			error_m = absf(hit_position.y-expected)
			# Native Terrain3D attaches its instance id to the physics body RID.
			valid = int(hit.get("collider_id",0)) == backend.terrain.get_instance_id() and error_m <= GROUND_GATE_TOLERANCE_M
		if not valid:
			if tick-ground_gate_begin_us >= GROUND_GATE_TIMEOUT_US:
				ground_gate_failed = true
				player.velocity = Vector3.ZERO
				reset_touch()
				source_label.text = "Fiziksel zemin doğrulanamadı. Başa dön ile tekrar dene."
				recorder.event("ground_gate_timeout",{"attempts":ground_gate_attempts,"hit":not hit.is_empty(),"height_error_m":error_m})
			return
		ready_to_walk = true
		source_label.text = "Dört Havza | %.1f × %.1f m | 64 bölge" % [extent.x,extent.y]
		recorder.event("ground_gate_pass",{"attempts":ground_gate_attempts,"wait_us":tick-ground_gate_begin_us,"height_error_m":error_m})
		if first_ground_ms < 0:
			first_ground_ms = float(Time.get_ticks_usec()-load_begin)/1000.0
			recorder.event("first_ground_ms",first_ground_ms)
		# Existing periodic probe starts a second later; avoid duplicating this ray now.
		last_probe = tick
	var move := stick
	if Input.is_physical_key_pressed(KEY_W): move.y -= 1
	if Input.is_physical_key_pressed(KEY_S): move.y += 1
	if Input.is_physical_key_pressed(KEY_A): move.x -= 1
	if Input.is_physical_key_pressed(KEY_D): move.x += 1
	if menu.visible: move = Vector2.ZERO
	move = move.limit_length()
	var direction := Vector3(move.x,0,move.y).rotated(Vector3.UP,yaw)
	player.velocity.x = direction.x*speed
	player.velocity.z = direction.z*speed
	if not player.is_on_floor():
		player.velocity.y -= 9.8*delta
	else:
		player.velocity.y = -0.1
	player.move_and_slide()
	if player.position.x < 0.15 or player.position.z < 0.15 or player.position.x > extent.x-0.15 or player.position.z > extent.y-0.15:
		respawn()
	elif player.position.y < spawn.y-200.0:
		gaps += 1
		respawn()
	update_camera()
	if has_previous_position:
		traveled += Vector2(player.position.x-previous_position.x,player.position.z-previous_position.z).length()
	previous_position = player.position
	has_previous_position = true
	var now := Time.get_ticks_usec()
	if ready_to_walk and now-last_probe>=1000000:
		last_probe = now
		var p := player.global_position
		var expected := backend.surface_height(p)
		ground_checks += 1
		var reason := ""
		var error_m := -1.0
		if not is_finite(expected):
			reason = "surface_data_missing"
		else:
			# Probe at the known terrain height, not the airborne player's height.
			# Same one ray per second; no extra per-physics-tick ray.
			var center := Vector3(p.x,expected,p.z)
			var ray := PhysicsRayQueryParameters3D.create(center+Vector3.UP,center-Vector3.UP,1)
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty():
				reason = "terrain_shape_missing"
			elif int(hit.get("collider_id",0)) != backend.terrain.get_instance_id():
				reason = "different_collider"
			else:
				var hit_position: Vector3 = hit["position"]
				error_m = absf(hit_position.y-expected)
				if error_m > GROUND_GATE_TOLERANCE_M:
					reason = "height_mismatch"
		recorder.last_ground_error_m = error_m
		if not reason.is_empty():
			ground_misses += 1
			recorder.event("ground_probe_miss",{"reason":reason,"pos":[p.x,p.y,p.z],"expected_height_m":expected if is_finite(expected) else null,"height_error_m":error_m,"on_floor":player.is_on_floor()})
	var elapsed_us := Time.get_ticks_usec()-tick
	physics_us += elapsed_us
	max_physics_tick_us = maxi(max_physics_tick_us,elapsed_us)
	physics_ticks += 1

func update_camera() -> void:
	# Exact unchanged pose only, never quantize or smooth the camera relative
	# to the native clipmap. No repeated transform/look_at while stationary.
	var current_pos := player.position
	if _camera_pose_valid and current_pos == _camera_last_player and yaw == _camera_last_yaw and pitch == _camera_last_pitch:
		return
	_camera_pose_valid = true
	_camera_last_player = current_pos
	_camera_last_yaw = yaw
	_camera_last_pitch = pitch
	var aim := current_pos + Vector3.UP*0.15
	var offset := Vector3(0,0.25,0.85).rotated(Vector3.RIGHT,pitch).rotated(Vector3.UP,yaw)
	camera.position = aim+offset
	camera.look_at(aim,Vector3.UP)

func _process(_delta: float) -> void:
	if status == null:
		return
	var now := Time.get_ticks_usec()
	if last_frame>0 and backend != null and not loading:
		recorder.frame(now-last_frame,player.position,physics_us,traveled,gaps,ground_checks,ground_misses,speed,ready_to_walk,menu.visible,get_viewport().get_visible_rect().size,previous_process_us,max_physics_tick_us,physics_ticks)
		physics_us = 0
		max_physics_tick_us = 0
		physics_ticks = 0
	last_frame = now
	if now-last_hud>=1000000:
		last_hud = now
		if preview_range.mode == 2 and backend != null:
			var decision := preview_range.observe(recorder.last_summary,ready_to_walk and not loading and not menu.visible,Engine.max_fps,now)
			if not decision.is_empty():
				apply_preview_range(decision)
		# Reuse last completed one-second summary; no second sort or ring shift.
		var p99 := float(recorder.last_summary.get("p99_ms",0.0))
		var worst := float(recorder.last_summary.get("max_ms",0.0))
		status.text = "FPS %d | P99 %.1f ms | MAX %.1f ms | düşme %d | %.0f m" % [Engine.get_frames_per_second(),p99,worst,gaps,traveled]
	previous_process_us = Time.get_ticks_usec()-now
