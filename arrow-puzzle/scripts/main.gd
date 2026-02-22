extends Node2D

@onready var _start_screen: CanvasLayer = $StartScreen
@onready var _settings_screen: CanvasLayer = $SettingsScreen
@onready var _game_board: Node2D = $GameBoard
@onready var _hud: CanvasLayer = $HUD
@onready var _victory_screen: CanvasLayer = $VictoryScreen


var _game_over_overlay: ColorRect = null
var _transition_overlay: ColorRect = null
var _victory_transitioning: bool = false


func _ready() -> void:
	# Set viewport clear color from active theme
	RenderingServer.set_default_clear_color(Config.COLOR_BG)

	# Create transition overlay (fade, CanvasLayer 15)
	var transition_canvas := CanvasLayer.new()
	transition_canvas.layer = 15
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Config.COLOR_BG
	_transition_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_transition_overlay.anchor_right = 1.0
	_transition_overlay.anchor_bottom = 1.0
	_transition_overlay.modulate.a = 0.0
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_canvas.add_child(_transition_overlay)
	add_child(transition_canvas)

	_start_screen.play_pressed.connect(_on_play_pressed)
	_start_screen.settings_pressed.connect(_show_settings_screen)
	_settings_screen.home_pressed.connect(_show_start_screen)
	_game_board.all_arrows_cleared.connect(_on_all_arrows_cleared)
	_game_board.hearts_changed.connect(_on_hearts_changed)
	_game_board.hearts_depleted.connect(_on_hearts_depleted)
	_game_board.guides_turned_off.connect(_on_guides_turned_off)
	_hud.reset_pressed.connect(_on_reset_pressed)
	_hud.back_pressed.connect(_on_back_pressed)
	_hud.guide_toggled.connect(_on_guide_toggled)
	_victory_screen.advance_requested.connect(_on_advance_requested)
	GameManager.level_changed.connect(_on_level_changed)

	_show_start_screen()


func _show_start_screen() -> void:
	_start_screen.show_screen()
	_settings_screen.hide_screen()
	_game_board.visible = false
	_hud.visible = false
	_victory_screen.hide_screen()


func _show_settings_screen() -> void:
	_start_screen.hide_screen()
	_settings_screen.show_screen()
	_game_board.visible = false
	_hud.visible = false
	_victory_screen.hide_screen()


func _load_current_level() -> void:
	var level_data := GameManager.get_current_level_data()
	if level_data.is_empty():
		_show_start_screen()
		return

	_start_screen.hide_screen()
	_settings_screen.hide_screen()
	_victory_screen.hide_screen()
	_game_board.visible = true
	_hud.visible = true

	_hud.update_level(GameManager.current_level + 1)
	_game_board.load_level(level_data)


func _on_play_pressed() -> void:
	_load_current_level()


func _on_all_arrows_cleared() -> void:
	_hud.visible = false
	_victory_screen.show_victory(_game_board.move_count)


func _on_back_pressed() -> void:
	_show_start_screen()


func _on_guide_toggled(active: bool) -> void:
	_game_board.set_show_guides(active)


func _on_guides_turned_off() -> void:
	_hud.set_guide_off()


func _on_reset_pressed() -> void:
	_load_current_level()


func _on_advance_requested() -> void:
	_victory_transitioning = true
	var old_level := GameManager.current_level

	# Fade to white
	var fade_in := create_tween()
	fade_in.tween_property(_transition_overlay, "modulate:a", 1.0, Config.TRANSITION_FADE_DURATION)
	await fade_in.finished

	# Switch screens behind white overlay
	_victory_screen.hide_screen()
	GameManager.complete_current_level()
	var new_level := GameManager.current_level

	# Set up start screen behind overlay
	_settings_screen.hide_screen()
	_game_board.visible = false
	_hud.visible = false
	_start_screen.show_screen_animated(old_level, new_level)

	# Fade from white
	var fade_out := create_tween()
	fade_out.tween_property(_transition_overlay, "modulate:a", 0.0, Config.TRANSITION_FADE_DURATION)
	await fade_out.finished

	_victory_transitioning = false


func _on_hearts_changed(hearts_count: int) -> void:
	_hud.update_hearts(hearts_count)


func _on_hearts_depleted() -> void:
	_show_game_over_dialog()


func _on_level_changed(_level_index: int) -> void:
	if _victory_transitioning:
		return
	_load_current_level()


func _show_game_over_dialog() -> void:
	if _game_over_overlay:
		return

	_game_over_overlay = ColorRect.new()
	_game_over_overlay.color = Color(0, 0, 0, 0.6)
	_game_over_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_game_over_overlay.anchor_right = 1.0
	_game_over_overlay.anchor_bottom = 1.0

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_game_over_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Out of Hearts!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var continue_btn := Button.new()
	continue_btn.text = "Continue (3 new hearts)"
	continue_btn.add_theme_font_size_override("font_size", 22)
	continue_btn.pressed.connect(_on_game_over_continue)
	vbox.add_child(continue_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit Level"
	exit_btn.add_theme_font_size_override("font_size", 22)
	exit_btn.flat = true
	exit_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	exit_btn.pressed.connect(_on_game_over_exit)
	vbox.add_child(exit_btn)

	# Add as CanvasLayer to be on top
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(_game_over_overlay)
	add_child(canvas)


func _dismiss_game_over() -> void:
	if _game_over_overlay:
		var canvas := _game_over_overlay.get_parent()
		canvas.queue_free()
		_game_over_overlay = null


func _on_game_over_continue() -> void:
	AudioManager.play("ui_click")
	_game_board.hearts = Config.HEARTS_START
	_game_board.hearts_changed.emit(Config.HEARTS_START)
	_dismiss_game_over()


func _on_game_over_exit() -> void:
	AudioManager.play("ui_click")
	_dismiss_game_over()
	_show_start_screen()
