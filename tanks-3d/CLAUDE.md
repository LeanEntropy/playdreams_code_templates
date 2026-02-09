# Godot 4.5 3D Tank Template - AI Development Guide

## Project Overview

A clean, modular 3D tank combat template built in Godot 4.5. Single tank controller with 3 camera modes, component-based architecture, and satisfying shooting feedback. Targets web, mobile, and desktop.

**Architecture**: Tank controller (CharacterBody3D) + CameraRig component + ShootingComponent + ShootingFeedback. All config values use `@export` with `game_config.cfg` overrides.

---

## Architecture

### Component Layout

```
Player (CharacterBody3D, script: tank_controller.gd)
  +-- PlayerTank (Node3D)
  |     +-- TankHull (Node3D - rotates with WASD)
  |     |     +-- TankArmature (from FBX)
  |     +-- Turret (Node3D - rotates with mouse X)
  |           +-- TurretMesh
  |           +-- BarrelPivot (Node3D - pitches with mouse Y)
  |                 +-- TankGunBarrel (MeshInstance3D)
  |                       +-- BarrelTip (Node3D - projectile spawn point)
  +-- CameraRig (Node3D, script: camera_rig.gd)
  |     +-- ChaseCamera (Camera3D)
  |     +-- TopDownCamera (Camera3D)
  |     +-- FreeCamera (Camera3D)
  +-- ShootingComponent (Node, script: shooting_component.gd)
  +-- ShootingFeedback (Node, script: shooting_feedback.gd)
```

### CameraRig (`code/components/camera_rig.gd`)

Manages three camera modes. Owns mouse mode. Decoupled from tank movement.

```gdscript
enum CameraMode { CHASE, TOP_DOWN, FREE }

signal camera_mode_changed(new_mode: CameraMode)

# Public API
func switch_mode(mode: CameraMode) -> void    # Activates camera + sets mouse mode
func get_active_camera() -> Camera3D
func get_current_mode() -> CameraMode
func set_chase_yaw(yaw: float) -> void         # Called by tank controller
func apply_camera_kick(pitch_degrees: float)    # Called by shooting feedback
```

| Mode | Mouse Mode | Turret Aiming | Input |
|------|-----------|---------------|-------|
| CHASE | CAPTURED | Mouse delta -> turret yaw | Default tank controls |
| TOP_DOWN | VISIBLE | Mouse ground raycast -> turret faces cursor | Scroll to zoom |
| FREE | VISIBLE | Turret holds position | Right-drag to orbit, scroll to zoom |

Switch modes with **C key** (`switch_camera` input action).

### Tank Controller (`code/tank_controller.gd`)

Extends `CharacterBody3D` directly (not a separate Node). Uses `_ready()`, `_unhandled_input()`, `_physics_process()`.

Key game-feel features:
- **Acceleration/deceleration** via `move_toward()` (not instant velocity)
- **Turret rotation speed limit** via `move_toward()` (configurable, can be disabled)
- **Separate reverse speed** (slower than forward)
- **Terrain following** with 4-corner raycasts
- **Health stub** with `take_damage(amount)` and `health_changed` signal

### ShootingComponent (`code/components/shooting_component.gd`)

Single fire rate and projectile speed (no per-mode branching). Barrel detection inlined from old WeaponComponent. Timer-based cooldown. Camera-mode-aware aiming via CameraRig.

```gdscript
signal shot_fired
signal ammo_changed(current: int, max_ammo: int)

func get_muzzle_position() -> Vector3
func get_fire_direction() -> Vector3
func reload() -> void
```

### ShootingFeedback (`code/components/shooting_feedback.gd`)

Subscribes to `ShootingComponent.shot_fired`. Provides:
- **Camera kick**: Pitch up on fire, lerp back
- **Screen shake**: Random h/v offset on active camera
- **Muzzle flash**: OmniLight3D at barrel tip
- **Barrel recoil**: Push barrel pivot, spring back

All values config-driven via `[shooting]` section.

### AimingHelper (`code/components/aiming_helper.gd`)

Static utility class for raycasts:
- `get_screen_center_target(camera, max_distance, exclude)` - Center-screen raycast
- `get_mouse_ground_target(camera, mouse_pos, ground_y, exclude)` - Mouse-to-ground raycast
- `calculate_fire_direction(muzzle_pos, target_pos)` - Direction vector
- `has_clear_line_of_sight(from, to, world_3d, exclude)` - LOS check

