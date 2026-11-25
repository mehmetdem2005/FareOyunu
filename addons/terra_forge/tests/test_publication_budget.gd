extends SceneTree
const A=preload("res://addons/terra_forge/core/publication_accounting.gd")
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const W=preload("res://addons/terra_forge/core/geometry_worker.gd")
const B=preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")
const ZERO: Dictionary={"vertices":0,"triangles":0,"mesh_bytes":0,"shape_bytes":0,"total_bytes":0,"meshes":0,"shapes":0}

func _initialize() -> void:
    var a=A.new()
    a.configure_budget(true,65536,1000)
    a.begin_pump(3)
    if not a.admit(0):
        _fail("first oversized tile",null,null)
        return
    a.record(0,A.expected(0),400,200,700)
    if a.admit(2):
        _fail("oversize must stand alone",null,null)
        return
    a.end_pump(ZERO)
    a.begin_pump(3)
    if not a.admit(2):
        _fail("reset",null,null)
        return
    a.record(2,A.expected(2),700,200,1100)
    if a.admit(2):
        _fail("time stop",null,null)
        return
    a.end_pump(ZERO)
    a.begin_pump(3)
    a.record(1,A.expected(1),100,50,200)
    if not a.admit(1) or a.admit(0):
        _fail("remaining byte allowance",null,null)
        return
    a.record(1,A.expected(1),100,50,200)
    if a.admit(2):
        _fail("third exceeds allowance",null,null)
        return
    a.end_pump(ZERO)
    var s: Dictionary=a.report(ZERO)
    if s["first_item_byte_exceptions"]!=1 or s["over_byte_pumps"]!=1 or s["over_time_pumps"]!=1 or s["time_stop_checks"]!=1 or s["byte_deferral_checks"]!=3 or s["count_stop_checks"]!=0 or s["peak_pump_count"]!=2:
        _fail("policy accounting",null,null)
        return
    # Isolate count, exact equality boundaries, precedence and disabled mode.
    # record() takes injected measured durations: no dependence on host speed.
    var policy: Dictionary=_deterministic_policy()
    if policy["error"]!=OK:
        _fail("deterministic policy "+str(policy),null,null)
        return
    print("PUBLICATION_POLICY_TRACE ",JSON.stringify(policy))
    for format in [0,1]:
        var builder: Variant
        if format==0:
            builder=V1.new()
        else:
            builder=V2.new()
        var err: Error=builder.start(Vector2i(576,576),true) if format==0 else builder.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start",null,builder)
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=builder.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture",null,builder)
            return
        var folder: String=made["directory"]
        for mode in [0,5]:
            var p=P.new()
            p.region_index_format=format
            p.sampling_strategy=mode
            p.enforce_publication_budget=true
            p.publication_byte_target=65536
            p.publication_time_target_us=8000
            p.geometry_job_limit=4
            p.tile_updates_per_frame=3
            p.max_tile_work_ms=8.0
            if p.start_preview(folder,16,4)!=OK:
                _fail("open",p,builder)
                return
            var x=Vector2i(15,15)
            var y=Vector2i(16,15)
            var z=Vector2i(15,16)
            var q=Vector2i(16,16)
            var desired: Dictionary={x:0,y:0,z:1,q:2}
            p._anchor=Vector3(496,20,496)
            p._desired_tiles=desired.duplicate()
            p._pending_tiles.clear()
            var pages: Array[Vector2i]=[]
            for k in desired:
                p._pending_tiles[k]=true
                for page in G.required_pages(p._reader,k.x,k.y,desired[k]):
                    if not pages.has(page):
                        pages.append(page)
            if not _load(p,pages):
                _fail("resident preload",p,builder)
                return
            if mode==5:
                # Fill original bounded ready queue deterministically.
                for k in desired:
                    var job: Dictionary=p._geometry_worker.submit(p._reader,k,desired[k],desired)
                    if job["error"]!=OK:
                        _fail("ready setup",p,builder)
                        return
                    p._geometry_jobs[k]=job["id"]
                for step in range(4000):
                    if p._geometry_worker.stats()["finished"]==4:
                        break
                    OS.delay_msec(1)
                if p._geometry_worker.stats()["finished"]!=4:
                    _fail("ready timeout",p,builder)
                    return
                var ids: Array[int]=p._geometry_worker.active_ids()
                var deferred: Dictionary=p._geometry_worker.poll(p._reader,desired,4096)
                if deferred["error"]!=ERR_BUSY or not deferred.get("deferred_bytes",false) or ids!=p._geometry_worker.active_ids() or p._geometry_worker.stats()["delivered"]!=0:
                    _fail("retained ready queue",p,builder)
                    return
            var seen: int=0
            var previous_bytes: int=0
            var empty_before_focus: int=0
            var outer_time_empty_pumps: int=0
            var max_wall_us: int=0
            for step in range(4000):
                p._last_sync_msec=Time.get_ticks_msec()
                var started_us: int=Time.get_ticks_usec()
                var status: Dictionary=p.pump_stream()
                var wall_us: int=Time.get_ticks_usec()-started_us
                max_wall_us=maxi(max_wall_us,wall_us)
                if status["error"]!=OK:
                    _fail("pump",p,builder)
                    return
                var pump_publication: Dictionary=p.stats()["publication"]
                var published: int=int(pump_publication["publication_count"])-seen
                var new_bytes: int=int(pump_publication["total_source_bytes"])-previous_bytes
                # A slow pump may do no publication at all. The FIRST actual
                # publication must still be the focus shape, alone.
                if seen==0:
                    if published==0:
                        empty_before_focus+=1
                    elif published!=1 or not p._tiles.has(x) or not p.has_collision_at(Vector3(496,20,496)):
                        _fail("focus first actual publication",p,builder)
                        return
                # Assert the effect of every budget decision, independent of
                # which guard (outer elapsed, count, publication time, byte)
                # stopped the loop first. Oversized first item stands alone.
                if published<0 or published>3 or new_bytes<0 or (new_bytes>65536 and (published!=1 or new_bytes!=116052)):
                    _fail("per-pump admission invariant "+str(pump_publication),p,builder)
                    return
                if published==0 and wall_us>=8000:
                    outer_time_empty_pumps+=1
                seen=int(pump_publication["publication_count"])
                previous_bytes=int(pump_publication["total_source_bytes"])
                if p._pending_tiles.is_empty() and p._geometry_jobs.is_empty():
                    break
                OS.delay_msec(1)
            var pub: Dictionary=p.stats()["publication"]
            if seen!=4 or pub["publication_count"]!=4 or pub["first_item_byte_exceptions"]!=2 or pub["over_byte_pumps"]!=2 or pub["peak_pump_source_bytes"]!=116052 or pub["over_count_pumps"]!=0 or pub["resident"]["shapes"]!=2 or pub["resident"]["meshes"]!=4 or pub["total_source_bytes"]!=269384 or pub["lod_counts"]!=[2,1,1]:
                _fail("bounded progress "+str(pub),p,builder)
                return
            if mode==5 and (p._geometry_worker.stats()["submitted"]!=4 or p._geometry_worker.stats()["delivered"]!=4 or p._geometry_worker.stats()["slots"]!=0):
                _fail("no duplicate/rebuild after defer",p,builder)
                return
            for k in desired:
                var expected: Dictionary=G.generate(p._reader,k.x,k.y,desired[k],desired)
                var tile: Dictionary=p._tiles[k]
                var arrays: Array=tile["visual"].mesh.surface_get_arrays(0)
                if expected["error"]!=OK or arrays[Mesh.ARRAY_VERTEX]!=expected["arrays"][Mesh.ARRAY_VERTEX] or arrays[Mesh.ARRAY_INDEX]!=expected["arrays"][Mesh.ARRAY_INDEX]:
                    _fail("resource parity",p,builder)
                    return
                if desired[k]==0 and tile["collision"].shape.map_data!=expected["collision_heights"]:
                    _fail("shape parity",p,builder)
                    return
            # Keep the real wall-time overrun in the evidence. This is not
            # a hard realtime gate; a single native call is indivisible.
            print("PUBLICATION_BUDGET_CASE ",JSON.stringify({"format":format+1,"mode":mode,"publication":pub,"worker":p.stats()["geometry_worker"],"empty_pumps_before_focus":empty_before_focus,"empty_pumps_wall_ge_8ms":outer_time_empty_pumps,"max_observed_pump_wall_us":max_wall_us,"integration_byte_deferral_observed":int(pub["byte_deferral_checks"])>0,"timing_note":"Wall-time diagnostic; reason for outer guard exit is not inferred."}))
            p.stop_preview()
            if not p.stats()["publication"].is_empty() or p._publication_budget_active:
                _fail("reset",p,builder)
                return
            p.free()
        builder.close()
    print("PASS: optional publication budget, oversized first-item progress, measured time stop, retained worker ready IDs, priority and exact resource parity")
    quit(0)

