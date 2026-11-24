@tool
extends RefCounted
const G = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const B = preload("res://addons/terra_forge/core/tile_sampling_benchmark.gd")

static func run_case(source,key: Vector2i,lod: int,desired: Dictionary,rounds: int=32) -> Dictionary:
    if rounds<4 or rounds>120 or rounds%4!=0:
        return {"error":ERR_INVALID_PARAMETER}
    var expected: Dictionary=G.generate(source,key.x,key.y,lod,desired)
    if expected.get("error",FAILED)!=OK:
        return expected
    if not B.equal(expected,G.generate_with_view(source,key.x,key.y,lod,desired)) or not B.equal(expected,G.generate_with_scalar_view(source,key.x,key.y,lod,desired)):
        return {"error":ERR_INVALID_DATA,"stage":"warmup"}
    var samples: Array=[[],[]]
    var reads: Array=[0,0]
    var touches: Array=[0,0]
    var initial: Dictionary=source.stats()
    for i in range(rounds):
        # ABBA over each four calls (each strategy once per round).
        for mode in ([0,1] if i%2==0 else [1,0]):
            var before: Dictionary=source.stats()
            var start: int=Time.get_ticks_usec()
            var result: Dictionary=G.generate_with_view(source,key.x,key.y,lod,desired) if mode==0 else G.generate_with_scalar_view(source,key.x,key.y,lod,desired)
            var elapsed: int=Time.get_ticks_usec()-start
            var after: Dictionary=source.stats()
            if not B.equal(expected,result) or after["tile_view_active_pages"]!=0:
                return {"error":ERR_INVALID_DATA,"stage":"timed parity","mode":mode}
            samples[mode].append(elapsed)
            reads[mode]+=after["tile_view_reads"]-before["tile_view_reads"]
            touches[mode]+=after["lru_touches"]-before["lru_touches"]
    var final: Dictionary=source.stats()
    if reads[0]!=reads[1] or touches[0]!=touches[1] or final["disk_reads"]!=initial["disk_reads"] or final["evictions"]!=initial["evictions"] or final["submitted"]!=initial["submitted"]:
        return {"error":ERR_BUG,"stage":"work parity"}
    return {"error":OK,"rounds":rounds,"tile":[key.x,key.y],"lod":lod,"vertices":expected["vertex_count"],"B_view":B._timing(samples[0]),"D_scalar":B._timing(samples[1]),"view_reads_each":reads[0],"lru_touches_each":touches[0],"disk_reads_during_case":0,"evictions_during_case":0}
