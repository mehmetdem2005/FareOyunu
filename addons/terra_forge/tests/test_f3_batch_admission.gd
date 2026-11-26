extends SceneTree
const SRC=preload("res://addons/terra_forge/core/async_region_source.gd")
const BATCH=preload("res://addons/terra_forge/core/batch_region_source_candidate.gd")
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")

func _initialize() -> void:
    for format in [0,1]:
        var b: Variant=V1.new() if format==0 else V2.new()
        var err: Error=b.start(Vector2i(576,576),true) if format==0 else b.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start",null,b)
            return
        var made: Dictionary={}
        for attempt in range(15000):
            made=b.take_result()
            if made["error"]!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture",null,b)
            return
        var arms: Array[bool]=[false,true]
        if format==1:
            arms.reverse()
        var reference: PackedFloat32Array=PackedFloat32Array()
        for batch in arms:
            var src: Variant=BATCH.new() if batch else SRC.new()
            var folder: String=made["directory"]
            err=src.open(folder,9,4,false) if format==0 else src.open_v2(folder,9,4,false,1)
            if err!=OK:
                _fail("open",src,b)
                return
            var values=PackedFloat32Array()
            var admission_us: int=0
            var peak_us: int=0
            var statuses: Array[int]=[]
            for round_id in range(32):
                if src.release_outside(Vector2i(18,18),Vector2i(18,18))!=OK:
                    _fail("cold reset",src,b)
                    return
                var x: int=14+(round_id%2)
                var z: int=14+((round_id/2)%2)
                var keys: Array[Vector2i]=[Vector2i(x,z),Vector2i(x+1,z),Vector2i(x,z+1),Vector2i(x+1,z+1),Vector2i(x,z),Vector2i(-1,-1),Vector2i(0,0)]
                var t: int=Time.get_ticks_usec()
                if batch:
                    var result: Dictionary=src.request_pages(keys)
                    if result["error"]!=OK or result["added"]!=4:
                        _fail("batch admission",src,b)
                        return
                    statuses.assign(result["statuses"])
                else:
                    statuses.clear()
                    for k in keys:
                        statuses.append(src.request_page(k))
                var elapsed: int=Time.get_ticks_usec()-t
                admission_us+=elapsed
                peak_us=maxi(peak_us,elapsed)
                if statuses!=[OK,OK,OK,OK,OK,ERR_INVALID_PARAMETER,ERR_BUSY]:
                    _fail("status parity "+str(statuses),src,b)
                    return
                for attempt in range(4000):
                    src.poll_results(4)
                    if src.stats()["resident"]==4:
                        break
                    OS.delay_msec(1)
                for i in range(4):
                    var k: Vector2i=keys[i]
                    var value: Dictionary=src.get_height(k.x*32,k.y*32)
                    if value["error"]!=OK:
                        _fail("verified sample",src,b)
                        return
                    values.append(value["height"])
                var s: Dictionary=src.stats()
                if s["resident"]!=4 or s["submitted"]!=(round_id+1)*4 or s["accepted_results"]!=s["submitted"] or s["outstanding"]+s["inflight"]+s["finished"]!=0:
                    _fail("ownership conservation",src,b)
                    return
            if reference.is_empty():
                reference=values
            elif reference!=values:
                _fail("equal verified heights",src,b)
                return
            var stats: Dictionary=src.stats()
            print("F3_BATCH_ADMISSION ",JSON.stringify({"format":format+1,"batch":batch,"rounds":32,"admission_us":admission_us,"peak_us":peak_us,"disk_reads":stats["disk_reads"],"submitted":stats["submitted"],"wake_posts":stats["wake_posts"],"shard_loads":stats["shard_loads"],"note":"Equal cold ordered page admissions; no physical I/O coalescing or route/device claim"}))
            src.close()
        b.close()
    print("PASS: F3 ordered bounded batch versus individual admissions, exact status and verified height parity, ownership conservation")
    quit(0)

func _fail(msg: String,src,b) -> void:
    if src!=null:
        src.close()
    if b!=null:
        b.close()
    push_error("F3 batch: "+msg)
    quit(1)
