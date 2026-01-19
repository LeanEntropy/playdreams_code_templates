extends Node
# Tank Controller - Proper tank combat with turret-controlled camera
#
# Controls:
# - W/S: Forward/backward movement
# - A/D: Hull rotation (turn tank body)
# - Mouse: Aim turret (camera follows turret)
# - Left Click: Fire projectile
#
# Camera follows turret rotation for aiming

const TankProjectileScene = preload("res://assets/tank_projectile.tscn")

# Player references
var player: CharacterBody3D
var camera: Camera3D
var turret: Node3D
var barrel_tip: Node3D
var barrel_pivot: Node3D  # For vertical barrel rotation

# Visual elements
var player_mesh: MeshInstance3D
var tank_hull: Node3D

# Configuration
var mouse_sensitivity: float = 0.002
var movement_speed: float = 5.0
var gravity: float = 9.8
var fire_rate: float = 0.5
var projectile_speed: float = 50.0
var hull_turn_speed: float = 2.0

# Terrain following configuration
var terrain_follow_enabled: bool = true
var terrain_raycast_length: float = 2.0  # How far down to check for ground
var terrain_rotation_speed: float = 8.0  # How fast tank tilts to match terrain
var raycast_offset: float = 0.8  # Distance from center to corner raycasts

# State
var is_active: bool = false
var can_shoot: bool = true
var camera_pitch: float = 0.0
var turret_yaw: float = 0.0
var barrel_pitch: float = 0.0
var barrel_pitch_min: float = -10.0  # Can aim down 10°
var barrel_pitch_max: float = 70.0   # Can aim up 70°

# UI
var crosshair_ui: Control = null

