extends Node3D
const Runtime = preload("res://terrain_runtime.gd")
const Recorder = preload("res://session_recorder.gd")
var recorder := Recorder.new()
var report_path := ""
var load_begin := 0
var first_ground_ms := -1.0
var physics_us := 0
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
var ready_to_walk := false
var loading := false
var stick := Vector2.ZERO
var stick_id := -1
var look_id := -1
var stick_origin := Vector2.ZERO
var overlay: StickOverlay
var last_frame := 0
var last_hud := 0
var frame_ms: Array[float] = []
var gaps := 0

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

func request_load() -> void:
	loading = true
	source_label.text = "Dünya hazırlanıyor..."
	await get_tree().process_frame
	await get_tree().process_frame
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
	var start: Array = world_info.get("spawn_m",[512.0,512.0])
	player.position = Vector3(float(start[0]),0,float(start[1]))
	update_camera()
	var next := Runtime.new()
	add_child(next)
	var result: Error = next.initialize(camera,player,spacing,"world",512)
	if result == OK:
		result = next.load_baked_regions(world_info)
	if result != OK:
		next.free()
		fail_load("Terrain3D aktarımı başarısız: " + str(result))
		return
	backend = next
	var height: float = backend.surface_height(player.position)
	if not is_finite(height):
		fail_load("Başlangıç yüksekliği okunamadı")
		return
	spawn = Vector3(player.position.x,height+0.20,player.position.z)
	respawn()
	source_label.text = "Dört Havza | %.1f × %.1f m | 64 bölge" % [extent.x,extent.y]
	loading = false
	gaps = 0
	frame_ms.clear()
	last_frame = 0
	recorder.begin(world_info, float(Time.get_ticks_usec()-load_begin)/1000.0)
	recorder.event("fps_cap",Engine.max_fps)

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
	if backend == null or loading:
		return
	var tick := Time.get_ticks_usec()
	if not ready_to_walk:
		var p := player.global_position
		var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP*2.0,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			return
		ready_to_walk = true
		if first_ground_ms < 0:
			first_ground_ms = float(Time.get_ticks_usec()-load_begin)/1000.0
			recorder.event("first_ground_ms",first_ground_ms)
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
	if now-last_probe>=1000000:
		last_probe = now
		var p := player.global_position
		var expected := backend.surface_height(p)
		var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*2.0,p-Vector3.UP*3.0,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		ground_checks += 1
		if hit.is_empty() or not is_finite(expected):
			ground_misses += 1
			recorder.event("ground_probe_miss",[p.x,p.y,p.z])
		else:
			recorder.last_ground_error_m = absf(float(hit.position.y)-expected)
	physics_us += Time.get_ticks_usec()-tick

func update_camera() -> void:
	var aim := player.position + Vector3.UP*0.15
	var offset := Vector3(0,0.25,0.85).rotated(Vector3.RIGHT,pitch).rotated(Vector3.UP,yaw)
	camera.position = aim+offset
	camera.look_at(aim,Vector3.UP)

func _process(_delta: float) -> void:
	if status == null:
		return
	var now := Time.get_ticks_usec()
	if last_frame>0 and backend != null and not loading:
		recorder.frame(now-last_frame,player.position,physics_us,traveled,gaps,ground_checks,ground_misses,speed,ready_to_walk,menu.visible,get_viewport().get_visible_rect().size)
		physics_us = 0
		frame_ms.append(float(now-last_frame)/1000.0)
		if frame_ms.size()>240:
			frame_ms.pop_front()
	last_frame = now
	if now-last_hud<500000:
		return
	last_hud = now
	var sorted := frame_ms.duplicate()
	sorted.sort()
	var p99 := 0.0 if sorted.is_empty() else float(sorted[clampi(ceili(sorted.size()*0.99)-1,0,sorted.size()-1)])
	var worst := 0.0 if sorted.is_empty() else float(sorted[-1])
	status.text = "FPS %d | P99 %.1f ms | MAX %.1f ms | düşme %d | %.0f m" % [Engine.get_frames_per_second(),p99,worst,gaps,traveled]
