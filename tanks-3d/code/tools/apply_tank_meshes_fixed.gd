@tool
extends EditorScript

# Implementation following MESH_INVISIBILITY_ANALYSIS.md conclusions
# Key principle: MOVE nodes from FBX, don't duplicate mesh resources
# IDEMPOTENT: Safe to run multiple times without creating duplicates

func _run():
	print("=== Tank Mesh Replacement (Node Moving Approach) ===")

	# Step 1: Load main scene first to check if already done
	var main_scene = load("res://main.tscn")
	if not main_scene:
		print("ERROR: Failed to load main.tscn")
		return

	var main_instance = main_scene.instantiate()
	var player = main_instance.get_node_or_null("Player")
	if not player:
		print("ERROR: Player node not found")
		main_instance.queue_free()
		return

	# Find PlayerTank container
	var player_tank = player.get_node_or_null("PlayerTank")
	if not player_tank:
		print("ERROR: PlayerTank node not found under Player")
		main_instance.queue_free()
		return

	# Find tank components under PlayerTank
	var tank_hull = player_tank.get_node_or_null("TankHull")
	var turret = player_tank.get_node_or_null("Turret")
	var barrel_pivot = turret.get_node_or_null("BarrelPivot") if turret else null

	if not tank_hull or not turret or not barrel_pivot:
		print("ERROR: Required nodes missing (TankHull, Turret, or BarrelPivot)")
		main_instance.queue_free()
		return

	print("✓ Found all required nodes (PlayerTank/TankHull, PlayerTank/Turret, BarrelPivot)")

	# IDEMPOTENCY CHECK: If meshes already applied, exit
	if tank_hull.has_node("TankArmature") and turret.has_node("TurretMesh") and barrel_pivot.has_node("TankGunBarrel"):
		print("✓ Tank meshes already applied - skipping")
		main_instance.queue_free()
		return

	print("Tank meshes not found or incomplete - proceeding with replacement...")

	# Step 2: Load and instantiate FBX
	var fbx_scene = load("res://assets/3d_models/tanks/Tank.fbx")
	if not fbx_scene:
		print("ERROR: Failed to load FBX")
		main_instance.queue_free()
		return

	var fbx_instance = fbx_scene.instantiate()
	print("✓ FBX loaded and instantiated")

	# Step 3: Clear existing hull children before adding new ones
	print("Clearing existing TankHull children...")
	for child in tank_hull.get_children():
		print("  Removing: " + child.name)
		tank_hull.remove_child(child)
		child.queue_free()

	# Step 4: Extract TankArmature (PROVEN WORKING METHOD)
	var hull_armature = fbx_instance.find_child("TankArmature", true, false)
	if hull_armature:
		print("Extracting TankArmature...")
		# Reset ownership before moving
		_reset_owner_recursive(hull_armature)
		# Remove from FBX, add to TankHull
		fbx_instance.remove_child(hull_armature)
		tank_hull.add_child(hull_armature)
		hull_armature.owner = main_instance
		_set_owner_recursive(hull_armature, main_instance)

		# Set mesh node scale and position
		hull_armature.scale = Vector3(1, 1, 1)
		hull_armature.position = Vector3(0, 0, 0)

		# Center skeleton Root bone for proper tank positioning
		var skeleton = hull_armature.find_child("Skeleton3D", false, false)
		if skeleton and skeleton is Skeleton3D:
			var root_bone_idx = skeleton.find_bone("Root")
			if root_bone_idx != -1:
				# Get current bone pose
				var bone_pose = skeleton.get_bone_pose_position(root_bone_idx)
				print("Original Root bone position: " + str(bone_pose))

				# Set Root bone to centered position for this tank model
				skeleton.set_bone_pose_position(root_bone_idx, Vector3(0, 0, -0.025))
				print("✓ Adjusted Root bone position to (0, 0, -0.025)")
			else:
				print("WARNING: Root bone not found in skeleton")
		else:
			print("WARNING: Skeleton3D not found in TankArmature")

		# Apply transforms to TankHull parent (centered at origin)
		tank_hull.rotation_degrees = Vector3(0, -90, 0)
		tank_hull.scale = Vector3(25, 25, 25)
		tank_hull.position = Vector3(0, 0, 0)
		print("✓ Hull armature extracted and added (scale: 1, position: 0,0,0, parent scale: 25)")
	else:
		print("ERROR: TankArmature not found")
		main_instance.queue_free()
		fbx_instance.queue_free()
		return

	# Step 5: Clear existing turret mesh children (keep SpringArm3D and BarrelPivot)
	print("Clearing existing Turret mesh children...")
	for child in turret.get_children():
		if child.name != "SpringArm3D" and child.name != "BarrelPivot":
			print("  Removing: " + child.name)
			turret.remove_child(child)
			child.queue_free()

	# Step 6: Extract Tank_Turret NODE (SAME METHOD AS HULL)
	var turret_node = fbx_instance.find_child("Tank_Turret", true, false)
	if turret_node:
		print("Extracting Tank_Turret node...")
		# Reset ownership before moving
		_reset_owner_recursive(turret_node)
		# Remove from FBX, add to Turret parent
		fbx_instance.remove_child(turret_node)
		turret_node.name = "TurretMesh"
		turret.add_child(turret_node)
		turret_node.owner = main_instance
		_set_owner_recursive(turret_node, main_instance)

		# Set mesh node scale to 1
		turret_node.scale = Vector3(1, 1, 1)

		# Calculate correct position for turret mesh
		# Turret should be centered and at origin (0,0,0) in local space
		turret_node.position = Vector3(0, 0, 0)

		# Set Turret parent scale
		turret.scale = Vector3(25, 25, 25)

		# Log mesh information for debugging
		if turret_node.mesh:
			var aabb = turret_node.mesh.get_aabb()
			print("  Turret mesh AABB: ", aabb)
			print("  Turret mesh size: ", aabb.size)

		print("✓ Turret node extracted and added (scale: 1, parent scale: 25, position: 0,0,0)")
		print("  Has mesh: ", turret_node.mesh != null)
		print("  Has skin: ", turret_node.skin != null if turret_node.has_method("skin") else "N/A")
	else:
		print("WARNING: Tank_Turret not found in FBX")

	# Step 7: Clear existing barrel mesh children (keep BarrelTip if exists)
	print("Clearing existing BarrelPivot mesh children...")
	for child in barrel_pivot.get_children():
		if child.name != "BarrelTip":
			print("  Removing: " + child.name)
			barrel_pivot.remove_child(child)
			child.queue_free()

	# Step 8: Extract Tank_Gun NODE (SAME METHOD AS HULL)
	var barrel_node = fbx_instance.find_child("Tank_Gun", true, false)
	if barrel_node:
		print("Extracting Tank_Gun node...")
		# Reset ownership before moving
		_reset_owner_recursive(barrel_node)
		# Remove from FBX, add to BarrelPivot parent
		fbx_instance.remove_child(barrel_node)
		barrel_node.name = "TankGunBarrel"
		barrel_pivot.add_child(barrel_node)
		barrel_node.owner = main_instance
		_set_owner_recursive(barrel_node, main_instance)

		# Set mesh node scale to 1
		barrel_node.scale = Vector3(1, 1, 1)

		# Calculate correct position for barrel mesh
		# Barrel should be centered and at origin (0,0,0) in local space
		barrel_node.position = Vector3(0, 0, 0)

		# Set BarrelPivot parent scale to 1 (all axes)
		barrel_pivot.scale = Vector3(1, 1, 1)

		# Log mesh information for debugging
		if barrel_node.mesh:
			var aabb = barrel_node.mesh.get_aabb()
			print("  Barrel mesh AABB: ", aabb)
			print("  Barrel mesh size: ", aabb.size)

		print("✓ Barrel node extracted and added (scale: 1, parent scale: 1, position: 0,0,0)")
		print("  Has mesh: ", barrel_node.mesh != null)
		print("  Has skin: ", barrel_node.skin != null if barrel_node.has_method("skin") else "N/A")
	else:
		print("WARNING: Tank_Gun not found in FBX")

	# Clean up FBX instance
	fbx_instance.queue_free()

	# Step 9: Save main.tscn
	print("\nSaving main.tscn...")
	var packed = PackedScene.new()
	var pack_result = packed.pack(main_instance)
	if pack_result != OK:
		print("ERROR: Failed to pack scene: ", pack_result)
		main_instance.queue_free()
		return

	var save_result = ResourceSaver.save(packed, "res://main.tscn")
	if save_result != OK:
		print("ERROR: Failed to save scene: ", save_result)
		main_instance.queue_free()
		return

	main_instance.queue_free()

	print("\n=== SUCCESS ===")
	print("✓ All nodes extracted using node-moving approach")
	print("✓ main.tscn saved")
	print("\nRun the game - turret and barrel should be VISIBLE")

func _set_owner_recursive(node: Node, new_owner: Node):
	for child in node.get_children():
		child.owner = new_owner
		_set_owner_recursive(child, new_owner)

func _reset_owner_recursive(node: Node):
	node.owner = null
	for child in node.get_children():
		_reset_owner_recursive(child)
