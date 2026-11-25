extends SceneTree
## Compare cropped worker inputs to full-halo output on curved terrain.
const Geometry = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const Dense = preload("res://addons/terra_forge/core/tile_dense_buffer.gd")
const Comparison = preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")
const Fixture = preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const Source = preload("res://addons/terra_forge/core/async_region_source.gd")
const FixtureV2 = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const Topology = preload("res://addons/terra_forge/core/tile_topology_cache.gd")
const Worker = preload("res://addons/terra_forge/core/geometry_worker.gd")
const KEY := Vector2i(1, 1)
const EDGES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var source := Source.new()
var fixture: Variant
var topology := Topology.new()
var cases: int=0
var threaded_cases: int=0
var worker := Worker.new()

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
        if not _threaded_boundaries(format):
            _finish("threaded boundary parity TFM%d" % format)
            return
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

# Nine tile positions cover all four world corners, edge midpoints and
# interior. Each LOD tests same-LOD normals and mixed/absent neighbors.
# Both scalar worker variants must match the canonical source exactly.
func _threaded_boundaries(format: int) -> bool:
    for cached in [false,true]:
        if worker.start(source,1,true,cached)!=OK:
            return false
        var before: int=threaded_cases
        var bytes_full: int=0
        var bytes_cropped: int=0
        for z in range(3):
            for x in range(3):
                var key := Vector2i(x,z)
                for lod in range(3):
                    for pattern in range(2):
                        var desired: Dictionary={key:lod}
                        for edge in range(4):
                            var neighbor: Vector2i=key+EDGES[edge]
                            if neighbor.x<0 or neighbor.y<0 or neighbor.x>=3 or neighbor.y>=3:
                                continue
                            if pattern==0:
                                desired[neighbor]=lod
                            elif edge%2==0:
                                desired[neighbor]=(lod+1)%3
                        var mask: int=Geometry.normal_halo(key,lod,desired)
                        var full_pages: Array[Vector2i]=Geometry.required_pages(source,key.x,key.y,lod)
                        if not _load_pages(full_pages):
                            return false
                        var expected: Dictionary=Geometry.generate(source,key.x,key.y,lod,desired)
                        if expected.get("error",FAILED)!=OK:
                            return false
                        var full_bounds: Rect2i=Dense.sample_bounds(source.cells,key,1<<lod,Dense.FULL_HALO)
                        var crop_bounds: Rect2i=Dense.sample_bounds(source.cells,key,1<<lod,mask)
                        var full_extent: Vector2i=(full_bounds.size-Vector2i.ONE)/(1<<lod)+Vector2i.ONE
                        var crop_extent: Vector2i=(crop_bounds.size-Vector2i.ONE)/(1<<lod)+Vector2i.ONE
                        var full_bytes: int=full_extent.x*full_extent.y*4
                        var crop_bytes: int=crop_extent.x*crop_extent.y*4
                        # Require the cropped page set before the worker copies.
                        var crop_pages: Array[Vector2i]=Geometry.required_pages(source,key.x,key.y,lod,mask)
                        if not _load_pages(crop_pages):
                            return false
                        var submitted: Dictionary=worker.submit(source,key,lod,desired,mask)
                        if submitted.get("error",FAILED)!=OK or submitted.get("input_bytes",-1)!=crop_bytes or crop_bytes>full_bytes or source.stats()["tile_view_active_pages"]!=0:
                            return false
                        # Drop source cache after enqueue. Owned input must
                        # survive independent of reader pages and their pins.
                        if source.release_outside(Vector2i(4,4),Vector2i(4,4))!=OK:
                            return false
                        var received: Dictionary=_wait_worker(desired)
                        if received.get("error",FAILED)!=OK:
                            return false
                        var result: Dictionary=received["result"]
                        if result["id"]!=submitted["id"] or result["input_bytes"]!=crop_bytes or not Comparison.equal(expected,result["geometry"]):
                            return false
                        if worker.stats()["slots"]!=0:
                            return false
                        bytes_full+=full_bytes
                        bytes_cropped+=crop_bytes
                        threaded_cases+=1
        var stats: Dictionary=worker.stats()
        if stats["submitted"]!=54 or stats["delivered"]!=54 or stats["dropped"]!=0 or stats["peak_slots"]!=1 or stats["slots"]!=0 or bytes_cropped>=bytes_full:
            return false
        print("HYBRID_HALO_THREADED ",JSON.stringify({"format":format,"topology":cached,"cases":threaded_cases-before,"full_input_bytes":bytes_full,"cropped_input_bytes":bytes_cropped,"note":"Exact arrays and collision samples after reader eviction; not a raycast or timing comparison."}))
        worker.close()
    return true

func _load_pages(keys: Array[Vector2i]) -> bool:
    for attempt in range(4000):
        source.poll_results(4)
        source.prioritize_resident(keys)
        var pages_ready: bool=true
        for key in keys:
            var status: Error=source.page_status(key)
            if status==ERR_BUSY:
                pages_ready=false
                source.request_page(key)
            elif status!=OK:
                return false
        if pages_ready:
            return true
        OS.delay_msec(1)
    return false

func _wait_worker(desired: Dictionary) -> Dictionary:
    for attempt in range(4000):
        var result: Dictionary=worker.poll(source,desired)
        if result.get("error",FAILED)!=ERR_BUSY:
            return result
        OS.delay_msec(1)
    return {"error":ERR_TIMEOUT}

func _finish(error: String) -> void:
    worker.close()
    source.close()
    if fixture!=null:
        fixture.close()
    if error.is_empty() and cases==96 and threaded_cases==216:
        print("PASS: 96 cropped halo inputs, 288 exact dense/scalar/topology comparisons plus 216 threaded boundary cases, TFM1/2")
        quit(0)
    else:
        push_error("Cropped worker halo: " + error)
        quit(1)
