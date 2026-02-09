extends Node
class_name ShootingFeedback

## Screen shake and muzzle flash on shot. Config-driven via [shooting] section.

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

var _barrel_tip: Node3D
var _shake_timer: float = 0.0
var _muzzle_light: OmniLight3D


func _ready() -> void:
	screen_shake_enabled = GameConfig.get_value("shooting", "screen_shake_enabled", screen_shake_enabled)
	screen_shake_intensity = GameConfig.get_value("shooting", "screen_shake_intensity", screen_shake_intensity)
	muzzle_flash_enabled = GameConfig.get_value("shooting", "muzzle_flash_enabled", muzzle_flash_enabled)

	await get_tree().process_frame

	var parent: Node = get_parent()
	var shooting := parent.get_node_or_null("ShootingComponent") as ShootingComponent
	_barrel_tip = parent.get_node_or_null("PlayerTank/Turret/BarrelPivot/TankGunBarrel/BarrelTip")

	if shooting:
		shooting.shot_fired.connect(_on_shot_fired)


func _on_shot_fired() -> void:
	if screen_shake_enabled:
		_shake_timer = screen_shake_duration
	if muzzle_flash_enabled and _barrel_tip:
		_flash_muzzle()


func _flash_muzzle() -> void:
	if not _muzzle_light or not is_instance_valid(_muzzle_light):
		_muzzle_light = OmniLight3D.new()
		_muzzle_light.name = "MuzzleFlash"
		get_tree().root.add_child(_muzzle_light)

	_muzzle_light.global_position = _barrel_tip.global_position
	_muzzle_light.light_color = muzzle_flash_color
	_muzzle_light.light_energy = muzzle_flash_energy
	_muzzle_light.omni_range = muzzle_flash_range
	_muzzle_light.visible = true

	get_tree().create_timer(muzzle_flash_duration).timeout.connect(
		func() -> void:
			if is_instance_valid(_muzzle_light):
				_muzzle_light.visible = false
	)


func _process(delta: float) -> void:
	if _shake_timer <= 0.0:
		return

	_shake_timer -= delta
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam:
		return

	if _shake_timer > 0.0:
		cam.h_offset = randf_range(-screen_shake_intensity, screen_shake_intensity)
		cam.v_offset = randf_range(-screen_shake_intensity, screen_shake_intensity)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
