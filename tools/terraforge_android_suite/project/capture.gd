extends Logger
## Thread-safe, bounded in-memory log capture; full structured traces saved per case.
var _lock := Mutex.new()
var _active: bool = false
var _lines: Array[String] = []
var _errors: Array[String] = []
var _bytes: int = 0
var _truncated: bool = false
var _passed: bool = false
var _records: Array[Dictionary]=[]
var _types: Dictionary={}
var _record_bytes: int=0
var _record_dropped: int=0
var _message_dropped: int=0

func begin() -> void:
    _lock.lock()
    _active = true
    _lines.clear()
    _errors.clear()
    _bytes = 0
    _truncated = false
    _passed = false
    _records.clear()
    _types.clear()
    _record_bytes=0
    _record_dropped=0
    _message_dropped=0
    _lock.unlock()

func _log_message(message: String, _error: bool) -> void:
    _lock.lock()
    if _active:
        if message.strip_edges().begins_with("PASS:"):
            _passed = true
        var bytes: int=message.to_utf8_buffer().size()
        if _bytes + bytes <= 8000000:
            _lines.append(message)
            _bytes += bytes
        else:
            _message_dropped+=1
            _truncated = true
    _lock.unlock()

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
    _lock.lock()
    if _active:
        var key: String=str(error_type)
        _types[key]=int(_types.get(key,0))+1
        var entry: Dictionary={"type":error_type,"function":function,"file":file,"line":line,"code":code,"rationale":rationale,"editor_notify":_editor_notify,"script_backtrace_count":_script_backtraces.size()}
        var size: int=JSON.stringify(entry).to_utf8_buffer().size()
        if _records.size()<512 and _record_bytes+size<=2000000:
            _records.append(entry)
            _record_bytes+=size
        else:
            _record_dropped+=1
        # Preserve V4 pass/fail contract; warning type is retained separately.
        if error_type!=1:
            if _errors.size()<128:
                _errors.append("%s:%d %s %s %s" % [file,line,function,code,rationale])
            else:
                _truncated=true
    _lock.unlock()

func take() -> Dictionary:
    _lock.lock()
    _active = false
    var data := {"messages": _lines.duplicate(), "errors": _errors.duplicate(), "pass_marker": _passed, "truncated": _truncated,"diagnostics":_records.duplicate(true),"error_type_counts":_types.duplicate(),"diagnostic_dropped":_record_dropped,"message_dropped":_message_dropped}
    _lock.unlock()
    return data
