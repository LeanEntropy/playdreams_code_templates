extends Node3D

## Main scene controller that manages title screen and game state.

@onready var title_screen: CanvasLayer = $TitleScreen
@onready var ui_layer: CanvasLayer = $UILayer
@onready var player: CharacterBody3D = $Player

var game_started: bool = false

func _ready() -> void:
	if not GameConfig.is_loaded:
		await GameConfig.config_loaded

	_setup_mobile_controls()

	var show_title: bool = GameConfig.get_value("title_screen", "show_title_screen", false)

	if show_title and title_screen:
		title_screen.show_title_screen()
		title_screen.play_pressed.connect(_on_play_pressed)
		get_tree().paused = true
		if ui_layer:
			ui_layer.visible = false
		if player:
			player.set_process_input(false)
			player.set_physics_process(false)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if title_screen:
			title_screen.visible = false
		_start_game()

func _on_play_pressed() -> void:
	get_tree().paused = false
	if ui_layer:
		ui_layer.visible = true
	if player:
		player.set_process_input(true)
		player.set_physics_process(true)
	_start_game()

func _setup_mobile_controls() -> void:
	var scene: PackedScene = load("res://assets/UI/mobile_controls.tscn")
	if scene:
		add_child(scene.instantiate())


func _start_game() -> void:
	game_started = true
	if not MobileControls.detect_mobile():
		var show_mode: String = GameConfig.get_value("controls", "show_mobile_controls", "auto")
		if show_mode != "always":
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
