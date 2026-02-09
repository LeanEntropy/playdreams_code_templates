extends CanvasLayer

@onready var pause_label = $CenterContainer/PauseLabel
@onready var pause_button = $MarginContainer/PauseButton
@onready var crosshair = $Crosshair

var pause_key_primary
var pause_key_secondary

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	pause_label.hide()
	get_tree().paused = false

	var config = ConfigFile.new()
	config.load("res://game_config.cfg")

	var primary_key_str = config.get_value("controls", "pause_key_primary", "P")
	var secondary_key_str = config.get_value("controls", "pause_key_secondary", "")
	pause_key_primary = OS.find_keycode_from_string(primary_key_str)
	if secondary_key_str != "":
		pause_key_secondary = OS.find_keycode_from_string(secondary_key_str)

	_update_crosshair_visibility()

func _unhandled_input(event):
	if event is InputEventKey and event.is_pressed():
		if event.keycode == pause_key_primary or (pause_key_secondary and event.keycode == pause_key_secondary):
			toggle_pause()

func toggle_pause():
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		pause_label.show()
		pause_button.text = "Resume"
		if crosshair:
			crosshair.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		pause_label.hide()
		pause_button.text = "Pause"
		_update_crosshair_visibility()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_PauseButton_pressed():
	toggle_pause()

func _update_crosshair_visibility() -> void:
	if not crosshair:
		return
	var show_crosshair = GameConfig.get_value("ui", "show_crosshair", true)
	crosshair.visible = show_crosshair
