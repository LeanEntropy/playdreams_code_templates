class_name Log
extends Node

enum LogLevel { INFO, WARNING, ERROR, PERFORMANCE }

static var performance_timers: Dictionary = {}

static func _log(level: LogLevel, message: String) -> void:
	var timestamp = Time.get_datetime_string_from_system(false, true)
	var log_level_str = LogLevel.keys()[level]
	var formatted_message = "[%s] [%s] %s" % [timestamp, log_level_str, message]

	match level:
		LogLevel.INFO:
			print(formatted_message)
		LogLevel.WARNING:
			print_rich("[color=yellow]%s[/color]" % formatted_message)
		LogLevel.ERROR:
			printerr(formatted_message)
		LogLevel.PERFORMANCE:
			print_rich("[color=cyan]%s[/color]" % formatted_message)

static func info(message: String) -> void:
	_log(LogLevel.INFO, message)

static func warning(message: String) -> void:
	_log(LogLevel.WARNING, message)

static func error(message: String) -> void:
	_log(LogLevel.ERROR, message)

static func performance(message: String) -> void:
	_log(LogLevel.PERFORMANCE, message)

static func start_performance_check(check_name: String) -> void:
	performance_timers[check_name] = Time.get_ticks_usec()
	performance("Starting performance check: '%s'" % check_name)

static func end_performance_check(check_name: String) -> void:
	if performance_timers.has(check_name):
		var start_time = performance_timers[check_name]
		var end_time = Time.get_ticks_usec()
		var duration_ms = (end_time - start_time) / 1000.0
		performance("'%s' took %.4f ms" % [check_name, duration_ms])
		performance_timers.erase(check_name)
	else:
		warning("Performance check '%s' ended without being started." % check_name)

# Aliases for backwards compatibility
static func start_timer(label: String) -> void:
	start_performance_check(label)

static func end_timer(label: String) -> void:
	end_performance_check(label)
