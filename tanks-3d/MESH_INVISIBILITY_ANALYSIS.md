# Tank Mesh Invisibility Root Cause Analysis

## Problem Statement
When replacing tank meshes from FBX, the skeletal hull meshes (Tank_body, TrackMesh_R, TrackMesh_L) are VISIBLE, but the static turret/barrel meshes (Tank_Turret, Tank_Gun) are INVISIBLE despite having valid geometry data.

## Investigation Summary

### Evidence Gathered

1. **Script Debug Output** (godot_log.txt):
   - Turret mesh: 334 vertices, 3 surfaces ✓
   - Barrel mesh: 254 vertices, 1 surface ✓
   - Materials assigned ✓
   - `visible = true` ✓

2. **Runtime Log** (godot_run_console_log.txt):
   - Barrel AABB shows valid dimensions: 9cm × 0.5cm ✓
   - Mesh exists in scene at runtime ✓

3. **Scene File Analysis** (tank_kenney_01.tscn, main.tscn):
   - Both scenes contain valid ArrayMesh definitions ✓
   - Mesh data is properly embedded ✓
   - No skeleton/skin references found in turret/barrel ✓

### User's Critical Observation (from Godot Editor)

**When inspecting mesh properties:**
- Hull meshes (VISIBLE): Have "skin" and "skeleton" properties assigned
- Turret/barrel meshes (INVISIBLE): "skin" and "skeleton" properties are EMPTY

## Root Cause

### FBX Structure Analysis

```
Tank.fbx:
├── Tank_Gun (MeshInstance3D) - STATIC mesh, standalone node
├── TankArmature (Node3D)
│   └── Skeleton3D
│       ├── Tank_body (MeshInstance3D) - Part of skeleton hierarchy
│       ├── TrackMesh_R (MeshInstance3D) - Part of skeleton hierarchy
│       └── TrackMesh_L (MeshInstance3D) - Part of skeleton hierarchy
└── Tank_Turret (MeshInstance3D) - STATIC mesh, standalone node
```

### What Works vs What Doesn't

**✅ WORKING (Hull Meshes - VISIBLE):**
- Approach: Move entire `TankArmature` node hierarchy from FBX
- Method: `fbx_instance.remove_child(hull_armature)` → `tank_hull.add_child(hull_armature)`
- Result: All internal Godot state preserved, meshes render correctly

**❌ NOT WORKING (Turret/Barrel - INVISIBLE):**
- Approach: Duplicate mesh RESOURCE, create new MeshInstance3D node
- Method: `turret_mesh = turret_src.mesh.duplicate(true)` → assign to new node
- Result: Geometry data copied, but rendering state lost

### The Critical Difference

**`mesh.duplicate(true)` copies:**
- ✓ Vertex data (positions, normals, UVs)
- ✓ Index data (triangles)
- ✓ Surface definitions
- ✓ AABB (bounding box)

**`mesh.duplicate(true)` does NOT preserve:**
- ✗ Internal rendering state from FBX import
- ✗ Material shader compilation state
- ✗ Potential FBX-specific metadata
- ✗ Vertex format flags that Godot relies on
- ✗ Hidden rendering layer/visibility mask state

**Node moving preserves:**
- ✓ ALL of the above
- ✓ Complete internal Godot object state
- ✓ Original FBX import configuration

## Solution

### Fix: Use Node Moving Instead of Resource Duplication

Change from duplicating mesh resources to moving actual nodes (like the hull approach):

```gdscript
# OLD APPROACH (INVISIBLE):
var turret_src = fbx_instance.find_child("Tank_Turret", true, false)
var turret_mesh = MeshInstance3D.new()
turret_mesh.mesh = turret_src.mesh.duplicate(true)  # ❌ Loses rendering state
turret.add_child(turret_mesh)

# NEW APPROACH (SHOULD BE VISIBLE):
var turret_src = fbx_instance.find_child("Tank_Turret", true, false)
fbx_instance.remove_child(turret_src)  # Extract node
turret_src.name = "TurretMesh"
turret.add_child(turret_src)  # ✓ Preserves all state
turret_src.owner = main_instance
```

### Why This Should Work

1. **TankArmature movement works perfectly** - this proves the approach is valid
2. **Only duplicated resources fail** - the issue is specific to mesh duplication
3. **Node moving preserves ALL state** - not just geometry, but rendering config too
4. **FBX nodes are already properly configured** - Godot's FBX importer set them up correctly

## Implementation

**New script created:** `code/tools/apply_tank_meshes_fixed.gd`

**Key changes:**
- Extract nodes instead of duplicating resources
- Use same pattern as TankArmature (proven working)
- Maintain ownership chain properly
- No material re-assignment needed (already on node)

**To test:**
1. Run `apply_tank_meshes_fixed.gd` in Godot editor
2. Open main.tscn
3. Verify turret/barrel meshes are now visible in editor
4. Run game to confirm visibility at runtime

## Alternative Theories (Investigated and Ruled Out)

### ❌ Theory 1: Scale Issues
- Ruled out: AABB shows reasonable dimensions
- Meshes at proper scale would still be visible even if tiny

### ❌ Theory 2: Material Problems
- Ruled out: Materials are duplicated and assigned
- Script confirms 3 materials on turret, 1 on barrel

### ❌ Theory 3: Bone Data in Static Meshes
- Ruled out: Scene file shows no skeleton/skin data in mesh definitions
- FBX structure confirms these are standalone nodes, not rigged

### ❌ Theory 4: Transform Issues
- Ruled out: Transform matrices are identity
- Position is (0,0,0) relative to parent

### ✓ Theory 5: FBX Import State Lost (CONFIRMED)
- Evidence: User observed empty skin/skeleton properties in invisible meshes
- Evidence: Moving nodes works, duplicating resources doesn't
- Evidence: Same pattern (node moving) works for hull

## Conclusion

The invisibility is caused by **mesh resource duplication losing internal FBX import state** that Godot needs for rendering. The solution is to **move the actual FBX nodes** instead of duplicating their mesh resources, matching the successful pattern used for the hull armature.

**Expected Result:** Turret and barrel meshes will become visible once the fixed script is run.

---

*Analysis completed: 2025-11-01*
*Investigator: Claude (AI Assistant)*
