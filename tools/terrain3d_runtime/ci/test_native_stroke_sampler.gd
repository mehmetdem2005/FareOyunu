extends SceneTree
const Sampler = preload("res://addons/terraforge_native/native_stroke_sampler.gd")

func _drain(s: RefCounted) -> Array[Vector2]:
    var output: Array[Vector2] = []
    while s.pending_count() > 0:
        output.append(s.take_next())
    return output

func _matches(a: Array[Vector2], b: Array[Vector2]) -> bool:
    if a.size() != b.size():
        return false
    for i in range(a.size()):
        if a[i].distance_to(b[i]) > 0.0001:
            return false
    return true

func _fail(message: String) -> void:
    push_error("TF_STROKE_SAMPLER_FAIL: " + message)
    quit(1)

func _initialize() -> void:
    var sparse = Sampler.new()
    var dense = Sampler.new()
    if not sparse.begin(2.0) or not dense.begin(2.0):
        _fail("begin")
        return
    if not sparse.offer(Vector2.ZERO) or not sparse.offer(Vector2(20,0)):
        _fail("sparse input")
        return
    for i in range(81):
        if not dense.offer(Vector2(i*0.25,0)):
            _fail("dense input")
            return
    if not sparse.seal() or not dense.seal():
        _fail("seal")
        return
    var a := _drain(sparse)
    var b := _drain(dense)
    if not _matches(a,b) or a.size()!=11 or not sparse.is_complete():
        _fail("cadence invariance")
        return
    print("TF_STROKE_CADENCE_OK sparse=2 dense=81 dabs=",a.size())
    var corner = Sampler.new()
    corner.begin(2.0)
    corner.offer(Vector2.ZERO)
    corner.offer(Vector2(3,0))
    corner.offer(Vector2(3,3))
    corner.seal()
    var expected: Array[Vector2] = [Vector2.ZERO,Vector2(2,0),Vector2(3,1),Vector2(3,3)]
    if not _matches(_drain(corner),expected):
        _fail("corner arc length")
        return
    var gap = Sampler.new()
    gap.begin(2.0)
    gap.offer(Vector2.ZERO)
    gap.offer(Vector2(2,0))
    gap.break_path()
    gap.offer(Vector2(100,0))
    gap.offer(Vector2(102,0))
    gap.seal()
    expected = [Vector2.ZERO,Vector2(2,0),Vector2(100,0),Vector2(102,0)]
    if not _matches(_drain(gap),expected):
        _fail("ray gap bridge")
        return
    print("TF_STROKE_PATH_OK corner=true gap=true")
    var bounded = Sampler.new()
    bounded.begin(1.0)
    bounded.offer(Vector2.ZERO)
    if bounded.offer(Vector2(256,0)) or bounded.pending_count()!=1:
        _fail("overflow must be atomic")
        return
    if not bounded.offer(Vector2(255,0)) or bounded.pending_count()!=256:
        _fail("capacity")
        return
    if bounded.take_next()!=Vector2.ZERO or bounded.pending_count()!=255:
        _fail("one sample consumer")
        return
    if not bounded.offer(Vector2(256,0)) or bounded.pending_count()!=256:
        _fail("retry after drain")
        return
    var drained := _drain(bounded)
    if drained[0]!=Vector2(1,0) or drained.back()!=Vector2(256,0):
        _fail("overflow changed phase or order")
        return
    bounded.seal()
    if not bounded.is_complete():
        _fail("completion")
        return
    var endpoint = Sampler.new()
    endpoint.begin(2.0)
    endpoint.offer(Vector2.ZERO)
    endpoint.offer(Vector2(5.5,0))
    endpoint.seal()
    expected = [Vector2.ZERO,Vector2(2,0),Vector2(4,0),Vector2(5.5,0)]
    if not _matches(_drain(endpoint),expected) or endpoint.offer(Vector2(6,0)):
        _fail("endpoint/sealed state")
        return
    endpoint.begin(2.0)
    endpoint.offer(Vector2.ZERO)
    endpoint.cancel()
    if endpoint.pending_count()!=0 or endpoint.offer(Vector2.ZERO) or endpoint.begin(NAN):
        _fail("cancel/invalid step")
        return
    print("TF_STROKE_BOUNDS_OK capacity=256 atomic=true retry=true endpoint=true cancel=true")
    print("TF_STROKE_SAMPLER_PASS")
    quit(0)
