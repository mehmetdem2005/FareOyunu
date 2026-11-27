extends Control
const Kernel = preload("res://authoring/landform_kernel.gd")
var job: RefCounted
var samples: OptionButton
var spacing: SpinBox
var relief: SpinBox
var width_m: SpinBox
var bend_m: SpinBox
var seed_value: SpinBox
var generate_button: Button
var export_button: Button
var status: Label
var preview: TextureRect
var progress: ProgressBar
var busy := false
var output_image: Image
var output_meta: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := HBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := ScrollContainer.new()
	panel.custom_minimum_size = Vector2(260,0)
	root.add_child(panel)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(form)
	var heading := Label.new()
	heading.text = "TerraForge | Sırt / Vadi"
	form.add_child(heading)
	samples = OptionButton.new()
	for n in [256,512,1024]:
		samples.add_item("%d × %d" % [n,n],n)
	samples.select(0)
	form.add_child(samples)
	spacing = field(form,"Örnek aralığı (m)",0.25,8.0,0.25,0.25)
	relief = field(form,"Yükseklik / derinlik (m)",-200.0,200.0,0.5,12.0)
	width_m = field(form,"Yarı genişlik (m)",0.5,512.0,0.5,10.0)
	bend_m = field(form,"Kıvrım (m)",0.0,512.0,0.5,6.0)
	seed_value = field(form,"Seed",0.0,2147483647.0,1.0,271127.0)
	generate_button = Button.new()
	generate_button.text = "Float32 üret"
	generate_button.pressed.connect(generate)
	form.add_child(generate_button)
	export_button = Button.new()
	export_button.text = "RF kaynak kaydet"
	export_button.disabled = true
	export_button.pressed.connect(export_result)
	form.add_child(export_button)
	progress = ProgressBar.new()
	progress.max_value = 100.0
	form.add_child(progress)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 230
	status.text = "Pozitif değer sırt, negatif değer vadi. Önizleme gri tonlu; kaynak Float32."
	form.add_child(status)
	preview = TextureRect.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(preview)

func field(parent: VBoxContainer, title: String, low: float, high: float, step: float, initial: float) -> SpinBox:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	var input := SpinBox.new()
	input.min_value = low
	input.max_value = high
	input.step = step
	input.value = initial
	parent.add_child(input)
	return input

func generate() -> void:
	if busy:
		return
	var candidate := Kernel.new()
	var err := candidate.begin(samples.get_selected_id(),spacing.value,relief.value,width_m.value,bend_m.value,int(seed_value.value))
	if err != OK:
		status.text = "Geçersiz ayar: yarı genişlik + kıvrım haritanın yarısından küçük olmalı; genişlik en az iki örnek."
		return
	busy = true
	generate_button.disabled = true
	export_button.disabled = true
	job = candidate
	progress.value = 0.0
	status.text = "Float32 üretiliyor..."
	while not candidate.step():
		progress.value = 100.0*float(candidate.next_row)/candidate.side
		await get_tree().process_frame
	output_image = candidate.image
	output_meta = candidate.metadata()
	job = null
	# Only the separate display copy is normalized. Never feed it into export.
	var thumb_side := mini(candidate.side,256)
	var thumb := Image.create_empty(thumb_side,thumb_side,false,Image.FORMAT_L8)
	var range_m := maxf(candidate.max_height-candidate.min_height,0.000001)
	for z in range(thumb_side):
		for x in range(thumb_side):
			var sx := roundi(float(x)*(candidate.side-1)/(thumb_side-1))
			var sz := roundi(float(z)*(candidate.side-1)/(thumb_side-1))
			var v := clampf((output_image.get_pixel(sx,sz).r-candidate.min_height)/range_m,0.0,1.0)
			thumb.set_pixel(x,z,Color(v,v,v,1.0))
		if z%16 == 15:
			await get_tree().process_frame
	preview.texture = ImageTexture.create_from_image(thumb)
	progress.value = 100.0
	status.text = "%d² RF | %.2f–%.2f m" % [candidate.side,candidate.min_height,candidate.max_height]
	busy = false
	generate_button.disabled = false
	export_button.disabled = false

func export_result() -> void:
	if busy or output_image == null:
		return
	var folder := "user://terraforge_landforms"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		status.text = "Kayıt klasörü açılamadı."
		return
	# Unique name; never replace an existing user project or the test fixture.
	var name := "landform_%d_%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
	var image_path := folder.path_join(name+".res")
	var json_path := folder.path_join(name+".json")
	if FileAccess.file_exists(image_path) or FileAccess.file_exists(json_path):
		status.text = "Dosya adı çakıştı; tekrar kaydet."
		return
	var err := ResourceSaver.save(output_image,image_path)
	if err != OK:
		status.text = "RF kayıt başarısız: %s" % str(err)
		return
	var saved := ResourceLoader.load(image_path,"Image",ResourceLoader.CACHE_MODE_IGNORE) as Image
	if saved == null or saved.get_format() != Image.FORMAT_RF or saved.get_size() != output_image.get_size() or saved.get_data() != output_image.get_data():
		status.text = "Kayıt doğrulanamadı; dosyayı kullanma."
		DirAccess.remove_absolute(ProjectSettings.globalize_path(image_path))
		return
	var f := FileAccess.open(json_path,FileAccess.WRITE)
	if f == null:
		status.text = "Metadata yazılamadı."
		DirAccess.remove_absolute(ProjectSettings.globalize_path(image_path))
		return
	var meta := output_meta.duplicate()
	meta["resource_sha256"] = FileAccess.get_sha256(image_path)
	f.store_string(JSON.stringify(meta,"\t"))
	f.close()
	status.text = "Kayıt: "+ProjectSettings.globalize_path(image_path)
