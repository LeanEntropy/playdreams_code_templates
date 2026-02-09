extends RigidBody3D
class_name TankProjectile

const HitEffectScene = preload("res://assets/projectile_hit_effect.tscn")

@export var speed: float = 30.0
@export var lifetime: float = 8.0
@export var damage: int = 25

var direction: Vector3 = Vector3.FORWARD


func _ready() -> void:
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	_apply_config_color()
	linear_velocity = direction * speed

	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()


func launch(launch_direction: Vector3, launch_speed: float = 30.0, launch_gravity_scale: float = 0.15) -> void:
	direction = launch_direction.normalized()
	speed = launch_speed
	linear_velocity = direction * speed
	gravity_scale = launch_gravity_scale

	var player = get_tree().get_first_node_in_group("player")
	if player:
		add_collision_exception_with(player)


func _apply_config_color() -> void:
	var color_hex: String = GameConfig.get_value("projectile", "mesh_color", "FF6B35")
	var color: Color = Color(color_hex) if color_hex.length() == 6 else Color.ORANGE

	var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_instance:
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.0
	mesh_instance.set_surface_override_material(0, material)


func _on_body_entered(body: Node) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true

	var hit_effect = HitEffectScene.instantiate()
	get_tree().root.add_child(hit_effect)
	hit_effect.global_position = global_position

	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