### Singleton Autoloads
- **GameConfig** (`code/game_config.gd`): Minimal config accessor. `GameConfig.get_value(section, key, default)`
- **Log** (`code/logger.gd`): Static logging via `class_name`. `Log.info()`, `Log.warning()`, `Log.error()`

**Note**: `Log` is a `class_name`, NOT an autoload. Call static methods directly.

---

## Directory Structure

```
tanks-3d/
+-- code/
|     +-- tank_controller.gd          # Hull movement, turret, terrain following
|     +-- main.gd                     # Title screen flow, game start
|     +-- game_config.gd              # Minimal config accessor (autoload)
|     +-- logger.gd                   # Static logging utility (class_name Log)
|     +-- tank_projectile.gd          # Projectile with gravity + hit effects
|     +-- projectile_hit_effect.gd    # Impact particles
|     +-- components/
|     |     +-- camera_rig.gd         # Camera mode management (3 modes)
|     |     +-- shooting_component.gd # Barrel detection + firing
|     |     +-- shooting_feedback.gd  # Camera kick, shake, flash, recoil
|     |     +-- aiming_helper.gd      # Static raycast utilities
|     +-- UI/
|     |     +-- ui_layer.gd           # Pause menu, crosshair visibility
|     |     +-- title_screen.gd       # Title screen
|     +-- tools/
|           +-- apply_tank_meshes_fixed.gd   # FBX mesh extraction
|           +-- cleanup_tank_duplicates.gd   # Mesh cleanup
+-- assets/
|     +-- UI/                         # Crosshair, title screen, UI layer scenes
|     +-- vehicles/                   # Tank model scenes
|     +-- weapons/                    # debug_barrel.tscn (dev only)
|     +-- tank_projectile.tscn        # Projectile scene
|     +-- projectile_hit_effect.tscn  # Hit effect scene
|     +-- 3d_models/tanks/            # FBX source files
+-- main.tscn                         # Primary game scene
+-- game_config.cfg                   # Runtime configuration
+-- project.godot                     # Godot project file
```

---

## Configuration

