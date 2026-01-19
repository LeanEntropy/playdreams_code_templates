extends Node2D
## Main game controller - handles UI updates and game flow

@onready var game_board: GameBoard = $BoardContainer/GameBoard
@onready var score_value: Label = $UI/TopBarContainer/TargetPanel/ScoreValue
@onready var target_value: Label = $UI/TopBarContainer/TargetPanel/TargetValue
@onready var target_header: Label = $UI/TopBarContainer/TargetPanel/TargetHeader
@onready var moves_value: Label = $UI/TopBarContainer/MovesPanel/MovesValue
@onready var combo_text: Label = $ComboTextLayer/ComboText
@onready var background: TextureRect = $Background
@onready var grid_background: TextureRect = $BoardContainer/GridBackground
@onready var booster_panel: PanelContainer = $UI/BottomBarContainer/BoosterPanel
@onready var settings_button: TextureButton = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/SettingsButton
@onready var hammer_button: TextureButton = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/HammerButton
@onready var hammer_label: Label = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/HammerButton/HammerLabel
@onready var switch_button: TextureButton = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/SwitchButton
@onready var switch_label: Label = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/SwitchButton/SwitchLabel
@onready var shuffle_button: TextureButton = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/ShuffleButton
@onready var shuffle_label: Label = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/ShuffleButton/ShuffleLabel
@onready var bomb_button: TextureButton = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/BombButton
@onready var bomb_label: Label = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/BombButton/BombLabel
@onready var moves_button: TextureButton = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/MovesButton
@onready var moves_booster_label: Label = $UI/BottomBarContainer/BoosterPanel/BoosterContainer/MovesButton/MovesLabel

# Dialog instances
var _pre_level_dialog: PreLevelDialog
var _level_complete_dialog: LevelCompleteDialog
var _level_failed_dialog: LevelFailedDialog
var _pause_dialog: PauseDialog

var combo_text_tween: Tween
var _current_level: int = 1
var _game_active: bool = false

