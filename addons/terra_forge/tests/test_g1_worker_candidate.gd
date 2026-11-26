extends "res://addons/terra_forge/tests/test_geometry_worker.gd"
const CAND=preload("res://addons/terra_forge/core/normal_cache_worker_candidate.gd")

func _initialize() -> void:
    for version in [1,2]:
        var src=ASYNC.new()
        var w=CAND.new()
        var b: Variant=V1.new() if version==1 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if version==1 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("candidate fixture start",src,w,b)
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("candidate fixture",src,w,b)
            return
        var folder: String=made["directory"]
        err=src.open(folder,16,4,false) if version==1 else src.open_v2(folder,16,4,false,2)
        if err!=OK or w.start(src,2,true)!=OK:
            _fail("candidate open",src,w,b)
            return
        var key=Vector2i(15,15)
        var neighbor=key+Vector2i.LEFT
        var cases: Array[Dictionary]=[{key:0,neighbor:0},{key:0},{key:0},{key:0,neighbor:2},{key:0,neighbor:2},{key:0,neighbor:2}]
        var expected_hits: Array[bool]=[false,true,true,false,true,false]
        var report: Dictionary={}
        var hit_us: int=0
        var full_us: int=0
        for i in range(cases.size()):
            if i==5 and src.set_generation(1)!=OK:
                _fail("epoch setup",src,w,b)
                return
            var desired: Dictionary=cases[i]
            if not _load(src,G.required_pages(src,key.x,key.y,0)):
                _fail("candidate load",src,w,b)
                return
            var expected: Dictionary=G.generate(src,key.x,key.y,0,desired)
            var submitted: Dictionary=w.submit(src,key,0,desired)
            if submitted["error"]!=OK or src.release_outside(Vector2i(18,18),Vector2i(18,18))!=OK:
                _fail("candidate submit or evict",src,w,b)
                return
            var result: Dictionary=_wait(w,src,desired)
            if result.get("error",FAILED)!=OK or not BENCH.equal(expected,result["result"]["geometry"]):
                _fail("candidate parity "+str(i),src,w,b)
                return
            report=result["result"]["g1_candidate"]
            if report["hit"]!=expected_hits[i] or report["cache"]["peak_bytes"]>262144 or report["cache"]["metadata_keys"]>20 or report["retain_fail"]!=0:
                _fail("candidate gate "+str(i)+" "+str(report),src,w,b)
                return
            if report["hit"]:
                hit_us+=int(result["result"]["build_elapsed_us"])
            else:
                full_us+=int(result["result"]["build_elapsed_us"])
        if report["full"]!=3 or report["partial"]!=3 or w.stats()["delivered"]!=6 or w.stats()["slots"]!=0:
            _fail("candidate counts",src,w,b)
            return
        print("G1_WORKER_CANDIDATE ",JSON.stringify({"format":version,"cases":6,"forced_hits":3,"full":3,"hit_us":hit_us,"full_us":full_us,"report":report,"note":"Different forced cases; not equal-work speedup, no preview publication, retained raw payload only"}))
        w.close()
        src.close()
        b.close()
    print("PASS: G1 actual worker-owned cache, full/patch parity, epoch fencing, bounded retention and source eviction")
    quit(0)
