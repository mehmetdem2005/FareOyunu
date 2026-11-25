extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
var builder
var p

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for format in [0,1]:
        builder=V1.new() if format==0 else V2.new()
        var err: Error=builder.start(Vector2i(576,576),true) if format==0 else builder.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=builder.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture")
            return
        for observe in [false,true]:
            var order: Array=[false,true,true,false] if format==0 else [true,false,false,true]
            for trial in range(4):
                var detached: bool=order[trial]
                p=P.new()
                p.region_index_format=format
                p.sampling_strategy=7
                p.hybrid_detached_publication=detached
                p.observe_publication_micro=observe
                p.position=Vector3(13,7,-19)
                p.rotation.y=0.37
                root.add_child(p)
                if p.start_preview(made["directory"],16,4)!=OK:
                    _fail("open")
                    return
                p.set_process(false)
                p.hybrid_detached_publication=not detached
                p._desired_tiles=EQ.DESIRED.duplicate()
                p._pending_tiles.clear()
                var pages: Array[Vector2i]=[]
                for key in EQ.DESIRED:
                    for page in G.required_pages(p._reader,key.x,key.y,EQ.DESIRED[key]):
                        if not pages.has(page):
                            pages.append(page)
                if not EQ._load(p,pages):
                    _fail("warm")
                    return
                var geometry: Dictionary={}
                for key in EQ.DESIRED:
                    geometry[key]=G.generate(p._reader,key.x,key.y,EQ.DESIRED[key],EQ.DESIRED)
                    if geometry[key]["error"]!=OK:
                        _fail("geometry")
                        return
                var hist=HIST.new()
                var deletion=HIST.new()
                var total_us: int=0
                var reference: Dictionary={}
                # One warmup + 16 identical batches of four fresh tiles.
                for batch in range(17):
                    for key in EQ.DESIRED:
                        var started: int=Time.get_ticks_usec()
                        var status: Error=p._publish_geometry(key,EQ.DESIRED[key],geometry[key],started)
                        var elapsed: int=Time.get_ticks_usec()-started
                        if status!=OK:
                            _fail("publish")
                            return
                        if batch>0:
                            total_us+=elapsed
                            hist.add(float(elapsed)/1000.0)
                        var tile: Dictionary=p._tiles[key]
                        if tile["root"].get_parent()!=p or not tile["visual"].is_inside_tree() or not tile["collision"].is_inside_tree():
                            _fail("subtree ownership")
                            return
                    var hashes: Dictionary=EQ._fingerprints(p)
                    if hashes.size()!=4 or (not reference.is_empty() and hashes!=reference):
                        _fail("resource fingerprint")
                        return
                    reference=hashes
                    await physics_frame
                    await physics_frame
                    for key in EQ.DESIRED:
                        var tile: Dictionary=p._tiles[key]
                        var local:=Vector3(key.x*32+16,0,key.y*32+16)
                        var hit: Dictionary=p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p.to_global(local+Vector3.UP*128),p.to_global(local-Vector3.UP*128)))
                        if (not hit.is_empty())!=(EQ.DESIRED[key]==0):
                            _fail("actual collision presence")
                            return
                        if not hit.is_empty() and (not p.is_ancestor_of(hit["collider"]) or absf(p.to_local(hit["position"]).y-V2.sample(int(local.x),int(local.z)))>0.002):
                            _fail("actual collision height")
                            return
                        var began: int=Time.get_ticks_usec()
                        tile["root"].free()
                        if batch>0:
                            deletion.add(float(Time.get_ticks_usec()-began)/1000.0)
                    p._tiles.clear()
                    await physics_frame
                    await physics_frame
                    var old_hit: Dictionary=p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p.to_global(Vector3(496,128,496)),p.to_global(Vector3(496,-128,496))))
                    if not old_hit.is_empty():
                        _fail("ghost collision")
                        return
                var stats: Dictionary=p.stats()
                var micro: Dictionary=p.publication_micro_profile()
                if stats["mesh_builds"]!=68 or stats["detached_publications"]!=(68 if detached else 0) or stats["detached_publication_active"]!=detached or (observe and (micro["success"]!=68 or micro["invalid_samples"]!=0)):
                    _fail("accounting")
                    return
                print("DETACHED_PUBLICATION ",JSON.stringify({"format":format+1,"trial":trial,"detached":detached,"instrumented":observe,"fresh_tiles":64,"mean_us_per_tile":float(total_us)/64.0,"publication_ms":hist.report(),"deletion_ms":deletion.report(),"micro":micro,"fingerprints":reference,"physics_presence_checks":68,"ghost_checks":17}))
                p.stop_preview()
                p.free()
                p=null
        builder.close()
        builder=null
    print("PASS: detached subtree on/off 16 matched fresh-publication arms, 1024 measured tiles, real in-tree ray/ghost checks, isolated instrumentation")
    quit(0)

func _fail(msg: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if builder!=null:
        builder.close()
    push_error("Detached publication: "+msg)
    quit(1)
