@tool
extends RefCounted
## Experimental combined vertex/attribute plan. Minimum added bytes for a
## fixed call cap by merging cheapest independent adjacent gaps. No runtime.
const MAX_RUNS: int=32
const OLD=preload("res://addons/terra_forge/core/mesh_buffer_patch_plan.gd")
static func plan(before_v: PackedByteArray,after_v: PackedByteArray,before_a: PackedByteArray,after_a: PackedByteArray,cap: int=MAX_RUNS) -> Dictionary:
    if cap<1 or cap>MAX_RUNS or before_v.size()!=after_v.size() or before_a.size()!=after_a.size() or before_v.size()%4!=0 or before_a.size()%4!=0:
        return {"error":ERR_INVALID_PARAMETER}
    var vr: Array[Vector2i]=_runs(before_v,after_v)
    var ar: Array[Vector2i]=_runs(before_a,after_a)
    var gaps: Array[Vector3i]=[]
    var initial_calls: int=vr.size()+ar.size()
    var changed_bytes: int=0
    for channel in [0,1]:
        var runs: Array[Vector2i]=vr if channel==0 else ar
        for i in range(runs.size()):
            changed_bytes+=runs[i].y-runs[i].x
            if i>0:
                gaps.append(Vector3i(runs[i].x-runs[i-1].y,channel,i))
    gaps.sort_custom(func(a: Vector3i,b: Vector3i)->bool:
        if a.x!=b.x:
            return a.x<b.x
        if a.y!=b.y:
            return a.y<b.y
        return a.z<b.z)
    var needed: int=maxi(0,initial_calls-cap)
    if needed>gaps.size():
        return {"error":ERR_UNAVAILABLE,"reason":"call_cap","initial_calls":initial_calls}
    var selected: Dictionary={}
    var bytes: int=changed_bytes
    for i in range(needed):
        var gap: Vector3i=gaps[i]
        selected[Vector2i(gap.y,gap.z)]=true
        bytes+=gap.x
    var full_bytes: int=before_v.size()+before_a.size()
    # Deliberately conservative traffic gate; no unconditional cap increase.
    if bytes*4>full_bytes*3:
        return {"error":ERR_UNAVAILABLE,"reason":"byte_cap","initial_calls":initial_calls,"bytes":bytes,"full_bytes":full_bytes}
    var v: Array[Vector2i]=_merge(vr,0,selected)
    var a: Array[Vector2i]=_merge(ar,1,selected)
    return {"error":OK,"vertex":v,"attribute":a,"bytes":bytes,"full_bytes":full_bytes,"calls":v.size()+a.size(),"initial_calls":initial_calls,"changed_bytes":changed_bytes}

static func _runs(before: PackedByteArray,after: PackedByteArray) -> Array[Vector2i]:
    var out: Array[Vector2i]=[]
    for i in range(0,before.size(),4):
        var different: bool=false
        for k in range(4):
            if before[i+k]!=after[i+k]:
                different=true
                break
        if different:
            if not out.is_empty() and out[-1].y==i:
                out[-1]=Vector2i(out[-1].x,i+4)
            else:
                out.append(Vector2i(i,i+4))
    return out

static func _merge(runs: Array[Vector2i],channel: int,selected: Dictionary) -> Array[Vector2i]:
    var out: Array[Vector2i]=[]
    for i in range(runs.size()):
        if i>0 and selected.has(Vector2i(channel,i)):
            out[-1]=Vector2i(out[-1].x,runs[i].y)
        else:
            out.append(runs[i])
    return out
