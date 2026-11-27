extends SceneTree

const PATCH = preload("res://patch.gd")

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var scene := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    scene.get_node("Overlay").hide()
    var cpu := PATCH.new()
    var gpu := PATCH.new()
    scene.add_child(cpu)
    scene.add_child(gpu)
    if cpu.construct(false) != OK or gpu.construct(true) != OK:
        quit(1)
        return
    for x in [0.0, 12.0, 24.0]:
        scene._camera(x)
        cpu.hide()
        gpu.hide()
        var empty: PackedByteArray = await _pixels()
        cpu.show()
        var baked: PackedByteArray = await _pixels()
        cpu.hide()
        gpu.show()
        var displaced: PackedByteArray = await _pixels()
        var errors := 0
        var terrain := 0
        for i in range(0, baked.size(), 3):
            # Pixel data is RGB8. Ignore one encoding step of normal quantization.
            var delta := maxi(absi(baked[i] - displaced[i]), maxi(absi(baked[i+1] - displaced[i+1]), absi(baked[i+2] - displaced[i+2])))
            errors += int(delta > 2)
            terrain += int(absi(baked[i] - empty[i]) > 4)
        print("PATCH_PIXELS ", x, " differing=", errors, " terrain=", terrain, " total=", baked.size()/3)
        if terrain < baked.size()/12 or errors > baked.size()/300:
            quit(1)
            return
    quit(0)

func _pixels() -> PackedByteArray:
    await process_frame
    await RenderingServer.frame_post_draw
    var frame := root.get_texture().get_image()
    frame.convert(Image.FORMAT_RGB8)
    return frame.get_data()
