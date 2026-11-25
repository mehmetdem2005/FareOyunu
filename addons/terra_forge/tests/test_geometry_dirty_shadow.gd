extends SceneTree
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")
const P=preload("res://addons/terra_forge/terrain/paged_terrain_preview.gd")
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const EQ=preload("res://addons/terra_forge/core/geometry_worker_comparison.gd")
const W=preload("res://addons/terra_forge/core/geometry_worker.gd")
var p
var b

func _initialize() -> void:
    for format in [0,1]:
        b=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start")
            return
        var made: Dictionary={}
        for i in range(15000):
            made=b.take_result()
            if made.get("error",FAILED)!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture")
            return
        p=P.new()
        p.region_index_format=format
        p.sampling_strategy=7
        if p.start_preview(made["directory"],16,4)!=OK:
            _fail("open")
            return
        var key=Vector2i(15,15)
        var pages: Array[Vector2i]=[]
        for lod in range(3):
            for page in G.required_pages(p._reader,key.x,key.y,lod):
                if not pages.has(page):
                    pages.append(page)
        if not EQ._load(p,pages):
            _fail("warm")
            return
        var counts: Dictionary={"cases":0,"same_output":0,"vertices_changed":0,"normals_changed":0,"indices_changed":0,"collision_changed":0,"same_signature_cases":0}
        for lod in range(3):
            var original: Dictionary={key:lod}
            for dir in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                original[key+dir]=lod
            var base: Dictionary=G.generate(p._reader,key.x,key.y,lod,original)
            if base["error"]!=OK:
                _fail("base")
                return
            var signature: Dictionary=W.signature(key,lod,original,p._reader.cells)
            for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(1,1)]:
                for level in [-1,0,1,2]:
                    var changed: Dictionary=original.duplicate()
                    if level<0:
                        changed.erase(key+direction)
                    else:
                        changed[key+direction]=level
                    var sig: Dictionary=W.signature(key,lod,changed,p._reader.cells)
                    var next: Dictionary=G.generate(p._reader,key.x,key.y,lod,changed)
                    if next["error"]!=OK or sig["error"]!=OK:
                        _fail("variant")
                        return
                    var arrays: Array=next["arrays"]
                    var prior: Array=base["arrays"]
                    var same: bool=arrays==prior and next["collision_heights"]==base["collision_heights"]
                    var same_sig: bool=signature["levels"]==sig["levels"]
                    if same_sig and not same:
                        _fail("same signature differs")
                        return
                    if arrays[Mesh.ARRAY_INDEX]!=prior[Mesh.ARRAY_INDEX]:
                        _fail("same LOD topology changed")
                        return
                    counts["cases"]+=1
                    counts["same_output"]+=int(same)
                    counts["same_signature_cases"]+=int(same_sig)
                    counts["vertices_changed"]+=int(arrays[Mesh.ARRAY_VERTEX]!=prior[Mesh.ARRAY_VERTEX])
                    counts["normals_changed"]+=int(arrays[Mesh.ARRAY_NORMAL]!=prior[Mesh.ARRAY_NORMAL])
                    counts["indices_changed"]+=int(arrays[Mesh.ARRAY_INDEX]!=prior[Mesh.ARRAY_INDEX])
                    counts["collision_changed"]+=int(next["collision_heights"]!=base["collision_heights"])
        print("GEOMETRY_DIRTY_SHADOW ",JSON.stringify({"format":format+1,"counts":counts,"note":"full rebuild comparison, no partial update or speed claim"}))
        p.stop_preview()
        p.free()
        p=null
        b.close()
        b=null
    print("PASS: same-LOD full geometry dirty classification, cardinal/diagonal neighbor changes, exact signature and stable indices")
    quit(0)

func _fail(msg: String) -> void:
    if p!=null:
        p.stop_preview()
        p.free()
    if b!=null:
        b.close()
    push_error("Geometry dirty shadow: "+msg)
    quit(1)
