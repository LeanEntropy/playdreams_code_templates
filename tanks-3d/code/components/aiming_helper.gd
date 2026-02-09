extends Node
class_name AimingHelper

## Utility class for aim raycasts. Static methods only.

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


static func get_mouse_ground_target(camera: Camera3D, mouse_position: Vector2, ground_y: float = 0.0, exclude_bodies: Array = []) -> Vector3:
	if not camera:
		return Vector3.ZERO

	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position)

	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 1000.0
	)
	query.exclude = exclude_bodies

	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		return result.position

	# No physics hit -- intersect with ground plane
	var ground_plane := Plane(Vector3.UP, ground_y)
	var intersection: Variant = ground_plane.intersects_ray(ray_origin, ray_direction)
	if intersection:
		return intersection

	return ray_origin + ray_direction * 10.0


static func calculate_fire_direction(muzzle_position: Vector3, target_position: Vector3) -> Vector3:
	var direction: Vector3 = (target_position - muzzle_position).normalized()
	if direction.length_squared() < 0.0001:
		return Vector3.FORWARD
	return direction


static func has_clear_line_of_sight(from_position: Vector3, to_position: Vector3, world_3d: World3D, exclude_bodies: Array = []) -> bool:
	var direction: Vector3 = (to_position - from_position)
	var distance: float = direction.length()

	var space_state: PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(world_3d.space)
	var query := PhysicsRayQueryParameters3D.create(
		from_position,
		from_position + direction.normalized() * distance
	)
	query.exclude = exclude_bodies

	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()
