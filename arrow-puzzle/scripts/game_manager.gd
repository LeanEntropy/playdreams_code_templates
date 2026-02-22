extends Node

signal level_changed(level_index: int)

var current_level: int = 0
var max_unlocked: int = 0

var _levels: Array = []


func _ready() -> void:
	_load_levels()
	_load_progress()


func _load_levels() -> void:
	var path := "res://data/levels.json"
	if not FileAccess.file_exists(path):
		push_warning("levels.json not found at %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("Failed to parse levels.json: %s" % json.get_error_message())
		return
	var data = json.data
	if data is Dictionary and data.has("levels"):
		_levels = data["levels"]
	elif data is Array:
		_levels = data
	else:
		push_error("levels.json has unexpected format")
		return


func _load_progress() -> void:
	if not FileAccess.file_exists(Config.SAVE_PATH):
		return
	var file := FileAccess.open(Config.SAVE_PATH, FileAccess.READ)
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_warning("Failed to parse save file, starting fresh")
		return
	if not json.data is Dictionary:
		push_warning("Save file has unexpected format, starting fresh")
		return
	var data: Dictionary = json.data
	if data.get("version", 0) != Config.SAVE_VERSION:
		push_warning("Save version mismatch, starting fresh")
		return
	max_unlocked = clampi(data.get("max_unlocked", 0), 0, maxi(get_level_count() - 1, 0))
	current_level = clampi(data.get("current_level", 0), 0, max_unlocked)


func _save_progress() -> void:
	var data := {
		"version": Config.SAVE_VERSION,
		"current_level": current_level,
		"max_unlocked": max_unlocked,
	}
	var file := FileAccess.open(Config.SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func get_current_level_data() -> Dictionary:
	if current_level >= 0 and current_level < _levels.size():
		return _levels[current_level]
	return {}


func complete_current_level() -> void:
	if current_level + 1 > max_unlocked:
		max_unlocked = mini(current_level + 1, maxi(get_level_count() - 1, 0))
	_save_progress()
	if current_level + 1 < get_level_count():
		set_level(current_level + 1)
	else:
		# All levels completed, loop back to first
		set_level(0)


func get_level_count() -> int:
	return _levels.size()


func set_level(index: int) -> void:
	if index >= 0 and index < get_level_count():
		current_level = index
		_save_progress()
		level_changed.emit(current_level)
