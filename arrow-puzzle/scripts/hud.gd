extends CanvasLayer

signal reset_pressed
signal back_pressed
signal guide_toggled(active: bool)

var _tier_label: Label
var _hearts_label: Label
var _level_index: int = 0
var _guide_active: bool = false
var _grid_btn: PanelContainer
var _grid_btn_style: StyleBoxFlat
var _is_dark: bool = Config.THEME == "pastel"


func _ready() -> void:
	var root := Control.new()
	root.anchors_preset = Control.PRESET_FULL_RECT
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top-left: back + reset buttons
	var top_left := HBoxContainer.new()
	top_left.anchor_left = 0.0
	top_left.anchor_top = 0.0
	top_left.offset_left = 16
	top_left.offset_top = 16
	top_left.add_theme_constant_override("separation", 12)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_left)

	var back_btn := _create_circle_button("\u25C0", 48)
	back_btn.gui_input.connect(_on_back_input)
	top_left.add_child(back_btn)

	var reset_btn := _create_circle_button("\u21BB", 48)
	reset_btn.gui_input.connect(_on_reset_input)
	top_left.add_child(reset_btn)

	# Top-center: tier label + hearts
	var top_center := VBoxContainer.new()
	top_center.anchor_left = 0.5
	top_center.anchor_top = 0.0
	top_center.offset_left = -100
	top_center.offset_right = 100
	top_center.offset_top = 12
	top_center.add_theme_constant_override("separation", 2)
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_center)

	_tier_label = Label.new()
	_tier_label.text = "Easy"
	_tier_label.add_theme_font_size_override("font_size", 22)
	_tier_label.add_theme_color_override("font_color", Config.COLOR_TIER_EASY)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.add_child(_tier_label)

	var theme: Dictionary = Config.get_theme()

	_hearts_label = Label.new()
	_hearts_label.text = "\u2764\u2764\u2764"
	_hearts_label.add_theme_font_size_override("font_size", 24)
	_hearts_label.add_theme_color_override("font_color", theme["heart"])
	_hearts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hearts_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.add_child(_hearts_label)

	# Bottom-right: guide lines toggle button
	_grid_btn = _create_circle_button("#", 48)
	_grid_btn.anchor_left = 1.0
	_grid_btn.anchor_top = 1.0
	_grid_btn.anchor_right = 1.0
	_grid_btn.anchor_bottom = 1.0
	_grid_btn.offset_left = -64
	_grid_btn.offset_top = -64
	_grid_btn.offset_right = -16
	_grid_btn.offset_bottom = -16
	_grid_btn.gui_input.connect(_on_grid_input)
	_grid_btn_style = _grid_btn.get_theme_stylebox("panel") as StyleBoxFlat
	root.add_child(_grid_btn)


func _create_circle_button(icon_text: String, btn_size: int) -> PanelContainer:
	var t: Dictionary = Config.get_theme()
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = t.get("nav_pill", Config.COLOR_NAV_PILL)
	Config.set_corner_radius(style, btn_size / 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(btn_size, btn_size)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var label := Label.new()
	label.text = icon_text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", t.get("nav_icon", Config.COLOR_NAV_ICON))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	return panel


func _on_back_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		AudioManager.play("ui_click")
		back_pressed.emit()


func _on_reset_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		AudioManager.play("ui_click")
		reset_pressed.emit()


func _on_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		AudioManager.play("ui_click")
		_guide_active = !_guide_active
		_update_grid_btn_style()
		guide_toggled.emit(_guide_active)


func _update_grid_btn_style() -> void:
	Config.set_corner_radius(_grid_btn_style, 12 if _guide_active else 24)


func set_guide_off() -> void:
	_guide_active = false
	_update_grid_btn_style()


func update_level(level_num: int) -> void:
	_level_index = level_num - 1
	var tier_name := Config.get_tier_name(_level_index)
	_tier_label.text = tier_name
	_tier_label.add_theme_color_override("font_color", Config.get_tier_color(tier_name))


func update_hearts(count: int) -> void:
	var t: Dictionary = Config.get_theme()
	var full := clampi(count, 0, Config.HEARTS_MAX)
	var empty := Config.HEARTS_MAX - full
	var heart_full := "\u2764"
	var heart_empty := "\u2661"
	_hearts_label.text = heart_full.repeat(full) + heart_empty.repeat(empty)
	# Update heart color from theme (full hearts color; empty hearts share the glyph)
	_hearts_label.add_theme_color_override("font_color", t["heart"])