@onready var goal_label: Label = $UI/TopBarContainer/GoalPanel/GoalLabel if has_node("UI/TopBarContainer/GoalPanel/GoalLabel") else null

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.moves_changed.connect(_on_moves_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.level_won.connect(_on_level_won)
	GameManager.goal_progress_changed.connect(_on_goal_progress_changed)
	BoosterManager.inventory_changed.connect(_update_booster_ui)
	BoosterManager.booster_activated.connect(_on_booster_activated)
	BoosterManager.booster_used.connect(_on_booster_used)
	BoosterManager.booster_cancelled.connect(_on_booster_cancelled)
	_update_booster_ui()
	booster_panel.visible = ConfigManager.are_boosters_enabled()
	_setup_dialogs()

	# Show pre-level dialog on start
	call_deferred("_show_pre_level")

func _setup_dialogs() -> void:
	# Create dialog layer
	var dialog_layer := CanvasLayer.new()
	dialog_layer.name = "DialogLayer"
	dialog_layer.layer = 100
	add_child(dialog_layer)

	# Pre-level dialog
	_pre_level_dialog = PreLevelDialog.new()
	_pre_level_dialog.play_pressed.connect(_on_pre_level_play)
	dialog_layer.add_child(_pre_level_dialog)

	# Level complete dialog
	_level_complete_dialog = LevelCompleteDialog.new()
	_level_complete_dialog.next_level_pressed.connect(_on_next_level)
	_level_complete_dialog.replay_pressed.connect(_on_replay_level)
	dialog_layer.add_child(_level_complete_dialog)

	# Level failed dialog
	_level_failed_dialog = LevelFailedDialog.new()
	_level_failed_dialog.retry_pressed.connect(_on_retry_level)
	_level_failed_dialog.quit_pressed.connect(_on_quit_to_menu)
	dialog_layer.add_child(_level_failed_dialog)

	# Pause dialog
	_pause_dialog = PauseDialog.new()
	_pause_dialog.resume_pressed.connect(_on_resume_game)
	_pause_dialog.restart_pressed.connect(_on_restart_level)
	_pause_dialog.quit_pressed.connect(_on_quit_to_menu)
	dialog_layer.add_child(_pause_dialog)

func _on_score_changed(_new_score: int) -> void:
	# Score display is now handled by _on_goal_progress_changed for all level types
	pass

func _on_moves_changed(moves_left: int) -> void:
	moves_value.text = str(moves_left)
	moves_value.modulate = Color(0.9, 0.3, 0.3) if moves_left <= 5 else Color(0.25, 0.2, 0.15)

func _on_combo_changed(combo: int) -> void:
	# Only show combo text from 2nd cascade onward (combo >= 2)
	if combo >= 2:
		_show_combo_text(combo + 1)

func _show_combo_text(combo_level: int) -> void:
	var message := ConfigManager.get_combo_message(combo_level)
	if message.is_empty():
		return

	if combo_text_tween and combo_text_tween.is_valid():
		combo_text_tween.kill()

	combo_text.text = message
	combo_text.modulate = Color.WHITE
	combo_text.scale = Vector2(0.5, 0.5)

	var duration := ConfigManager.get_combo_text_duration()
	var pop_time := duration * 0.15  # 15% for pop-in animation
	var hold_time := duration * 0.5  # 50% visible at full size
	var fade_time := duration * 0.35  # 35% for fade out

	combo_text_tween = create_tween()
	combo_text_tween.tween_property(combo_text, "scale", Vector2(1.2, 1.2), pop_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	combo_text_tween.tween_property(combo_text, "scale", Vector2.ONE, pop_time * 0.5)
	combo_text_tween.tween_interval(hold_time)  # Hold visible
	combo_text_tween.tween_property(combo_text, "modulate:a", 0.0, fade_time)
	combo_text_tween.tween_callback(func(): combo_text.text = "")

func _on_game_over() -> void:
	_game_active = false
	game_board.set_input_enabled(false)
	_level_failed_dialog.setup(GameManager.score, GameManager.target_score)
	_level_failed_dialog.show_dialog()

func _on_level_won() -> void:
	_game_active = false
	game_board.set_input_enabled(false)
	var stars := _calculate_stars(GameManager.score, GameManager.target_score)
	_level_complete_dialog.setup(GameManager.score, stars)
	_level_complete_dialog.show_dialog()

func _calculate_stars(score: int, _target: int) -> int:
	return GameManager.calculate_stars(score)

func _on_goal_progress_changed(current: int, target: int, label: String) -> void:
	if goal_label:
		goal_label.text = "%s: %d/%d" % [label, current, target]

	# Update header to show goal type
	var header_text := _get_goal_header_text(label)
	target_header.text = header_text

	# Update progress display
	score_value.text = _format_number(current)
	target_value.text = "/ " + _format_number(target)

func _get_goal_header_text(label: String) -> String:
	var level := ConfigManager.get_current_level()

	match label:
		"Score":
			return "SCORE"
		"Cleared":
			return "GEMS"
		"Combos":
			return "COMBOS"
		"Specials":
			return "SPECIALS"
		"Colors":
			if level:
				var c1_name := _get_color_name(level.target_color_1)
				var c2_name := _get_color_name(level.target_color_2)
				return "%s+%s" % [c1_name, c2_name]
			return "COLORS"
	return "TARGET"

func _get_color_name(color: Enums.GemColor) -> String:
	match color:
		Enums.GemColor.RED: return "RED"
		Enums.GemColor.ORANGE: return "ORG"
		Enums.GemColor.YELLOW: return "YLW"
		Enums.GemColor.GREEN: return "GRN"
		Enums.GemColor.BLUE: return "BLU"
		Enums.GemColor.PURPLE: return "PRP"
	return "?"

func _show_pre_level() -> void:
	game_board.set_input_enabled(false)
	var level := ConfigManager.load_level(_current_level)
	var goal_desc := level.goal_description if level else "Reach the target score"
	var moves := level.max_moves if level else ConfigManager.get_starting_moves()
	var target := level.target_score if level else ConfigManager.get_target_score()
	_pre_level_dialog.setup(_current_level, goal_desc, moves, target)
	_pre_level_dialog.show_dialog()

func _on_pre_level_play() -> void:
	_game_active = true
	game_board.set_input_enabled(true)
	BoosterManager.reset_inventory()
	game_board.initialize_board()
	_update_booster_ui()

func _on_next_level() -> void:
	_current_level += 1
	if _current_level > ConfigManager.get_max_levels():
		_current_level = 1  # Wrap back to level 1
	_show_pre_level()

func _on_replay_level() -> void:
	_show_pre_level()

func _on_retry_level() -> void:
	_show_pre_level()

func _on_restart_level() -> void:
	_show_pre_level()

func _on_quit_to_menu() -> void:
	_current_level = 1
	_show_pre_level()

func _on_pause_pressed() -> void:
	if _game_active:
		game_board.set_input_enabled(false)
		_pause_dialog.show_dialog()

func _on_resume_game() -> void:
	game_board.set_input_enabled(true)

func _on_new_game_pressed() -> void:
	_show_pre_level()

func _on_play_again_pressed() -> void:
	_on_new_game_pressed()

func _format_number(num: int) -> String:
	var str_num := str(num)
	var formatted := ""
	for i in range(str_num.length()):
		if i > 0 and (str_num.length() - i) % 3 == 0:
			formatted += ","
		formatted += str_num[i]
	return formatted

func _update_booster_ui() -> void:
	var buttons: Array[TextureButton] = [hammer_button, switch_button, shuffle_button, bomb_button, moves_button]
	var labels: Array[Label] = [hammer_label, switch_label, shuffle_label, bomb_label, moves_booster_label]
	var types: Array[Enums.BoosterType] = [
		Enums.BoosterType.LOLLIPOP_HAMMER,
		Enums.BoosterType.FREE_SWITCH,
		Enums.BoosterType.SHUFFLE,
		Enums.BoosterType.COLOR_BOMB_START,
		Enums.BoosterType.EXTRA_MOVES
	]

	for i in range(buttons.size()):
		var btn := buttons[i]
		var label := labels[i]
		var booster_type := types[i]
		var count := BoosterManager.get_count(booster_type)

		label.text = str(count)
		btn.disabled = count <= 0 or not ConfigManager.is_booster_enabled(booster_type)
		btn.visible = ConfigManager.is_booster_enabled(booster_type)
		label.visible = btn.visible

func _on_hammer_pressed() -> void:
	if BoosterManager.is_booster_active():
		BoosterManager.cancel_booster()
	else:
		BoosterManager.activate_booster(Enums.BoosterType.LOLLIPOP_HAMMER)

func _on_switch_pressed() -> void:
	if BoosterManager.is_booster_active():
		BoosterManager.cancel_booster()
	else:
		BoosterManager.activate_booster(Enums.BoosterType.FREE_SWITCH)

func _on_shuffle_pressed() -> void:
	if BoosterManager.has_booster(Enums.BoosterType.SHUFFLE):
		game_board.use_shuffle_booster()

func _on_bomb_pressed() -> void:
	if BoosterManager.is_booster_active():
		BoosterManager.cancel_booster()
	else:
		BoosterManager.activate_booster(Enums.BoosterType.COLOR_BOMB_START)

func _on_moves_pressed() -> void:
	if BoosterManager.has_booster(Enums.BoosterType.EXTRA_MOVES):
		game_board.use_extra_moves_booster()

func _on_booster_activated(booster_type: Enums.BoosterType) -> void:
	var btn := _get_button_for_booster(booster_type)
	if btn:
		btn.modulate = Color(1.2, 1.2, 0.8)  # Highlight active booster

func _on_booster_used(_booster_type: Enums.BoosterType) -> void:
	_reset_all_booster_styles()
	_update_booster_ui()

func _on_booster_cancelled() -> void:
	_reset_all_booster_styles()

func _reset_all_booster_styles() -> void:
	hammer_button.modulate = Color.WHITE
	switch_button.modulate = Color.WHITE
	shuffle_button.modulate = Color.WHITE
	bomb_button.modulate = Color.WHITE
	moves_button.modulate = Color.WHITE

func _get_button_for_booster(booster_type: Enums.BoosterType) -> TextureButton:
	match booster_type:
		Enums.BoosterType.LOLLIPOP_HAMMER:
			return hammer_button
		Enums.BoosterType.FREE_SWITCH:
			return switch_button
		Enums.BoosterType.SHUFFLE:
			return shuffle_button
		Enums.BoosterType.COLOR_BOMB_START:
			return bomb_button
		Enums.BoosterType.EXTRA_MOVES:
			return moves_button
	return null
