extends SceneTree
const SRC=preload("res://addons/terra_forge/core/async_region_source.gd")
const V1=preload("res://addons/terra_forge/core/profile_fixture_builder.gd")
const V2=preload("res://addons/terra_forge/core/region_fixture_v2.gd")

func _initialize() -> void:
    for format in [0,1]:
        var builder: Variant=V1.new() if format==0 else V2.new()
        var err: Error=builder.start(Vector2i(576,576),true) if format==0 else builder.start(Vector2i(576,576))
        if err!=OK:
            _fail("fixture start",null,builder)
            return
        var made: Dictionary={}
        for step in range(15000):
            made=builder.take_result()
            if made.get("error",FAILED)!=ERR_BUSY:
                break
            OS.delay_msec(2)
        if made.get("error",FAILED)!=OK:
            _fail("fixture build",null,builder)
            return
        for cap in [1,3]:
            var delays: Array[int]=[0,12,12,0]
            for trial in range(delays.size()):
                var src=SRC.new()
                var directory: String=made["directory"]
                err=src.open(directory,4,cap,false) if format==0 else src.open_v2(directory,4,cap,false,1)
                if err!=OK:
                    _fail("open",src,builder)
                    return
                src.collect_io_profile=true
                var poll_us: int=0
                var injected_us: int=0
                for cycle in range(8):
                    for z in range(cap):
                        if src.request_page(Vector2i(cycle+1,z+1))!=OK:
                            _fail("request",src,builder)
                            return
                    if not _ready(src,cap):
                        _fail("ready timeout",src,builder)
                        return
                    var ready_at: int=Time.get_ticks_usec()
                    var target_us: int=delays[trial]*1000
                    while Time.get_ticks_usec()-ready_at<target_us:
                        OS.delay_msec(1)
                    injected_us+=Time.get_ticks_usec()-ready_at
                    var before: int=Time.get_ticks_usec()
                    var accepted: Dictionary=src.poll_results(cap)
                    poll_us+=Time.get_ticks_usec()-before
                    if accepted.get("committed",0)!=cap or accepted.get("failed",-1)!=0:
                        _fail("accept",src,builder)
                        return
                    for z in range(cap):
                        if src.page_status(Vector2i(cycle+1,z+1))!=OK:
                            _fail("resident",src,builder)
                            return
                var stats: Dictionary=src.stats()
                var profile: Dictionary=src.pipeline_profile()
                for stage in ["queue_wait_ms","worker_service_ms","delivery_wait_ms","request_to_accept_ms"]:
                    if int(profile[stage]["count"])!=8*cap:
                        _fail("sample count "+stage,src,builder)
                        return
                if int(stats["submitted"])!=8*cap or int(stats["accepted_results"])!=8*cap or int(stats["disk_reads"])!=8*cap or int(stats["finished"])!=0 or int(stats["inflight"])!=0 or int(stats["outstanding"])!=0 or int(stats["resident"])>4:
                    _fail("equal work or bounds",src,builder)
                    return
                if delays[trial]>0 and float(profile["delivery_wait_ms"]["mean_ms"])<float(delays[trial]):
                    _fail("injected delivery wait missing",src,builder)
                    return
                # Cancel one ready result; it must not enter accepted histograms.
                if src.request_page(Vector2i(12,12))!=OK or not _ready(src,1) or src.set_generation(1)!=OK:
                    _fail("cancel setup",src,builder)
                    return
                var after: Dictionary=src.stats()
                if int(after["cancelled_finished"])!=1 or int(after["accepted_results"])!=8*cap or int(after["submitted"])!=8*cap+1 or int(src.pipeline_profile()["delivery_wait_ms"]["count"])!=8*cap:
                    _fail("cancelled sample contamination",src,builder)
                    return
                print("IO_DELIVERY_ABBA ",JSON.stringify({"format":format+1,"cap":cap,"trial":trial,"hold_ms":delays[trial],"injected_us":injected_us,"poll_wall_us":poll_us,"accepted":8*cap,"cancelled_finished":1,"profile":profile,"shard_loads":stats["shard_loads"],"resident":stats["resident"],"note":"Injected ready hold; not an optimization or physical disk measurement"}))
                src.close()
                if int(src.pipeline_profile()["delivery_wait_ms"]["count"])!=0:
                    _fail("close reset",src,builder)
                    return
        builder.close()
    print("PASS: matched reader delivery ABBA, controlled ready delay, bounded cap1/3, cancelled result isolation, both formats")
    quit(0)

func _ready(src, count: int) -> bool:
    var deadline: int=Time.get_ticks_msec()+5000
    while Time.get_ticks_msec()<deadline:
        if int(src.stats()["finished"])==count:
            return true
        OS.delay_msec(1)
    return false

func _fail(reason: String,src,builder) -> void:
    if src!=null:
        src.close()
    if builder!=null:
        builder.close()
    push_error("IO delivery ABBA: "+reason)
    quit(1)