func _deterministic_policy() -> Dictionary:
    var a=A.new()
    var item: Dictionary=A.expected(2)
    var size: int=int(item["total_bytes"])
    # Count limit only.
    a.configure_budget(true,65536,8000)
    a.begin_pump(1)
    if not a.admit(2):
        return {"error":FAILED,"case":"count first"}
    a.record(2,item,1,1,1)
    if a.admit(2):
        return {"error":FAILED,"case":"count bypass"}
    a.end_pump(ZERO)
    # Exact byte allowance: equal fits, next byte gate stops.
    a.configure_budget(true,size*2,8000)
    a.begin_pump(4)
    a.record(2,item,1,1,1)
    if a.admission_bytes()!=size or not a.admit(2):
        return {"error":FAILED,"case":"equal byte allowance"}
    a.record(2,item,1,1,1)
    if a.admit(2):
        return {"error":FAILED,"case":"exact byte boundary"}
    a.end_pump(ZERO)
    # Equality at time threshold, byte room remains.
    a.configure_budget(true,65536,8000)
    a.begin_pump(4)
    a.record(2,item,1,1,8000)
    if a.admit(2):
        return {"error":FAILED,"case":"exact time boundary"}
    a.end_pump(ZERO)
    # Simulate the Android spike without waiting. Both limits reached;
    # time has precedence over bytes, and actual overrun remains recorded.
    a.configure_budget(true,65536,8000)
    a.begin_pump(3)
    if not a.admit(0):
        return {"error":FAILED,"case":"oversize first"}
    a.record(0,A.expected(0),526,197,128279)
    if a.admit(2):
        return {"error":FAILED,"case":"time-byte precedence"}
    a.end_pump(ZERO)
    var enabled: Dictionary=a.report(ZERO)
    if enabled["count_stop_checks"]!=1 or enabled["time_stop_checks"]!=2 or enabled["byte_deferral_checks"]!=1 or enabled["over_time_pumps"]!=1 or enabled["max_time_excess_us"]!=120279 or enabled["first_item_byte_exceptions"]!=1 or enabled["over_byte_pumps"]!=1 or enabled["over_count_pumps"]!=0:
        return {"error":FAILED,"case":"independent counter conservation","report":enabled}
    # Disabled observation must not unexpectedly restrict work.
    a.configure_budget(false,1,1)
    a.begin_pump(1)
    a.record(2,item,1,1,100)
    if a.admission_bytes()!=-1 or not a.admit(0):
        return {"error":FAILED,"case":"disabled mode"}
    a.end_pump(ZERO)
    return {"error":OK,"cases":5,"synthetic_android_spike_us":128279,"enabled_report":enabled,"disabled_unrestricted":true}

func _load(p,keys: Array[Vector2i]) -> bool:
    for step in range(4000):
        p._reader.poll_results(4)
        p._reader.prioritize_resident(keys)
        var pages_ready: bool=true
        for k in keys:
            var status: Error=p._reader.page_status(k)
            if status==ERR_BUSY:
                pages_ready=false
                p._reader.request_page(k)
            elif status!=OK:
                return false
        if pages_ready:
            return true
        OS.delay_msec(1)
    return false

func _fail(msg: String,p,b) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("Publication budget: "+msg)
    quit(1)
