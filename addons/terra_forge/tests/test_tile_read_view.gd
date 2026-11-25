extends SceneTree
const ASYNC = preload("res://addons/terra_forge/core/async_region_source.gd")
const V1 = preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2 = preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const G = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const PREVIEW = preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")

func _initialize() -> void:
    var src = ASYNC.new()
    for version in [1,2]:
        var b: Variant
        if version == 1:
            b=V1.new()
        else:
            b=V2.new()
        var err: Error = b.start(Vector2i(96,96),true) if version == 1 else b.start(Vector2i(96,96))
        if err != OK:
            _fail("fixture start",src,b)
            return
        var deadline: int = Time.get_ticks_msec()+30000
        var result: Dictionary = {}
        while Time.get_ticks_msec()<deadline:
            result=b.take_result()
            if result["error"]!=ERR_BUSY:
                break
            OS.delay_msec(1)
        if result.get("error",FAILED)!=OK:
            _fail("fixture generation",src,b)
            return
        var directory: String = result["directory"]
        err=src.open(directory,9,4,false) if version==1 else src.open_v2(directory,9,4,false,1)
        if err!=OK:
            _fail("source open",src,b)
            return
        var keys: Array[Vector2i] = G.required_pages(src,1,1,0)
        if keys.size()!=9 or src.acquire_tile_view(keys)["error"]!=ERR_BUSY or not _load(src,keys):
            _fail("missing page or required halo",src,b)
            return
        var total_baseline: int=0
        var total_view: int=0
        for lod in [0,1,2]:
            var desired: Dictionary={Vector2i(1,1):lod,Vector2i(0,1):lod,Vector2i(2,1):lod,Vector2i(1,0):lod,Vector2i(1,2):lod}
            if not _compare(src,lod,desired):
                _fail("LOD parity "+str(lod),src,b)
                return
        var mixed: Dictionary={Vector2i(1,1):0,Vector2i(0,1):2,Vector2i(2,1):1,Vector2i(1,0):2,Vector2i(1,2):1}
        if not _compare(src,0,mixed):
            _fail("mixed LOD parity",src,b)
            return
        var stats: Dictionary=src.stats()
        total_baseline=stats["direct_height_reads"]
        total_view=stats["tile_view_page_touches"]
        if total_baseline<2000 or total_view!=36 or stats["tile_view_reads"]!=total_baseline or stats["tile_view_peak_pages"]!=9 or stats["tile_view_active_pages"]!=0:
            _fail("work counters "+str(stats),src,b)
            return
        var acquired: Dictionary=src.acquire_tile_view(keys)
        var view=acquired["view"]
        var repeated_keys: Array[Vector2i]=[keys[0],keys[0]]
        if src.acquire_tile_view(keys)["error"]!=ERR_BUSY or view.get_height(-1,0).has("height") or view.get_height(96,96).has("height"):
            _fail("lease bounds/exclusive",src,b)
            return
        if src.set_generation(1)!=OK or view.is_open() or view.page_count_held()!=0 or view.get_height(32,32).has("height") or src.release_tile_view(view)==OK or src.acquire_tile_view(repeated_keys)["error"]==OK:
            _fail("stale lease",src,b)
            return
        view=src.acquire_tile_view(keys)["view"]
        src.poll_results(4)
        if view.is_open() or view.page_count_held()!=0:
            _fail("poll revocation",src,b)
            return
        view=src.acquire_tile_view(keys)["view"]
        if src.release_outside(Vector2i.ZERO,Vector2i.ZERO)!=OK or view.is_open() or src.acquire_tile_view(keys)["error"]!=ERR_BUSY:
            _fail("eviction revocation",src,b)
            return
        if not _load(src,keys):
            _fail("reload",src,b)
            return
        view=src.acquire_tile_view(keys)["view"]
        src.close()
        if view.is_open() or view.page_count_held()!=0 or src.stats()["tile_view_reads"]!=0:
            _fail("close revocation",src,b)
            return
        var preview=PREVIEW.new()
        preview.region_index_format=version-1
        preview.use_tile_read_view=true
        preview.max_visible_tiles=1
        if preview.start_preview(directory,9,4)!=OK:
            preview.free()
            _fail("preview open",src,b)
            return
        preview.set_stream_center(Vector3(48,20,48))
        for attempt in range(3000):
            preview.pump_stream()
            if preview._tiles.has(Vector2i(1,1)):
                break
            OS.delay_msec(1)
        var success: bool=preview._tiles.has(Vector2i(1,1)) and preview.has_collision_at(Vector3(48,0,48)) and preview.stats()["source"]["tile_view_acquires"]>0 and preview.stats()["source"]["tile_view_active_pages"]==0
        preview.stop_preview()
        preview.free()
        if not success:
            _fail("actual preview",src,b)
            return
        print("VIEW_WORK format=",version," direct_sample_touches=",total_baseline," lease_page_touches=",total_view)
        b.close()
    print("PASS: TFM1/TFM2 bounded tile leases, exact all-array LOD and mixed parity, deterministic LRU reduction, stale lease revocation, actual preview")
    quit(0)

func _load(src,keys: Array[Vector2i]) -> bool:
    for attempt in range(3000):
        src.poll_results(4)
        src.prioritize_resident(keys)
        var pages_ready: bool=true
        for key in keys:
            var status: Error=src.page_status(key)
            if status==ERR_BUSY:
                pages_ready=false
                src.request_page(key)
            elif status!=OK:
                return false
        if pages_ready:
            return true
        OS.delay_msec(1)
    return false

func _compare(src,lod: int,desired: Dictionary) -> bool:
    var before: Dictionary=src.stats()
    var a: Dictionary=G.generate(src,1,1,lod,desired)
    var middle: Dictionary=src.stats()
    var b: Dictionary=G.generate_with_view(src,1,1,lod,desired)
    var after: Dictionary=src.stats()
    if a["error"]!=OK or b["error"]!=OK:
        return false
    for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:
        if a["arrays"][slot]!=b["arrays"][slot]:
            return false
    return a["collision_heights"]==b["collision_heights"] and middle["lru_touches"]-before["lru_touches"]==middle["direct_height_reads"]-before["direct_height_reads"] and after["lru_touches"]-middle["lru_touches"]==9 and after["tile_view_reads"]-middle["tile_view_reads"]==middle["direct_height_reads"]-before["direct_height_reads"]

func _fail(msg: String,src,b) -> void:
    src.close()
    b.close()
    push_error("Tile view: "+msg)
    quit(1)
