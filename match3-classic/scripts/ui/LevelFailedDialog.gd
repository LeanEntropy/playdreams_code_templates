extends BaseDialog
class_name LevelFailedDialog
## Level failed screen with progress feedback

signal retry_pressed
signal quit_pressed

var _title_label: Label
var _message_label: Label
var _progress_bar: ProgressBar
var _progress_label: Label

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	_panel.custom_minimum_size = Vector2(340, 300)
	_recenter_panel()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Title
	_title_label = create_title_label(ConfigManager.get_level_failed_title(), ConfigManager.get_ui_fail_color())
	vbox.add_child(_title_label)

	# Message (So close! or Try again!)
	_message_label = Label.new()
	_message_label.text = ConfigManager.get_close_message()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 20)
	_message_label.add_theme_color_override("font_color", ConfigManager.get_ui_text_color())
	vbox.add_child(_message_label)

	# Progress section
	var progress_title := create_body_label("Progress")
	progress_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(progress_title)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(250, 24)
	_progress_bar.show_percentage = false
	_progress_bar.add_theme_stylebox_override("background", _create_progress_bg_style())
	_progress_bar.add_theme_stylebox_override("fill", _create_progress_fill_style())
	vbox.add_child(_progress_bar)

	# Progress label
	_progress_label = Label.new()
	_progress_label.text = "0 / 0"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 16)
	_progress_label.add_theme_color_override("font_color", ConfigManager.get_ui_text_secondary_color())
	vbox.add_child(_progress_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Buttons container
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_container)

	var quit_btn := create_styled_button("Quit", "quit", false)
	quit_btn.custom_minimum_size = Vector2(120, 45)
	btn_container.add_child(quit_btn)

	var retry_btn := create_styled_button("Retry", "retry", true)
	retry_btn.custom_minimum_size = Vector2(120, 45)
	btn_container.add_child(retry_btn)

func _create_progress_bg_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ConfigManager.get_ui_panel_color().darkened(0.2)
	style.set_corner_radius_all(10)
	return style

func _create_progress_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ConfigManager.get_ui_accent_color()
	style.set_corner_radius_all(10)
	return style

func setup(current_progress: int, target: int, objective_name: String = "Score") -> void:
	var progress_percent := float(current_progress) / float(target) if target > 0 else 0.0
	progress_percent = clampf(progress_percent, 0.0, 1.0)

	_progress_bar.value = progress_percent * 100

	# Format progress text
	_progress_label.text = "%s / %s" % [_format_number(current_progress), _format_number(target)]

	# Set message based on how close they were
	if progress_percent >= 0.9:
		_message_label.text = ConfigManager.get_close_message()
		_message_label.add_theme_color_override("font_color", ConfigManager.get_ui_accent_color())
	elif progress_percent >= 0.7:
		_message_label.text = "Almost there!"
		_message_label.add_theme_color_override("font_color", ConfigManager.get_ui_text_color())
	else:
		_message_label.text = ConfigManager.get_try_again_message()
		_message_label.add_theme_color_override("font_color", ConfigManager.get_ui_text_secondary_color())

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
	match button_id:
		"retry":
			retry_pressed.emit()
			hide_dialog()
		"quit":
			quit_pressed.emit()
			hide_dialog()
