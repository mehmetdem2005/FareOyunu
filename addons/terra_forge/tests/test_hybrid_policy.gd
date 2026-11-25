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
        p.sampling_strategy=7
        p.hybrid_topology_cache=true
        if p.start_preview(folder,9,4)!=ERR_INVALID_PARAMETER or p.stats()["active"]:
            p.free()
            _fail(b,"topology without scalar accepted")
            return
        p.hybrid_scalar_sampling=true
        p.hybrid_cropped_halo=true
        p.sampling_strategy=4
        if p.start_preview(folder,9,4)!=ERR_INVALID_PARAMETER or p.stats()["active"]:
            p.free()
            _fail(b,"I policy leaked to F")
            return
        p.sampling_strategy=7
        if p.start_preview(folder,9,4)!=OK:
            p.free()
            _fail(b,"I H open")
            return
        p.hybrid_scalar_sampling=false
        p.hybrid_topology_cache=false
        p.hybrid_cropped_halo=false
        var pinned: Dictionary=p.stats()
        if pinned["sampling_strategy"]!=7 or pinned["effective_sampling_strategy"]!=6 or not pinned["hybrid_cropped_halo_active"] or not pinned["geometry_worker"]["scalar_sampling"] or pinned["geometry_worker"]["topology_cache_bytes"]!=32256:
            p.free()
            _fail(b,"live policy mutation")
            return
        p.stop_preview()
        if p.stats()["hybrid_cropped_halo_active"] or p.stats()["hybrid_cropped_submissions"]!=0:
            p.free()
            _fail(b,"stop reset")
            return
        p.free()
        var reference: Dictionary={}
        for backend in [4,5,6]:
            for crop in [false,true]:
                for cap in [1,2,4]:
                    var policy: Dictionary={"scalar":backend>=5,"topology":backend==6,"crop":crop}
                    var result: Dictionary=EQ.run(folder,format,7,cap,{},false,false,policy)
                    if result.get("error",FAILED)!=OK or result["effective_sampling_strategy"]!=backend or int(result["hybrid_cropped_submissions"])!=(36 if crop else 0) or (not reference.is_empty() and result["fingerprints"]!=reference):
                        _fail(b,"policy parity "+str(result))
                        return
                    reference=result["fingerprints"]
                    var stats: Dictionary=result["worker"]
                    if stats["scalar_sampling"]!=(backend>=5) or stats["topology_cache_bytes"]!=(32256 if backend==6 else 0) or stats["submitted"]!=36 or stats["delivered"]!=36 or stats["dropped"]!=0 or stats["slots"]!=0 or stats["peak_slots"]>cap:
                        _fail(b,"worker accounting")
                        return
                    print("HYBRID_POLICY_EQUAL ",JSON.stringify(result))
        b.close()
    print("PASS: I independent session scalar/topology/halo policies, 36 matched arms, invalid and pinned policy")
    quit(0)

func _fail(b,msg: String) -> void:
    b.close()
    push_error("I policies: "+msg)
    quit(1)
