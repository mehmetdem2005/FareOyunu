@tool
extends RefCounted
## Fixed resident workload. Timings are wall elapsed on calling thread,
## include acquisition/copy/release and array generation, exclude IO/upload.
const G = preload("res://addons/terra_forge/core/paged_tile_geometry.gd")
const MODES: Array[String] = ["A_direct","B_view","C_dense"]
const ORDERS: Array = [[0,1,2],[1,2,0],[2,0,1],[2,1,0],[1,0,2],[0,2,1]]
const MAX_ROUNDS: int = 120

static func build(source,key: Vector2i,lod: int,desired: Dictionary,mode: int) -> Dictionary:
    match mode:
        0: return G.generate(source,key.x,key.y,lod,desired)
        1: return G.generate_with_view(source,key.x,key.y,lod,desired)
        2: return G.generate_with_dense(source,key.x,key.y,lod,desired)
    return {"error":ERR_INVALID_PARAMETER}

static func equal(a: Dictionary,b: Dictionary) -> bool:
    if a.get("error",FAILED)!=OK or b.get("error",FAILED)!=OK:
        return false
    for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:
        if a["arrays"][slot]!=b["arrays"][slot]:
            return false
    return a["collision_heights"]==b["collision_heights"] and a["width"]==b["width"] and a["vertex_count"]==b["vertex_count"]

static func _timing(samples: Array) -> Dictionary:
    var sorted: Array = samples.duplicate()
    sorted.sort()
    var count: int = sorted.size()
    var sum: float = 0.0
    for value in sorted:
        sum += float(value)
    return {"count":count,"mean_us":sum/count,"p50_us":sorted[ceili(count*0.50)-1],"p95_us":sorted[ceili(count*0.95)-1],"p99_us":sorted[ceili(count*0.99)-1],"max_us":sorted[-1]}

static func run_case(source,key: Vector2i,lod: int,desired: Dictionary,rounds: int=24) -> Dictionary:
    if rounds < 6 or rounds > MAX_ROUNDS or rounds%6!=0:
        return {"error":ERR_INVALID_PARAMETER}
    # No IO pumping within a case. Caller warms exact resident halo.
    var pages: Array[Vector2i] = G.required_pages(source,key.x,key.y,lod)
    for page in pages:
        var status: Error = source.page_status(page)
        if status!=OK:
            return {"error":status}
    var expected: Dictionary = build(source,key,lod,desired,0)
    if expected.get("error",FAILED)!=OK:
        return expected
    for mode in [1,2]:
        if not equal(expected,build(source,key,lod,desired,mode)):
            return {"error":ERR_INVALID_DATA,"stage":"warmup parity"}
    var times: Array = [[],[],[]]
    var work: Array = []
    for mode in range(3):
        work.append({"direct_reads":0,"view_reads":0,"lru_touches":0,"dense_payload_peak":0})
    var initial: Dictionary = source.stats()
    for round_id in range(rounds):
        for mode in ORDERS[round_id%6]:
            var before: Dictionary = source.stats()
            var start: int = Time.get_ticks_usec()
            var result: Dictionary = build(source,key,lod,desired,mode)
            var elapsed: int = Time.get_ticks_usec()-start
            var after: Dictionary = source.stats()
            if not equal(expected,result):
                return {"error":ERR_INVALID_DATA,"stage":"timed parity","mode":mode}
            if after["tile_view_active_pages"]!=0:
                return {"error":ERR_BUG}
            times[mode].append(elapsed)
            work[mode]["direct_reads"] += after["direct_height_reads"]-before["direct_height_reads"]
            work[mode]["view_reads"] += after["tile_view_reads"]-before["tile_view_reads"]
            work[mode]["lru_touches"] += after["lru_touches"]-before["lru_touches"]
            work[mode]["dense_payload_peak"] = maxi(work[mode]["dense_payload_peak"],int(result.get("dense_payload_bytes",0)))
    var final_stats: Dictionary = source.stats()
    if initial["disk_reads"]!=final_stats["disk_reads"] or initial["evictions"]!=final_stats["evictions"] or initial["submitted"]!=final_stats["submitted"]:
        return {"error":ERR_BUG,"stage":"unexpected IO"}
    var reports: Dictionary = {}
    for mode in range(3):
        reports[MODES[mode]] = {"timing":_timing(times[mode]),"work":work[mode]}
    return {"error":OK,"rounds":rounds,"tile":[key.x,key.y],"lod":lod,"vertices_per_build":expected["vertex_count"],"pages":pages.size(),"modes":reports,"disk_reads_during_case":0,"evictions_during_case":0}
