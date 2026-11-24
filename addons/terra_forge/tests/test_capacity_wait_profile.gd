extends SceneTree
const PROFILE=preload("res://addons/terra_forge/core/capacity_wait_profile.gd")

func _initialize() -> void:
    var p=PROFILE.new()
    var a=Vector2i(1,1)
    var b=Vector2i(2,1)
    var c=Vector2i(3,1)
    if p.observe(0,{a:0,b:1},true,1000)!=OK or p.observe(0,{a:0,b:1,c:2},true,4000)!=OK:
        _fail("open")
        return
    var active:Dictionary=p.report(5000)
    if active["active"]!=3 or active["critical_oldest_us"]!=4000 or active["optional_oldest_us"]!=4000 or active["critical_ms"]["count"]!=0:
        _fail("censored ages")
        return
    # b disappeared, c changed class; only a releases successfully.
    if p.observe(0,{a:0,c:0},false,6000)!=OK:
        _fail("release")
        return
    var done:Dictionary=p.report(6000)
    if done["critical_ms"]["count"]!=1 or done["critical_ms"]["mean_ms"]!=5.0 or done["optional_ms"]["count"]!=0 or done["cancelled"]!=2 or done["active"]!=0:
        _fail("classification")
        return
    p.observe(0,{a:0,b:2},true,7000)
    p.observe(1,{a:0,b:2},true,8000)
    p.observe(1,{a:0,b:2},false,11000)
    var final:Dictionary=p.report(11000)
    if final["cancelled"]!=4 or final["critical_ms"]["count"]!=2 or final["critical_ms"]["mean_ms"]!=4.0 or final["optional_ms"]["count"]!=1 or final["optional_ms"]["mean_ms"]!=3.0:
        _fail("epoch")
        return
    var oversize:Dictionary={}
    for i in range(129):
        oversize[Vector2i(i,0)]=0
    if p.observe(1,oversize,true,12000)==OK or p.observe(1,{a:3},true,12000)==OK or p.observe(1,{"bad":0},true,12000)==OK:
        _fail("invalid")
        return
    if p.report(12000)["observations"]!=6:
        _fail("invalid mutation")
        return
    print("CAPACITY_WAIT_TRACE ",JSON.stringify(final))
    print("PASS: bounded observed capacity episodes, class changes and epoch cancellation")
    quit(0)

func _fail(msg:String) -> void:
    push_error("Capacity wait: "+msg)
    quit(1)
