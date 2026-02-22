extends CanvasLayer

signal home_pressed

const _CARD_DEFS: Array = [
	[
		{"type": "button", "icon": "globe", "label": "Language", "value": "English >"},
		{"type": "toggle", "icon": "vibrate", "label": "Vibrations", "key": "vibrations"},
		{"type": "toggle", "icon": "sound", "label": "Sounds", "key": "sounds"},
		{"type": "toggle", "icon": "moon", "label": "Dark mode", "key": "dark_mode"},
		{"type": "toggle", "icon": "phone", "label": "Native Refresh Rate", "key": "native_refresh"},
	],
	[
		{"type": "button", "icon": "star", "label": "Rate us"},
		{"type": "button", "icon": "pencil", "label": "Write us"},
	],
	[
		{"type": "toggle", "icon": "person", "label": "Account Connection", "key": "account"},
	],
	[
		{"type": "toggle", "icon": "block", "label": "Remove Ads", "key": "remove_ads"},
		{"type": "button", "icon": "refresh", "label": "Restore purchases"},
	],
	[
		{"type": "button", "icon": "doc", "label": "Privacy"},
	],
]

const _ICON_MAP := {
	"globe": "\u25CB",
	"vibrate": "\u2248",
	"sound": "\u266A",
	"moon": "\u263E",
	"phone": "\u25A1",
	"star": "\u2605",
	"pencil": "\u270E",
	"person": "\u25CF",
	"block": "\u25D8",
	"refresh": "\u21BB",
	"doc": "\u25A0",
}

const _DEFAULT_SETTINGS := {
	"vibrations": true,
	"sounds": true,
	"dark_mode": false,
	"native_refresh": true,
	"account": false,
	"remove_ads": false,
}

var _settings: Dictionary = {}
var _toggles: Dictionary = {}  # key -> {track: ColorRect, knob: ColorRect}
var _is_dark: bool = Config.THEME == "pastel"


func _ready() -> void:
	_load_settings()

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

	# Scroll area (leave room for nav bar)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 24
	scroll.offset_top = 40
	scroll.offset_right = -24
	scroll.offset_bottom = -Config.NAV_BAR_HEIGHT
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var cards_vbox := VBoxContainer.new()
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(cards_vbox)

	# Build cards
	for card_def: Array in _CARD_DEFS:
		var card := _build_card(card_def)
		cards_vbox.add_child(card)

	# Bottom spacer (so last card isn't flush with nav)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	cards_vbox.add_child(spacer)

	# Nav bar
	_build_nav_bar(root)

	# Apply loaded settings to AudioManager
	_apply_audio_settings()


