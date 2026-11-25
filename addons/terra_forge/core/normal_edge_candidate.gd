@tool
extends RefCounted
## Isolated G1 candidate. Caller must own the base arrays and guarantee the
## SAME immutable verified height snapshot, tile, spacing and LOD. Not a
## runtime cache or GPU upload path. Changed seam heights => full rebuild.
const LOD=preload("res://addons/terra_forge/core/lod_policy.gd")
const W=preload("res://addons/terra_forge/core/geometry_worker.gd")
const DIRS=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]

static func patch(source,key: Vector2i,lod: int,before: Dictionary,after: Dictionary,base: Dictionary) -> Dictionary:
    if source==null or not source.is_open() or not is_finite(source.spacing) or source.spacing<=0.0 or base.get("error",FAILED)!=OK:
        return {"error":ERR_INVALID_PARAMETER}
    var old: Dictionary=W.signature(key,lod,before,source.cells)
    var new: Dictionary=W.signature(key,lod,after,source.cells)
    if old.get("error",FAILED)!=OK or new.get("error",FAILED)!=OK:
        return {"error":ERR_INVALID_PARAMETER}
    var dirty: int=0
    for edge in range(4):
        var a: int=old["levels"][edge]
        var b: int=new["levels"][edge]
        # All <= current LOD have canonical heights. Coarser seam
        # interpolation class must be unchanged to reuse vertex/shape data.
        if maxi(lod,a)!=maxi(lod,b):
            return {"error":ERR_UNAVAILABLE,"reason":"full_rebuild_required"}
        if (a==lod)!=(b==lod):
            dirty|=1<<edge
    var stride: int=LOD.sample_stride(lod)
    var width: int=32/stride+1
    var arrays: Array=base.get("arrays",[])
    if arrays.size()!=Mesh.ARRAY_MAX or base.get("width",0)!=width:
        return {"error":ERR_INVALID_DATA}
    if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
        return {"error":ERR_INVALID_DATA}
    var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
    if vertices.size()!=width*width or normals.size()!=vertices.size() or colors.size()!=vertices.size():
        return {"error":ERR_INVALID_DATA}
    # Owned result; packed arrays use copy-on-write. No in-use mesh mutation.
    var out: Dictionary=base.duplicate()
    var result_arrays: Array=arrays.duplicate()
    if dirty==0:
        out["arrays"]=result_arrays
        out["updated_normals"]=0
        out["halo_reads"]=0
        return out
    normals=normals.duplicate()
    colors=colors.duplicate()
    var indices: Dictionary={}
    for edge in range(4):
        if (dirty&(1<<edge))==0:
            continue
        for j in range(width):
            var idx: int=0
            match edge:
                0: idx=j*width
                1: idx=j*width+width-1
                2: idx=j
                3: idx=(width-1)*width+j
            indices[idx]=true
    var cell_world: float=source.spacing*float(stride)
    var halo_reads: int=0
    for idx in indices:
        var x: int=int(idx)%width
        var z: int=int(idx)/width
        var west: int=maxi(0,x-1)
        var east: int=mini(width-1,x+1)
        var north: int=maxi(0,z-1)
        var south: int=mini(width-1,z+1)
        var dx: float=(vertices[z*width+east].y-vertices[z*width+west].y)/(float(east-west)*cell_world)
        var dz: float=(vertices[south*width+x].y-vertices[north*width+x].y)/(float(south-north)*cell_world)
        var gx: int=key.x*32+x*stride
        var gz: int=key.y*32+z*stride
        for edge in range(4):
            if new["levels"][edge]!=lod:
                continue
            if not ((edge==0 and x==0) or (edge==1 and x==width-1) or (edge==2 and z==0) or (edge==3 and z==width-1)):
                continue
            var halo: Dictionary=source.get_height(gx+DIRS[edge].x*stride,gz+DIRS[edge].y*stride)
            halo_reads+=1
            if halo.get("error",ERR_FILE_CORRUPT)!=OK or not is_finite(float(halo.get("height",NAN))):
                return {"error":int(halo.get("error",ERR_FILE_CORRUPT)) if halo.get("error",ERR_FILE_CORRUPT)!=OK else ERR_FILE_CORRUPT}
            var h: float=float(halo["height"])
            match edge:
                0: dx=(vertices[idx+1].y-h)/(2.0*cell_world)
                1: dx=(h-vertices[idx-1].y)/(2.0*cell_world)
                2: dz=(vertices[idx+width].y-h)/(2.0*cell_world)
                3: dz=(h-vertices[idx-width].y)/(2.0*cell_world)
        var normal: Vector3=Vector3(-dx,1.0,-dz).normalized()
        normals[idx]=normal
        colors[idx]=Color(0.27,0.39,0.22).lerp(Color(0.48,0.46,0.41),clampf((1.0-normal.y)*3.0,0.0,1.0))
    result_arrays[Mesh.ARRAY_NORMAL]=normals
    result_arrays[Mesh.ARRAY_COLOR]=colors
    out["arrays"]=result_arrays
    out["updated_normals"]=indices.size()
    out["halo_reads"]=halo_reads
    return out
