extends SceneTree
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const W=preload("res://addons/terra_forge/core/geometry_worker.gd")

# Scratch analytic height source; no disk, no mutation of real terrain.
class CurvedSource extends RefCounted:
    var cells: Vector2i=Vector2i(128,128)
    var spacing: float=1.0
    var profile: int=0
    func is_open() -> bool:
        return true
    func get_height(x: int,z: int) -> Dictionary:
        if x<0 or z<0 or x>cells.x or z>cells.y:
            return {"error":ERR_INVALID_PARAMETER}
        var h: float=0.0
        if profile==0:
            h=0.001*float(x*x+z*z)+0.0003*float(x*z)
        elif profile==1:
            h=4.0*sin(float(x)*0.19)+3.0*cos(float(z)*0.23)+0.002*float(x*z)
        else:
            h=0.0
        return {"error":OK,"height":h}

func _initialize() -> void:
    var source=CurvedSource.new()
    var key=Vector2i(1,1)
    for profile in [0,1,2]:
        source.profile=profile
        var counts: Dictionary={"cases":0,"same_output":0,"normals_only_or_color":0,"vertices_changed":0,"normals_changed":0,"colors_changed":0,"indices_changed":0,"uv_changed":0,"collision_changed":0,"same_signature":0,"interior_vertex_changed":0}
        for lod in range(3):
            var original: Dictionary={key:lod}
            for dir in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                original[key+dir]=lod
            var base: Dictionary=G.generate(source,key.x,key.y,lod,original)
            if base["error"]!=OK:
                _fail("base")
                return
            var sig0: Dictionary=W.signature(key,lod,original,source.cells)
            for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(1,1)]:
                for level in [-1,0,1,2]:
                    var desired: Dictionary=original.duplicate()
                    if level<0:
                        desired.erase(key+direction)
                    else:
                        desired[key+direction]=level
                    var next: Dictionary=G.generate(source,key.x,key.y,lod,desired)
                    var sig: Dictionary=W.signature(key,lod,desired,source.cells)
                    if next["error"]!=OK or sig["error"]!=OK:
                        _fail("variant")
                        return
                    var a: Array=base["arrays"]
                    var c: Array=next["arrays"]
                    var v: bool=a[Mesh.ARRAY_VERTEX]!=c[Mesh.ARRAY_VERTEX]
                    var n: bool=a[Mesh.ARRAY_NORMAL]!=c[Mesh.ARRAY_NORMAL]
                    var color: bool=a[Mesh.ARRAY_COLOR]!=c[Mesh.ARRAY_COLOR]
                    var collision: bool=base["collision_heights"]!=next["collision_heights"]
                    var same: bool=a==c and not collision
                    var same_sig: bool=sig["levels"]==sig0["levels"]
                    if (same_sig and not same) or a[Mesh.ARRAY_INDEX]!=c[Mesh.ARRAY_INDEX] or a[Mesh.ARRAY_TEX_UV]!=c[Mesh.ARRAY_TEX_UV] or (lod==0 and v!=collision) or (lod>0 and collision):
                        _fail("identity or invariant")
                        return
                    var width: int=base["width"]
                    for z in range(1,width-1):
                        for x in range(1,width-1):
                            var idx: int=z*width+x
                            if a[Mesh.ARRAY_VERTEX][idx]!=c[Mesh.ARRAY_VERTEX][idx]:
                                _fail("interior vertex changed by edge")
                                return
                    counts["cases"]+=1
                    counts["same_output"]+=int(same)
                    counts["normals_only_or_color"]+=int(not v and not collision and (n or color))
                    counts["vertices_changed"]+=int(v)
                    counts["normals_changed"]+=int(n)
                    counts["colors_changed"]+=int(color)
                    counts["collision_changed"]+=int(collision)
                    counts["same_signature"]+=int(same_sig)
        if profile<2 and (counts["vertices_changed"]<=0 or counts["collision_changed"]<=0 or counts["normals_only_or_color"]<=0):
            _fail("nonlinear fixture lacks positive controls")
            return
        if profile==2 and counts["same_output"]!=counts["cases"]:
            _fail("flat negative control")
            return
        print("G0_CURVED_DIRTY ",JSON.stringify({"profile":profile,"counts":counts,"note":"Analytic source; classification only, no runtime partial update."}))
    print("PASS: G0 180 curved/flat neighbor cases, color, stable topology and collision positive/negative controls")
    quit(0)

func _fail(msg: String) -> void:
    push_error("G0 curved dirty: "+msg)
    quit(1)
