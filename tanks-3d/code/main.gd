extends Node3D

## Main scene controller that manages title screen and game state
## Coordinates between title screen, player, and UI

@onready var title_screen: CanvasLayer = $TitleScreen
@onready var ui_layer: CanvasLayer = $UILayer
@onready var player: CharacterBody3D = $Player

var game_started: bool = false

func _ready() -> void:
	# Wait for GameConfig to load
	if not GameConfig.is_loaded:
		await GameConfig.config_loaded

	# Check if title screen should be shown
	var show_title: bool = GameConfig.get_value("title_screen", "show_title_screen", false)

	if show_title and title_screen:
		# Show title screen
		title_screen.show_title_screen()
		title_screen.play_pressed.connect(_on_play_pressed)

		# Pause the game until play is pressed
		get_tree().paused = true

		# Hide UI during title screen
		if ui_layer:
			ui_layer.visible = false

		# Disable player input
		if player:
			player.set_process_input(false)
			player.set_physics_process(false)

		# Make mouse visible for title screen
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		Log.info("Game starting with title screen")
	else:
		# Skip title screen, start game immediately
		if title_screen:
			title_screen.visible = false

		# CRITICAL: Set mouse mode for controller when skipping title screen
		_set_mouse_mode_for_controller()

		_start_game()
		Log.info("Game starting without title screen")

func _on_play_pressed() -> void:
	"""Called when title screen PLAY button is pressed"""
	Log.info("=== RECEIVED PLAY_PRESSED SIGNAL ===")
	Log.info("Current pause state: " + str(get_tree().paused))
	Log.info("Unpausing game...")

	# Unpause the game
	get_tree().paused = false
	Log.info("Game tree unpaused")

	# Show game UI
	if ui_layer:
		ui_layer.visible = true
		Log.info("UI layer shown")

	# Enable player input and physics
	if player:
		player.set_process_input(true)
		player.set_physics_process(true)
		Log.info("Player input and physics enabled")

	# Restore appropriate mouse mode for current controller
	_set_mouse_mode_for_controller()

	_start_game()
	Log.info("=== PLAY TRANSITION COMPLETE ===")

func _set_mouse_mode_for_controller() -> void:
	"""Set correct mouse mode based on active controller"""
	var control_mode = GameConfig.get_value("global", "controller_mode", "first_person")

	# Controllers that need captured mouse (hidden, locked to center)
	var captured_modes = ["first_person", "third_person", "over_the_shoulder", "tank"]

	# Controllers that need visible mouse (free movement)
	var visible_modes = ["isometric", "free_camera", "top_down"]

	if control_mode in captured_modes:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		Log.info("Mouse mode set to CAPTURED for controller: " + control_mode)
	elif control_mode in visible_modes:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Log.info("Mouse mode set to VISIBLE for controller: " + control_mode)
	else:
		# Default to captured for unknown modes
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		Log.warning("Unknown controller mode: " + control_mode + ", defaulting to CAPTURED")

func _start_game() -> void:
	"""Initialize game state after title screen is dismissed"""
	game_started = true
	Log.info("Game started")