func initialize(player_node: CharacterBody3D) -> void:
	Log.info("TankController initializing...")
	
	if player_node == null:
		Log.error("TankController: Player node is null!")
		return
	
	player = player_node
	is_active = true
	
	# Get nodes (now under PlayerTank)
	turret = player.get_node("PlayerTank/Turret")
	player_mesh = player.get_node("PlayerMesh")
	tank_hull = player.get_node("PlayerTank/TankHull")

	# Setup camera on turret (camera is direct child of Turret - NO SpringArm3D)
	camera = player.get_node_or_null("PlayerTank/Turret/TankCamera")
	if not camera:
		Log.error("TankController: TankCamera not found under Turret!")
		return

	Log.info("=== CAMERA INITIAL STATE ===")
	Log.info("TankController: Found camera at Turret/TankCamera")
	Log.info("Camera position: " + str(camera.position))
	Log.info("Camera rotation: " + str(camera.rotation_degrees))
	Log.info("Camera transform: " + str(camera.transform))
	
	# Setup barrel pivot for elevation
	if player.has_node("PlayerTank/Turret/BarrelPivot"):
		barrel_pivot = player.get_node("PlayerTank/Turret/BarrelPivot")
		Log.info("Found existing BarrelPivot")
	else:
		Log.warning("No BarrelPivot found - creating one")
		barrel_pivot = Node3D.new()
		barrel_pivot.name = "BarrelPivot"
		turret.add_child(barrel_pivot)

		# Move barrel under pivot
		var barrel_to_move = player.get_node("PlayerTank/Turret/TankGunBarrel")
		if barrel_to_move:
			barrel_to_move.get_parent().remove_child(barrel_to_move)
			barrel_pivot.add_child(barrel_to_move)
			barrel_to_move.position = Vector3(0, 0, 0)  # Reset position
		barrel_pivot.position = Vector3(0, 0.3, 0)  # Adjust height

	# Keep BarrelPivot at origin - same as scene file
	# This is the rotation point at turret origin
	barrel_pivot.position = Vector3(0, 0, 0)
	Log.info("Set BarrelPivot at origin: " + str(barrel_pivot.position))

	# Position barrel mesh to extend forward from pivot
	# When pivot rotates around X axis, barrel tip moves in Y direction
	var barrel_mesh = barrel_pivot.get_node_or_null("TankGunBarrel")
	if barrel_mesh:
		# DEBUG: Log initial barrel mesh transform from scene file
		Log.info("=== BARREL MESH INITIAL STATE ===")
		Log.info("Barrel mesh initial position: " + str(barrel_mesh.position))
		Log.info("Barrel mesh initial rotation: " + str(barrel_mesh.rotation_degrees))
		Log.info("Barrel mesh initial scale: " + str(barrel_mesh.scale))
		Log.info("Barrel mesh initial transform: " + str(barrel_mesh.transform))

		# Get the barrel's length from its mesh to calculate proper offset
		# The barrel extends in X direction (longest axis), not Z
		var barrel_length = 0.04  # Default fallback
		if barrel_mesh.mesh:
			var aabb = barrel_mesh.mesh.get_aabb()
			barrel_length = abs(aabb.size.x)  # Barrel extends in X direction
			Log.info("Barrel mesh AABB: " + str(aabb))
			Log.info("Barrel mesh length (X axis): " + str(barrel_length))

		# CRITICAL: Barrel extends in -X direction, need to rotate to correct orientation
		# The barrel mesh naturally extends in -X (AABB shows X is the long axis)
		# Y rotation: 0° (was -90°, added +90° as requested)
		barrel_mesh.rotation = Vector3(0, deg_to_rad(0), 0)
		Log.info("Applied Y=0° rotation to align barrel forward")

		# Position barrel at front center of turret
		# X=0 centers it, Z offset places it at front
		barrel_mesh.position = Vector3(0, 0, 0)
		Log.info("Barrel mesh NEW position: " + str(barrel_mesh.position))
		Log.info("=================================")

	# Get or create barrel tip - AUTO-CALCULATED from mesh
	var barrel = player.get_node_or_null("PlayerTank/Turret/BarrelPivot/TankGunBarrel")
	if not barrel:
		barrel = player.get_node_or_null("PlayerTank/Turret/TankGunBarrel")
	
	if barrel:
		# Find the barrel mesh to measure its actual length
		var barrel_mesh_instance: MeshInstance3D = null
		if barrel is MeshInstance3D:
			barrel_mesh_instance = barrel
		else:
			for child in barrel.get_children():
				if child is MeshInstance3D:
					barrel_mesh_instance = child
					break
		
		var barrel_tip_z: float = -2.0  # Default fallback
		
		if barrel_mesh_instance and barrel_mesh_instance.mesh:
			# Get mesh bounding box in local space
			var mesh_aabb = barrel_mesh_instance.mesh.get_aabb()
			
			# Account for mesh instance's local transform if it's a child
			var mesh_local_pos = Vector3.ZERO
			if barrel_mesh_instance != barrel:
				mesh_local_pos = barrel_mesh_instance.position
			
			# Calculate tip position: mesh position + mesh extent in -Z direction
			barrel_tip_z = mesh_local_pos.z + mesh_aabb.position.z - mesh_aabb.size.z / 2.0
			
			Log.info("=== AUTO BARREL TIP CALCULATION ===")
			Log.info("Barrel node: " + barrel.name)
			Log.info("Barrel mesh found: " + barrel_mesh_instance.name)
			Log.info("Barrel mesh AABB: " + str(mesh_aabb))
			Log.info("Barrel mesh size: " + str(mesh_aabb.size))
			Log.info("Barrel mesh local position: " + str(mesh_local_pos))
			Log.info("Calculated barrel tip Z: " + str(barrel_tip_z))
			Log.info("===================================")
		else:
			Log.warning("No barrel mesh found - using default tip position")
		
		# Get or create BarrelTip node
		if barrel.has_node("BarrelTip"):
			barrel_tip = barrel.get_node("BarrelTip")
			Log.info("Found existing BarrelTip - repositioning")
		else:
			barrel_tip = Node3D.new()
			barrel_tip.name = "BarrelTip"
			barrel.add_child(barrel_tip)
			Log.info("Created new BarrelTip")
		
		# Position at calculated tip
		barrel_tip.position = Vector3(0, 0, barrel_tip_z)
		Log.info("BarrelTip positioned at: " + str(barrel_tip.position))
	else:
		Log.error("Could not find barrel node!")
	
	# Load config
	movement_speed = GameConfig.speed
	gravity = GameConfig.gravity
	hull_turn_speed = GameConfig.hull_turn_speed
	mouse_sensitivity = GameConfig.mouse_sensitivity
	
	var config = ConfigFile.new()
	config.load("res://game_config.cfg")
	var fire_cooldown_ms = config.get_value("tank", "fire_cooldown_ms", 500)
	fire_rate = 1000.0 / fire_cooldown_ms  # Convert ms to shots per second
	projectile_speed = config.get_value("tank", "projectile_speed", 50.0)
	barrel_pitch_min = config.get_value("tank", "barrel_pitch_min", -10.0)
	barrel_pitch_max = config.get_value("tank", "barrel_pitch_max", 70.0)
	
	# Ensure player doesn't collide with its own projectiles
	player.collision_layer = 1  # Player on layer 1
	player.collision_mask = 1   # Player only collides with layer 1

	# Camera setup - use scene file values, just activate it
	Log.info("=== BEFORE camera.make_current() ===")
	Log.info("Camera position BEFORE make_current: " + str(camera.position))
	Log.info("Camera rotation BEFORE make_current: " + str(camera.rotation_degrees))

	camera.make_current()

	Log.info("=== AFTER camera.make_current() ===")
	Log.info("Camera position AFTER make_current: " + str(camera.position))
	Log.info("Camera rotation AFTER make_current: " + str(camera.rotation_degrees))

	Log.info("Camera activated - position: " + str(camera.position) + ", FOV: " + str(camera.fov))

	# Initialize camera_pitch from scene file camera rotation (preserve scene setup)
	camera_pitch = camera.rotation_degrees.x
	Log.info("Initial camera pitch from scene: " + str(camera_pitch))

	# Initialize turret_yaw from scene file turret rotation (preserve scene setup)
	turret_yaw = turret.rotation.y
	Log.info("Initial turret yaw from scene: " + str(rad_to_deg(turret_yaw)) + " degrees")

	# === DETAILED CAMERA DEBUGGING ===
	Log.info("=== CAMERA POSITIONING DEBUG ===")
	Log.info("Player global position: " + str(player.global_position))
	Log.info("Camera global position: " + str(camera.global_position))
	Log.info("Camera global rotation (degrees): " + str(camera.global_rotation_degrees))
	Log.info("Camera local rotation (degrees): " + str(camera.rotation_degrees))
	Log.info("Camera forward direction: " + str(-camera.global_transform.basis.z))

	# Find red cube and log its position
	var red_cube = player.get_tree().get_root().find_child("RedBox", true, false)
	if red_cube:
		Log.info("Red cube global position: " + str(red_cube.global_position))
		var distance = camera.global_position.distance_to(red_cube.global_position)
		Log.info("Distance from camera to red cube: " + str(distance))
		var direction_to_cube = (red_cube.global_position - camera.global_position).normalized()
		Log.info("Direction from camera to red cube: " + str(direction_to_cube))
	else:
		Log.warning("Red cube not found in scene!")

	# Check tank mesh visibility and positions
	Log.info("=== TANK MESH DEBUG ===")

	# Check parent visibility chain
	Log.info("Player visible: " + str(player.visible))
	var player_tank = player.get_node_or_null("PlayerTank")
	if player_tank:
		Log.info("PlayerTank visible: " + str(player_tank.visible))

	Log.info("TankHull visible: " + str(tank_hull.visible))
	Log.info("TankHull global position: " + str(tank_hull.global_position))
	Log.info("TankHull scale: " + str(tank_hull.scale))
	Log.info("TankHull layers: " + str(tank_hull.layers if tank_hull is VisualInstance3D else "N/A"))

	var hull_armature = tank_hull.get_node_or_null("TankArmature")
	if hull_armature:
		Log.info("TankArmature found, visible: " + str(hull_armature.visible))
		Log.info("TankArmature global position: " + str(hull_armature.global_position))
		Log.info("TankArmature scale: " + str(hull_armature.scale))

		# Check skeleton and its child meshes
		var skeleton = hull_armature.get_node_or_null("Skeleton3D")
		if skeleton:
			Log.info("Skeleton3D found, children count: " + str(skeleton.get_child_count()))
			for child in skeleton.get_children():
				if child is MeshInstance3D:
					Log.info("  Skeletal mesh: " + child.name + ", visible: " + str(child.visible))
					Log.info("    Layers: " + str(child.layers))
					if child.mesh:
						Log.info("    Surface count: " + str(child.mesh.get_surface_count()))
						for i in range(min(child.mesh.get_surface_count(), 2)):  # Only first 2 for brevity
							var mat = child.get_surface_override_material(i)
							if not mat:
								mat = child.mesh.surface_get_material(i)
							Log.info("      Surface " + str(i) + " material: " + str(mat))

	Log.info("Turret visible: " + str(turret.visible))
	Log.info("Turret global position: " + str(turret.global_position))
	Log.info("Turret scale: " + str(turret.scale))
	Log.info("Turret layers: " + str(turret.layers if turret is VisualInstance3D else "N/A"))

	var turret_mesh = turret.get_node_or_null("TurretMesh")
	if turret_mesh:
		Log.info("TurretMesh found, visible: " + str(turret_mesh.visible))
		Log.info("TurretMesh global position: " + str(turret_mesh.global_position))
		Log.info("TurretMesh layers: " + str(turret_mesh.layers))
		Log.info("TurretMesh has surface: " + str(turret_mesh.get_surface_override_material_count() if turret_mesh.mesh else "no mesh"))
		if turret_mesh.mesh:
			Log.info("TurretMesh surface count: " + str(turret_mesh.mesh.get_surface_count()))
			for i in range(turret_mesh.mesh.get_surface_count()):
				var mat = turret_mesh.get_surface_override_material(i)
				if not mat:
					mat = turret_mesh.mesh.surface_get_material(i)
				Log.info("  Surface " + str(i) + " material: " + str(mat))
				if mat is StandardMaterial3D:
					Log.info("    Albedo color: " + str(mat.albedo_color))
					Log.info("    Shading mode: " + str(mat.shading_mode))
					Log.info("    Transparency: " + str(mat.transparency))
					Log.info("    Cull mode: " + str(mat.cull_mode))

	# Camera rendering properties
	Log.info("=== CAMERA RENDERING DEBUG ===")
	Log.info("Camera cull_mask: " + str(camera.cull_mask))
	Log.info("Camera near: " + str(camera.near))
	Log.info("Camera far: " + str(camera.far))
	Log.info("Camera current: " + str(camera.current))

	Log.info("=== END CAMERA DEBUG ===")

	# Visuals
	player_mesh.hide()
	tank_hull.show()
	turret.show()  # Show turret node (includes all turret components and barrel)
	
	# Hide selection ring in tank mode
	var selection_ring = player.get_node_or_null("SelectionRing")
	if selection_ring:
		selection_ring.hide()
	
	# Create simple crosshair (deferred)
	call_deferred("_create_crosshair")
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
	Log.info("TankController initialized")

