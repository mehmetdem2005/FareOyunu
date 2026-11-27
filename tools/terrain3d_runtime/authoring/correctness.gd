extends SceneTree
const Flow = preload("res://authoring/flow_kernel.gd")
const Micro = preload("res://authoring/micro_kernel.gd")
const Ridge = preload("res://authoring/landform_kernel.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("flow"):
		test_flow()
	elif args.has("micro"):
		test_micro()
	elif args.has("ridge"):
		test_ridge()
	else:
		failures += 1
	if failures == 0:
		print("AUTHORING_CORRECTNESS_PASS ",args)
	quit(0 if failures == 0 else 1)

func test_flow() -> void:
	var src := Image.create_empty(24,16,false,Image.FORMAT_RF)
	for z in range(16):
		for x in range(24):
			src.set_pixel(x,z,Color(24-x+absf(z-8)*0.1,0,0,1))
	var bytes := src.get_data()
	var job := Flow.new()
	check(job.begin(src,0.25,0.1,0.05,0.25)==OK,"flow begin")
	while not job.step(20):
		pass
	check(job.completed(),"flow completed")
	if not job.completed():
		return
	check(job.processed==384,"all nodes processed")
	check(job.sinks==1,"one sink on converging slope")
	check(job.eroded>0.0,"erosion occurred")
	check(absf(job.eroded-job.deposited)<0.000001,"closed sediment conservation")
	check(absf(job.output_sum-job.source_sum)<0.001,"RF mass tolerance")
	check(src.get_data()==bytes,"source unchanged")
	var other := Flow.new()
	check(other.begin(src,0.25,0.1,0.05,0.25)==OK,"repeat begin")
	while not other.step(3000):
		pass
	check(other.completed() and other.image.get_data()==job.image.get_data(),"budget-independent output")
	var flat := Image.create_empty(8,8,false,Image.FORMAT_RF)
	flat.fill(Color(2.0,0,0,1))
	var still := Flow.new()
	check(still.begin(flat,1.0,0.2,0.1,0.5)==OK,"flat begin")
	while not still.step():
		pass
	check(still.completed() and still.image.get_data()==flat.get_data(),"flat unchanged")
	check(Flow.new().begin(src,0.0,0.1,0.05,0.5)!=OK,"invalid spacing rejected")

func test_micro() -> void:
	var src := Image.create_empty(64,48,false,Image.FORMAT_RF)
	src.fill(Color(2.0,0,0,1))
	var bytes := src.get_data()
	var job := Micro.new()
	check(job.begin(src,0.025,Vector2(0.75,0.5),Vector2(0.3,0.1),-0.08,0.0)==OK,"micro begin")
	while not job.step(20):
		pass
	check(job.completed(),"micro complete")
	if not job.completed():
		return
	check(absf(job.image.get_pixel(30,20).r-1.92)<0.000001,"signed center")
	check(job.image.get_pixel(0,0).r==2.0,"outside unchanged")
	check(src.get_data()==bytes,"source immutable")
	check(job.changed>0,"stamp has changes")
	var rotated := Micro.new()
	check(rotated.begin(src,0.025,Vector2(0.75,0.5),Vector2(0.3,0.1),0.08,PI/2.0)==OK,"rotated begin")
	while not rotated.step():
		pass
	check(rotated.completed(),"rotated complete")
	check(rotated.image.get_pixel(30,28).r>2.0 and rotated.image.get_pixel(38,20).r==2.0,"orientation")
	check(Micro.new().begin(src,0.025,Vector2(0.75,0.5),Vector2(0.01,0.1),0.08,0.0)!=OK,"underresolved rejected")

func test_ridge() -> void:
	var a := Ridge.new()
	var b := Ridge.new()
	check(a.begin(64,0.25,3.0,2.0,1.0,123)==OK,"ridge begin")
	check(b.begin(64,0.25,3.0,2.0,1.0,123)==OK,"repeat begin")
	while not a.step(20):
		pass
	while not b.step(3000):
		pass
	check(a.completed() and b.completed(),"ridge complete")
	check(a.image.get_data()==b.image.get_data(),"ridge deterministic")
	check(a.image.get_format()==Image.FORMAT_RF,"float32 format")
	for x in range(64):
		check(a.image.get_pixel(x,0).r==0.0 and a.image.get_pixel(x,63).r==0.0,"taper ends")
	check(a.max_height>0.0 and a.max_height<=3.0,"ridge bound")
