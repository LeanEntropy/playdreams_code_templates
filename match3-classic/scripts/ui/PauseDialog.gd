extends BaseDialog
class_name PauseDialog
## Pause menu with resume and quit options

signal resume_pressed
signal restart_pressed
signal quit_pressed

var _title_label: Label
var _sound_btn: Button
var _music_btn: Button

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	_panel.custom_minimum_size = Vector2(280, 340)
	_recenter_panel()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Title
	_title_label = create_title_label(ConfigManager.get_pause_title(), ConfigManager.get_ui_accent_color())
	vbox.add_child(_title_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", _create_separator_style())
	vbox.add_child(sep)

	# Sound toggles row
	var sound_row := HBoxContainer.new()
	sound_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sound_row.add_theme_constant_override("separation", 15)
	vbox.add_child(sound_row)

	_sound_btn = _create_toggle_button("🔊", "sound")
	sound_row.add_child(_sound_btn)

	_music_btn = _create_toggle_button("🎵", "music")
	sound_row.add_child(_music_btn)

	_update_sound_buttons()

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer)

	# Resume button (primary)
	var resume_btn := create_styled_button("Resume", "resume", true)
	resume_btn.custom_minimum_size = Vector2(180, 45)
	var resume_container := CenterContainer.new()
	resume_container.add_child(resume_btn)
	vbox.add_child(resume_container)

	# Restart button (secondary)
	var restart_btn := create_styled_button("Restart", "restart", false)
	restart_btn.custom_minimum_size = Vector2(180, 45)
	var restart_container := CenterContainer.new()
	restart_container.add_child(restart_btn)
	vbox.add_child(restart_container)

	# Quit button (secondary)
	var quit_btn := create_styled_button("Quit", "quit", false)
	quit_btn.custom_minimum_size = Vector2(180, 45)
	var quit_container := CenterContainer.new()
	quit_container.add_child(quit_btn)
	vbox.add_child(quit_container)

func _create_toggle_button(icon: String, id: String) -> Button:
	var btn := Button.new()
	btn.text = icon
	btn.custom_minimum_size = Vector2(60, 60)
	btn.add_theme_font_size_override("font_size", 24)

	var style := StyleBoxFlat.new()
	style.bg_color = ConfigManager.get_ui_button_color()
	style.set_corner_radius_all(30)  # Round buttons
	style.border_color = ConfigManager.get_ui_panel_border_color()
	style.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = ConfigManager.get_ui_button_hover_color()
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.pressed.connect(func(): _on_toggle_pressed(id))
	return btn

func _update_sound_buttons() -> void:
	if _sound_btn:
		_sound_btn.text = "🔊" if ConfigManager.is_sound_enabled() else "🔇"
		_sound_btn.modulate = Color.WHITE if ConfigManager.is_sound_enabled() else Color(0.5, 0.5, 0.5)
	if _music_btn:
		_music_btn.text = "🎵" if ConfigManager.is_music_enabled() else "🎵"
		_music_btn.modulate = Color.WHITE if ConfigManager.is_music_enabled() else Color(0.5, 0.5, 0.5)

func _on_toggle_pressed(id: String) -> void:
	match id:
		"sound":
			SoundManager.toggle_sound()
		"music":
			SoundManager.toggle_music()
	_update_sound_buttons()

func _create_separator_style() -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = ConfigManager.get_ui_panel_border_color().darkened(0.3)
	style.thickness = 2
	return style

func _on_button_pressed(button_id: String) -> void:
	super._on_button_pressed(button_id)
	match button_id:
		"resume":
			resume_pressed.emit()
			hide_dialog()
		"restart":
			restart_pressed.emit()
			hide_dialog()
		"quit":
			quit_pressed.emit()
			hide_dialog()

func _gui_input(event: InputEvent) -> void:
	# Allow clicking overlay to resume
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel_rect := _panel.get_global_rect()
		if not panel_rect.has_point(event.global_position):
			resume_pressed.emit()
			hide_dialog()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		resume_pressed.emit()
		hide_dialog()
		get_viewport().set_input_as_handled()
