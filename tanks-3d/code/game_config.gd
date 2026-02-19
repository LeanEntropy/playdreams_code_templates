extends Node

signal config_loaded
var is_loaded: bool = false
var config := ConfigFile.new()

func get_value(section: String, key: String, default = null):
	return config.get_value(section, key, default)

func _ready() -> void:
	var err := config.load("res://game_config.cfg")
	if err != OK:
		Log.warning("game_config.cfg not found, using defaults")
	is_loaded = true
	config_loaded.emit()
