extends Logger
## Thread-safe, bounded in-memory log capture; full structured traces saved per case.
var _lock := Mutex.new()
var _active: bool = false
var _lines: Array[String] = []
var _errors: Array[String] = []
var _bytes: int = 0
var _truncated: bool = false
var _passed: bool = false

func begin() -> void:
    _lock.lock()
    _active = true
    _lines.clear()
    _errors.clear()
    _bytes = 0
    _truncated = false
    _passed = false
    _lock.unlock()

func _log_message(message: String, _error: bool) -> void:
    _lock.lock()
    if _active:
        if message.strip_edges().begins_with("PASS:"):
            _passed = true
        if _bytes + message.length() <= 8000000:
            _lines.append(message)
            _bytes += message.length()
        else:
            _truncated = true
    _lock.unlock()

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
    _lock.lock()
    if _active and error_type != 1:
        if _errors.size() < 128:
            _errors.append("%s:%d %s %s %s" % [file,line,function,code,rationale])
        else:
            _truncated = true
    _lock.unlock()

func take() -> Dictionary:
    _lock.lock()
    _active = false
    var data := {"messages": _lines.duplicate(), "errors": _errors.duplicate(), "pass_marker": _passed, "truncated": _truncated}
    _lock.unlock()
    return data