All components use `@export` variables with `@export_group` for inspector visibility. Values can be overridden via `game_config.cfg` (loaded in each component's `_ready()`).

### game_config.cfg

```ini
[global]
capture_mouse_on_start=true

[tank]
camera_mode="chase"           # Default camera: "chase", "top_down", "free"
forward_speed=10.0
reverse_speed=4.0
hull_turn_speed=2.0
acceleration=4.0
deceleration=6.0
turret_speed_limited=true
turret_rotation_speed=3.0
mouse_sensitivity=0.003
barrel_pitch_min=-12.0
barrel_pitch_max=30.0
camera_follow_speed=12.0
topdown_camera_height=20.0
topdown_min_zoom=10.0
topdown_max_zoom=40.0
free_cam_distance=15.0
fov=75.0

[shooting]
fire_rate=2.0                 # Seconds between shots (cannon rhythm)
projectile_speed=55.0
projectile_gravity_scale=0.1
screen_shake_enabled=true
screen_shake_intensity=0.03
camera_kick_degrees=2.5
muzzle_flash_enabled=true
barrel_recoil_distance=0.1

[projectile]
mesh_radius=0.2
mesh_color="000000"
lifetime=8.0
damage=25
hit_effect_enabled=true

[ui]
show_crosshair=true
crosshair_size=4.0
crosshair_color="FFFFFF"

[title_screen]
show_title_screen=false

[controls]
pause_key_primary="P"
pause_key_secondary="Escape"
```

### Input Actions
- **WASD**: Tank movement and hull rotation
- **Mouse**: Turret rotation (chase mode) / cursor aiming (top-down mode)
- **Left click / shoot**: Fire projectile
- **C / switch_camera**: Cycle camera modes
- **P / Escape**: Pause
- **Gamepad**: Left stick = move, right stick = turret, RT = shoot, Y = switch camera

---

## Common Tasks

### Adjusting Tank Feel

Edit `game_config.cfg` `[tank]` section. Key values:
- `acceleration` / `deceleration`: Higher = snappier, lower = heavier feel
- `turret_rotation_speed`: Lower = more realistic turret lag
- `turret_speed_limited=false`: Instant turret snap (arcade mode)
- `forward_speed` / `reverse_speed`: Reverse should be ~40% of forward

### Adjusting Shooting Feel

Edit `game_config.cfg` `[shooting]` section:
- `fire_rate=2.0`: Cannon rhythm. Lower = faster firing
- `camera_kick_degrees=2.5`: Recoil punch. 0 = no kick
- `screen_shake_intensity=0.03`: Shake amplitude. 0 = no shake
- `barrel_recoil_distance=0.1`: Visual barrel kickback

### Adding a New Component

1. Create `code/components/my_component.gd`
2. Use `@export` for config, `_load_config_overrides()` for cfg file
3. Add as child of Player in `main.tscn`
4. Connect to existing signals (e.g., `shot_fired`, `health_changed`, `camera_mode_changed`)

### Replacing the Tank Model

1. Place FBX in `assets/3d_models/tanks/`
2. Configure constants in `code/tools/apply_tank_meshes_fixed.gd`
3. Run cleanup script, then apply script from Godot editor
4. See `.claude/skills/replace_vehicle_mesh.md` for full guide

---

## Technical Details

### Signal Flow

```
tank_controller.gd
  -> CameraRig.set_chase_yaw()     (every physics frame)
  -> health_changed signal          (on take_damage)

CameraRig
  -> camera_mode_changed signal     (on C key / switch_mode)
  -> Consumed by: ui_layer.gd (crosshair), tank_controller.gd (aiming mode)

ShootingComponent
  -> shot_fired signal              (on fire)
  -> ammo_changed signal            (on fire/reload)
  -> Consumed by: ShootingFeedback (kick/shake/flash/recoil)

ShootingFeedback
  -> CameraRig.apply_camera_kick()  (on shot_fired)
```

### Mouse Mode Ownership

CameraRig exclusively owns `Input.set_mouse_mode()`. On pause, `ui_layer.gd` sets VISIBLE; on unpause, it calls `CameraRig.switch_mode()` to restore the correct mode.

### Barrel Tip Detection

ShootingComponent finds barrel tip automatically:
1. Checks for existing `BarrelTip` node under `TankGunBarrel`
2. If missing, calculates from mesh AABB (tip at far end of barrel in -Z)
3. Creates `BarrelTip` Node3D at calculated position

### Web Compatibility

- Uses CPUParticles3D (not GPU) for Compatibility renderer support
- OmniLight3D for muzzle flash (universally supported)
- No GPU-only shader features

---

## Code Style

- **Files**: `snake_case.gd`
- **Classes**: `PascalCase` (`class_name CameraRig`)
- **Functions**: `snake_case()`, private prefixed with `_`
- **Variables**: `snake_case`, private prefixed with `_`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Signals**: `snake_case`
- **Static typing**: Required on all new code
- **Config pattern**: `@export` defaults + `_load_config_overrides()` from cfg

---

## For AI Assistants

1. **Read existing code** before modifying
2. **Use `@export` with `@export_group`** for all configurable values
3. **Use signals** for inter-component communication (check signal flow above)
4. **Use `Log.info()` / `Log.warning()` / `Log.error()`** for logging
5. **Add static typing** to all new code
6. **Use CPUParticles3D** for particles (web compatibility)
7. **Connect to CameraRig signals** when behavior depends on camera mode
8. **Config overrides**: Always provide `@export` defaults, override in `_load_config_overrides()`
9. **Node-moving approach** for FBX mesh extraction (never duplicate mesh resources)
10. **Test all 3 camera modes** after changes that affect aiming or camera

### Key Files
- `code/tank_controller.gd` - Main tank logic (~248 lines)
- `code/components/camera_rig.gd` - Camera system (~296 lines)
- `code/components/shooting_component.gd` - Firing system (~212 lines)
- `code/components/shooting_feedback.gd` - Juice effects (~157 lines)
- `game_config.cfg` - All runtime configuration

---

## Version Info

- **Godot Version**: 4.5
- **Project Type**: 3D Tank Combat Template
- **Template Version**: 3.0 (Refactored to tank-only architecture)
- **Last Updated**: February 2026
