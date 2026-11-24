extends SceneTree
const S = preload("res://addons/terra_forge/core/support_tile_selection.gd")

func _initialize() -> void:
    var grid = Vector2i(18,18)
    var a = Vector2i(15,15)
    var b = Vector2i(16,15)
    var c = Vector2i(1,1)
    var d = Vector2i(1,2)
    var e = Vector2i(2,2)
    var support: Array[Vector2i] = [a,b]
    var camera: Array[Dictionary] = [{"key":c,"lod":0},{"key":d,"lod":1},{"key":a,"lod":2},{"key":e,"lod":2},{"key":c,"lod":0}]
    var original_support = support.duplicate()
    var original_camera = camera.duplicate(true)
    var one: Array[Vector2i] = [a]
    var empty: Array[Vector2i] = []
    var four: Array[Vector2i] = [a,b,Vector2i(15,16),Vector2i(16,16)]
    var five: Array[Vector2i] = [a,b,Vector2i(15,16),Vector2i(16,16),e]
    var dup: Array[Vector2i] = [a,a]
    var outside: Array[Vector2i] = [Vector2i(18,0)]
    var bad: Array[Dictionary] = camera.duplicate(true)
    bad.append({"key":Vector2i(-1,0),"lod":0})
    var conflict: Array[Dictionary] = camera.duplicate(true)
    conflict.append({"key":c,"lod":2})
    var missing: Array[Dictionary] = [{"key":c}]
    var bad_lod: Array[Dictionary] = [{"key":c,"lod":3}]
    var too_many: Array[Dictionary] = []
    for i in range(129):
        too_many.append({"key":c,"lod":0})
    var checks: Array[bool] = []
    var r: Dictionary = S.select(one,camera,grid,1)
    checks.append(r.get("desired",{}) == {a:0})
    r = S.select(support,camera,grid,4)
    checks.append(r.get("desired",{}) == {a:0,b:0,c:0,d:1})
    checks.append(r.get("desired",{}).keys() == [a,b,c,d])
    checks.append(S.select(support,camera,grid,4) == r)
    checks.append(S.select(four,camera,grid,4).get("desired",{}).size() == 4)
    checks.append(S.select(support,camera,grid,8).get("desired",{}) == {a:0,b:0,c:0,d:1,e:2})
    checks.append(S.select(empty,camera,grid,8).get("desired",{}) == {c:0,d:1,a:2,e:2})
    checks.append(S.select(empty,[],grid,1).get("desired",{}).is_empty())
    for denied in [S.select(support,camera,grid,1),S.select(five,camera,grid,8),S.select(dup,camera,grid,4),S.select(outside,camera,grid,4),S.select(one,bad,grid,1),S.select(one,conflict,grid,1),S.select(one,missing,grid,4),S.select(one,bad_lod,grid,4),S.select(one,too_many,grid,4),S.select(one,camera,grid,0),S.select(one,camera,grid,129),S.select(one,camera,Vector2i.ZERO,4)]:
        checks.append(denied["error"] != OK and not denied.has("desired"))
    checks.append(support == original_support and camera == original_camera)
    for i in range(checks.size()):
        if not checks[i]:
            push_error("Support tile selection invariant failed: %d" % i)
            quit(1)
            return
    print("SUPPORT_SELECTION ",JSON.stringify({"checks":checks.size(),"support_cap":S.MAX_SUPPORT,"total_cap":S.MAX_TOTAL,"pure_only":true}))
    print("PASS: bounded deterministic support-first selection, cap and invalid input rejection, caller inputs unchanged")
    quit(0)
