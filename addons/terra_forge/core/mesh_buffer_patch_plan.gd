@tool
extends RefCounted
## Pure diagnostic planning for engine-packed buffers. No live mesh ownership.
## Align to four bytes, group nearby changed words, cap API calls.
const MAX_RUNS: int=32
static func plan(before: PackedByteArray,after: PackedByteArray,merge_gap: int=16) -> Dictionary:
    if before.size()!=after.size() or before.size()%4!=0 or merge_gap<0 or merge_gap>64 or merge_gap%4!=0:
        return {"error":ERR_INVALID_PARAMETER}
    var ranges: Array[Vector2i]=[]
    var changed_words: int=0
    for i in range(0,before.size(),4):
        var differs: bool=false
        for k in range(4):
            if before[i+k]!=after[i+k]:
                differs=true
                break
        if not differs:
            continue
        changed_words+=1
        if not ranges.is_empty() and i-ranges.back().y<=merge_gap:
            ranges[-1]=Vector2i(ranges.back().x,i+4)
        else:
            ranges.append(Vector2i(i,i+4))
    if ranges.size()>MAX_RUNS:
        return {"error":ERR_UNAVAILABLE,"reason":"call_cap","changed_words":changed_words}
    var bytes: int=0
    for span in ranges:
        bytes+=span.y-span.x
    return {"error":OK,"ranges":ranges,"bytes":bytes,"changed_words":changed_words}

static func reconstruct(before: PackedByteArray,after: PackedByteArray,spans: Array[Vector2i]) -> PackedByteArray:
    var out: PackedByteArray=before.duplicate()
    for span in spans:
        if span.x<0 or span.y>out.size() or span.y<=span.x:
            return PackedByteArray()
        for i in range(span.x,span.y):
            out[i]=after[i]
    return out
