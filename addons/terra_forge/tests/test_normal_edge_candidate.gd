extends SceneTree
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const C=preload("res://addons/terra_forge/core/normal_edge_candidate.gd")
class Source extends RefCounted:
    var cells: Vector2i=Vector2i(128,128)
    var spacing: float=1.0
    var profile: int=0
    var reads: int=0
    var broken: bool=false
    func is_open() -> bool:
        return true
    func get_height(x: int,z: int) -> Dictionary:
        reads+=1
        if broken or x<0 or z<0 or x>cells.x or z>cells.y:
            return {"error":ERR_FILE_CORRUPT}
        var h: float=0.0
        if profile==0:
            h=0.001*float(x*x+z*z)+0.0003*float(x*z)
        elif profile==1:
            h=4.0*sin(float(x)*0.19)+3.0*cos(float(z)*0.23)+0.002*float(x*z)
        return {"error":OK,"height":h}

func _initialize() -> void:
    var s=Source.new()
    var key=Vector2i(1,1)
    var totals: Dictionary={"matched":0,"fallback":0,"zero_work":0,"full_normals":0,"patch_normals":0,"full_reads":0,"patch_reads":0,"full_us":0,"patch_us":0}
    for profile in range(3):
        s.profile=profile
        for spacing in [1.0,0.25]:
            s.spacing=spacing
            for lod in range(3):
                var before: Dictionary={key:lod}
                for dir in C.DIRS:
                    before[key+dir]=lod
                var base: Dictionary=G.generate(s,key.x,key.y,lod,before)
                if base["error"]!=OK:
                    _fail("base")
                    return
                var fingerprint: PackedByteArray=var_to_bytes(base)
                var variants: Array[Dictionary]=[]
                for dir in C.DIRS:
                    for level in [-1,0,1,2]:
                        var after: Dictionary=before.duplicate()
                        if level<0:
                            after.erase(key+dir)
                        else:
                            after[key+dir]=level
                        variants.append(after)
                var both: Dictionary=before.duplicate()
                both.erase(key+Vector2i.LEFT)
                both.erase(key+Vector2i.UP)
                variants.append(both)
                variants.append({key:lod})
                for after in variants:
                    s.reads=0
                    var full_start: int=Time.get_ticks_usec()
                    var full: Dictionary=G.generate(s,key.x,key.y,lod,after)
                    var full_us: int=Time.get_ticks_usec()-full_start
                    var full_reads: int=s.reads
                    s.reads=0
                    var patch_start: int=Time.get_ticks_usec()
                    var patched: Dictionary=C.patch(s,key,lod,before,after,base)
                    var patch_us: int=Time.get_ticks_usec()-patch_start
                    if full["error"]!=OK or var_to_bytes(base)!=fingerprint:
                        _fail("full or base mutation")
                        return
                    var coarse_change: bool=false
                    for dir in C.DIRS:
                        if maxi(lod,int(before.get(key+dir,-1)))!=maxi(lod,int(after.get(key+dir,-1))):
                            coarse_change=true
                    if coarse_change:
                        if patched.get("error",FAILED)!=ERR_UNAVAILABLE:
                            _fail("missing fallback")
                            return
                        totals["fallback"]+=1
                        continue
                    if patched.get("error",FAILED)!=OK or full["arrays"]!=patched["arrays"] or full["collision_heights"]!=patched["collision_heights"] or patched["updated_normals"]>4*(base["width"]-1):
                        _fail("exact full parity "+str([profile,spacing,lod,after]))
                        return
                    totals["matched"]+=1
                    totals["zero_work"]+=int(patched["updated_normals"]==0)
                    totals["full_normals"]+=base["width"]*base["width"]
                    totals["patch_normals"]+=patched["updated_normals"]
                    totals["full_reads"]+=full_reads
                    totals["patch_reads"]+=s.reads
                    totals["full_us"]+=full_us
                    totals["patch_us"]+=patch_us
                var removed: Dictionary=before.duplicate()
                removed.erase(key+Vector2i.LEFT)
                var previous: Dictionary=G.generate(s,key.x,key.y,lod,removed)
                var restored: Dictionary=C.patch(s,key,lod,removed,before,previous)
                if restored.get("error",FAILED)!=OK or restored["arrays"]!=base["arrays"]:
                    _fail("reverse edge")
                    return
                s.broken=true
                var fault: Dictionary=C.patch(s,key,lod,removed,before,previous)
                s.broken=false
                if fault.get("error",OK)==OK or fault.has("arrays"):
                    _fail("halo fail closed")
                    return
    print("G1_EDGE_PARITY ",JSON.stringify(totals))
    print("PASS: G1 isolated immutable-height normal/color patch exact full parity, corner and reverse transitions, coarse fallback and corrupt halo")
    quit(0)

func _fail(msg: String) -> void:
    push_error("G1 edge patch: "+msg)
    quit(1)
