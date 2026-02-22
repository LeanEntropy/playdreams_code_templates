extends CanvasLayer

signal play_pressed
signal settings_pressed

var _level_label: Label
var _tier_label: Label
var _level_clip: Control
var _is_dark: bool = Config.THEME == "pastel"

const _NUM_CLIP_HEIGHT := 44.0


func _ready() -> void:
	var root := Control.new()
	root.anchors_preset = Control.PRESET_FULL_RECT
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	var theme: Dictionary = Config.get_theme()
	var text_color: Color = Color.WHITE if _is_dark else Config.COLOR_TITLE

	# Background
	var bg := ColorRect.new()
	bg.color = theme["bg"]
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# Main content area (centered vertically, offset upward a bit)
	var content := VBoxContainer.new()
	content.anchors_preset = Control.PRESET_CENTER
	content.anchor_left = 0.5
	content.anchor_top = 0.5
	content.anchor_right = 0.5
	content.anchor_bottom = 0.5
	content.offset_left = -200
	content.offset_right = 200
	content.offset_top = -140
	content.offset_bottom = 60
	content.grow_horizontal = Control.GROW_DIRECTION_BOTH
	content.grow_vertical = Control.GROW_DIRECTION_BOTH
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	root.add_child(content)

	# Title
	var title_label := Label.new()
	title_label.text = "Arrow Puzzle"
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", text_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	# Level line: static "Level " prefix + sliding number
	var level_line := HBoxContainer.new()
	level_line.add_theme_constant_override("separation", 0)
	level_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	level_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(level_line)

	var accent_color: Color = Color("#A0B0E0") if _is_dark else Config.COLOR_ACCENT

	var level_prefix := Label.new()
	level_prefix.text = "Level "
	level_prefix.add_theme_font_size_override("font_size", 32)
	level_prefix.add_theme_color_override("font_color", accent_color)
	level_prefix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_line.add_child(level_prefix)

	_level_clip = Control.new()
	_level_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_level_clip.custom_minimum_size = Vector2(20.0, _NUM_CLIP_HEIGHT)
	_level_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_line.add_child(_level_clip)

	_level_label = Label.new()
	_level_label.text = "1"
	_level_label.add_theme_font_size_override("font_size", 32)
	_level_label.add_theme_color_override("font_color", accent_color)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.position = Vector2.ZERO
	_level_label.size = Vector2(20.0, _NUM_CLIP_HEIGHT)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_clip.add_child(_level_label)

	# Tier label
	_tier_label = Label.new()
	_tier_label.text = "Easy"
	_tier_label.add_theme_font_size_override("font_size", 22)
	_tier_label.add_theme_color_override("font_color", Config.COLOR_TIER_EASY)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_tier_label)

	# Continue button (positioned lower on screen)
	var btn_container := Control.new()
	btn_container.anchors_preset = Control.PRESET_FULL_RECT
	btn_container.anchor_right = 1.0
	btn_container.anchor_bottom = 1.0
	btn_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(btn_container)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.add_theme_font_size_override("font_size", 28)
	continue_btn.add_theme_color_override("font_color", Color.WHITE)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = accent_color
	Config.set_corner_radius(btn_style, 28)
	btn_style.content_margin_left = 80
	btn_style.content_margin_right = 80
	btn_style.content_margin_top = 20
	btn_style.content_margin_bottom = 20
	continue_btn.add_theme_stylebox_override("normal", btn_style)
	continue_btn.add_theme_stylebox_override("hover", btn_style)
	continue_btn.add_theme_stylebox_override("pressed", btn_style)
	continue_btn.add_theme_stylebox_override("focus", btn_style)

	continue_btn.anchors_preset = Control.PRESET_CENTER_BOTTOM
	continue_btn.anchor_left = 0.5
	continue_btn.anchor_top = 1.0
	continue_btn.anchor_right = 0.5
	continue_btn.anchor_bottom = 1.0
	continue_btn.offset_top = -220
	continue_btn.offset_bottom = -150
	continue_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_btn.pressed.connect(_on_play_pressed)
	btn_container.add_child(continue_btn)

	# Bottom nav bar
	_build_nav_bar(root)


func _build_nav_bar(parent: Control) -> void:
	var t: Dictionary = Config.get_theme()
	# Nav bar background
	var nav_bg := ColorRect.new()
	nav_bg.color = t.get("nav_bg", Config.COLOR_NAV_BG)
	nav_bg.anchor_left = 0.0
	nav_bg.anchor_top = 1.0
	nav_bg.anchor_right = 1.0
	nav_bg.anchor_bottom = 1.0
	nav_bg.offset_top = -Config.NAV_BAR_HEIGHT
	nav_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(nav_bg)

	# Nav items container
	var nav_hbox := HBoxContainer.new()
	nav_hbox.anchor_left = 0.0
	nav_hbox.anchor_top = 1.0
	nav_hbox.anchor_right = 1.0
	nav_hbox.anchor_bottom = 1.0
	nav_hbox.offset_top = -Config.NAV_BAR_HEIGHT
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 120)
	parent.add_child(nav_hbox)

	# Home button (selected)
	var home_btn := _create_nav_item("Home", true)
	home_btn.gui_input.connect(_on_home_gui_input)
	nav_hbox.add_child(home_btn)

	# Settings button (unselected)
	var settings_btn := _create_nav_item("Settings", false)
	settings_btn.gui_input.connect(_on_settings_gui_input)
	nav_hbox.add_child(settings_btn)


