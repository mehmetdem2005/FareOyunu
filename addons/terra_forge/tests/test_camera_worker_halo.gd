extends SceneTree
## Camera-only comparison: separate flag, same route and cadence, no support.
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const TRACE=preload("res://addons/terra_forge/core/sampling_stream_trace.gd")

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
        var directory: String=made["directory"]
        # Disallow accidental activation on A and G/H, including legacy.
        var p=P.new()
        p.region_index_format=format
        p.enable_camera_worker_cropped_halo=true
        for mode in [0,1,2,5,6,-1]:
            p.sampling_strategy=mode
            if p.start_preview(directory,9,4)!=ERR_INVALID_PARAMETER or p.stats()["active"]:
                p.free()
                _fail(b,"unsupported camera flag")
                return
        p.free()
        for mode in [3,4]:
            for cache in [9,16]:
                var order: Array[bool]=[false,true,true,false] if cache==9 else [true,false,false,true]
                for trial in range(order.size()):
                    var crop: bool=order[trial]
                    var result: Dictionary=TRACE.run(directory,format,mode,cache,2,8000,false,{"camera_crop":crop})
                    if result.get("error",FAILED)!=OK or result.get("camera_crop")!=crop or (crop and int(result.get("camera_cropped_submissions",0))<=0) or (not crop and int(result.get("camera_cropped_submissions",0))!=0):
                        _fail(b,"trace "+str(result))
                        return
                    result["trial"]=trial
                    print("CAMERA_HALO_TRACE ",JSON.stringify(result))
        b.close()
    print("PASS: E/F camera halo opt-in, invalid mode rejection, 32 paired fixed-cadence traces")
    quit(0)

func _fail(b,msg: String) -> void:
    b.close()
    push_error("Camera halo: "+msg)
    quit(1)
