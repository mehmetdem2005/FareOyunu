extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")
const ASYNC=preload("res://addons/terra_forge/core/async_region_source.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const W=preload("res://addons/terra_forge/core/geometry_worker.gd")
const TARGETS: Array[int]=[0,65536,131072,262144]

func _initialize() -> void:
    print("PUB_COMPARE_ENV ",JSON.stringify({"cpu":OS.get_processor_name(),"os":OS.get_name(),"godot":Engine.get_version_info().get("string",""),"notes":"same G priority worker mode5, cap4, observation enabled all cases, warm equal-work separate from fixed 4/8ms cadence; no GPU/raycast"}))
    for format in [0,1]:
        var b: Variant=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start",b)
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture",b)
            return
        var folder: String=made["directory"]
        if not _stale_deferred(folder,format):
            _fail("stale deferred ready result",b)
            return
        var reference: Dictionary={}
        for updates in [2,3]:
            var order: Array[int]=TARGETS.duplicate()
            if (format==0)!=(updates==2):
                order.reverse()
            for target in order:
                var opts: Dictionary=_options(target,updates)
                var result: Dictionary=EQ.run(folder,format,5,4,opts)
                if result.get("error",FAILED)!=OK or (not reference.is_empty() and result["fingerprints"]!=reference):
                    _fail("equal work "+str(result),b)
                    return
                reference=result["fingerprints"]
                if not _check(result["publication"],target,updates,36) or result["worker"]["submitted"]!=36 or result["worker"]["delivered"]!=36 or result["worker"]["dropped"]!=0:
                    _fail("equal budget/counter conservation",b)
                    return
                result["target"]=target
                print("PUB_COMPARE_EQUAL ",JSON.stringify(result))
        # Slow and fast sections already exist in each route. 4ms versus
        # 8ms also changes wall-clock traversal rate, with lateness logged.
        for config in [[2,8000],[3,8000],[3,4000]]:
            var updates: int=config[0]
            var cadence: int=config[1]
            var order: Array[int]=TARGETS.duplicate()
            if (format==1)!=(cadence==4000):
                order.reverse()
            for target in order:
                var result: Dictionary=TRACE.run(folder,format,5,16,4,cadence,true,_options(target,updates))
                if result.get("error",FAILED)!=OK or not _check(result.get("publication",{}),target,updates,int(result.get("mesh_builds",0))):
                    _fail("trace "+str(result),b)
                    return
                if result["publication"]["pumps"]!=144:
                    _fail("trace pump accounting",b)
                    return
                result["target"]=target
                print("PUB_COMPARE_TRACE ",JSON.stringify(result))
        b.close()
    print("PASS: same G worker budget on/off, 16 warm equal-work runs, 24 fixed-cadence traces, retained then stale result discarded")
    quit(0)

func _options(target: int,updates: int) -> Dictionary:
    return {"enabled":target>0,"bytes":target if target>0 else 131072,"time_us":1000,"updates":updates}

func _check(p: Dictionary,target: int,updates: int,count: int) -> bool:
    if p.is_empty() or p["publication_count"]!=count or p["peak_pump_count"]>updates or p["over_count_pumps"]!=0 or p["gpu_time_ms"]!=null or p["budget_enabled"]!=(target>0):
        return false
    if target>0:
        if p["peak_pump_source_bytes"]>maxi(target,116052) or p["over_byte_pumps"]!=p["first_item_byte_exceptions"]:
            return false
    var lod: Array=p["lod_counts"]
    return lod[0]+lod[1]+lod[2]==count and p["total_source_bytes"]==lod[0]*116052+lod[1]*29264+lod[2]*8016

func _stale_deferred(folder: String,format: int) -> bool:
    var src=ASYNC.new()
    var w=W.new()
    var err: Error=src.open(folder,16,4,false) if format==0 else src.open_v2(folder,16,4,false,2)
    var ok: bool=err==OK and w.start(src,2,true)==OK
    var key=Vector2i(15,15)
    var neighbor=Vector2i(16,15)
    var desired: Dictionary={key:0,neighbor:0}
    if ok:
        ok=_load(src,G.required_pages(src,key.x,key.y,0))
    if ok:
        var submitted: Dictionary=w.submit(src,key,0,desired)
        ok=submitted["error"]==OK
        for step in range(4000):
            if w.stats()["finished"]==1:
                break
            OS.delay_msec(1)
        ok=ok and w.stats()["finished"]==1
        if ok:
            var denied: Dictionary=w.poll(src,desired,65536)
            ok=denied["error"]==ERR_BUSY and denied.get("deferred_bytes",false) and w.active_ids()==[submitted["id"]] and w.stats()["delivered"]==0
            desired.erase(neighbor)
            var stale: Dictionary=w.poll(src,desired)
            ok=ok and stale["error"]==ERR_BUSY and w.stats()["dropped"]==1 and w.stats()["slots"]==0 and w.stats()["delivered"]==0
            var next: Dictionary=w.submit(src,key,0,desired)
            ok=ok and next["error"]==OK
            var current: Dictionary={}
            for step in range(4000):
                current=w.poll(src,desired)
                if current["error"]!=ERR_BUSY:
                    break
                OS.delay_msec(1)
            ok=ok and current.get("error",FAILED)==OK
            if ok:
                ok=current["result"]["id"]==next["id"] and current["result"]["geometry"]["error"]==OK and w.stats()["submitted"]==2 and w.stats()["delivered"]==1 and w.stats()["dropped"]==1 and w.stats()["slots"]==0
    w.close()
    src.close()
    return ok

func _load(src,keys: Array[Vector2i]) -> bool:
    for step in range(4000):
        src.poll_results(4)
        src.prioritize_resident(keys)
        var ready: bool=true
        for key in keys:
            var status: Error=src.page_status(key)
            if status==ERR_BUSY:
                ready=false
                src.request_page(key)
            elif status!=OK:
                return false
        if ready:
            return true
        OS.delay_msec(1)
    return false

func _fail(msg: String,b) -> void:
    b.close()
    push_error("Publication comparison: "+msg)
    quit(1)
