extends CharacterBody3D

## Tank controller with hull movement, independent turret, terrain following,
## and turret-following camera. Attach directly to the Player CharacterBody3D.
##
## Camera is parented to the Turret node and auto-follows turret rotation.
## Barrel pitch is mirrored to camera pitch so the barrel tip stays at crosshair.

signal health_changed(current: int, max_health: int)

@export_group("Movement")
@export var forward_speed: float = 10.0
@export var reverse_speed: float = 4.0
@export var hull_turn_speed: float = 2.0
@export var acceleration: float = 4.0
@export var deceleration: float = 6.0
@export var gravity: float = 9.8

@export_group("Turret")
@export var mouse_sensitivity: float = 0.003
@export var turret_speed_limited: bool = true
@export var turret_rotation_speed: float = 3.0
@export var barrel_pitch_min: float = -12.0
@export var barrel_pitch_max: float = 30.0

@export_group("Terrain")
@export var terrain_follow_enabled: bool = true
@export var terrain_raycast_length: float = 2.0
@export var terrain_rotation_speed: float = 8.0
@export var raycast_offset: float = 0.8

@export_group("Health")
@export var max_health: int = 100

# Node references
var _turret: Node3D
var _barrel_pivot: Node3D
var _tank_hull: Node3D
var _camera: Camera3D

# Turret state
var _turret_yaw: float = 0.0
var _turret_target_yaw: float = 0.0
var _barrel_pitch: float = 0.0

# Movement state
var _current_speed: float = 0.0

# Health state
var _current_health: int = 100


func _ready() -> void:
	_turret = get_node_or_null("PlayerTank/Turret")
	_barrel_pivot = get_node_or_null("PlayerTank/Turret/BarrelPivot")
	_tank_hull = get_node_or_null("PlayerTank/TankHull")
	_camera = get_node_or_null("PlayerTank/Turret/TankCamera") as Camera3D

	if _turret:
		_turret_yaw = _turret.rotation.y
		_turret_target_yaw = _turret_yaw

	if _camera:
		_camera.make_current()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_current_health = max_health
	_load_config_overrides()


func _load_config_overrides() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://game_config.cfg") != OK:
		return

	forward_speed = cfg.get_value("tank", "forward_speed", forward_speed)
	reverse_speed = cfg.get_value("tank", "reverse_speed", reverse_speed)
	hull_turn_speed = cfg.get_value("tank", "hull_turn_speed", hull_turn_speed)
	acceleration = cfg.get_value("tank", "acceleration", acceleration)
	deceleration = cfg.get_value("tank", "deceleration", deceleration)
	mouse_sensitivity = cfg.get_value("tank", "mouse_sensitivity", mouse_sensitivity)
	turret_speed_limited = cfg.get_value("tank", "turret_speed_limited", turret_speed_limited)
	turret_rotation_speed = cfg.get_value("tank", "turret_rotation_speed", turret_rotation_speed)
	barrel_pitch_min = cfg.get_value("tank", "barrel_pitch_min", barrel_pitch_min)
	barrel_pitch_max = cfg.get_value("tank", "barrel_pitch_max", barrel_pitch_max)
	gravity = cfg.get_value("tank", "gravity", gravity)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Mouse X -> turret yaw target
		_turret_target_yaw -= event.relative.x * mouse_sensitivity

		# Mouse Y -> barrel pitch
		var pitch_delta: float = -event.relative.y * mouse_sensitivity
		_barrel_pitch += pitch_delta
		_barrel_pitch = clampf(_barrel_pitch, deg_to_rad(barrel_pitch_min), deg_to_rad(barrel_pitch_max))

		if _barrel_pivot:
			# Rotate around Z axis because barrel extends in -X direction
			_barrel_pivot.rotation.z = -_barrel_pitch

		# Camera pitch follows barrel pitch so barrel tip stays at crosshair
		if _camera:
			var cam_pitch: float = rad_to_deg(_barrel_pitch)
			cam_pitch = clampf(cam_pitch, -15.0, 60.0)
			_camera.rotation_degrees.x = cam_pitch

	# ESC to toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Movement input
	var forward_input: float = Input.get_action_strength("forward") - Input.get_action_strength("backward")
	var turn_input: float = Input.get_action_strength("right") - Input.get_action_strength("left")

	# Hull rotation
	var current_y: float = rotation.y
	rotate_y(-turn_input * hull_turn_speed * delta)
	current_y = rotation.y

	# Terrain following
	if terrain_follow_enabled and is_on_floor():
		_apply_terrain_rotation(delta, current_y)
	elif terrain_follow_enabled:
		var level_rot := Vector3(0, current_y, 0)
		rotation = rotation.lerp(level_rot, 5.0 * delta)

	# Acceleration / deceleration
	var target_speed: float = forward_input * (forward_speed if forward_input >= 0.0 else reverse_speed)
	var accel: float = acceleration if absf(target_speed) >= absf(_current_speed) else deceleration
	_current_speed = move_toward(_current_speed, target_speed, accel * delta)

	var move_dir: Vector3 = -transform.basis.z * _current_speed
	velocity.x = move_dir.x
	velocity.z = move_dir.z

	move_and_slide()

	# Turret rotation with speed limit
	_update_turret(delta)


func _update_turret(delta: float) -> void:
	if not _turret:
		return

	if turret_speed_limited:
		_turret_yaw = move_toward(_turret_yaw, _turret_target_yaw, turret_rotation_speed * delta)
	else:
		_turret_yaw = _turret_target_yaw

	_turret.rotation.y = _turret_yaw


func _apply_terrain_rotation(delta: float, preserve_y: float) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var corners: Array[Vector3] = [
		Vector3(raycast_offset, 0, raycast_offset),
		Vector3(-raycast_offset, 0, raycast_offset),
		Vector3(raycast_offset, 0, -raycast_offset),
		Vector3(-raycast_offset, 0, -raycast_offset),
	]

	var hit_normals: Array[Vector3] = []

	for corner_local in corners:
		var corner_world: Vector3 = global_transform * corner_local
		var ray_start: Vector3 = corner_world + Vector3(0, 0.5, 0)
		var ray_end: Vector3 = corner_world - Vector3(0, terrain_raycast_length, 0)

		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [self]
		query.collision_mask = 1

		var result: Dictionary = space_state.intersect_ray(query)
		if result:
			hit_normals.append(result.normal)

	if hit_normals.size() < 3:
		return

	var avg_normal := Vector3.ZERO
	for n in hit_normals:
		avg_normal += n
	avg_normal = avg_normal.normalized()

	var target_basis := Basis()
	target_basis.y = avg_normal
	target_basis.x = -target_basis.y.cross(Vector3.FORWARD).normalized()
	target_basis.z = target_basis.x.cross(target_basis.y).normalized()

	var target_rot: Vector3 = target_basis.get_euler()
	target_rot.y = preserve_y

	var current_rot: Vector3 = rotation
	current_rot.y = preserve_y

	var new_rot: Vector3 = current_rot.lerp(target_rot, terrain_rotation_speed * delta)
	new_rot.y = preserve_y
	rotation = new_rot


# === Health ===

func take_damage(amount: int) -> void:
	_current_health = maxi(0, _current_health - amount)
	health_changed.emit(_current_health, max_health)
