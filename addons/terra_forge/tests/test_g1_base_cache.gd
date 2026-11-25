extends SceneTree
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const C=preload("res://addons/terra_forge/core/normal_edge_candidate.gd")
const K=preload("res://addons/terra_forge/core/normal_base_cache_candidate.gd")
class Source extends RefCounted:
    var cells=Vector2i(256,256)
    var spacing: float=1.0
    func is_open() -> bool:
        return true
    func get_height(x: int,z: int) -> Dictionary:
        if x<0 or z<0 or x>cells.x or z>cells.y:
            return {"error":ERR_FILE_CORRUPT}
        return {"error":OK,"height":0.001*float(x*x+z*z)+0.0003*float(x*z)}

func _initialize() -> void:
    var source=Source.new()
    var k=K.new()
    if k.begin("verified-a",1)!=OK:
        _fail("begin")
        return
    var cases: int=0
    var rejected: int=0
    var key=Vector2i(1,1)
    for lod in [0,1,2]:
        for i in range(12):
            key=Vector2i(1+i%5,1+i/5)
            var before: Dictionary={key:lod}
            for d in C.DIRS:
                before[key+d]=lod
            var base: Dictionary=G.generate(source,key.x,key.y,lod,before)
            if base["error"]!=OK or k.retain("verified-a",1,key,lod,source.spacing,source.cells,before,base)!=OK:
                _fail("retain")
                return
            var after: Dictionary=before.duplicate()
            after.erase(key+Vector2i.LEFT)
            var full: Dictionary=G.generate(source,key.x,key.y,lod,after)
            var result: Dictionary=k.patch("verified-a",1,source,key,lod,after)
            if result["error"]!=OK or result["arrays"]!=full["arrays"] or result["collision_heights"]!=full["collision_heights"]:
                _fail("cache parity")
                return
            # Mutate caller-owned result and original after retention; repeat must match.
            var normals: PackedVector3Array=result["arrays"][Mesh.ARRAY_NORMAL]
            normals[0]=Vector3.ZERO
            result["arrays"][Mesh.ARRAY_NORMAL]=normals
            var verts: PackedVector3Array=base["arrays"][Mesh.ARRAY_VERTEX]
            verts[0]=Vector3.ZERO
            base["arrays"][Mesh.ARRAY_VERTEX]=verts
            var again: Dictionary=k.patch("verified-a",1,source,key,lod,after)
            if again["error"]!=OK or again["arrays"]!=full["arrays"]:
                _fail("alias")
                return
            for wrong in [["verified-b",1,lod],["verified-a",2,lod],["verified-a",1,(lod+1)%3]]:
                if k.patch(wrong[0],wrong[1],source,key,wrong[2],after)["error"]==OK:
                    _fail("identity")
                    return
                rejected+=1
            source.spacing=2.0
            if k.patch("verified-a",1,source,key,lod,after)["error"]==OK:
                _fail("spacing")
                return
            source.spacing=1.0
            rejected+=1
            var r: Dictionary=k.report()
            if r["entries"]>K.MAX_ENTRIES or r["bytes"]>K.MAX_BYTES or r["peak_bytes"]>K.MAX_BYTES:
                _fail("bound")
                return
            cases+=1
    var report: Dictionary=k.report()
    if report["evictions"]<=0 or k.begin("verified-b",2)!=OK or k.report()["entries"]!=0 or k.patch("verified-a",1,source,key,2,{key:2})["error"]==OK:
        _fail("evict/reset")
        return
    k.clear()
    if k.report()["bytes"]!=0:
        _fail("clear")
        return
    print("G1_BASE_CACHE ",JSON.stringify({"cases":cases,"identity_rejections":rejected,"report":report,"cap_bytes":K.MAX_BYTES,"cap_entries":K.MAX_ENTRIES,"note":"Conservative raw geometry payload only, no RSS, worker transfer or GPU, caller must supply authoritative identity."}))
    print("PASS: G1 bounded owned base cache, exact arrays, alias isolation, identity rejection and lifecycle")
    quit(0)

func _fail(msg: String) -> void:
    push_error("G1 base cache: "+msg)
    quit(1)
