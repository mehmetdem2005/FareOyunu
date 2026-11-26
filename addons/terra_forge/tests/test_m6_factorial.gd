extends SceneTree
## Matched completed work, cap2 only, independent crop/scalar/topology.
## Each block reverses the six policy arms, not a fixed-time FPS comparison.
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const ARMS: Array[Dictionary]=[
    {"name":"I-F full","scalar":false,"topology":false,"crop":false},
    {"name":"I-F crop","scalar":false,"topology":false,"crop":true},
    {"name":"I-G full","scalar":true,"topology":false,"crop":false},
    {"name":"I-G crop","scalar":true,"topology":false,"crop":true},
    {"name":"I-H full","scalar":true,"topology":true,"crop":false},
    {"name":"I-H crop","scalar":true,"topology":true,"crop":true}
]
func _formats() -> Array[int]:
    return [0]
func _initialize() -> void:
    for format in _formats():
        var b: Variant=V1.new() if format==0 else V2.new()
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
        var manifest: String=folder.path_join("manifest.tfm" if format==0 else "manifest.tfm2")
        var hash: String=FileAccess.get_sha256(manifest)
        var reference: Dictionary={}
        for block in range(2):
            var order: Array[int]=[-1,0,1,2,3,4,5]
            if (block+format)%2==1:
                order.reverse()
            for arm in order:
                var policy: Dictionary={} if arm<0 else ARMS[arm].duplicate()
                var label: String="F" if arm<0 else str(policy["name"])
                policy.erase("name")
                var r: Dictionary=EQ.run(folder,format,4 if arm<0 else 7,2,{},false,false,policy)
                if r.get("error",FAILED)!=OK or r["completed"]!=32 or r["warmup_builds"]!=4 or r["pages"]!=16 or (not reference.is_empty() and r["fingerprints"]!=reference):
                    _fail(b,"parity or work "+str(r))
                    return
                reference=r["fingerprints"]
                var w: Dictionary=r["worker"]
                if w["submitted"]!=36 or w["delivered"]!=36 or w["dropped"]!=0 or w["slots"]!=0 or w["peak_slots"]>2 or r["hybrid_cropped_submissions"]!=(36 if policy.get("crop",false) else 0):
                    _fail(b,"ownership or crop")
                    return
                print("M6_FACTORIAL ",JSON.stringify({"format":format+1,"block":block,"arm":label,"metrics":r,"notes":"32 timed rebuilds, four warmups; off-tree, resident pages, no timed IO, CPU wall time not GPU or FPS; worker stage histograms include warmup."}))
        if hash.is_empty() or FileAccess.get_sha256(manifest)!=hash:
            _fail(b,"source changed")
            return
        b.close()
    print("PASS: M6 matched cap2 hybrid factorial, full fallback parity")
    quit(0)
func _fail(b,message: String) -> void:
    b.close()
    push_error("M6: "+message)
    quit(1)
