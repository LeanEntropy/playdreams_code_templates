extends Node
class_name ShootingComponent

## Tank shooting system. Finds barrel tip for muzzle position,
## uses the viewport's active camera for aim direction, fires projectiles on "shoot" action.

const AimingHelper = preload("res://code/components/aiming_helper.gd")

signal shot_fired
signal ammo_changed(current: int, max_ammo: int)

@export_group("Firing")
@export var fire_rate: float = 2.0
@export var projectile_speed: float = 55.0
@export var projectile_gravity_scale: float = 0.1

@export_group("Ammo")
@export var max_ammo: int = -1  # -1 = unlimited
@export var ammo_per_clip: int = 10
@export var reload_time: float = 3.0

# Internal state
var _can_shoot: bool = true
var _is_reloading: bool = false
var _current_ammo: int = 10
var _player: CharacterBody3D
var _muzzle_marker: Node3D
var _projectile_scene: PackedScene
var _cooldown_timer: Timer


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	if not _player:
		Log.error("ShootingComponent: Parent must be CharacterBody3D")
		queue_free()
		return

	_projectile_scene = load("res://assets/tank_projectile.tscn")
	if not _projectile_scene:
		Log.error("ShootingComponent: Could not load tank_projectile.tscn")
		queue_free()
		return

	# Cooldown timer
	_cooldown_timer = Timer.new()
	_cooldown_timer.name = "CooldownTimer"
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

	# Wait a frame for sibling nodes to be ready
	await get_tree().process_frame

	_setup_barrel_muzzle()
	_load_config_overrides()

	if max_ammo > 0:
		_current_ammo = ammo_per_clip
		ammo_changed.emit(_current_ammo, ammo_per_clip)


func _setup_barrel_muzzle() -> void:
	var barrel_pivot: Node3D = _player.get_node_or_null("PlayerTank/Turret/BarrelPivot")
	if not barrel_pivot:
		Log.warning("ShootingComponent: BarrelPivot not found")
		return

	var barrel: Node3D = barrel_pivot.get_node_or_null("TankGunBarrel")
	if not barrel:
		Log.warning("ShootingComponent: TankGunBarrel not found")
		return

	# Use existing BarrelTip if present
	_muzzle_marker = barrel.get_node_or_null("BarrelTip")
	if _muzzle_marker:
		return

	# Calculate barrel tip from mesh AABB
	var barrel_mesh: MeshInstance3D = barrel as MeshInstance3D if barrel is MeshInstance3D else null
	if not barrel_mesh:
		for child in barrel.get_children():
			if child is MeshInstance3D:
				barrel_mesh = child
				break

	var tip_z: float = -0.01
	if barrel_mesh and barrel_mesh.mesh:
		var aabb: AABB = barrel_mesh.mesh.get_aabb()
		var mesh_local_pos: Vector3 = Vector3.ZERO if barrel_mesh == barrel else barrel_mesh.position
		tip_z = mesh_local_pos.z + aabb.position.z - aabb.size.z / 2.0

	var tip := Node3D.new()
	tip.name = "BarrelTip"
	barrel.add_child(tip)
	tip.position = Vector3(0, 0, tip_z)
	_muzzle_marker = tip


func _load_config_overrides() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://game_config.cfg") != OK:
		return

	fire_rate = cfg.get_value("shooting", "fire_rate", fire_rate)
	projectile_speed = cfg.get_value("shooting", "projectile_speed", projectile_speed)
	projectile_gravity_scale = cfg.get_value("shooting", "projectile_gravity_scale", projectile_gravity_scale)
	max_ammo = cfg.get_value("shooting", "max_ammo", max_ammo)
	ammo_per_clip = cfg.get_value("shooting", "ammo_per_clip", ammo_per_clip)
	reload_time = cfg.get_value("shooting", "reload_time", reload_time)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot") and _can_shoot and not _is_reloading:
		if _check_ammo():
			_shoot()


func _check_ammo() -> bool:
	if max_ammo == -1:
		return true
	if _current_ammo > 0:
		return true
	if not _is_reloading:
		_start_reload()
	return false


func _shoot() -> void:
	if not _projectile_scene:
		return

	var muzzle_pos: Vector3 = get_muzzle_position()
	var fire_dir: Vector3 = get_fire_direction()

	var projectile: RigidBody3D = _projectile_scene.instantiate() as RigidBody3D
	get_tree().root.add_child(projectile)
	projectile.global_position = muzzle_pos

	if projectile.has_method("launch"):
		projectile.launch(fire_dir, projectile_speed, projectile_gravity_scale)
	else:
		projectile.linear_velocity = fire_dir * projectile_speed
		projectile.gravity_scale = projectile_gravity_scale

	if max_ammo > 0:
		_current_ammo -= 1
		ammo_changed.emit(_current_ammo, ammo_per_clip)

	shot_fired.emit()

	# Start cooldown
	_can_shoot = false
	_cooldown_timer.wait_time = fire_rate
	_cooldown_timer.start()


func _on_cooldown_timeout() -> void:
	_can_shoot = true


func _start_reload() -> void:
	if _is_reloading or max_ammo == -1:
		return
	_is_reloading = true
	await get_tree().create_timer(reload_time).timeout
	_current_ammo = ammo_per_clip
	_is_reloading = false
	ammo_changed.emit(_current_ammo, ammo_per_clip)


func reload() -> void:
	if not _is_reloading and _current_ammo < ammo_per_clip:
		_start_reload()


# === Public API ===

func get_muzzle_position() -> Vector3:
	if _muzzle_marker:
		return _muzzle_marker.global_position
	return _player.global_position + Vector3(0, 1.5, 0)


func get_fire_direction() -> Vector3:
	var muzzle_pos: Vector3 = get_muzzle_position()
	var target_pos: Vector3 = _get_aim_target()
	return AimingHelper.calculate_fire_direction(muzzle_pos, target_pos)


func _get_aim_target() -> Vector3:
	# Use whatever camera is currently active in the viewport
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam:
		return get_muzzle_position() + Vector3.FORWARD * 100.0

	return AimingHelper.get_screen_center_target(cam, 1000.0, [_player])
