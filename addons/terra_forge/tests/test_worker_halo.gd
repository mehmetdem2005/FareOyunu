extends SceneTree
## Compare cropped worker inputs to full-halo output on curved terrain.
const Geometry = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const Dense = preload("res://addons/terra_forge/core/tile_dense_buffer.gd")
const Comparison = preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")
const Fixture = preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const Source = preload("res://addons/terra_forge/core/async_region_source.gd")
const KEY := Vector2i(1, 1)
const EDGES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var source := Source.new()
var fixture := Fixture.new()

func _initialize() -> void:
    if fixture.start(Vector2i(96, 96)) != OK:
        _finish("fixture start")
        return
    var made: Dictionary
    for attempt in range(5000):
        made = fixture.take_result()
        if made["error"] != ERR_BUSY:
            break
        OS.delay_msec(1)
    if made["error"] != OK or source.open(made["directory"], 9, 4, false) != OK:
        _finish("open")
        return
    var pages := Geometry.required_pages(source, KEY.x, KEY.y, 0)
    for attempt in range(5000):
        source.poll_results(4)
        var ready := true
        for page in pages:
            if source.page_status(page) != OK:
                ready = false
                source.request_page(page)
        if ready:
            break
        OS.delay_msec(1)
    for lod in range(3):
        for mask in range(16):
            var desired := {KEY: lod}
            for edge in range(4):
                if mask & (1 << edge):
                    desired[KEY + EDGES[edge]] = lod
                elif edge % 2 == 0:
                    desired[KEY + EDGES[edge]] = (lod + 1) % 3
            if not _check(desired, lod, mask):
                _finish("LOD %d, mask %d" % [lod, mask])
                return
    _finish("")

func _check(desired: Dictionary, lod: int, mask: int) -> bool:
    if Geometry.normal_halo(KEY, lod, desired) != mask:
        return false
    var expected := Geometry.generate(source, KEY.x, KEY.y, lod, desired)
    var keys := Geometry.required_pages(source, KEY.x, KEY.y, lod, mask)
    var expected_count := (3 if mask & 1 else 2) * (3 if mask & 4 else 2)
    if keys.size() != expected_count:
        return false
    var acquired := source.acquire_tile_view(keys)
    if acquired["error"] != OK:
        return false
    var owned := Dense.build(acquired["view"], KEY.x, KEY.y, 1 << lod, mask)
    if source.release_tile_view(acquired["view"]) != OK or owned["error"] != OK:
        return false
    var actual := Geometry.generate(owned["buffer"], KEY.x, KEY.y, lod, desired)
    return Comparison.equal(expected, actual)

func _finish(error: String) -> void:
    source.close()
    fixture.close()
    if error.is_empty():
        print("PASS: exact geometry and collision for 48 cropped normal halos")
        quit(0)
    else:
        push_error("Cropped worker halo: " + error)
        quit(1)
