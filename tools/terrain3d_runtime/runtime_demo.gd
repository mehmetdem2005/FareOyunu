extends Node3D
const Runtime = preload("res://terrain_runtime.gd")
var backend: Node3D
var camera: Camera3D
var target: Node3D
var smoke := false
var elapsed := 0.0
var samples: Array[float] = []

func _ready() -> void:
	smoke = "--smoke" in OS.get_cmdline_user_args()
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.far = 400.0
	target = Node3D.new()
	add_child(target)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.1, 0.17, 0.24)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	_move(0.0)
	backend = Runtime.new()
	add_child(backend)
	if backend.initialize(camera, target, 0.25) != OK:
		_fail("native terrain initialization")
		return
	var image := Image.create_empty(256, 256, false, Image.FORMAT_RF)
	for z in range(256):
		for x in range(256):
			var h: float = _height(x, z)
			image.set_pixel(x, z, Color(h, 0, 0, 1))
	if backend.import_height_snapshot(image) != OK:
		_fail("float height import")
		return
	var wrong := Image.create_empty(256, 256, false, Image.FORMAT_R8)
	if backend.import_height_snapshot(wrong) == OK:
		_fail("invalid input accepted")
		return
	for xy in [Vector2i(40, 40), Vector2i(80, 96), Vector2i(180, 150)]:
		var expected: float = _height(xy.x, xy.y)
		var actual: float = backend.surface_height(Vector3(xy.x * 0.25, 0, xy.y * 0.25))
		if not is_finite(actual) or absf(actual - expected) > 0.001:
			_fail("height parity")
			return
	if smoke:
		await _run_smoke()
	else:
		set_process(true)

func _height(x: int, z: int) -> float:
	return 2.0 + 0.8 * sin(float(x) * 0.045) + 0.4 * cos(float(z) * 0.07)

func _move(t: float) -> void:
	var x := lerpf(12.0, 48.0, t)
	var z := 30.0 + 8.0 * sin(t * TAU)
	target.position = Vector3(x, 3, z)
	camera.position = target.position + Vector3(0, 13, 15)
	camera.look_at(target.position, Vector3.UP)

func _process(delta: float) -> void:
	if smoke or backend == null:
		return
	elapsed += delta
	_move(0.5 - 0.5 * cos(elapsed * 0.12))

func _run_smoke() -> void:
	for step in range(9):
		_move(float(step) / 8.0)
		for frame in range(12):
			await get_tree().physics_frame
			await get_tree().process_frame
		var p: Vector3 = target.global_position
		var expected: float = backend.surface_height(p)
		var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, 20, p.z), Vector3(p.x, -20, p.z), 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or not is_finite(expected) or absf(float(hit.position.y) - expected) > 0.08:
			_fail("physics ray parity at step %d" % step)
			return
		samples.append(float(hit.position.y))
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("rendered image unavailable")
		return
	var center := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	var corner := image.get_pixel(0, 0)
	if center.is_equal_approx(corner):
		_fail("rendered image has no center/corner contrast")
		return
	image.save_png("user://terrain3d-smoke.png")
	print("TERRAIN3D_SMOKE_PASS ", JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "ray_samples": samples.size(), "height_parity": true}))
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("TERRAIN3D_SMOKE_FAIL: " + reason)
	get_tree().quit(1)
