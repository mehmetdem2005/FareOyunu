@tool
extends RefCounted
## Isolated same-source, same-LOD owned-array candidate. Caller guarantees
## identical verified snapshot; no runtime reuse or partial physics upload.
const G=preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const W=preload("res://addons/terra_forge/core/geometry_worker.gd")
const LOD=preload("res://addons/terra_forge/core/lod_policy.gd")
const A=preload("res://addons/terra_forge/core/publication_accounting.gd")
const TILE_CELLS: int=32

static func patch(source,key: Vector2i,lod: int,before: Dictionary,after: Dictionary,base: Dictionary,scalar: bool=false) -> Dictionary:
    if source==null or not source.is_open() or not is_finite(source.spacing) or source.spacing<=0.0 or A.describe(base,lod)["error"]!=OK:
        return {"error":ERR_INVALID_PARAMETER}
    var old: Dictionary=W.signature(key,lod,before,source.cells)
    var new: Dictionary=W.signature(key,lod,after,source.cells)
    if old["error"]!=OK or new["error"]!=OK:
        return {"error":ERR_INVALID_PARAMETER}
    var width: int=base["width"]
    var stride: int=LOD.sample_stride(lod)
    var spacing: float=source.spacing
    var tx: int=key.x
    var tz: int=key.y
    var desired: Dictionary=new["desired"]
    var arrays: Array=base["arrays"].duplicate()
    var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
    var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate()
    var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR].duplicate()
    var heights: PackedFloat32Array=base["collision_heights"].duplicate()
    var dirty: Dictionary={}
    var edges: Dictionary={}
    var changed: int=0
    for edge in range(4):
        var a: int=old["levels"][edge]
        var b: int=new["levels"][edge]
        if maxi(lod,a)==maxi(lod,b) and (a==lod)==(b==lod):
            continue
        for j in range(width):
            var x: int=0 if edge==0 else (width-1 if edge==1 else j)
            var z: int=0 if edge==2 else (width-1 if edge==3 else j)
            var idx: int=z*width+x
            dirty[idx]=true
            if maxi(lod,a)!=maxi(lod,b):
                edges[idx]=true
    for idx in edges:
        var x: int=int(idx)%width
        var z: int=int(idx)/width
        var h: float
        if scalar:
            h=G._seam_scalar(source,tx,tz,x*stride,z*stride,lod,desired)
        else:
            var sample: Dictionary=G._seam(source,tx,tz,x*stride,z*stride,lod,desired)
            if sample.get("error",FAILED)!=OK:
                return {"error":int(sample.get("error",FAILED))}
            h=float(sample["height"])
        if not is_finite(h):
            return {"error":ERR_FILE_CORRUPT}
        var v: Vector3=vertices[idx]
        var next: Vector3=Vector3(v.x,h,v.z)
        if v!=next:
            changed+=1
            vertices[idx]=next
            # Normals sample immediate cardinal rendered neighbors.
            for d in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                var q: Vector2i=Vector2i(x,z)+d
                if q.x>=0 and q.y>=0 and q.x<width and q.y<width:
                    dirty[q.y*width+q.x]=true
        if lod==0:
            heights[idx]=h/spacing
    var cell_world: float=spacing*float(stride)
    var grass: Color=Color(0.27,0.39,0.22)
    var stone: Color=Color(0.48,0.46,0.41)
    var west_same: bool=new["levels"][0]==lod
    var east_same: bool=new["levels"][1]==lod
    var north_same: bool=new["levels"][2]==lod
    var south_same: bool=new["levels"][3]==lod
    for i in dirty:
        var x: int=int(i)%width
        var z: int=int(i)/width
        var west: int = maxi(0, x - 1)
        var east: int = mini(width - 1, x + 1)
        var north: int = maxi(0, z - 1)
        var south: int = mini(width - 1, z + 1)
        var dx: float = (
            vertices[z * width + east].y - vertices[z * width + west].y
        ) / (float(east - west) * cell_world)
        var dz: float = (
            vertices[south * width + x].y - vertices[north * width + x].y
        ) / (float(south - north) * cell_world)
        var gx: int = tx * TILE_CELLS + x * stride
        var gz: int = tz * TILE_CELLS + z * stride
        var halo: Dictionary
        var halo_value: float
        if x == 0 and west_same:
            if scalar:
                halo_value = source.read_finite_or_nan(gx - stride, gz)
                if not is_finite(halo_value):
                    return {"error":ERR_FILE_CORRUPT}
            else:
                halo = source.get_height(gx - stride, gz)
                if int(halo["error"]) != OK:
                    return {"error": int(halo["error"])}
                halo_value = float(halo["height"])
            dx = (vertices[i + 1].y - halo_value) / (2.0 * cell_world)
        elif x == width - 1 and east_same:
            if scalar:
                halo_value = source.read_finite_or_nan(gx + stride, gz)
                if not is_finite(halo_value):
                    return {"error":ERR_FILE_CORRUPT}
            else:
                halo = source.get_height(gx + stride, gz)
                if int(halo["error"]) != OK:
                    return {"error": int(halo["error"])}
                halo_value = float(halo["height"])
            dx = (halo_value - vertices[i - 1].y) / (2.0 * cell_world)
        if z == 0 and north_same:
            if scalar:
                halo_value = source.read_finite_or_nan(gx, gz - stride)
                if not is_finite(halo_value):
                    return {"error":ERR_FILE_CORRUPT}
            else:
                halo = source.get_height(gx, gz - stride)
                if int(halo["error"]) != OK:
                    return {"error": int(halo["error"])}
                halo_value = float(halo["height"])
            dz = (vertices[i + width].y - halo_value) / (2.0 * cell_world)
        elif z == width - 1 and south_same:
            if scalar:
                halo_value = source.read_finite_or_nan(gx, gz + stride)
                if not is_finite(halo_value):
                    return {"error":ERR_FILE_CORRUPT}
            else:
                halo = source.get_height(gx, gz + stride)
                if int(halo["error"]) != OK:
                    return {"error": int(halo["error"])}
                halo_value = float(halo["height"])
            dz = (halo_value - vertices[i - width].y) / (2.0 * cell_world)
        var normal: Vector3 = Vector3(-dx, 1.0, -dz).normalized()
        normals[i] = normal
        colors[i] = grass.lerp(stone, clampf((1.0 - normal.y) * 3.0, 0.0, 1.0))

    arrays[Mesh.ARRAY_VERTEX]=vertices
    arrays[Mesh.ARRAY_NORMAL]=normals
    arrays[Mesh.ARRAY_COLOR]=colors
    var out: Dictionary=base.duplicate()
    out["arrays"]=arrays
    out["collision_heights"]=heights
    out["sampled_edges"]=edges.size()
    out["changed_vertices"]=changed
    out["updated_normals"]=dirty.size()
    return out
