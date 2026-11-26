extends "res://addons/terra_forge/tests/test_i0_integrated_route.gd"
## M5 uses exact I0 physical route, F reference, only page cap varies.
## Counter snapshots and matched route, not an equal-work FPS claim.
func _run() -> void:
    for format in _formats():
        _builder=V1.new() if format==0 else V2.new()
        var err: Error=_builder.start(Vector2i(576,576),true) if format==0 else _builder.start(Vector2i(576,576))
        if err!=OK:
            _fail("M5 fixture")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=_builder.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("M5 fixture result")
            return
        var order: Array[int]=[16,24,32]
        if format==1:
            order.reverse()
        var path: String=made["directory"]
        var manifest: String=path.path_join("manifest.tfm" if format==0 else "manifest.tfm2")
        var fingerprint: String=FileAccess.get_sha256(manifest)
        if fingerprint.is_empty():
            _fail("M5 manifest")
            return
        for page_cap in order:
            var before: float=Performance.get_monitor(Performance.MEMORY_STATIC)
            var result: Dictionary=await _route(path,format,0,page_cap)
            if result.get("error",FAILED)!=OK or result.get("page_cap",-1)!=page_cap or not result.get("shutdown_clean",false) or FileAccess.get_sha256(manifest)!=fingerprint:
                _fail("M5 "+str([format,page_cap,result]))
                return
            var source: Dictionary=result["source"]
            var reads: int=int(source.get("disk_reads",-1))
            var verified: int=int(source.get("pages_verified_on_demand",-1))
            if reads<0 or result["peak_pages"]>page_cap or result["missing_rays"]!=0 or result["airborne_ticks"]!=0:
                _fail("M5 counters")
                return
            print("M5_PAGE_CAP ",JSON.stringify({"format":format+1,"cap":page_cap,"reads":reads,"accepted_reloads":maxi(0,reads-verified) if verified>=0 else null,"static_before_bytes":before if before>0 else null,"static_after_shutdown_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"metrics":result,"notes":"Static before/after is not peak RSS; fixed physical route, optional work can differ; accepted reads are not physical disk transactions."}))
        _builder.close()
        _builder=null
    print("PASS: M5 bounded page capacity matrix and identical physical route")
    quit(0)
