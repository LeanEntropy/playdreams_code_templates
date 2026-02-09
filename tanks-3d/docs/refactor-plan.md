# Plan: Lean 3D Tank Template with Flexible Camera & Great Game Feel

## Context

The current codebase is a multi-mode 3D game with 7 interchangeable controller modes (FPS, TPS, OTS, tank, free camera, top-down, isometric). Every system has branching logic for all 7 modes. The goal is to strip it to a clean, modular, production-quality tank template with 3 camera views and satisfying tank combat feel. This template will be used for commercial games on web, mobile, and desktop.

### Architecture Principles (from review)
- **Separate CameraRig component** -- camera logic out of the tank controller
- **Use `@export` with `@export_group`** -- values visible in Godot inspector, config overrides in _ready()
- **Use signals** for inter-component communication (no string matching)
- **Strip GameConfig** to just a generic accessor (no legacy variables)
- **Merge WeaponComponent into ShootingComponent** (only ~60 lines of tank code after cleanup)
- **CPUParticles3D** instead of GPU (web Compatibility renderer support)

### Game Feel Fixes (from review)
- **Add acceleration/deceleration** (instant velocity = weightless tank)
- **Implement turret rotation speed limit** (config value exists but is never used)
- **Actually use reverse_speed** (configured but code always uses forward_speed)
- **Shooting juice**: camera kick, screen shake, muzzle flash, barrel recoil
- **Slower fire rate** (0.5s -> 2.0s, cannon not machine gun)
- **Reduce barrel pitch max** (70 -> 30 degrees)

---

## Phase 1: Delete Dead Files (~18 files)

### Non-tank controllers (6 files)
- `code/player_controllers/first_person_controller.gd`
- `code/player_controllers/third_person_controller.gd`
- `code/player_controllers/over_the_shoulder_controller.gd`
- `code/player_controllers/top_down_controller.gd`
- `code/player_controllers/isometric_controller.gd`
- `code/player_controllers/free_camera_controller.gd`

### Dispatcher + legacy (4 files)
- `code/player_controller.gd` - The 7-mode dispatcher
- `code/shooting_manager.gd` - Legacy shooting, not in scene tree
- `code/player_visuals_manager.gd` - Not in scene tree
- `code/components/weapon_component.gd` - Merge barrel detection into ShootingComponent, delete

### Old projectile system (2 files)
- `code/projectile.gd` - Broken (references nonexistent `GameConfig.projectile_mass`)
- `assets/projectile.tscn` - Replaced by `assets/tank_projectile.tscn`

### Non-tank weapon scenes (3 files)
- `assets/weapons/fps_pistol.tscn`
- `assets/weapons/tps_rifle.tscn`
- `assets/weapons/topdown_gun.tscn`

### Non-tank UI/assets (2 files)
- `code/UI/aim_cursor.gd` - Only used by top-down/isometric
- `assets/destination_marker.tscn` - Only used by top-down click-to-move

### Dead audio (3 files -- reference nonexistent GameConfig properties, would crash)
- `code/audio_manager.gd`
- `code/audio_setup.gd`
- `assets/audio_setup.tscn`

### Scene cleanup (main.tscn)
- Remove `RedBox` node (debug artifact)
- Remove `SelectionRing` node (isometric-only)
- Remove `PlayerMesh` node (capsule placeholder for non-tank modes)

### Directory cleanup
- Delete `code/player_controllers/` directory after moving tank_controller.gd out

---

## Phase 2: Create CameraRig Component (NEW)

Create `code/components/camera_rig.gd` as a **separate Node3D** on the Player node. This keeps camera logic fully decoupled from tank movement.

### Architecture
```
Player (CharacterBody3D, script: tank_controller.gd)
  +-- PlayerTank (Node3D)
  |     +-- TankHull, Turret, BarrelPivot...
  +-- CameraRig (Node3D, script: camera_rig.gd)
  |     +-- ChaseCamera (Camera3D) -- moved from Turret/TankCamera
  |     +-- TopDownCamera (Camera3D) -- created in _ready()
  |     +-- FreeCamera (Camera3D) -- created in _ready()
  +-- ShootingComponent
```

