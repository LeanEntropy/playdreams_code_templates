extends Node3D
class_name CameraRig

## Camera management component with three modes: Chase, TopDown, Free.
## Add as child of Player (CharacterBody3D). Owns mouse mode.
##
## Node structure (created in _ready):
##   CameraRig (this)
##     +-- ChaseCamera (Camera3D)
##     +-- TopDownCamera (Camera3D)
##     +-- FreeCamera (Camera3D)

enum CameraMode { CHASE, TOP_DOWN, FREE }

signal camera_mode_changed(new_mode: CameraMode)

@export var default_mode: CameraMode = CameraMode.CHASE

@export_group("Chase Camera")
@export var chase_offset: Vector3 = Vector3(0.0, 3.0, 8.0)
@export var chase_fov: float = 75.0
@export var camera_follow_speed: float = 12.0

@export_group("Top Down Camera")
@export var topdown_height: float = 20.0
@export var topdown_min_zoom: float = 10.0
@export var topdown_max_zoom: float = 40.0
@export var topdown_fov: float = 75.0

@export_group("Free Camera")
@export var free_cam_distance: float = 15.0
@export var free_cam_min_distance: float = 5.0
@export var free_cam_max_distance: float = 30.0
@export var free_orbit_speed: float = 0.005
@export var free_cam_fov: float = 75.0

# Camera nodes
var _chase_camera: Camera3D
var _topdown_camera: Camera3D
var _free_camera: Camera3D

# State
var _current_mode: CameraMode = CameraMode.CHASE
var _player: CharacterBody3D
var _turret: Node3D

# Chase camera state
var _chase_target_yaw: float = 0.0
var _chase_current_yaw: float = 0.0
var _chase_pitch_offset: float = 0.0  # For camera kick from shooting feedback

# Top-down state
var _topdown_current_height: float = 20.0

# Free camera state
var _free_yaw: float = 0.0
var _free_pitch: float = -0.4  # Slightly looking down
var _free_distance: float = 15.0
var _free_dragging: bool = false


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	if not _player:
		Log.error("CameraRig: Parent must be CharacterBody3D")
		queue_free()
		return

	_turret = _player.get_node_or_null("PlayerTank/Turret")

	_create_cameras()
	_load_config_overrides()
	_topdown_current_height = topdown_height
	_free_distance = free_cam_distance
	switch_mode(default_mode)


func _create_cameras() -> void:
	# Chase camera
	_chase_camera = Camera3D.new()
	_chase_camera.name = "ChaseCamera"
	_chase_camera.fov = chase_fov
	_chase_camera.position = chase_offset
	add_child(_chase_camera)

	# Top-down camera
	_topdown_camera = Camera3D.new()
	_topdown_camera.name = "TopDownCamera"
	_topdown_camera.fov = topdown_fov
	add_child(_topdown_camera)

	# Free camera
	_free_camera = Camera3D.new()
	_free_camera.name = "FreeCamera"
	_free_camera.fov = free_cam_fov
	add_child(_free_camera)


func _load_config_overrides() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://game_config.cfg") != OK:
		return

	# Chase
	chase_offset.y = cfg.get_value("tank", "camera_height", chase_offset.y)
	chase_offset.z = cfg.get_value("tank", "camera_distance", chase_offset.z)
	camera_follow_speed = cfg.get_value("tank", "camera_follow_speed", camera_follow_speed)
	chase_fov = cfg.get_value("tank", "fov", chase_fov)
	_chase_camera.fov = chase_fov

	# Top-down
	topdown_height = cfg.get_value("tank", "topdown_camera_height", topdown_height)
	topdown_min_zoom = cfg.get_value("tank", "topdown_min_zoom", topdown_min_zoom)
	topdown_max_zoom = cfg.get_value("tank", "topdown_max_zoom", topdown_max_zoom)

	# Free
	free_cam_distance = cfg.get_value("tank", "free_cam_distance", free_cam_distance)

	# Default mode from string
	var mode_str: String = cfg.get_value("tank", "camera_mode", "chase")
	match mode_str:
		"chase":
			default_mode = CameraMode.CHASE
		"top_down":
			default_mode = CameraMode.TOP_DOWN
		"free":
			default_mode = CameraMode.FREE


func _unhandled_input(event: InputEvent) -> void:
	# Camera switch on C key
	if event.is_action_pressed("switch_camera"):
		var next_mode: CameraMode = wrapi(_current_mode + 1, 0, 3) as CameraMode
		switch_mode(next_mode)
		return

	match _current_mode:
		CameraMode.CHASE:
			_chase_input(event)
		CameraMode.TOP_DOWN:
			_topdown_input(event)
		CameraMode.FREE:
			_free_input(event)


func _physics_process(delta: float) -> void:
	if not _player:
		return

	match _current_mode:
		CameraMode.CHASE:
			_chase_process(delta)
		CameraMode.TOP_DOWN:
			_topdown_process(delta)
		CameraMode.FREE:
			_free_process(delta)


