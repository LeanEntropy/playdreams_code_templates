extends Node
class_name AimingHelper

## Static aiming utility for screen-center raycasts.

static func get_screen_center_target(camera: Camera3D, max_distance: float, exclude_bodies: Array = []) -> Vector3:
	if not camera:
		return Vector3.ZERO

	var viewport: Viewport = camera.get_viewport()
	if not viewport:
		return camera.global_position + (-camera.global_transform.basis.z * max_distance)

	var screen_center: Vector2 = viewport.get_visible_rect().size / 2.0
	var ray_origin: Vector3 = camera.project_ray_origin(screen_center)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_center)

	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * max_distance
	)
	query.exclude = exclude_bodies

	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		return result.position
	return ray_origin + ray_direction * max_distance
