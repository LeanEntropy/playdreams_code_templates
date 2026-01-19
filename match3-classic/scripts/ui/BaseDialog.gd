extends Control
class_name BaseDialog
## Base class for all game dialogs with theme support

signal dialog_closed
signal button_pressed(button_id: String)

@export var animate_open: bool = true
@export var animate_close: bool = true

var _overlay: ColorRect
var _panel: PanelContainer
var _panel_style: StyleBoxFlat

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_overlay()
	_setup_panel()
	_apply_theme()
	# Connect to viewport size changes
	get_tree().root.size_changed.connect(_on_viewport_resized)
	call_deferred("_on_viewport_resized")

func _on_viewport_resized() -> void:
	var viewport_size := get_viewport_rect().size
	size = viewport_size
	position = Vector2.ZERO

func _setup_overlay() -> void:
	# Set size manually since CanvasLayer children don't auto-size
	var viewport_size := Vector2(720, 1280)  # Default, will be updated
	size = viewport_size

	# Create overlay ColorRect
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = ConfigManager.get_ui_overlay_color()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

func _setup_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 200)

	# Center the panel using anchors at center
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	_panel_style = StyleBoxFlat.new()
	_panel.add_theme_stylebox_override("panel", _panel_style)

func _apply_theme() -> void:
	if _overlay:
		_overlay.color = ConfigManager.get_ui_overlay_color()
	_panel_style.bg_color = ConfigManager.get_ui_panel_color()
	_panel_style.border_color = ConfigManager.get_ui_panel_border_color()
	_panel_style.set_border_width_all(3)
	_panel_style.set_corner_radius_all(20)  # Rounder corners for royal theme

func _recenter_panel() -> void:
	# Reset position for center preset
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -_panel.custom_minimum_size.x / 2
	_panel.offset_top = -_panel.custom_minimum_size.y / 2
	_panel.offset_right = _panel.custom_minimum_size.x / 2
	_panel.offset_bottom = _panel.custom_minimum_size.y / 2
	_panel.pivot_offset = _panel.custom_minimum_size / 2

func create_styled_button(text: String, button_id: String = "", primary: bool = true) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 50)

	var style := StyleBoxFlat.new()
	style.bg_color = ConfigManager.get_ui_button_color() if primary else ConfigManager.get_ui_panel_color()
	style.set_corner_radius_all(14)  # Rounder corners for royal theme
	style.border_color = ConfigManager.get_ui_panel_border_color()
	style.set_border_width_all(2)
	if not primary:
		style.bg_color = ConfigManager.get_ui_panel_color().lightened(0.05)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = ConfigManager.get_ui_button_hover_color() if primary else ConfigManager.get_ui_panel_color().lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := style.duplicate()
	pressed_style.bg_color = ConfigManager.get_ui_button_pressed_color()
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", ConfigManager.get_ui_text_color())
	btn.add_theme_font_size_override("font_size", 20)

	var id := button_id if not button_id.is_empty() else text.to_lower().replace(" ", "_")
	btn.pressed.connect(func(): _on_button_pressed(id))

	return btn

func create_title_label(text: String, color_override: Color = Color.TRANSPARENT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	var text_color := color_override if color_override != Color.TRANSPARENT else ConfigManager.get_ui_text_color()
	label.add_theme_color_override("font_color", text_color)
	return label

func create_body_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", ConfigManager.get_ui_text_secondary_color())
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func show_dialog() -> void:
	visible = true
	if animate_open:
		_panel.scale = Vector2(0.8, 0.8)
		_panel.modulate.a = 0.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_panel, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(_panel, "modulate:a", 1.0, 0.1)

func hide_dialog() -> void:
	if animate_close:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_panel, "scale", Vector2(0.8, 0.8), 0.08).set_ease(Tween.EASE_IN)
		tween.tween_property(_panel, "modulate:a", 0.0, 0.08)
		tween.chain().tween_callback(func():
			visible = false
			dialog_closed.emit()
		)
	else:
		visible = false
		dialog_closed.emit()

func _on_button_pressed(button_id: String) -> void:
	SoundManager.play_button_click()
	button_pressed.emit(button_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Clicking overlay does nothing by default - override if needed
		pass
