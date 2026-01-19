@tool
extends EditorScript

# ONE-TIME CLEANUP: Removes all tank mesh nodes to allow clean re-application
# Run this ONCE before running apply_tank_meshes_fixed.gd

func _run():
	print("=== Cleaning Up Tank Mesh Duplicates ===")

	# Load main scene
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
	if not tank_hull or not turret:
		print("ERROR: TankHull or Turret missing under PlayerTank")
		main_instance.queue_free()
		return

	var barrel_pivot = turret.get_node_or_null("BarrelPivot")
	if not barrel_pivot:
		print("ERROR: BarrelPivot missing")
		main_instance.queue_free()
		return

	print("✓ Found all required nodes (PlayerTank/TankHull, PlayerTank/Turret)")

	# Clear ALL children from TankHull
	print("\nClearing TankHull children...")
	var hull_children_count = 0
	for child in tank_hull.get_children():
		print("  Removing: " + child.name)
		tank_hull.remove_child(child)
		child.queue_free()
		hull_children_count += 1
	print("  Removed " + str(hull_children_count) + " nodes from TankHull")

	# Clear mesh children from Turret (keep SpringArm3D and BarrelPivot)
	print("\nClearing Turret mesh children...")
	var turret_children_count = 0
	for child in turret.get_children():
		if child.name != "SpringArm3D" and child.name != "BarrelPivot":
			print("  Removing: " + child.name)
			turret.remove_child(child)
			child.queue_free()
			turret_children_count += 1
	print("  Removed " + str(turret_children_count) + " mesh nodes from Turret")

	# Clear mesh children from BarrelPivot (keep BarrelTip if exists)
	print("\nClearing BarrelPivot mesh children...")
	var barrel_children_count = 0
	for child in barrel_pivot.get_children():
		if child.name != "BarrelTip":
			print("  Removing: " + child.name)
			barrel_pivot.remove_child(child)
			child.queue_free()
			barrel_children_count += 1
	print("  Removed " + str(barrel_children_count) + " mesh nodes from BarrelPivot")

	# Reset TankHull transforms to default
	tank_hull.rotation_degrees = Vector3(0, 0, 0)
	tank_hull.scale = Vector3(1, 1, 1)
	print("\n✓ Reset TankHull transforms to default")

	# Save main.tscn
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

	print("\n=== CLEANUP COMPLETE ===")
	print("✓ All tank mesh nodes removed")
	print("✓ TankHull transforms reset")
	print("✓ main.tscn saved")
	print("\nNow run apply_tank_meshes_fixed.gd to apply the meshes cleanly")
