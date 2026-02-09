extends CanvasLayer
class_name TitleScreen

signal play_pressed

@onready var background_image: TextureRect = $BackgroundImage
@onready var background_color: ColorRect = $BackgroundColor
@onready var play_button: Button = $MainContainer/ButtonContainer/PlayButton
@onready var title_image: TextureRect = $MainContainer/TitleContainer/GameTitle


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	play_button.pressed.connect(_on_play_pressed)
	_apply_background()
	_apply_button_colors()
	_check_title_image()


func _apply_background() -> void:
	var have_background: bool = GameConfig.get_value("title_screen", "have_background", true)
	if not have_background:
		background_image.visible = false
		background_color.visible = false
		return

	var bg_image_path: String = GameConfig.get_value("title_screen", "background_image", "")
	if bg_image_path != "" and ResourceLoader.exists(bg_image_path):
		var texture = load(bg_image_path)
		if texture:
			background_image.texture = texture
			background_image.visible = true
			background_color.visible = false
			return

	# Solid color fallback
	var bg_hex: String = GameConfig.get_value("title_screen", "background_color", "1A1A2E")
	var bg_opacity: float = GameConfig.get_value("title_screen", "background_color_opacity", 1.0)
	var color = Color.from_string(bg_hex, Color(0.1, 0.1, 0.18))
	color.a = clampf(bg_opacity, 0.0, 1.0)
	background_color.color = color
	background_color.visible = true
	background_image.visible = false


func _apply_button_colors() -> void:
	var btn_hex: String = GameConfig.get_value("title_screen", "button_color", "16213E")
	var hover_hex: String = GameConfig.get_value("title_screen", "button_hover_color", "0F3460")
	var text_hex: String = GameConfig.get_value("title_screen", "button_text_color", "FFFFFF")
	var text_color: Color = Color.from_string(text_hex, Color.WHITE)

	var normal := _make_button_style(Color.from_string(btn_hex, Color(0.09, 0.13, 0.24)), text_color)
	var hover := _make_button_style(Color.from_string(hover_hex, Color(0.06, 0.2, 0.38)), text_color)
	var pressed := _make_button_style(Color.from_string(hover_hex, Color(0.06, 0.2, 0.38)).darkened(0.2), text_color)

	play_button.add_theme_stylebox_override("normal", normal)
	play_button.add_theme_stylebox_override("hover", hover)
	play_button.add_theme_stylebox_override("pressed", pressed)
	play_button.add_theme_color_override("font_color", text_color)


func _make_button_style(bg: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border_color
	return style


func _check_title_image() -> void:
	var image_path = "res://assets/UI/GameTitle.png"
	if ResourceLoader.exists(image_path):
		var texture = load(image_path)
		if texture:
			title_image.texture = texture
			return
	_show_fallback_title()


func _show_fallback_title() -> void:
	title_image.visible = false
	var title_label = Label.new()
	title_label.text = "GAME TEMPLATE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_constant_override("shadow_offset_x", 4)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	$MainContainer/TitleContainer.add_child(title_label)


func _on_play_pressed() -> void:
	play_pressed.emit()
	var tween = create_tween()
	tween.tween_property($MainContainer, "modulate", Color(1, 1, 1, 0), 0.3)
	if background_image.visible:
		tween.parallel().tween_property(background_image, "modulate", Color(1, 1, 1, 0), 0.3)
	if background_color.visible:
		tween.parallel().tween_property(background_color, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(queue_free)


func show_title_screen() -> void:
	visible = true
	$MainContainer.modulate = Color.WHITE
	background_image.modulate = Color.WHITE
	background_color.modulate = Color.WHITE
