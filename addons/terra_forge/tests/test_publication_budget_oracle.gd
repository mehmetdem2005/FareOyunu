extends SceneTree
const A=preload("res://addons/terra_forge/core/publication_accounting.gd")
const ZERO: Dictionary={"vertices":0,"triangles":0,"mesh_bytes":0,"shape_bytes":0,"total_bytes":0,"meshes":0,"shapes":0}

func _initialize() -> void:
    var rng=RandomNumberGenerator.new()
    rng.seed=151103
    var bytes_by_lod: Array[int]=[116052,26192,8024]
    # Derive the independent source-byte oracle from the contract.
    for lod in range(3):
        var side: int=32>>lod
        var vertices: int=(side+1)*(side+1)
        bytes_by_lod[lod]=vertices*80+side*side*6*4+(vertices*4 if lod==0 else 0)
    var totals: Dictionary={"cases":0,"attempts":0,"published":0,"count_stops":0,"time_stops":0,"byte_stops":0,"first_oversize":0,"over_time":0,"over_bytes":0}
    for trial in range(512):
        var count_cap: int=rng.randi_range(1,4)
        var byte_cap: int=[1,bytes_by_lod[2],bytes_by_lod[1]*2,65536,131072][trial%5]
        var time_cap: int=[1,1000,8000,16000][trial%4]
        var a=A.new()
        a.configure_budget(true,byte_cap,time_cap)
        a.begin_pump(count_cap)
        var count: int=0
        var used: int=0
        var elapsed: int=0
        var count_stops: int=0
        var time_stops: int=0
        var byte_stops: int=0
        var first_oversize: int=0
        # First critical tile then optional candidates. This is a policy oracle,
        # not proof of the runtime scheduler's ordering.
        for attempt in range(12):
            var lod: int=0 if attempt==0 else rng.randi_range(0,2)
            var cost: int=[0,1,time_cap-1,time_cap,time_cap+1,128279][rng.randi_range(0,5)]
            var size: int=bytes_by_lod[lod]
            var expected: bool=true
            if count>0:
                if count>=count_cap:
                    count_stops+=1
                    expected=false
                elif elapsed>=time_cap:
                    time_stops+=1
                    expected=false
                elif used+size>byte_cap:
                    byte_stops+=1
                    expected=false
            totals["attempts"]+=1
            if a.admit(lod)!=expected:
                _fail("oracle admission "+str(trial)+":"+str(attempt))
                return
            if expected:
                if count==0 and size>byte_cap:
                    first_oversize+=1
                a.record(lod,A.expected(lod),0,0,cost)
                used+=size
                elapsed+=cost
                count+=1
        a.end_pump(ZERO)
        var report: Dictionary=a.report(ZERO)
        if int(report["publication_count"])!=count or int(report["total_source_bytes"])!=used or int(report["peak_pump_publish_us"])!=elapsed or int(report["count_stop_checks"])!=count_stops or int(report["time_stop_checks"])!=time_stops or int(report["byte_deferral_checks"])!=byte_stops or int(report["first_item_byte_exceptions"])!=first_oversize or int(report["over_count_pumps"])!=0 or int(report["over_time_pumps"])!=int(elapsed>time_cap) or int(report["over_byte_pumps"])!=int(used>byte_cap) or count<1:
            _fail("counter oracle "+str(trial))
            return
        totals["cases"]+=1
        totals["published"]+=count
        totals["count_stops"]+=count_stops
        totals["time_stops"]+=time_stops
        totals["byte_stops"]+=byte_stops
        totals["first_oversize"]+=first_oversize
        totals["over_time"]+=int(elapsed>time_cap)
        totals["over_bytes"]+=int(used>byte_cap)
        # Next pump resets admission; previous oversize must not starve progress.
        a.begin_pump(count_cap)
        if not a.admit(0):
            _fail("next-pump critical progress")
            return
        a.record(0,A.expected(0),0,0,1)
        a.end_pump(ZERO)
        if int(a.report(ZERO)["publication_count"])!=count+1:
            _fail("second pump accounting")
            return
    print("PUBLICATION_BUDGET_ORACLE ",JSON.stringify(totals))
    print("PASS: 512 deterministic budget cases, 6144 admissions, count/time/byte precedence, critical-first progress and reset")
    quit(0)

func _fail(reason: String) -> void:
    push_error("Publication oracle: "+reason)
    quit(1)
