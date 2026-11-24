@tool
extends RefCounted
## Main-thread, bounded per-class delivered-result accounting.
## Not a record of every submitted job: cancelled/failed work is separate.
const HIST=preload("res://addons/terra_forge/core/profile_histogram.gd")
var _critical: Dictionary=_group()
var _optional: Dictionary=_group()

static func _group() -> Dictionary:
    return {"queue":HIST.new(),"build":HIST.new(),"delivery":HIST.new(),"total":HIST.new(),"errors":0}

func record(result: Dictionary) -> void:
    var group: Dictionary=_critical if int(result["lod"])==0 else _optional
    if int(result["geometry"]["error"])!=OK:
        group["errors"]+=1
        return
    group["queue"].add(float(result["queue_wait_us"])/1000.0)
    group["build"].add(float(result["build_elapsed_us"])/1000.0)
    group["delivery"].add(float(result["delivery_wait_us"])/1000.0)
    group["total"].add(float(result["queue_wait_us"]+result["build_elapsed_us"]+result["delivery_wait_us"])/1000.0)

static func _report_group(group: Dictionary) -> Dictionary:
    return {"queue_ms":group["queue"].report(),"build_ms":group["build"].report(),"delivery_ms":group["delivery"].report(),"stage_sum_ms":group["total"].report(),"delivered_errors":group["errors"]}

func report() -> Dictionary:
    return {"critical":_report_group(_critical),"optional":_report_group(_optional),"scope":"successful_delivered_results_only"}
