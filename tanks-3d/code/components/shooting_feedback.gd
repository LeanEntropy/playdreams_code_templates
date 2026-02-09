extends Node
class_name ShootingFeedback

## Subscribes to ShootingComponent.shot_fired and provides game-feel feedback:
## screen shake and muzzle flash. All values are config-driven via [shooting]
## section of game_config.cfg.

@export_group("Screen Shake")
@export var screen_shake_enabled: bool = true
@export var screen_shake_intensity: float = 0.03
@export var screen_shake_duration: float = 0.15

@export_group("Muzzle Flash")
@export var muzzle_flash_enabled: bool = true
@export var muzzle_flash_duration: float = 0.05
@export var muzzle_flash_energy: float = 8.0
@export var muzzle_flash_range: float = 6.0
@export var muzzle_flash_color: Color = Color(1.0, 0.7, 0.2)

# Internal references
var _shooting_component: ShootingComponent
var _barrel_tip: Node3D

# State
var _shake_timer: float = 0.0
var _muzzle_light: OmniLight3D


func _ready() -> void:
	_load_config_overrides()

	# Defer to ensure scene tree is ready
	await get_tree().process_frame

	var parent: Node = get_parent()

	_shooting_component = parent.get_node_or_null("ShootingComponent") as ShootingComponent
	_barrel_tip = parent.get_node_or_null("PlayerTank/Turret/BarrelPivot/TankGunBarrel/BarrelTip")

	if _shooting_component:
		_shooting_component.shot_fired.connect(_on_shot_fired)
	else:
		Log.warning("ShootingFeedback: ShootingComponent not found on parent")


func _load_config_overrides() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://game_config.cfg") != OK:
		return

	screen_shake_enabled = cfg.get_value("shooting", "screen_shake_enabled", screen_shake_enabled)
	screen_shake_intensity = cfg.get_value("shooting", "screen_shake_intensity", screen_shake_intensity)
	muzzle_flash_enabled = cfg.get_value("shooting", "muzzle_flash_enabled", muzzle_flash_enabled)


func _on_shot_fired() -> void:
	_apply_screen_shake()
	_apply_muzzle_flash()


func _apply_screen_shake() -> void:
	if screen_shake_enabled:
		_shake_timer = screen_shake_duration


func _apply_muzzle_flash() -> void:
	if not muzzle_flash_enabled:
		return

	var flash_pos: Vector3
	if _barrel_tip:
		flash_pos = _barrel_tip.global_position
	else:
		return

	# Reuse or create muzzle flash light
	if not _muzzle_light or not is_instance_valid(_muzzle_light):
		_muzzle_light = OmniLight3D.new()
		_muzzle_light.name = "MuzzleFlash"
		get_tree().root.add_child(_muzzle_light)

	_muzzle_light.global_position = flash_pos
	_muzzle_light.light_color = muzzle_flash_color
	_muzzle_light.light_energy = muzzle_flash_energy
	_muzzle_light.omni_range = muzzle_flash_range
	_muzzle_light.visible = true

	# Hide after duration
	get_tree().create_timer(muzzle_flash_duration).timeout.connect(
		func() -> void:
			if is_instance_valid(_muzzle_light):
				_muzzle_light.visible = false
	)


func _process(delta: float) -> void:
	# Screen shake
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam:
			var shake_offset := Vector3(
				randf_range(-screen_shake_intensity, screen_shake_intensity),
				randf_range(-screen_shake_intensity, screen_shake_intensity),
				0.0
			)
			cam.h_offset = shake_offset.x
			cam.v_offset = shake_offset.y
		if _shake_timer <= 0.0:
			var reset_cam: Camera3D = get_viewport().get_camera_3d()
			if reset_cam:
				reset_cam.h_offset = 0.0
				reset_cam.v_offset = 0.0
