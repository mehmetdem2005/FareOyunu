extends SceneTree
## Compare cropped worker inputs to full-halo output on curved terrain.
const Geometry = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const Dense = preload("res://addons/terra_forge/core/tile_dense_buffer.gd")
const Comparison = preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")
const Fixture = preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const Source = preload("res://addons/terra_forge/core/async_region_source.gd")
const FixtureV2 = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const Topology = preload("res://addons/terra_forge/core/tile_topology_cache.gd")
const KEY := Vector2i(1, 1)
const EDGES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var source := Source.new()
var fixture: Variant
var topology := Topology.new()
var cases: int=0

func _initialize() -> void:
    if topology.initialize()!=OK or topology.payload_bytes()!=32256:
        _finish("topology setup")
        return
    for format in [1,2]:
        if format==1:
            fixture=Fixture.new()
        else:
            fixture=FixtureV2.new()
        if fixture.start(Vector2i(96, 96)) != OK:
            _finish("fixture start")
            return
        var made: Dictionary={}
        for attempt in range(5000):
            made = fixture.take_result()
            if made["error"] != ERR_BUSY:
                break
            OS.delay_msec(1)
        if made.get("error",FAILED)!=OK:
            _finish("fixture")
            return
        var directory:String=made["directory"]
        var opened:Error=source.open(directory,9,4,false) if format==1 else source.open_v2(directory,9,4,false,1)
        if opened!=OK:
            _finish("open")
            return
        var pages := Geometry.required_pages(source, KEY.x, KEY.y, 0)
        for attempt in range(5000):
            source.poll_results(4)
            var pages_ready := true
            for page in pages:
                if source.page_status(page) != OK:
                    pages_ready = false
                    source.request_page(page)
            if pages_ready:
                break
            OS.delay_msec(1)
        var before:int=cases
        for lod in range(3):
            for mask in range(16):
                var desired := {KEY: lod}
                for edge in range(4):
                    if mask & (1 << edge):
                        desired[KEY + EDGES[edge]] = lod
                    elif edge % 2 == 0:
                        desired[KEY + EDGES[edge]] = (lod + 1) % 3
                if not _check(desired, lod, mask):
                    _finish("TFM%d LOD %d, mask %d" % [format,lod,mask])
                    return
                cases+=1
        print("HYBRID_HALO_PARITY ",JSON.stringify({"format":format,"input_cases":cases-before,"backends":["dense","scalar","scalar_topology"],"exact_comparisons":(cases-before)*3,"topology_payload_bytes":topology.payload_bytes(),"note":"Owned input parity only; not threaded delivery, live camera or Android performance."}))
        source.close()
        fixture.close()
        fixture=null
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
    if not Comparison.equal(expected,actual):
        return false
    var scalar:=Geometry.generate_owned_dense_scalar(owned["buffer"],KEY.x,KEY.y,lod,desired)
    if not Comparison.equal(expected,scalar):
        return false
    var cached:=Geometry.generate_owned_dense_scalar(owned["buffer"],KEY.x,KEY.y,lod,desired,topology)
    return Comparison.equal(expected,cached)

func _finish(error: String) -> void:
    source.close()
    if fixture!=null:
        fixture.close()
    if error.is_empty() and cases==96:
        print("PASS: 96 cropped halo inputs, 288 exact dense/scalar/topology comparisons, TFM1/2")
        quit(0)
    else:
        push_error("Cropped worker halo: " + error)
        quit(1)
