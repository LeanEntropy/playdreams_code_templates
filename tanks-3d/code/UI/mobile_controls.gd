extends CanvasLayer
class_name MobileControls

## On-screen touch controls for mobile devices.
## Virtual joystick (left side) for movement, fire button (right side) for shooting.
## Auto-shown on mobile platforms, configurable via [controls] in game_config.cfg.
##
## Touch zones:
##   Left 40% of screen  -> Virtual joystick (appears where you touch)
##   Right side           -> Drag to aim turret (handled by tank_controller.gd)
##   Fire button (bottom-right) -> Shoot

@export var joystick_radius: float = 80.0
@export var joystick_dead_zone: float = 15.0
@export var fire_button_radius: float = 50.0

var _joystick_touch_index: int = -1
var _fire_touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_base: Panel
var _joystick_tip: Panel
var _fire_button: Panel
var _screen_size: Vector2


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var show_mode: String = GameConfig.get_value("controls", "show_mobile_controls", "auto")

	var should_show: bool = false
	match show_mode:
		"always":
			should_show = true
		"never":
			should_show = false
		_:
			should_show = _detect_mobile()

	if not should_show:
		set_process_input(false)
		return

	_screen_size = get_viewport().get_visible_rect().size
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)


func _build_ui() -> void:
	_joystick_base = _make_circle(joystick_radius, Color(1, 1, 1, 0.15))
	_joystick_base.visible = false
	add_child(_joystick_base)

	_joystick_tip = _make_circle(joystick_radius * 0.4, Color(1, 1, 1, 0.5))
	_joystick_tip.visible = false
	add_child(_joystick_tip)

	_fire_button = _make_circle(fire_button_radius, Color(1, 0.3, 0.2, 0.3))
	_position_fire_button()
	add_child(_fire_button)

	var label := Label.new()
	label.text = "FIRE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	label.size = _fire_button.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fire_button.add_child(label)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _is_in_fire_button(event.position):
			_fire_touch_index = event.index
			Input.action_press("shoot")
			_fire_button.modulate = Color(1.5, 1.5, 1.5)
			get_viewport().set_input_as_handled()
			return

		if event.position.x < _screen_size.x * 0.4 and _joystick_touch_index == -1:
			_joystick_touch_index = event.index
			_joystick_center = event.position
			_joystick_base.position = _joystick_center - Vector2(joystick_radius, joystick_radius)
			_joystick_tip.position = _joystick_center - _joystick_tip.size / 2.0
			_joystick_base.visible = true
			_joystick_tip.visible = true
			get_viewport().set_input_as_handled()
	else:
		if event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_joystick_base.visible = false
			_joystick_tip.visible = false
			_release_movement_actions()
			get_viewport().set_input_as_handled()
		elif event.index == _fire_touch_index:
			_fire_touch_index = -1
			Input.action_release("shoot")
			_fire_button.modulate = Color.WHITE
			get_viewport().set_input_as_handled()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch_index:
		var offset: Vector2 = event.position - _joystick_center
		if offset.length() > joystick_radius:
			offset = offset.normalized() * joystick_radius

		var tip_size: Vector2 = _joystick_tip.size
		_joystick_tip.position = _joystick_center + offset - tip_size / 2.0

		if offset.length() < joystick_dead_zone:
			_release_movement_actions()
		else:
			_apply_movement_actions(offset / joystick_radius)

		get_viewport().set_input_as_handled()
	elif event.index == _fire_touch_index:
		get_viewport().set_input_as_handled()


func _apply_movement_actions(stick: Vector2) -> void:
	if stick.y < -0.1:
		Input.action_press("forward", absf(stick.y))
		Input.action_release("backward")
	elif stick.y > 0.1:
		Input.action_press("backward", absf(stick.y))
		Input.action_release("forward")
	else:
		Input.action_release("forward")
		Input.action_release("backward")

	if stick.x < -0.1:
		Input.action_press("left", absf(stick.x))
		Input.action_release("right")
	elif stick.x > 0.1:
		Input.action_press("right", absf(stick.x))
		Input.action_release("left")
	else:
		Input.action_release("left")
		Input.action_release("right")


func _release_movement_actions() -> void:
	Input.action_release("forward")
	Input.action_release("backward")
	Input.action_release("left")
	Input.action_release("right")


func _is_in_fire_button(pos: Vector2) -> bool:
	var center: Vector2 = _fire_button.position + Vector2(fire_button_radius, fire_button_radius)
	return pos.distance_to(center) <= fire_button_radius * 1.3


func _position_fire_button() -> void:
	var margin: float = 40.0
	_fire_button.position = Vector2(
		_screen_size.x - fire_button_radius * 2 - margin,
		_screen_size.y - fire_button_radius * 2 - margin
	)


func _on_viewport_resized() -> void:
	_screen_size = get_viewport().get_visible_rect().size
	if _fire_button:
		_position_fire_button()


func _make_circle(radius: float, color: Color) -> Panel:
	var panel := Panel.new()
	panel.size = Vector2(radius * 2, radius * 2)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


static func detect_mobile() -> bool:
	var os_name := OS.get_name()
	if os_name in ["Android", "iOS"]:
		return true
	if os_name == "Web":
		return DisplayServer.is_touchscreen_available()
	return false


func _detect_mobile() -> bool:
	return MobileControls.detect_mobile()
