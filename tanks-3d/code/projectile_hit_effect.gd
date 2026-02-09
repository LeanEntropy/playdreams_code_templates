extends GPUParticles3D
class_name ProjectileHitEffect

func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.5).timeout
	if is_instance_valid(self):
		queue_free()
