extends BaseDialog
class_name PreLevelDialog
## Pre-level screen showing objectives before starting

signal play_pressed

var _level_label: Label
var _objective_label: Label
var _moves_label: Label
var _target_label: Label

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	_panel.custom_minimum_size = Vector2(340, 320)
	_recenter_panel()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Level number
	_level_label = create_title_label("Level 1", ConfigManager.get_ui_accent_color())
	vbox.add_child(_level_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 5)
	sep.add_theme_stylebox_override("separator", _create_separator_style())
	vbox.add_child(sep)

	# Objective section
	var obj_title := create_body_label("Objective")
	obj_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(obj_title)

	_objective_label = Label.new()
	_objective_label.text = "Reach the target score"
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 20)
	_objective_label.add_theme_color_override("font_color", ConfigManager.get_ui_text_color())
	vbox.add_child(_objective_label)

	# Stats container
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 40)
	vbox.add_child(stats)

	# Moves
	var moves_vbox := _create_stat_display("MOVES", "30")
	_moves_label = moves_vbox.get_child(1) as Label
	stats.add_child(moves_vbox)

	# Target
	var target_vbox := _create_stat_display("TARGET", "10,000")
	_target_label = target_vbox.get_child(1) as Label
	stats.add_child(target_vbox)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Play button
	var play_btn := create_styled_button("Play!", "play")
	play_btn.custom_minimum_size = Vector2(180, 50)
	play_btn.add_theme_font_size_override("font_size", 22)
	vbox.add_child(play_btn)

	# Center the button
	var btn_container := CenterContainer.new()
	play_btn.reparent(btn_container)
	vbox.add_child(btn_container)

func _create_stat_display(title: String, value: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", ConfigManager.get_ui_text_secondary_color())
	vbox.add_child(title_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 28)
	value_label.add_theme_color_override("font_color", ConfigManager.get_ui_accent_color())
	vbox.add_child(value_label)

	return vbox

func _create_separator_style() -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = ConfigManager.get_ui_panel_border_color().darkened(0.3)
	style.thickness = 2
	return style

func setup(level_number: int, objective: String, moves: int, target: int) -> void:
	_level_label.text = "Level %d" % level_number
	_objective_label.text = objective
	_moves_label.text = str(moves)

	# Show appropriate target based on level type
	var level := ConfigManager.get_current_level()
	if level:
		match level.level_type:
			Enums.LevelType.SCORE_TARGET:
				_target_label.text = _format_number(target)
			Enums.LevelType.CLEAR_COUNT:
				_target_label.text = str(level.target_clears)
			Enums.LevelType.COMBO_CHALLENGE:
				_target_label.text = str(level.target_combos)
			Enums.LevelType.SPECIAL_CREATION:
				_target_label.text = str(level.target_specials)
			Enums.LevelType.COLOR_COLLECTION:
				_target_label.text = str(level.target_color_1_count + level.target_color_2_count)
			_:
				_target_label.text = _format_number(target)
	else:
		_target_label.text = _format_number(target)

func _format_number(num: int) -> String:
	var str_num := str(num)
	var formatted := ""
	for i in range(str_num.length()):
		if i > 0 and (str_num.length() - i) % 3 == 0:
			formatted += ","
		formatted += str_num[i]
	return formatted

func _on_button_pressed(button_id: String) -> void:
	super._on_button_pressed(button_id)
	if button_id == "play":
		play_pressed.emit()
		hide_dialog()
