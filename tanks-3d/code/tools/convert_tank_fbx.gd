@tool
extends EditorScript

## Converts Quaternius tank FBX files into clean .tscn scenes ready for gameplay.
##
## Compatible with: Quaternius "Tank Pack June 2019" (CC0 license)
## Available at: https://quaternius.com
## The pack contains 4 tank variants (Tank.fbx through Tank4.fbx) with meshes:
##   Tank_body, Tank_Turret, Tank_Gun, TrackMesh.R, TrackMesh.L
##
## Usage:
##   1. Copy FBX files into res://assets/3d_models/tanks/
##   2. Let Godot import them (reopen project if needed)
##   3. Run this script: File > Run in the Godot editor
##   4. Output scenes appear in res://assets/vehicles/
##   5. Instance any output scene as "PlayerTank" under your Player node

# ============================================================
# Configuration
# ============================================================

const FBX_DIR: String = "res://assets/3d_models/tanks/"
const OUTPUT_DIR: String = "res://assets/vehicles/"
const SCALE_FACTOR: float = 25.0
const DEFAULT_TURRET_Y: float = 0.524
const CAMERA_FOV: float = 75.0

## Mesh name fallback lists — Tank4 uses "Tank_body.001" instead of "Tank_body"
const HULL_BODY_NAMES := ["Tank_body", "Tank_body.001", "Tank_Body"]
const TRACK_R_NAMES := ["TrackMesh.R", "TrackMesh_R"]
const TRACK_L_NAMES := ["TrackMesh.L", "TrackMesh_L"]
const TURRET_MESH_NAME: String = "Tank_Turret"
const BARREL_MESH_NAME: String = "Tank_Gun"

# ============================================================
# Entry point
# ============================================================

func _run() -> void:
	print("=== Quaternius Tank FBX Converter ===")
	_ensure_output_dir()

	var fbx_files: PackedStringArray = _scan_fbx_files()
	if fbx_files.is_empty():
		print("No .fbx files found in %s" % FBX_DIR)
		return

	var success_count: int = 0
	for fbx_file in fbx_files:
		var fbx_path: String = FBX_DIR + fbx_file
		var output_name: String = fbx_file.get_basename().to_lower() + ".tscn"
		var output_path: String = OUTPUT_DIR + output_name

		print("\nConverting: %s -> %s" % [fbx_file, output_name])
		if _convert_single_fbx(fbx_path, output_path):
			success_count += 1

	print("\n=== Done: %d/%d converted ===" % [success_count, fbx_files.size()])


func _scan_fbx_files() -> PackedStringArray:
	var files: PackedStringArray = []
	var dir := DirAccess.open(FBX_DIR)
	if not dir:
		print("ERROR: Cannot open %s" % FBX_DIR)
		return files

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "fbx":
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files

# ============================================================
# Core conversion
# ============================================================

func _convert_single_fbx(fbx_path: String, output_path: String) -> bool:
	var fbx_scene: PackedScene = load(fbx_path) as PackedScene
	if not fbx_scene:
		print("  ERROR: Failed to load %s" % fbx_path)
		return false

	var fbx: Node = fbx_scene.instantiate()

	# Find required meshes
	var hull_node: MeshInstance3D = _find_mesh_by_names(fbx, HULL_BODY_NAMES)
	var turret_node: MeshInstance3D = _find_mesh(fbx, TURRET_MESH_NAME)
	var barrel_node: MeshInstance3D = _find_mesh(fbx, BARREL_MESH_NAME)
	var track_r_node: MeshInstance3D = _find_mesh_by_names(fbx, TRACK_R_NAMES)
	var track_l_node: MeshInstance3D = _find_mesh_by_names(fbx, TRACK_L_NAMES)

	if not hull_node or not hull_node.mesh:
		print("  ERROR: Hull body mesh not found")
		fbx.queue_free()
		return false
	if not turret_node or not turret_node.mesh:
		print("  ERROR: Turret mesh not found")
		fbx.queue_free()
		return false
	if not barrel_node or not barrel_node.mesh:
		print("  ERROR: Barrel mesh not found")
		fbx.queue_free()
		return false
	if not track_r_node:
		print("  WARNING: Right track mesh not found")
	if not track_l_node:
		print("  WARNING: Left track mesh not found")

	# Calculate turret height from hull mesh
	var turret_y: float = _calculate_turret_y_offset(hull_node.mesh)
	print("  Turret Y offset: %.4f" % turret_y)

	# Build clean scene tree
	var root: Node3D = _build_scene_tree(
		hull_node.mesh,
		track_r_node.mesh if track_r_node else null,
		track_l_node.mesh if track_l_node else null,
		track_r_node.position if track_r_node else Vector3.ZERO,
		track_l_node.position if track_l_node else Vector3.ZERO,
		turret_node.mesh,
		barrel_node.mesh,
		turret_y
	)

	# Pack and save
	var packed := PackedScene.new()
	var err: Error = packed.pack(root)
	if err != OK:
		print("  ERROR: Failed to pack scene (error %d)" % err)
		root.free()
		fbx.queue_free()
		return false

	err = ResourceSaver.save(packed, output_path)
	if err != OK:
		print("  ERROR: Failed to save %s (error %d)" % [output_path, err])
		root.free()
		fbx.queue_free()
		return false

	print("  SUCCESS: %s" % output_path)
	root.free()
	fbx.queue_free()
	return true

# ============================================================
# Scene tree construction
# ============================================================

