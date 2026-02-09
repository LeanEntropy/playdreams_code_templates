class_name Log
extends Node

enum LogLevel { INFO, WARNING, ERROR, PERFORMANCE }

static var _timers: Dictionary = {}

static func _log(level: LogLevel, message: String) -> void:
	var timestamp = Time.get_datetime_string_from_system(false, true)
	var formatted = "[%s] [%s] %s" % [timestamp, LogLevel.keys()[level], message]
	match level:
		LogLevel.WARNING:
			print_rich("[color=yellow]%s[/color]" % formatted)
		LogLevel.ERROR:
			printerr(formatted)
		LogLevel.PERFORMANCE:
			print_rich("[color=cyan]%s[/color]" % formatted)
		_:
			print(formatted)

static func info(message: String) -> void:
	_log(LogLevel.INFO, message)

static func warning(message: String) -> void:
	_log(LogLevel.WARNING, message)

static func error(message: String) -> void:
	_log(LogLevel.ERROR, message)

static func start_timer(label: String) -> void:
	_timers[label] = Time.get_ticks_usec()

static func end_timer(label: String) -> void:
	if _timers.has(label):
		var ms = (Time.get_ticks_usec() - _timers[label]) / 1000.0
		_log(LogLevel.PERFORMANCE, "'%s' took %.4f ms" % [label, ms])
		_timers.erase(label)
