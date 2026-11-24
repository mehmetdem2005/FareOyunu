@tool
extends RefCounted
## Fixed topology for exactly three regular 32-cell tile LODs.
## Owned by a single worker session. No static mutable global cache.
## Return independent copies: callers cannot corrupt the cached template.
const PAYLOAD_BYTES: int=32256
var _templates: Array[PackedInt32Array]=[]

func initialize() -> Error:
    _templates.clear()
    for lod in range(3):
        var side: int=32>>lod
        var width: int=side+1
        var indices=PackedInt32Array()
        var err: Error=indices.resize(side*side*6)
        if err!=OK:
            _templates.clear()
            return err
        var i: int=0
        for z in range(side):
            for x in range(side):
                var a: int=z*width+x
                indices[i]=a
                indices[i+1]=a+1
                indices[i+2]=a+width
                indices[i+3]=a+1
                indices[i+4]=a+width+1
                indices[i+5]=a+width
                i+=6
        _templates.append(indices)
    return OK

func payload_bytes() -> int:
    var total: int=0
    for template in _templates:
        total+=template.size()*4
    return total

func copy_indices(lod: int) -> PackedInt32Array:
    if lod<0 or lod>2 or _templates.size()!=3:
        return PackedInt32Array()
    return _templates[lod].duplicate()
