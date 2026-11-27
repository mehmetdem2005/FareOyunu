extends Node3D
const Runtime = preload("res://terrain_runtime.gd")
const Source = preload("res://import_source.gd")
var backend: Runtime
var player: CharacterBody3D
var camera: Camera3D
var status: Label
var source_label: Label
var menu: PanelContainer
var path_field: LineEdit
var dialog: FileDialog
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
	camera.far = 400
	camera.near = 0.025
	add_child(camera)
	camera.current = true
	make_ui()
	if FileAccess.file_exists("res://world.tfh"):
		request_load("res://world.tfh")
	elif DirAccess.dir_exists_absolute("res://world"):
		request_load("res://world")
	else:
		menu.show()
		source_label.text = "Dünya seçin. DEMO ayrı bir örnek arazidir."

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
	open.text = "Dünya / Ayarlar"
	open.pressed.connect(func(): menu.visible = not menu.visible; stick = Vector2.ZERO)
	bar.add_child(open)
	var reset := Button.new()
	reset.text = "Başa dön"
	reset.pressed.connect(respawn)
	bar.add_child(reset)
	menu = PanelContainer.new()
	ui.add_child(menu)
	menu.position = Vector2(12,104)
	menu.custom_minimum_size = Vector2(440,0)
	var box := VBoxContainer.new()
	menu.add_child(box)
	var hint := Label.new()
	hint.text = "TFH dosyası veya TFM1/TFM2 klasörü"
	box.add_child(hint)
	path_field = LineEdit.new()
	path_field.placeholder_text = "res://world veya /storage/.../world"
	box.add_child(path_field)
	var row := HBoxContainer.new()
	box.add_child(row)
	var load_button := Button.new()
	load_button.text = "Aç"
	load_button.pressed.connect(func(): request_load(path_field.text.strip_edges()))
	row.add_child(load_button)
	var browse := Button.new()
	browse.text = "Dosya"
	browse.pressed.connect(func(): dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; dialog.popup_centered_ratio(0.85))
	row.add_child(browse)
	var folder := Button.new()
	folder.text = "Klasör"
	folder.pressed.connect(func(): dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR; dialog.popup_centered_ratio(0.85))
	row.add_child(folder)
	var demo := Button.new()
	demo.text = "DEMO"
	demo.pressed.connect(func(): request_load("@demo"))
	row.add_child(demo)
	var speed_label := Label.new()
	speed_label.text = "Hareket hızı: 2.5 m/s"
	box.add_child(speed_label)
	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 12.0
	slider.step = 0.5
	slider.value = speed
	slider.value_changed.connect(func(v: float): speed = v; speed_label.text = "Hareket hızı: %.1f m/s" % v)
	box.add_child(slider)
	dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_selected.connect(func(p: String): path_field.text = p; request_load(p))
	dialog.dir_selected.connect(func(p: String): path_field.text = p; request_load(p))
	add_child(dialog)

func request_load(path: String) -> void:
	if loading or path.is_empty():
		return
	loading = true
	ready_to_walk = false
	stick = Vector2.ZERO
	source_label.text = "Arazi içe aktarılıyor..."
	await get_tree().process_frame
	await get_tree().process_frame
	var source := Source.new()
	var result: Error = source.demo() if path == "@demo" else source.load_source(path)
	if result != OK:
		source_label.text = "Açılmadı: " + source.error_message
		loading = false
		ready_to_walk = backend != null
		return
	if backend != null:
		backend.free()
		backend = null
	var next := Runtime.new()
	add_child(next)
	extent = Vector2(source.cells)*source.spacing
	player.position = Vector3(extent.x*0.5,0,extent.y*0.5)
	update_camera()
	result = next.initialize(camera,player,source.spacing,"lean")
	if result == OK:
		result = next.import_height_snapshot(source.height_image(),Vector3.ZERO,source.control_image())
	if result != OK:
		next.free()
		source_label.text = "Terrain3D aktarımı başarısız: " + str(result)
		loading = false
		return
	backend = next
	var height: float = backend.surface_height(player.position)
	if not is_finite(height):
		source_label.text = "Başlangıç yüksekliği okunamadı."
		loading = false
		return
	spawn = Vector3(player.position.x,height+0.20,player.position.z)
	respawn()
	source_label.text = ("DEMO — özgün dünya değil" if path=="@demo" else path.get_file()) + " | %.0f × %.0f m" % [extent.x,extent.y]
	menu.hide()
	loading = false
	gaps = 0
	frame_ms.clear()
	last_frame = 0

func respawn() -> void:
	if backend == null:
		return
	player.position = spawn
	player.velocity = Vector3.ZERO
	ready_to_walk = false
	update_camera()

func _input(event: InputEvent) -> void:
	if menu == null or menu.visible or loading or dialog.visible:
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
	if not ready_to_walk:
		var p := player.global_position
		var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP*2.0,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			return
		ready_to_walk = true
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
	status.text = "FPS %d | P99 %.1f ms | MAX %.1f ms | düşme %d" % [Engine.get_frames_per_second(),p99,worst,gaps]
