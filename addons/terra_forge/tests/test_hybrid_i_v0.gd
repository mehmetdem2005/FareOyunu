extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")

func _initialize() -> void:
    for format in [0,1]:
        var b: Variant
        if format==0:
            b=V1.new()
        else:
            b=V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail(b,"fixture start")
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail(b,"fixture")
            return
        var folder: String=made["directory"]
        var p=P.new()
        p.region_index_format=format
        if p.resolved_sampling_strategy()!=0:
            p.free()
            _fail(b,"legacy default changed")
            return
        p.sampling_strategy=8
        if p.start_preview(folder,9,4)!=ERR_INVALID_PARAMETER or p.stats()["active"]:
            p.free()
            _fail(b,"invalid mode accepted")
            return
        p.sampling_strategy=7
        p.enable_camera_worker_cropped_halo=true
        if p.start_preview(folder,9,4)!=ERR_INVALID_PARAMETER or p.stats()["active"]:
            p.free()
            _fail(b,"I-v0 camera flag must stay independent")
            return
        p.enable_camera_worker_cropped_halo=false
        if p.start_preview(folder,9,4)!=OK:
            p.free()
            _fail(b,"I open")
            return
        p.sampling_strategy=6
        var s: Dictionary=p.stats()
        if s["sampling_strategy"]!=7 or s["effective_sampling_strategy"]!=4 or s["geometry_worker"]["scalar_sampling"] or s["geometry_worker"]["topology_cache_bytes"]!=0:
            p.free()
            _fail(b,"I session selection changed")
            return
        p.stop_preview()
        if p.stats()["sampling_strategy"]!=6 or p.stats()["effective_sampling_strategy"]!=6 or not p.stats()["geometry_worker"].is_empty():
            p.free()
            _fail(b,"stop reset")
            return
        p.free()
        var reference: Dictionary={}
        for cap in [1,2,4]:
            for mode in [4,7]:
                var result: Dictionary=EQ.run(folder,format,mode,cap)
                if result.get("error",FAILED)!=OK or result["effective_sampling_strategy"]!=4 or (not reference.is_empty() and result["fingerprints"]!=reference):
                    _fail(b,"F/I resource parity "+str(result))
                    return
                reference=result["fingerprints"]
                var stats: Dictionary=result["worker"]
                if stats["scalar_sampling"] or stats["topology_cache_bytes"]!=0 or stats["submitted"]!=36 or stats["delivered"]!=36 or stats["dropped"]!=0 or stats["slots"]!=0 or stats["peak_slots"]>cap:
                    _fail(b,"F/I worker parity")
                    return
                print("HYBRID_I_V0_EQUAL ",JSON.stringify(result))
        b.close()
    print("PASS: I-v0 F-equivalent selection and 12 matched resource arms; serialized old IDs retained")
    quit(0)

func _fail(b,msg: String) -> void:
    b.close()
    push_error("I-v0: "+msg)
    quit(1)
