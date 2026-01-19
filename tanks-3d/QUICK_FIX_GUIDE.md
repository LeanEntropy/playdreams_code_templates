# Quick Fix Guide: Tank Mesh Invisibility

## TL;DR

**Problem:** Turret and barrel meshes are invisible
**Cause:** Duplicating mesh resources loses FBX import state
**Fix:** Move FBX nodes instead of duplicating resources

## How to Apply the Fix

1. Open Godot editor
2. Navigate to `code/tools/apply_tank_meshes_fixed.gd`
3. Click "Run" in the script editor (or File → Run)
4. Wait for "SUCCESS" message
5. Open `main.tscn` in editor to verify meshes are visible
6. Run the game - turret/barrel should now render

## What Changed

### Before (Resource Duplication - BROKEN):
```gdscript
var turret_src = fbx.find_child("Tank_Turret")
var new_mesh = MeshInstance3D.new()
new_mesh.mesh = turret_src.mesh.duplicate(true)  # ❌ Loses state
```

### After (Node Moving - FIXED):
```gdscript
var turret_src = fbx.find_child("Tank_Turret")
fbx.remove_child(turret_src)
turret.add_child(turret_src)  # ✓ Preserves state
turret_src.owner = main_instance
```

## Why This Works

- **Hull meshes:** Already use node moving → VISIBLE ✓
- **Turret/barrel:** Were using resource duplication → INVISIBLE ✗
- **Fix:** Use same approach for all meshes → ALL VISIBLE ✓

## Files Changed

- **New:** `code/tools/apply_tank_meshes_fixed.gd` (fixed script)
- **Modified:** `main.tscn` (after running script)
- **Reference:** `MESH_INVISIBILITY_ANALYSIS.md` (detailed analysis)

## Verification Checklist

After running the fixed script:

- [ ] Console shows "✓ Turret mesh added"
- [ ] Console shows "✓ Barrel mesh added"  
- [ ] Console shows "SUCCESS"
- [ ] Open `main.tscn` in editor
- [ ] Select `Player/Turret/TurretMesh` - mesh should be visible in viewport
- [ ] Select `Player/Turret/BarrelPivot/TankGunBarrel` - mesh should be visible
- [ ] Run game (F5) - tank should have complete model
- [ ] Turret rotates with mouse movement
- [ ] Barrel tilts up/down correctly

## If It Still Doesn't Work

1. Check console for error messages
2. Verify FBX file exists: `assets/3d_models/tanks/Tank.fbx`
3. Try reimporting the FBX (right-click → Reimport)
4. Check if Tank_Turret and Tank_Gun exist in FBX preview
5. Review full analysis in `MESH_INVISIBILITY_ANALYSIS.md`

## Technical Details

See `MESH_INVISIBILITY_ANALYSIS.md` for complete root cause analysis.

**Key insight:** Godot's `ArrayMesh.duplicate(true)` copies geometry data but not internal rendering state from FBX import. Moving the original nodes preserves everything.

---

**Status:** Ready to test
**Expected outcome:** All tank meshes visible