func _build_card(rows: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Config.get_theme()["card_bg"] if _is_dark else Config.COLOR_CARD_BG
	Config.set_corner_radius(style, 16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	for i: int in rows.size():
		var row_def: Dictionary = rows[i]
		var row := _build_row(row_def)
		vbox.add_child(row)

		# Separator between rows (not after last)
		if i < rows.size() - 1:
			var sep := HSeparator.new()
			var sep_style := StyleBoxFlat.new()
			sep_style.bg_color = Color(1, 1, 1, 0.1) if _is_dark else Color(0.75, 0.78, 0.85, 0.3)
			sep_style.content_margin_top = 0.5
			sep_style.content_margin_bottom = 0.5
			sep.add_theme_stylebox_override("separator", sep_style)
			vbox.add_child(sep)

	return panel


func _build_row(row_def: Dictionary) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	var t_text: Color = Color.WHITE if _is_dark else Config.COLOR_TITLE
	var t_icon: Color = Color(1, 1, 1, 0.6) if _is_dark else Config.COLOR_NAV_ICON

	# Icon
	var icon := Label.new()
	icon.text = _ICON_MAP.get(row_def.get("icon", ""), "?")
	icon.add_theme_font_size_override("font_size", 22)
	icon.add_theme_color_override("font_color", t_icon)
	icon.custom_minimum_size = Vector2(30, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon)

	# Label
	var label := Label.new()
	label.text = row_def.get("label", "")
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", t_text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	# Right side: toggle or value text
	if row_def.get("type") == "toggle":
		var toggle := _build_toggle(row_def.get("key", ""))
		hbox.add_child(toggle)
	elif row_def.has("value"):
		var value_label := Label.new()
		value_label.text = row_def["value"]
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.add_theme_color_override("font_color", t_icon)
		hbox.add_child(value_label)

	# Make tappable rows respond to input
	if row_def.get("type") == "button":
		margin.mouse_filter = Control.MOUSE_FILTER_STOP
		margin.gui_input.connect(_on_button_row_input.bind(row_def.get("label", "")))

	return margin


func _build_toggle(key: String) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(52, 30)

	var is_on: bool = _settings.get(key, _DEFAULT_SETTINGS.get(key, false))

	var track_panel := Panel.new()
	var on_color: Color = Color("#A0B0E0") if _is_dark else Config.COLOR_TOGGLE_ON
	var off_color: Color = Color(1, 1, 1, 0.2) if _is_dark else Config.COLOR_TOGGLE_OFF
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = on_color if is_on else off_color
	Config.set_corner_radius(track_style, 15)
	track_panel.add_theme_stylebox_override("panel", track_style)
	track_panel.position = Vector2(0, 0)
	track_panel.size = Vector2(52, 30)
	track_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(track_panel)

	# Knob
	var knob := Panel.new()
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color.WHITE
	Config.set_corner_radius(knob_style, 11)
	knob.add_theme_stylebox_override("panel", knob_style)
	knob.size = Vector2(22, 22)
	knob.position = Vector2(26, 4) if is_on else Vector2(4, 4)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(knob)

	# Store references
	_toggles[key] = {"track": track_panel, "knob": knob, "style": track_style}

	# Input
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_toggle_input.bind(key))

	return container


func _on_toggle_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		AudioManager.play("ui_click")
		var current: bool = _settings.get(key, _DEFAULT_SETTINGS.get(key, false))
		_settings[key] = !current
		_update_toggle_visual(key, !current)
		_save_settings()
		_apply_audio_settings()


func _update_toggle_visual(key: String, is_on: bool) -> void:
	if not _toggles.has(key):
		return
	var toggle_data: Dictionary = _toggles[key]
	var track_panel: Panel = toggle_data["track"]
	var knob: Panel = toggle_data["knob"]
	var style: StyleBoxFlat = toggle_data["style"]

	var t_on: Color = Color("#A0B0E0") if _is_dark else Config.COLOR_TOGGLE_ON
	var t_off: Color = Color(1, 1, 1, 0.2) if _is_dark else Config.COLOR_TOGGLE_OFF
	style.bg_color = t_on if is_on else t_off
	knob.position = Vector2(26, 4) if is_on else Vector2(4, 4)


func _apply_audio_settings() -> void:
	AudioManager.sounds_enabled = _settings.get("sounds", true)
	AudioManager.vibrations_enabled = _settings.get("vibrations", true)


func _on_button_row_input(event: InputEvent, label_text: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		AudioManager.play("ui_click")
		# Placeholder for future actions (rate, write, privacy, etc.)


func _build_nav_bar(parent: Control) -> void:
	var t: Dictionary = Config.get_theme()
	var nav_bg := ColorRect.new()
	nav_bg.color = t.get("nav_bg", Config.COLOR_NAV_BG)
	nav_bg.anchor_left = 0.0
	nav_bg.anchor_top = 1.0
	nav_bg.anchor_right = 1.0
	nav_bg.anchor_bottom = 1.0
	nav_bg.offset_top = -Config.NAV_BAR_HEIGHT
	nav_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(nav_bg)

	var nav_hbox := HBoxContainer.new()
	nav_hbox.anchor_left = 0.0
	nav_hbox.anchor_top = 1.0
	nav_hbox.anchor_right = 1.0
	nav_hbox.anchor_bottom = 1.0
	nav_hbox.offset_top = -Config.NAV_BAR_HEIGHT
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 120)
	parent.add_child(nav_hbox)

	# Home (unselected)
	var home_btn := _create_nav_item("Home", false)
	home_btn.gui_input.connect(_on_home_gui_input)
	nav_hbox.add_child(home_btn)

	# Settings (selected)
	var settings_btn := _create_nav_item("Settings", true)
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


func _on_home_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		AudioManager.play("ui_click")
		home_pressed.emit()


# --- Settings persistence ---

func _load_settings() -> void:
	_settings = _DEFAULT_SETTINGS.duplicate()
	if not FileAccess.file_exists(Config.SETTINGS_SAVE_PATH):
		return
	var file := FileAccess.open(Config.SETTINGS_SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		return
	if json.data is Dictionary:
		var data: Dictionary = json.data
		for key: String in _DEFAULT_SETTINGS:
			if data.has(key):
				_settings[key] = data[key]


func _save_settings() -> void:
	var file := FileAccess.open(Config.SETTINGS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_settings, "\t"))


func show_screen() -> void:
	visible = true
	# Re-apply settings in case they were changed externally
	_apply_audio_settings()


func hide_screen() -> void:
	visible = false