func _create_crosshair() -> void:
	"""Create simple crosshair UI"""
	Log.info("Creating crosshair UI...")
	
	crosshair_ui = Control.new()
	crosshair_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_ui.z_index = 100  # Ensure it's on top
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_ui.add_child(center)
	
	var label = Label.new()
	label.text = "+"
	label.add_theme_font_size_override("font_size", 48)  # Bigger
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)  # Thicker outline
	center.add_child(label)
	
	# Add to scene
	get_tree().root.add_child(crosshair_ui)
	
	Log.info("Crosshair created and added to scene tree")
	Log.info("Crosshair visible: " + str(crosshair_ui.visible))
	Log.info("Crosshair z_index: " + str(crosshair_ui.z_index))

func handle_input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Mouse look - rotates turret and barrel
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Horizontal: rotate turret (Y axis)
		turret_yaw -= event.relative.x * mouse_sensitivity
		turret.rotation.y = turret_yaw
		
		# Vertical: pitch barrel AND camera together
		var pitch_delta = -event.relative.y * mouse_sensitivity

		# Update barrel pitch
		var old_pitch = barrel_pitch
		barrel_pitch += pitch_delta
		barrel_pitch = clamp(barrel_pitch, deg_to_rad(barrel_pitch_min), deg_to_rad(barrel_pitch_max))

		# DEBUG: Log barrel rotation changes
		if abs(pitch_delta) > 0.0001:  # Only log when actually moving mouse
			Log.info("=== BARREL ROTATION DEBUG ===")
			Log.info("Mouse delta Y: " + str(event.relative.y))
			Log.info("Pitch delta: " + str(pitch_delta))
			Log.info("Old barrel_pitch: " + str(rad_to_deg(old_pitch)) + "°")
			Log.info("New barrel_pitch: " + str(rad_to_deg(barrel_pitch)) + "°")
			Log.info("barrel_pivot valid: " + str(barrel_pivot != null))
			if barrel_pivot:
				Log.info("barrel_pivot.rotation.z BEFORE: " + str(rad_to_deg(barrel_pivot.rotation.z)) + "°")

		if barrel_pivot:
			# Rotate around Z axis because barrel extends in -X direction
			# Rotating around Z makes tip move in Y direction (up/down)
			# Negate to match mouse direction (up = up, down = down)
			barrel_pivot.rotation.z = -barrel_pitch

			# DEBUG: Verify rotation was applied
			if abs(pitch_delta) > 0.0001:
				Log.info("barrel_pivot.rotation.z AFTER: " + str(rad_to_deg(barrel_pivot.rotation.z)) + "°")
				Log.info("============================")
		else:
			Log.error("barrel_pivot is NULL - cannot rotate barrel!")
		
		# Camera follows barrel pitch (but with different limits)
		camera_pitch = rad_to_deg(barrel_pitch)
		camera_pitch = clamp(camera_pitch, -15.0, 60.0)  # Camera doesn't look as extreme
		camera.rotation_degrees.x = camera_pitch
	
	# Shooting - DISABLED (ShootingComponent handles all shooting now)
	# if event is InputEventMouseButton:
	# 	Log.info("Mouse button event: " + str(event.button_index) + " pressed: " + str(event.pressed))
	# 	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
	# 		Log.info("Left click detected, calling shoot")
	# 		_shoot_projectile()
	
	# Release mouse on ESC
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func handle_physics(delta: float) -> void:
	if not is_active:
		return

	# Gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

	# Input
	var forward_input: float = Input.get_action_strength("forward") - Input.get_action_strength("backward")
	var turn_input: float = Input.get_action_strength("right") - Input.get_action_strength("left")

	# Store current Y rotation (for steering)
	var current_y_rotation: float = player.rotation.y

	# Hull rotation (A/D keys) - negate to fix reversed controls
	player.rotate_y(-turn_input * hull_turn_speed * delta)
	current_y_rotation = player.rotation.y  # Update after rotation

	# Terrain following - align tank with ground slope (only when on ground)
	if terrain_follow_enabled and player.is_on_floor():
		_apply_terrain_rotation(delta, current_y_rotation)
	elif terrain_follow_enabled:
		# Level out tank when airborne
		var level_rotation := Vector3(0, current_y_rotation, 0)
		player.rotation = player.rotation.lerp(level_rotation, 5.0 * delta)

	# Movement (W/S keys) - always relative to hull direction
	var move_direction: Vector3 = -player.transform.basis.z * forward_input

	player.velocity.x = move_direction.x * movement_speed
	player.velocity.z = move_direction.z * movement_speed

	player.move_and_slide()

