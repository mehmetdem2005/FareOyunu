extends SceneTree
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const C=preload("res://addons/terra_forge/core/seam_patch_candidate.gd")
const DIRS=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]

class Source extends RefCounted:
    var cells: Vector2i=Vector2i(128,128)
    var spacing: float=1.0
    var profile: int=0
    var fail: bool=false
    func is_open() -> bool:
        return true
    func get_height(x: int,z: int) -> Dictionary:
        if fail or x<0 or z<0 or x>cells.x or z>cells.y:
            return {"error":ERR_FILE_CORRUPT}
        var h: float=0.001*float(x*x+z*z)+0.0003*float(x*z) if profile==0 else 4.0*sin(float(x)*0.19)+3.0*cos(float(z)*0.23)+0.002*float(x*z)
        return {"error":OK,"height":h}
    func read_finite_or_nan(x: int,z: int) -> float:
        var result: Dictionary=get_height(x,z)
        return result["height"] if result["error"]==OK else NAN

func _initialize() -> void:
    var s=Source.new()
    var totals: Dictionary={"cases":0,"changed":0,"collision_changed":0,"full_us":0,"patch_us":0,"full_vertices":0,"sampled_edges":0,"full_normals":0,"patch_normals":0}
    for profile in [0,1]:
        s.profile=profile
        for spacing in [0.25,1.0]:
            s.spacing=spacing
            var key=Vector2i(1,1)
            for lod in range(3):
                var before: Dictionary={key:lod}
                for d in DIRS:
                    before[key+d]=lod
                var variants: Array[Dictionary]=[]
                for d in DIRS:
                    for level in [-1,0,1,2]:
                        var next: Dictionary=before.duplicate()
                        if level<0:
                            next.erase(key+d)
                        else:
                            next[key+d]=level
                        variants.append(next)
                variants.append({key:lod,key+Vector2i.LEFT:2,key+Vector2i.UP:2})
                variants.append({key:lod,key+Vector2i.RIGHT:2,key+Vector2i.DOWN:1})
                for i in range(variants.size()):
                    # Both transitions, including coarse-to-fine recovery.
                    var a: Dictionary=before if i%2==0 else variants[i]
                    var z: Dictionary=variants[i] if i%2==0 else before
                    var base: Dictionary=G._generate(s,key.x,key.y,lod,a,true)
                    var unchanged: PackedByteArray=var_to_bytes(base)
                    var full: Dictionary
                    var patch: Dictionary
                    for patch_first in ([false,true] if i%2==0 else [true,false]):
                        var t: int=Time.get_ticks_usec()
                        if patch_first:
                            patch=C.patch(s,key,lod,a,z,base,true)
                            totals["patch_us"]+=Time.get_ticks_usec()-t
                        else:
                            full=G._generate(s,key.x,key.y,lod,z,true)
                            totals["full_us"]+=Time.get_ticks_usec()-t
                    if full.get("error",FAILED)!=OK or patch.get("error",FAILED)!=OK or full["arrays"]!=patch["arrays"] or full["collision_heights"]!=patch["collision_heights"] or var_to_bytes(base)!=unchanged:
                        _fail("parity "+str([profile,spacing,lod,i]))
                        return
                    totals["cases"]+=1
                    totals["changed"]+=int(patch["changed_vertices"]>0)
                    totals["collision_changed"]+=int(base["collision_heights"]!=patch["collision_heights"])
                    totals["full_vertices"]+=base["vertex_count"]
                    totals["sampled_edges"]+=patch["sampled_edges"]
                    totals["full_normals"]+=base["vertex_count"]
                    totals["patch_normals"]+=patch["updated_normals"]
    var key=Vector2i(1,1)
    var base: Dictionary=G.generate(s,key.x,key.y,0,{key:0})
    s.fail=true
    if C.patch(s,key,0,{key:0},{key:0,key+Vector2i.LEFT:2},base)["error"]==OK or totals["changed"]<=0 or totals["collision_changed"]<=0:
        _fail("positive/negative control")
        return
    print("G2_SEAM_PATCH ",JSON.stringify(totals))
    print("PASS: G2 changed coarse seams, reverse transitions, corner normals, collision and topology exact parity, fail-closed read")
    quit(0)

func _fail(msg: String) -> void:
    push_error("G2 seam: "+msg)
    quit(1)
