extends SceneTree
## CI parse/load all adapted runnable scripts before long regression shards.
## Do not instantiate or execute test cases.
func _initialize() -> void:
    var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://suite.json"))
    if not data is Dictionary or not data.get("tests") is Array or data["tests"].is_empty():
        push_error("Invalid adapter inventory")
        quit(1)
        return
    var passed: int=0
    var failures: Array[String]=[]
    for name in data["tests"]:
        var script: Resource=load("res://mobile_tests/"+str(name)+".gd")
        if not script is GDScript or not script.can_instantiate() or script.get_instance_base_type()!="Node":
            failures.append(str(name))
        else:
            passed+=1
    print("ANDROID_ADAPTER_LOAD_GATE ",JSON.stringify({"passed":passed,"total":data["tests"].size(),"failures":failures}))
    quit(0 if failures.is_empty() and passed==data["tests"].size() else 1)
