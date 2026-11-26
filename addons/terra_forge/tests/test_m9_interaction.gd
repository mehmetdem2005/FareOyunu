extends "res://addons/terra_forge/tests/test_i0_integrated_route.gd"
## M9: same physical route, fixed cap2 worker, F vs I-G crop vs I-H crop,
## crossed with page16/32; three arms per process to bound timeout.
func _page_cap() -> int:
    return 16
func _run() -> void:
    var format: int=_formats()[0]
    var cap: int=_page_cap()
    _builder=V1.new() if format==0 else V2.new()
    var err: Error=_builder.start(Vector2i(576,576),true) if format==0 else _builder.start(Vector2i(576,576))
    if err!=OK:
        _fail("M9 fixture")
        return
    var made: Dictionary={}
    for attempt in range(15000):
        made=_builder.take_result()
        if made["error"]!=ERR_BUSY:
            break
        OS.delay_msec(2)
    if made.get("error",FAILED)!=OK:
        _fail("M9 fixture result")
        return
    var directory: String=made["directory"]
    var manifest: String=directory.path_join("manifest.tfm" if format==0 else "manifest.tfm2")
    var hash: String=FileAccess.get_sha256(manifest)
    var order: Array[int]=[0,2,3]
    if (format==1)!=(cap==32):
        order.reverse()
    var reference: Array=[]
    for arm in order:
        var r: Dictionary=await _route(directory,format,arm,cap)
        if r.get("error",FAILED)!=OK or r.get("page_cap",0)!=cap or r["ticks"]!=720 or r["missing_rays"]!=0 or r["airborne_ticks"]!=0 or not r["shutdown_clean"] or r["peak_pages"]>cap:
            _fail("M9 route "+str([format,cap,arm,r]))
            return
        # _route verifies all ordered waypoints. A safe wait can shift the
        # arrival ticks, which remain in the trace as a measured outcome.
        var route: Array=[r["goals"].size(),r["support_revisions"],r["tier_transitions"],r["camera_shifts"]]
        if not reference.is_empty() and route!=reference:
            _fail("M9 unmatched physical route "+str([reference,route]))
            return
        reference=route
        var source: Dictionary=r["source"]
        var builds: int=r["mesh_builds"]
        var reads: int=source["disk_reads"]
        if builds<=0 or reads<=0 or int(source["resident_float_bytes"])>cap*4096:
            _fail("M9 counters")
            return
        print("M9_INTERACTION ",JSON.stringify({"format":format+1,"page_cap":cap,"arm":arm,"reads_per_build":float(reads)/float(builds),"metrics":r,"note":"Matched physical waypoints and route counters. Arrival and denial ticks record timing. Optional work may vary. Reads count accepted results. Memory counts resident Float32 payload."}))
    if hash.is_empty() or FileAccess.get_sha256(manifest)!=hash:
        _fail("M9 source changed")
        return
    _builder.close()
    _builder=null
    print("PASS: M9 guarded hybrid and cache interaction")
    quit(0)