func _build_scene_tree(
	hull_mesh: Mesh, track_r_mesh: Mesh, track_l_mesh: Mesh,
	track_r_pos: Vector3, track_l_pos: Vector3,
	turret_mesh: Mesh, barrel_mesh: Mesh, turret_y: float
) -> Node3D:

	var root := Node3D.new()
	root.name = "PlayerTank"

	# --- Hull ---
	var tank_hull := Node3D.new()
	tank_hull.name = "TankHull"
	tank_hull.rotation_degrees = Vector3(0, -90, 0)
	tank_hull.scale = Vector3(SCALE_FACTOR, SCALE_FACTOR, SCALE_FACTOR)
	root.add_child(tank_hull)
	tank_hull.owner = root

	# TankArmature provides the FBX -90 X coordinate conversion
	var armature := Node3D.new()
	armature.name = "TankArmature"
	armature.rotation_degrees = Vector3(-90, 0, 0)
	tank_hull.add_child(armature)
	armature.owner = root

	var body := MeshInstance3D.new()
	body.name = "Tank_body"
	body.mesh = hull_mesh
	armature.add_child(body)
	body.owner = root

	if track_r_mesh:
		var track_r := MeshInstance3D.new()
		track_r.name = "TrackMesh_R"
		track_r.mesh = track_r_mesh
		track_r.position = track_r_pos
		armature.add_child(track_r)
		track_r.owner = root

	if track_l_mesh:
		var track_l := MeshInstance3D.new()
		track_l.name = "TrackMesh_L"
		track_l.mesh = track_l_mesh
		track_l.position = track_l_pos
		armature.add_child(track_l)
		track_l.owner = root

	# --- Turret ---
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.rotation_degrees = Vector3(0, -90, 0)
	turret.scale = Vector3(SCALE_FACTOR, SCALE_FACTOR, SCALE_FACTOR)
	turret.position = Vector3(0, turret_y, 0)
	root.add_child(turret)
	turret.owner = root

	var cam: Camera3D = _create_tank_camera()
	turret.add_child(cam)
	cam.owner = root

	var barrel_pivot := Node3D.new()
	barrel_pivot.name = "BarrelPivot"
	turret.add_child(barrel_pivot)
	barrel_pivot.owner = root

	var gun_barrel := MeshInstance3D.new()
	gun_barrel.name = "TankGunBarrel"
	gun_barrel.mesh = barrel_mesh
	gun_barrel.rotation_degrees = Vector3(-90, 0, 0)
	barrel_pivot.add_child(gun_barrel)
	gun_barrel.owner = root

	var tip: Marker3D = _create_barrel_tip(barrel_mesh)
	gun_barrel.add_child(tip)
	tip.owner = root

	var turret_mesh_node := MeshInstance3D.new()
	turret_mesh_node.name = "TurretMesh"
	turret_mesh_node.mesh = turret_mesh
	turret_mesh_node.rotation_degrees = Vector3(-90, 0, 0)
	turret.add_child(turret_mesh_node)
	turret_mesh_node.owner = root

	return root

# ============================================================
# Helpers
# ============================================================

func _find_mesh_by_names(root: Node, names: Array) -> MeshInstance3D:
	for mesh_name in names:
		var node: Node = root.find_child(mesh_name, true, false)
		if node and node is MeshInstance3D:
			return node as MeshInstance3D
	return null


func _find_mesh(root: Node, mesh_name: String) -> MeshInstance3D:
	var node: Node = root.find_child(mesh_name, true, false)
	if node and node is MeshInstance3D:
		return node as MeshInstance3D
	return null


func _calculate_turret_y_offset(hull_mesh: Mesh) -> float:
	if not hull_mesh:
		return DEFAULT_TURRET_Y

	var aabb: AABB = hull_mesh.get_aabb()
	# After the rotation chain (TankHull -90Y, TankArmature -90X),
	# the mesh's local Z axis maps to world Y.
	# Turret sits at the hull's max Z (top surface) * scale.
	var hull_top_z: float = aabb.position.z + aabb.size.z
	var offset: float = (hull_top_z + 0.005) * SCALE_FACTOR
	if offset > 0.1:
		return offset
	return DEFAULT_TURRET_Y


func _create_tank_camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "TankCamera"
	cam.current = true
	cam.fov = CAMERA_FOV
	# Exact transform from the working tank_model.tscn.
	# Encodes: position behind/above turret, rotation looking forward,
	# and 1/25 scale to cancel the parent Turret's scale factor.
	cam.transform = Transform3D(
		-1.74846e-09, -0.0118283, 0.0382111,
		0, 0.0382111, 0.0118283,
		-0.04, 5.17034e-10, -1.67027e-09,
		0.160438, 0.0387447, 0.00258549
	)
	return cam


func _create_barrel_tip(barrel_mesh: Mesh) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = "BarrelTip"
	if barrel_mesh:
		var aabb: AABB = barrel_mesh.get_aabb()
		# Barrel tip is at the far end in -Z (forward in Godot convention)
		marker.position = Vector3(0, 0, aabb.position.z)
	else:
		marker.position = Vector3(0, 0, -0.1)
	return marker


func _ensure_output_dir() -> void:
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR.replace("res://", ProjectSettings.globalize_path("res://"))):
		var dir := DirAccess.open("res://assets/")
		if dir:
			dir.make_dir("vehicles")
			print("Created: %s" % OUTPUT_DIR)
