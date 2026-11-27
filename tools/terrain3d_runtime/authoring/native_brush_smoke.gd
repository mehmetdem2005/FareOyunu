extends SceneTree
const Brush = preload("res://addons/terraforge_native/native_brush.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("NATIVE_BRUSH_SMOKE_FAIL: "+message)

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(128,30,64)
	camera.current = true
	var terrain := ClassDB.instantiate("Terrain3D") as Node3D
	var material := ClassDB.instantiate("Terrain3DMaterial") as Resource
	if terrain == null or material == null:
		push_error("NATIVE_BRUSH_SMOKE_FAIL: native class unavailable")
		quit(1)
		return
	material.set("max_regions",64)
	material.set("world_background",0)
	material.set("shader_override",load("res://shaders/world_surface.gdshader"))
	material.set("shader_override_enabled",true)
	terrain.set("material",material)
	terrain.set("vertex_spacing",0.25)
	terrain.set("mesh_size",16)
	terrain.set("mesh_lods",7)
	terrain.set("tessellation_level",0)
	terrain.set("collision_mode",0)
	stage.add_child(terrain)
	terrain.call("set_camera",camera)
	if int(terrain.call("get_region_size"))!=512:
		terrain.call("change_region_size",512)
	var data: Object = terrain.get("data")
	if data == null or int(terrain.call("get_region_size"))!=512:
		push_error("NATIVE_BRUSH_SMOKE_FAIL: initialization")
		quit(1)
		return
	for x in range(2):
		var region: Resource = data.call("add_region_blank",Vector2i(x,0),false)
		if region==null:
			push_error("NATIVE_BRUSH_SMOKE_FAIL: blank region")
			quit(1)
			return
	data.call("update_maps",3,true,false)
	material.call("set_show_checkered",false)
	await process_frame
	var region0: Resource = data.call("get_region",Vector2i.ZERO)
	var source_h: Image = region0.call("get_height_map")
	var source_c: Image = region0.call("get_control_map")
	check(source_h.get_format()==Image.FORMAT_RF and source_c.get_format()==Image.FORMAT_RF,"CPU RF survives upload")
	var initial_control := source_c.get_data()
	var brush := Brush.new()
	brush.attach(terrain)
	# Match the user brush radius/power on the interior of one region.
	var inside := Vector3(64,0,64)
	brush.begin()
	var interior_error := brush.dab(inside,0,8.0,3.0)
	brush.end()
	check(interior_error.is_empty() and brush.last_changed_cells>0 and absf(float(data.call("get_height",inside))-3.0)<0.00001,"8m interior raise: "+interior_error)
	check(brush.undo()=="Native undo applied." and is_zero_approx(float(data.call("get_height",inside))),"8m interior undo")
	var center := Vector3(128,0,64)
	var left := Vector3(127.75,0,64)
	var hit: Vector3 = terrain.call("get_intersection",center+Vector3.UP*20.0,Vector3.DOWN,false)
	check(hit.is_finite() and hit.distance_to(center)<0.01,"native flat surface intersection")
	check(is_zero_approx(float(data.call("get_height",center))),"initial center")
	brush.begin()
	var error := brush.dab(hit,0,2.0,3.0)
	check(error.is_empty() and brush.last_changed_cells>0,"raise accepted: "+error)
	brush.end()
	var raised := float(data.call("get_height",center))
	check(absf(raised-3.0)<0.00001,"center raise")
	check(float(data.call("get_height",left))>0.0,"cross-region raise")
	check(brush.undo()=="Native undo applied.","undo")
	check(is_zero_approx(float(data.call("get_height",center))) and is_zero_approx(float(data.call("get_height",left))),"undo values")
	check(brush.redo()=="Native redo applied.","redo")
	check(absf(float(data.call("get_height",center))-raised)<0.00001,"redo value")
	brush.begin()
	error=brush.dab(center,1,2.0,1.0)
	brush.end()
	check(error.is_empty() and absf(float(data.call("get_height",center))-2.0)<0.00001,"lower")
	var final_h: Image = region0.call("get_height_map")
	var final_c: Image = region0.call("get_control_map")
	check(final_h.get_format()==Image.FORMAT_RF and final_c.get_format()==Image.FORMAT_RF,"CPU RF survives incremental update")
	check(final_c.get_data()==initial_control,"control word bytes unchanged")
	# Linux CI readback only. No GPU readback in normal editing.
	var layer := int(data.call("get_region_id",Vector2i.ZERO))
	var gpu_h := RenderingServer.texture_2d_layer_get(data.call("get_height_maps_rid"),layer)
	var gpu_c := RenderingServer.texture_2d_layer_get(data.call("get_control_maps_rid"),layer)
	check(gpu_h!=null and gpu_h.get_format()==Image.FORMAT_RGBA8 and gpu_h.get_data()==final_h.get_data(),"GPU height RGBA8 exact bytes after update")
	check(gpu_c!=null and gpu_c.get_format()==Image.FORMAT_RGBA8 and gpu_c.get_data()==final_c.get_data(),"GPU control RGBA8 exact bytes")
	if failures==0:
		print("TERRAFORGE_PACKED_RF_OK cpu_rf=true gpu_bytes_exact=true")
		print("NATIVE_BRUSH_SMOKE_OK regions=2 raise_lower_undo_redo=true")
	stage.free()
	quit(0 if failures==0 else 1)