### CameraRig responsibilities:
- Enum `CameraMode { CHASE, TOP_DOWN, FREE }`
- `@export var default_mode: CameraMode`
- Signal `camera_mode_changed(new_mode: CameraMode)`
- `switch_mode(mode)` activates correct Camera3D + sets mouse mode
- `get_active_camera() -> Camera3D`
- Handles C-key cycling (via `switch_camera` input action)
- **CHASE**: Follows turret rotation with `camera_follow_speed` smoothing + collision avoidance raycast
- **TOP_DOWN**: Overhead, follows player position, scroll to zoom
- **FREE**: Orbit around player, right-drag to orbit, scroll to zoom

### Mouse mode ownership:
- CHASE -> `MOUSE_MODE_CAPTURED`
- TOP_DOWN -> `MOUSE_MODE_VISIBLE`
- FREE -> `MOUSE_MODE_VISIBLE`

This eliminates scattered mouse mode logic from main.gd, ui_layer.gd, and the tank controller.

---

## Phase 3: Rewrite Tank Controller

### Move and refactor
- **From**: `code/player_controllers/tank_controller.gd` (extends Node)
- **To**: `code/tank_controller.gd` (extends CharacterBody3D)

### Structural changes:
1. `extends Node` -> `extends CharacterBody3D`
2. `initialize(player_node)` -> `_ready()`, all `player.xxx` -> `self.xxx` or just `xxx`
3. `handle_input(event)` -> `_unhandled_input(event)`
4. `handle_physics(delta)` -> `_physics_process(delta)`
5. Remove: TankProjectileScene preload, _create_crosshair(), cleanup(), all debug logging (150+ lines)

### Use @export for config values:
```gdscript
@export_group("Movement")
@export var forward_speed: float = 10.0
@export var reverse_speed: float = 4.0
@export var hull_turn_speed: float = 2.0
@export var acceleration: float = 4.0
@export var deceleration: float = 6.0
@export var gravity: float = 9.8

@export_group("Turret")
@export var mouse_sensitivity: float = 0.003
@export var turret_speed_limited: bool = true
@export var turret_rotation_speed: float = 3.0
@export var barrel_pitch_min: float = -12.0
@export var barrel_pitch_max: float = 30.0

func _ready() -> void:
    _load_config_overrides()  # game_config.cfg overrides @export defaults
```

### Game feel improvements:

**Acceleration/deceleration** (currently instant velocity):
```gdscript
var current_speed: float = 0.0
# In _physics_process:
var target_speed = forward_input * (forward_speed if forward_input > 0 else reverse_speed)
current_speed = move_toward(current_speed, target_speed,
    (acceleration if abs(target_speed) > abs(current_speed) else deceleration) * delta)
```

**Turret rotation speed limit** (currently instant snap):
```gdscript
var turret_target_yaw: float = 0.0  # Raw mouse intent
# In _unhandled_input: turret_target_yaw -= event.relative.x * mouse_sensitivity
# In _physics_process:
if turret_speed_limited:
    turret_yaw = move_toward(turret_yaw, turret_target_yaw, turret_rotation_speed * delta)
else:
    turret_yaw = turret_target_yaw  # Arcade instant mode
turret.rotation.y = turret_yaw
```

**Turret aiming per camera mode** (reads from CameraRig):
- CHASE: mouse delta -> turret_target_yaw (current behavior, improved)
- TOP_DOWN: mouse ground raycast -> calculate yaw to face target point
- FREE: turret holds position (no mouse input)

### Health system stub:
```gdscript
signal health_changed(current: int, max_health: int)
@export var max_health: int = 100
var current_health: int

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)
    health_changed.emit(current_health, max_health)
```

### Target: ~200 lines (down from 541)

---

## Phase 4: Simplify ShootingComponent + Add Shooting Feedback

### Simplify `code/components/shooting_component.gd`:
- Remove `_detect_controller_mode()` and all mode branching
- Inline WeaponComponent's `_setup_tank_weapon()` barrel detection (~40 lines)
- Single `fire_rate` and `projectile_speed` (remove fps/tank split)
- Just use `"shoot"` action for input (remove isometric/top_down special cases)
- Connect to CameraRig's `camera_mode_changed` to switch aiming method
- Use Timer node instead of `await create_timer()` for cooldown
- Delete `code/components/weapon_component.gd` (absorbed)

### NEW: Create `code/components/shooting_feedback.gd`:
Subscribe to ShootingComponent's `shot_fired` signal. On fire:
- **Camera kick**: Push camera pitch up ~2.5 degrees over 0.05s, lerp back over 0.3s
- **Screen shake**: Small random offset (amplitude ~0.03, duration 0.15s)
- **Muzzle flash**: Spawn OmniLight3D at barrel tip for 0.05s
- **Barrel recoil**: Push barrel_pivot back, spring back over 0.4s
All config-driven via `[shooting]` section.