func _apply_terrain_rotation(delta: float, preserve_y_rotation: float) -> void:
	"""Rotate tank to match terrain angle using raycasts"""

	# Get tank's current position and rotation
	var tank_pos: Vector3 = player.global_position
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state

	# Define 4 corner points around the tank (in local space)
	var corners: Array[Vector3] = [
		Vector3(raycast_offset, 0, raycast_offset),   # Front-right
		Vector3(-raycast_offset, 0, raycast_offset),  # Front-left
		Vector3(raycast_offset, 0, -raycast_offset),  # Back-right
		Vector3(-raycast_offset, 0, -raycast_offset)  # Back-left
	]

	# Transform corners to world space and perform raycasts
	var hit_points: Array[Vector3] = []
	var hit_normals: Array[Vector3] = []

	for corner_local in corners:
		# Transform corner to world space
		var corner_world: Vector3 = player.global_transform * corner_local

		# Raycast downward from this corner
		var ray_start: Vector3 = corner_world + Vector3(0, 0.5, 0)  # Start slightly above
		var ray_end: Vector3 = corner_world - Vector3(0, terrain_raycast_length, 0)

		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [player]  # Don't hit ourselves
		query.collision_mask = 1  # Only hit world geometry (layer 1)

		var result: Dictionary = space_state.intersect_ray(query)

		if result:
			hit_points.append(result.position)
			hit_normals.append(result.normal)

	# Need at least 3 hits to calculate a plane
	if hit_points.size() >= 3:
		# Calculate average normal from all hits
		var avg_normal := Vector3.ZERO
		for normal in hit_normals:
			avg_normal += normal
		avg_normal = avg_normal.normalized()

		# Calculate target rotation to align with terrain
		# We want the tank's up vector to point along avg_normal
		var target_basis: Basis = Basis()
		target_basis.y = avg_normal
		target_basis.x = -target_basis.y.cross(Vector3.FORWARD).normalized()
		target_basis.z = target_basis.x.cross(target_basis.y).normalized()

		# Extract rotation while preserving Y rotation (steering)
		var target_rotation: Vector3 = target_basis.get_euler()
		target_rotation.y = preserve_y_rotation  # Keep steering angle

		# Smoothly interpolate current rotation to target rotation
		var current_rotation: Vector3 = player.rotation
		current_rotation.y = preserve_y_rotation  # Ensure Y is preserved

		var new_rotation: Vector3 = current_rotation.lerp(target_rotation, terrain_rotation_speed * delta)
		new_rotation.y = preserve_y_rotation  # Force Y to preserved value

		player.rotation = new_rotation

# OLD SHOOTING SYSTEM - REMOVED
# ShootingComponent now handles all shooting for tank mode
# The old system had a bug where projectiles wouldn't explode (velocity check prevented destruction)

func _calculate_movement_direction() -> Vector3:
	return Vector3.ZERO

func cleanup() -> void:
	"""Cleanup"""
	is_active = false
	
	if crosshair_ui and is_instance_valid(crosshair_ui):
		crosshair_ui.queue_free()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	Log.info("TankController cleaned up")
