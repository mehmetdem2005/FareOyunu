extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
var p
var b

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    b=V1.new()
    if b.start(Vector2i(576,576),true)!=OK:
        _fail("fixture start")
        return
    var made: Dictionary={}
    for i in range(15000):
        made=b.take_result()
        if made.get("error",FAILED)!=ERR_BUSY:
            break
        OS.delay_msec(2)
    if made.get("error",FAILED)!=OK:
        _fail("fixture")
        return
    for cap in [0,4,8]:
        p=P.new()
        p.sampling_strategy=7
        p.hybrid_idle_pool_limit=cap
        p.max_visible_tiles=12
        root.add_child(p)
        if p.start_preview(made["directory"],64,4)!=OK:
            _fail("open")
            return
        p.set_process(false)
        var desired: Dictionary={}
        for x in range(10,14):
            for z in range(10,13):
                desired[Vector2i(x,z)]=0
        p._desired_tiles=desired.duplicate()
        p._pending_tiles.clear()
        var pages: Array[Vector2i]=[]
        for key in desired:
            for page in G.required_pages(p._reader,key.x,key.y,0):
                if not pages.has(page):
                    pages.append(page)
        if not EQ._load(p,pages):
            _fail("warm")
            return
        var geometry: Dictionary={}
        for key in desired:
            geometry[key]=G.generate(p._reader,key.x,key.y,0,desired)
            if geometry[key]["error"]!=OK:
                _fail("geometry")
                return
        for cycle in range(12):
            for key in desired:
                if p._publish_geometry(key,0,geometry[key],Time.get_ticks_usec())!=OK:
                    _fail("publish")
                    return
            await physics_frame
            await physics_frame
            for key in desired:
                if not _ray(key):
                    _fail("live ray")
                    return
                p._retire_tile(key)
            if p._idle_pool.size()!=cap or not p._tiles.is_empty():
                _fail("overflow cap")
                return
            await physics_frame
            await physics_frame
            for key in desired:
                if _ray(key):
                    _fail("ghost ray")
                    return
        var stats: Dictionary=p.stats()["idle_pool"]
        if stats["peak"]!=cap or stats["hits"]!=cap*11 or stats["idle"]!=cap:
            _fail("reuse/overflow totals "+str(stats))
            return
        print("POOL_OVERFLOW ",JSON.stringify({"cap":cap,"cycles":12,"publications":144,"ray_checks":288,"pool":stats,"overflow_frees":12*(12-cap)}))
        p.stop_preview()
        if not p._idle_pool.is_empty():
            _fail("stop")
            return
        p.free()
        p=null
    b.close()
    b=null
    print("PASS: 12-tile overflow, cap0/4/8, real rays, ghost absence, exact reuse and stop")
    quit(0)

func _ray(key: Vector2i) -> bool:
    var point:=Vector3(key.x*32+16,0,key.y*32+16)
    var hit: Dictionary=p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*128,point-Vector3.UP*128))
    return not hit.is_empty()

func _fail(msg: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("Pool overflow: "+msg)
    quit(1)