### Simplify `code/components/aiming_helper.gd`:
- Remove `get_target_for_mode()` match statement
- Keep: `get_screen_center_target()`, `get_mouse_ground_target()`, `calculate_fire_direction()`, `has_clear_line_of_sight()`

---

## Phase 5: Simplify UI, Config, and Main

### `code/game_config.gd`
Strip to minimal:
```gdscript
extends Node
signal config_loaded
var is_loaded: bool = false
var config := ConfigFile.new()

func get_value(section: String, key: String, default = null):
    return config.get_value(section, key, default)

func _ready() -> void:
    config.load("res://game_config.cfg")
    is_loaded = true
    config_loaded.emit()
```
Remove: all legacy variables, `_debug_print_weapons_config()`

### `game_config.cfg`
Remove sections: `[first_person]`, `[third_person]`, `[over_the_shoulder]`, `[free_camera]`, `[top_down]`, `[isometric]`

Updated `[tank]` section:
```ini
[tank]
camera_mode="chase"
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
```

Updated `[shooting]`:
```ini
[shooting]
fire_rate=2.0
projectile_speed=55.0
projectile_gravity_scale=0.1
screen_shake_enabled=true
screen_shake_intensity=0.03
camera_kick_degrees=2.5
muzzle_flash_enabled=true
barrel_recoil_distance=0.1
```

Strip `[weapons]` section entirely (tank uses barrel, not weapon models).

### `code/UI/ui_layer.gd`
- Remove aim_cursor references
- Connect to CameraRig's `camera_mode_changed` to toggle crosshair visibility
- Remove all mode-list arrays

### `code/main.gd`
- Remove `_set_mouse_mode_for_controller()` entirely (CameraRig owns mouse mode)
- Keep: title screen flow, game start/pause logic

### `main.tscn`
- Change Player script to `code/tank_controller.gd`
- Add CameraRig node as child of Player

### `project.godot`
- Add `switch_camera` input action (C key)
- Add gamepad mappings (left stick = move, right stick = turret, RT = shoot)

---

## Phase 6: Update Documentation

### `CLAUDE.md`
Rewrite for tank-only architecture:
- CameraRig component instead of 7 controller modes
- @export-based config with game_config.cfg overrides
- Simplified component APIs
- Updated file structure

### `template-api.json`
Update to reflect simplified APIs.

### `template-index.json`
Regenerate (auto-generated).

---

## Final File Structure

```
code/
  tank_controller.gd              # Hull movement, turret, terrain following
  main.gd                         # Title screen flow, game start
  game_config.gd                  # Minimal config accessor (autoload)
  logger.gd                       # Logging utility
  tank_projectile.gd              # Projectile with gravity + hit effects
  projectile_hit_effect.gd        # Impact particles
  components/
    camera_rig.gd                 # NEW: Camera mode management
    shooting_component.gd         # Simplified: barrel detection + firing
    shooting_feedback.gd          # NEW: Camera kick, shake, flash, recoil
    aiming_helper.gd              # Simplified: utility raycasts only
  UI/
    ui_layer.gd                   # Simplified: crosshair only
    title_screen.gd               # Unchanged
assets/
  UI/                             # Crosshair, title screen scenes
  weapons/debug_barrel.tscn       # Keep for dev
  vehicles/tank_kenney_01.tscn    # Tank model
  tank_projectile.tscn            # Tank projectile scene
  projectile_hit_effect.tscn      # Hit effect scene
  3d_models/tanks/                # FBX source files
```

---

## Verification

1. Run game -- tank moves with acceleration/deceleration feel
2. Turret rotation has visible speed limit (not instant snap)
3. Reverse is slower than forward
4. Firing feels punchy: camera kick, shake, flash, recoil all trigger
5. Fire rate is ~2s (cannon rhythm, not spam)
6. Switch camera modes with C key: chase (captured mouse), top-down (visible mouse, turret tracks cursor), free (orbit camera)
7. No Godot console errors on startup
8. Crosshair shows in chase mode, hides in top-down/free
9. Search codebase for `first_person`, `third_person`, `isometric` -- zero results
10. Test on web export (Compatibility renderer) -- particles work, no GPU-only features