# === Mode switching ===

func switch_mode(mode: CameraMode) -> void:
	_current_mode = mode

	match mode:
		CameraMode.CHASE:
			_chase_camera.make_current()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			# Sync chase yaw to current turret yaw
			if _turret:
				_chase_target_yaw = _turret.rotation.y
				_chase_current_yaw = _turret.rotation.y
		CameraMode.TOP_DOWN:
			_topdown_camera.make_current()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		CameraMode.FREE:
			_free_camera.make_current()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			# Initialize orbit from current chase direction
			_free_yaw = _chase_current_yaw

	camera_mode_changed.emit(mode)


func get_active_camera() -> Camera3D:
	match _current_mode:
		CameraMode.CHASE:
			return _chase_camera
		CameraMode.TOP_DOWN:
			return _topdown_camera
		CameraMode.FREE:
			return _free_camera
	return _chase_camera


func get_current_mode() -> CameraMode:
	return _current_mode


# === Chase camera ===

func _chase_input(_event: InputEvent) -> void:
	# Chase camera input is handled by the tank controller (turret rotation).
	# Camera follows turret in _chase_process.
	pass


func set_chase_yaw(yaw: float) -> void:
	## Called by tank_controller when turret rotates. Camera tracks this.
	_chase_target_yaw = yaw


func apply_camera_kick(pitch_degrees: float) -> void:
	## Called by ShootingFeedback to add recoil kick to chase camera.
	_chase_pitch_offset += deg_to_rad(pitch_degrees)


func _chase_process(delta: float) -> void:
	if not _turret:
		return

	# Smoothly follow turret yaw
	_chase_current_yaw = lerp_angle(_chase_current_yaw, _chase_target_yaw, camera_follow_speed * delta)

	# Decay camera kick
	_chase_pitch_offset = move_toward(_chase_pitch_offset, 0.0, delta * 8.0)

	# Position camera behind turret direction
	var yaw_basis := Basis(Vector3.UP, _chase_current_yaw)
	var offset_rotated: Vector3 = yaw_basis * chase_offset
	var target_pos: Vector3 = _player.global_position + offset_rotated

	# Collision avoidance: raycast from player to desired camera position
	var space_state := _player.get_world_3d().direct_space_state
	var ray_from: Vector3 = _player.global_position + Vector3(0, chase_offset.y * 0.5, 0)
	var query := PhysicsRayQueryParameters3D.create(ray_from, target_pos)
	query.exclude = [_player]
	var result: Dictionary = space_state.intersect_ray(query)

	if not result.is_empty():
		# Pull camera in front of the obstacle
		target_pos = result.position + (ray_from - target_pos).normalized() * 0.3

	_chase_camera.global_position = _chase_camera.global_position.lerp(target_pos, camera_follow_speed * delta)

	# Look at player with pitch kick offset
	var look_target: Vector3 = _player.global_position + Vector3(0, 1.0, 0)
	_chase_camera.look_at(look_target)
	_chase_camera.rotation.x += _chase_pitch_offset


# === Top-down camera ===

func _topdown_input(event: InputEvent) -> void:
	# Scroll to zoom
	if event.is_action_pressed("zoom_in"):
		_topdown_current_height = maxf(_topdown_current_height - 2.0, topdown_min_zoom)
	elif event.is_action_pressed("zoom_out"):
		_topdown_current_height = minf(_topdown_current_height + 2.0, topdown_max_zoom)


func _topdown_process(_delta: float) -> void:
	# Follow player position from above
	_topdown_camera.global_position = _player.global_position + Vector3(0, _topdown_current_height, 0)
	_topdown_camera.rotation_degrees = Vector3(-90, 0, 0)


# === Free camera ===

func _free_input(event: InputEvent) -> void:
	# Right-drag to orbit
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_free_dragging = event.pressed

		# Scroll to zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_free_distance = maxf(_free_distance - 1.0, free_cam_min_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_free_distance = minf(_free_distance + 1.0, free_cam_max_distance)

	if event is InputEventMouseMotion and _free_dragging:
		_free_yaw -= event.relative.x * free_orbit_speed
		_free_pitch -= event.relative.y * free_orbit_speed
		_free_pitch = clampf(_free_pitch, -1.2, -0.1)  # Keep above ground


func _free_process(_delta: float) -> void:
	# Orbit around player
	var offset := Vector3.ZERO
	offset.x = _free_distance * cos(_free_pitch) * sin(_free_yaw)
	offset.y = _free_distance * -sin(_free_pitch)
	offset.z = _free_distance * cos(_free_pitch) * cos(_free_yaw)

	_free_camera.global_position = _player.global_position + offset
	_free_camera.look_at(_player.global_position + Vector3(0, 1.0, 0))
