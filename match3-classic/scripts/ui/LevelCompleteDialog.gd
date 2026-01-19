extends BaseDialog
class_name LevelCompleteDialog
## Level complete screen with star rating and celebration

signal next_level_pressed
signal replay_pressed

var _title_label: Label
var _score_label: Label
var _stars_container: HBoxContainer
var _star_textures: Array[TextureRect] = []
var _current_stars: int = 0

const STAR_SIZE := Vector2(48, 48)

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	_panel.custom_minimum_size = Vector2(340, 350)
	_recenter_panel()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Title
	_title_label = create_title_label(ConfigManager.get_level_complete_title(), ConfigManager.get_ui_success_color())
	vbox.add_child(_title_label)

	# Stars container
	_stars_container = HBoxContainer.new()
	_stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_stars_container)

	# Create 3 star placeholders
	for i in range(3):
		var star := TextureRect.new()
		star.custom_minimum_size = STAR_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.modulate = ConfigManager.get_ui_accent_color()
		_stars_container.add_child(star)
		_star_textures.append(star)

	# Score display
	var score_title := create_body_label("Final Score")
	score_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(score_title)

	_score_label = Label.new()
	_score_label.text = "0"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 36)
	_score_label.add_theme_color_override("font_color", ConfigManager.get_ui_accent_color())
	vbox.add_child(_score_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer)

	# Buttons container
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_container)

	var replay_btn := create_styled_button("Replay", "replay", false)
	replay_btn.custom_minimum_size = Vector2(120, 45)
	btn_container.add_child(replay_btn)

	var next_btn := create_styled_button("Next", "next", true)
	next_btn.custom_minimum_size = Vector2(120, 45)
	btn_container.add_child(next_btn)

func setup(score: int, stars: int, high_score: int = 0) -> void:
	_score_label.text = _format_number(score)
	_current_stars = clampi(stars, 0, 3)
	_update_stars(0)  # Start with no stars, will animate

func show_dialog() -> void:
	super.show_dialog()
	# Animate stars after dialog opens
	_animate_stars()

func _update_stars(count: int) -> void:
	var filled_tex := ConfigManager.get_star_filled_texture()
	var empty_tex := ConfigManager.get_star_empty_texture()

	for i in range(3):
		var star := _star_textures[i]
		if i < count:
			if filled_tex:
				star.texture = filled_tex
			else:
				star.texture = _create_fallback_star(true)
		else:
			if empty_tex:
				star.texture = empty_tex
			else:
				star.texture = _create_fallback_star(false)

func _animate_stars() -> void:
	await get_tree().create_timer(0.15).timeout

	for i in range(_current_stars):
		await get_tree().create_timer(0.12).timeout
		_update_stars(i + 1)

		# Pop animation
		var star := _star_textures[i]
		var tween := create_tween()
		tween.tween_property(star, "scale", Vector2(1.3, 1.3), 0.06).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "scale", Vector2.ONE, 0.06).set_ease(Tween.EASE_IN)

func _create_fallback_star(filled: bool) -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var center := Vector2(24, 24)
	var outer_radius := 20.0
	var inner_radius := 8.0
	var points := 5
	var fill_color := ConfigManager.get_ui_accent_color() if filled else Color(0.3, 0.3, 0.3, 0.5)

	# Draw star shape
	for x in range(48):
		for y in range(48):
			var pos := Vector2(x, y) - center
			var angle := atan2(pos.y, pos.x)
			var dist := pos.length()

			# Calculate star boundary at this angle
			var segment := (angle + PI) / (2 * PI) * points * 2
			var t := fmod(segment, 1.0)
			var r: float
			if int(segment) % 2 == 0:
				r = lerpf(outer_radius, inner_radius, t)
			else:
				r = lerpf(inner_radius, outer_radius, t)

			if dist <= r:
				img.set_pixel(x, y, fill_color)

	var tex := ImageTexture.create_from_image(img)
	return tex

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
		"next":
			next_level_pressed.emit()
			hide_dialog()
		"replay":
			replay_pressed.emit()
			hide_dialog()