func _create_nav_item(label_text: String, active: bool) -> PanelContainer:
	var t: Dictionary = Config.get_theme()
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = t.get("nav_pill", Config.COLOR_NAV_PILL) if active else Color.TRANSPARENT
	Config.set_corner_radius(panel_style, 20)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.custom_minimum_size = Vector2(0, 44)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", t.get("nav_icon_active", Config.COLOR_NAV_ICON_ACTIVE) if active else t.get("nav_icon", Config.COLOR_NAV_ICON))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	return panel


func _on_play_pressed() -> void:
	AudioManager.play("ui_click")
	play_pressed.emit()


func _on_home_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		AudioManager.play("ui_click")


func _on_settings_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		AudioManager.play("ui_click")
		settings_pressed.emit()


func _get_number_width(num: int) -> float:
	var font: Font = _level_label.get_theme_font("font")
	return font.get_string_size(str(num), HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x


func _set_clip_width(w: float) -> void:
	_level_clip.custom_minimum_size.x = w
	_level_label.size.x = w


func show_screen() -> void:
	_reset_level_label()
	if GameManager:
		var level_num: int = GameManager.current_level + 1
		_level_label.text = str(level_num)
		_set_clip_width(_get_number_width(level_num))
		var tier_name := Config.get_tier_name(GameManager.current_level)
		_tier_label.text = tier_name
		_tier_label.add_theme_color_override("font_color", Config.get_tier_color(tier_name))
		_tier_label.modulate.a = 1.0
	visible = true


func show_screen_animated(old_level_index: int, new_level_index: int) -> void:
	_reset_level_label()

	# Show screen with OLD level number (visible during fade-from-white)
	var old_level_num: int = old_level_index + 1
	var new_level_num: int = new_level_index + 1
	_level_label.text = str(old_level_num)
	_level_label.modulate.a = 1.0

	# Size clip to fit the wider of old/new number during animation
	var old_w := _get_number_width(old_level_num)
	var new_w := _get_number_width(new_level_num)
	var anim_w := maxf(old_w, new_w)
	_set_clip_width(anim_w)

	var old_tier: String = Config.get_tier_name(old_level_index)
	var new_tier: String = Config.get_tier_name(new_level_index)
	var tier_changed: bool = old_tier != new_tier

	if tier_changed:
		_tier_label.text = new_tier
		_tier_label.add_theme_color_override("font_color", Config.get_tier_color(new_tier))
		_tier_label.modulate.a = 0.0
	else:
		_tier_label.text = old_tier
		_tier_label.add_theme_color_override("font_color", Config.get_tier_color(old_tier))
		_tier_label.modulate.a = 1.0

	visible = true

	# Wait 1 second after menu is visible before animating
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)

	# Create temporary label for the new number, positioned above clip area
	var anim_accent: Color = Color("#A0B0E0") if _is_dark else Config.COLOR_ACCENT
	var new_label := Label.new()
	new_label.text = str(new_level_num)
	new_label.add_theme_font_size_override("font_size", 32)
	new_label.add_theme_color_override("font_color", anim_accent)
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_label.position = Vector2(0.0, -_NUM_CLIP_HEIGHT)
	new_label.size = Vector2(anim_w, _NUM_CLIP_HEIGHT)
	new_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	tween.tween_callback(func() -> void:
		_level_clip.add_child(new_label)
	)

	# Slide old number down + new number in from top (parallel)
	var slide_dur := Config.LEVEL_ANIM_DURATION
	tween.set_parallel(true)
	tween.tween_property(_level_label, "position:y", _NUM_CLIP_HEIGHT, slide_dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(new_label, "position:y", 0.0, slide_dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(false)

	# Clean up: update real label, resize clip to new number width, remove temp
	tween.tween_callback(func() -> void:
		_level_label.text = str(new_level_num)
		_level_label.position.y = 0.0
		_set_clip_width(new_w)
		new_label.queue_free()
	)

	# If tier changed, fade it in after the slide completes
	if tier_changed:
		tween.tween_property(_tier_label, "modulate:a", 1.0, 0.3)


func _reset_level_label() -> void:
	_level_label.position.y = 0.0
	_level_label.modulate.a = 1.0
	# Remove any leftover temp labels from previous animations
	for child in _level_clip.get_children():
		if child != _level_label:
			child.queue_free()


func hide_screen() -> void:
	visible = false
