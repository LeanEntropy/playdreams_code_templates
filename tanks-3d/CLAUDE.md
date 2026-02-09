# Godot 4.6 3D Tank Template - AI Development Guide

## Project Overview

A clean, modular 3D tank combat template built in Godot 4.6. Single tank controller with 2 camera views, component-based shooting, screen shake/muzzle flash feedback, and mobile touch input support. Targets web, mobile, and desktop.

**Architecture**: Tank controller (CharacterBody3D) with inline camera management + ShootingComponent + ShootingFeedback + MobileControls. All config values use `@export` with `game_config.cfg` overrides.

---

## Architecture

### Component Layout

```
Player (CharacterBody3D, script: tank_controller.gd)
  +-- PlayerCollision (CollisionShape3D)
  +-- PlayerTank (instance of tank_model.tscn)
  |     +-- TankHull (Node3D - scale 25, -90 Y rotation)
  |     |     +-- TankArmature (Node3D - -90 X rotation, FBX coord fix)
  |     |           +-- Tank_body (MeshInstance3D)
  |     |           +-- TrackMesh_R (MeshInstance3D)
  |     |           +-- TrackMesh_L (MeshInstance3D)
  |     +-- Turret (Node3D - scale 25, -90 Y rotation, y=turret offset)
  |           +-- TankCamera (Camera3D - 3rd person, child of turret)
  |           +-- BarrelPivot (Node3D - pitches with mouse Y)
  |           |     +-- TankGunBarrel (MeshInstance3D)
  |           |           +-- BarrelTip (Marker3D - projectile spawn point)
  |           +-- TurretMesh (MeshInstance3D)
  +-- ShootingComponent (Node, script: shooting_component.gd)
  +-- ShootingFeedback (Node, script: shooting_feedback.gd)

Main (Node3D, script: main.gd)
  +-- Player (above)
  +-- UILayer (CanvasLayer, script: ui_layer.gd)
  +-- TitleScreen (CanvasLayer, script: title_screen.gd)
  +-- MobileControls (CanvasLayer, loaded at runtime by main.gd)
```

### Tank Controller (`code/tank_controller.gd`)

Extends `CharacterBody3D`. Manages hull movement, turret rotation, terrain following, and 2 camera views. Supports both mouse and touch input.

```gdscript
enum CameraView { TURRET, ISOMETRIC }

signal health_changed(current: int, max_health: int)
```

**Two camera views** (press C to switch):

| View | Camera | Mouse Mode | Aiming |
|------|--------|-----------|--------|
| TURRET | TankCamera (child of turret) | CAPTURED | Mouse/touch drag -> turret yaw + barrel pitch |
| ISOMETRIC | IsometricCamera (created at runtime) | CAPTURED | Same controls, overhead view |

Key game-feel features:
- **Acceleration/deceleration** via `move_toward()` (not instant velocity)
- **Turret rotation speed limit** via `move_toward()` (configurable, can be disabled)
- **Separate reverse speed** (slower than forward)
- **Terrain following** with 4-corner raycasts
- **Touch input** via `InputEventScreenDrag` for turret aiming on mobile
- **Health stub** with `take_damage(amount)` and `health_changed` signal

### ShootingComponent (`code/components/shooting_component.gd`)

Fires projectiles from barrel tip on "shoot" action. Uses active camera's screen-center raycast for aiming. Timer-based cooldown. Optional ammo system.

```gdscript
signal shot_fired
signal ammo_changed(current: int, max_ammo: int)

func get_muzzle_position() -> Vector3
func get_fire_direction() -> Vector3
```

### ShootingFeedback (`code/components/shooting_feedback.gd`)

Subscribes to `ShootingComponent.shot_fired`. Provides:
- **Screen shake**: Random h/v camera offset, decays over time
- **Muzzle flash**: OmniLight3D at barrel tip, brief pulse

All values config-driven via `[shooting]` section.

### MobileControls (`code/UI/mobile_controls.gd`)

Touch controls for mobile devices. Auto-detected via `OS.get_name()` and `DisplayServer.is_touchscreen_available()`.

- **Virtual joystick** (left 40% of screen): Appears where you touch, feeds into Input action system
- **Fire button** (bottom-right): Triggers "shoot" action
- **Turret aiming** (right side drag): Handled by `tank_controller.gd` via `InputEventScreenDrag`
- **Configurable**: `show_mobile_controls` in game_config.cfg ("auto", "always", "never")

### AimingHelper (`code/components/aiming_helper.gd`)

Static utility class. Single function:
- `get_screen_center_target(camera, max_distance, exclude)` - Center-screen raycast for aiming

### Singleton Autoloads
- **GameConfig** (`code/game_config.gd`): Minimal config accessor. `GameConfig.get_value(section, key, default)`

### Static Utilities
- **Log** (`code/logger.gd`): Static logging via `class_name Log`. `Log.info()`, `Log.warning()`, `Log.error()`

**Note**: `Log` is a `class_name`, NOT an autoload. Call static methods directly.

---

## Directory Structure

```
tanks-3d/
+-- code/
|     +-- tank_controller.gd          # Hull movement, turret, cameras, terrain
|     +-- main.gd                     # Title screen flow, game start, mobile setup
|     +-- game_config.gd              # Minimal config accessor (autoload)
|     +-- logger.gd                   # Static logging utility (class_name Log)
|     +-- tank_projectile.gd          # Projectile with gravity + hit effects
|     +-- projectile_hit_effect.gd    # Impact particles
|     +-- components/
|     |     +-- shooting_component.gd # Barrel detection + firing
|     |     +-- shooting_feedback.gd  # Screen shake, muzzle flash
|     |     +-- aiming_helper.gd      # Static raycast utility
|     +-- UI/
|     |     +-- ui_layer.gd           # Pause menu, crosshair visibility
|     |     +-- title_screen.gd       # Title screen
|     |     +-- mobile_controls.gd    # Virtual joystick + fire button
|     +-- tools/
|           +-- convert_tank_fbx.gd   # FBX-to-tank scene converter
+-- assets/
|     +-- UI/                         # Crosshair, title screen, UI layer, mobile controls scenes
|     +-- tank_model.tscn             # Default tank model scene
|     +-- tank_projectile.tscn        # Projectile scene
|     +-- projectile_hit_effect.tscn  # Hit effect scene
|     +-- 3d_models/tanks/            # FBX source files (place Quaternius tanks here)
+-- main.tscn                         # Primary game scene
+-- game_config.cfg                   # Runtime configuration
+-- project.godot                     # Godot project file
```

---

## Configuration

All components use `@export` variables with `@export_group` for inspector visibility. Values can be overridden via `game_config.cfg` (loaded in each component's `_ready()`).

### game_config.cfg

```ini
[tank]
forward_speed=18.0
reverse_speed=8.0
hull_turn_speed=2.0
acceleration=20.0
deceleration=25.0
turret_speed_limited=true
turret_rotation_speed=3.0
mouse_sensitivity=0.003
barrel_pitch_min=-12.0
barrel_pitch_max=30.0

[shooting]
fire_rate=1.0
projectile_speed=55.0
projectile_gravity_scale=0.1
screen_shake_enabled=true
screen_shake_intensity=0.03
muzzle_flash_enabled=true

[projectile]
mesh_color="000000"

[ui]
show_crosshair=true

[title_screen]
show_title_screen=false

[controls]
pause_key_primary="P"
pause_key_secondary="Escape"
show_mobile_controls="auto"
touch_sensitivity=0.005
```

### Input Actions
- **WASD / Arrow keys**: Tank movement and hull rotation
- **Mouse**: Turret rotation (desktop)
- **Touch drag** (right side): Turret rotation (mobile)
- **Left click / Space / RT**: Fire projectile
- **C / Y button**: Switch camera view
- **P / Escape**: Pause
- **Virtual joystick** (mobile): Movement
- **Fire button** (mobile): Shoot

---

## Common Tasks

### Adjusting Tank Feel

Edit `game_config.cfg` `[tank]` section:
- `acceleration` / `deceleration`: Higher = snappier, lower = heavier feel
- `turret_rotation_speed`: Lower = more realistic turret lag
- `turret_speed_limited=false`: Instant turret snap (arcade mode)
- `forward_speed` / `reverse_speed`: Reverse should be ~40% of forward

### Adjusting Shooting Feel

Edit `game_config.cfg` `[shooting]` section:
- `fire_rate=1.0`: Seconds between shots. Lower = faster firing
- `screen_shake_intensity=0.03`: Shake amplitude. 0 = no shake
- `muzzle_flash_enabled=true`: Toggle muzzle flash light

### Adding a New Component

1. Create `code/components/my_component.gd`
2. Use `@export` with `@export_group` for config, add `_load_config_overrides()` for cfg
3. Add as child of Player in `main.tscn`
4. Connect to existing signals (e.g., `shot_fired`, `health_changed`)

### Replacing the Tank Model

Use the FBX converter tool with Quaternius "Tank Pack June 2019" (CC0, free at quaternius.com):

1. Copy FBX files into `res://assets/3d_models/tanks/`
2. Let Godot import them (reopen project if needed)
3. Run `code/tools/convert_tank_fbx.gd` via File > Run in the Godot editor
4. Output scenes appear in `res://assets/vehicles/`
5. In `main.tscn`, change the PlayerTank instance to use the generated scene

The converter produces scenes with the exact node hierarchy the game code expects, including TankCamera and BarrelTip. Compatible with all 4 Quaternius tank variants (Tank.fbx through Tank4.fbx).

### Testing Mobile Controls on Desktop

Set `show_mobile_controls="always"` in `game_config.cfg` `[controls]` section. The virtual joystick and fire button will appear. Mouse clicks emulate touch events (via `emulate_touch_from_mouse` in project settings).

---

## Technical Details

### Signal Flow

```
ShootingComponent
  -> shot_fired signal              (on fire)
  -> ammo_changed signal            (on fire/reload)
  -> Consumed by: ShootingFeedback (shake/flash)

tank_controller.gd
  -> health_changed signal          (on take_damage)
```

### Mouse Mode

- **Desktop**: `tank_controller.gd` captures mouse in `_ready()`. `ui_layer.gd` sets VISIBLE on pause, re-captures on unpause.
- **Mobile**: Mouse is never captured. Touch controls handle all input.
- **Desktop with `show_mobile_controls="always"`**: Mouse stays visible for touch emulation testing.

### Barrel Tip Detection

ShootingComponent finds barrel tip automatically:
1. Checks for existing `BarrelTip` node under `TankGunBarrel`
2. If missing, calculates from mesh AABB (tip at far end of barrel in -Z)
3. Creates `BarrelTip` Node3D at calculated position

### Touch Input Architecture

- `MobileControls._input()` handles joystick + fire button touches, consuming them via `set_input_as_handled()`
- Remaining touches (right-side drags) propagate to `tank_controller._unhandled_input()` as `InputEventScreenDrag`
- Joystick feeds into the same `Input.action_press()`/`Input.action_release()` as keyboard, so movement code works unchanged

### Web/Mobile Compatibility

- Uses CPUParticles3D (not GPU) for Compatibility renderer support
- OmniLight3D for muzzle flash (universally supported)
- No GPU-only shader features
- Touch controls auto-detected for mobile and web with touchscreen

---

## Code Style

- **Files**: `snake_case.gd`
- **Classes**: `PascalCase` (`class_name ShootingComponent`)
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
6. **Use CPUParticles3D** for particles (web/mobile compatibility)
7. **Config overrides**: Always provide `@export` defaults, override in `_load_config_overrides()`
8. **Test both camera views** after changes that affect aiming or camera
9. **Test mobile controls** after changes that affect input handling

### Key Files
- `code/tank_controller.gd` - Main tank logic (~247 lines)
- `code/components/shooting_component.gd` - Firing system (~169 lines)
- `code/components/shooting_feedback.gd` - Juice effects (~79 lines)
- `code/UI/mobile_controls.gd` - Touch controls (~175 lines)
- `code/tools/convert_tank_fbx.gd` - FBX converter tool (~308 lines)
- `game_config.cfg` - All runtime configuration

---

## Version Info

- **Godot Version**: 4.6
- **Project Type**: 3D Tank Combat Template
- **Tank Model Source**: Quaternius "Tank Pack June 2019" (CC0 license)
- **Template Version**: 4.0 (Cleaned up, touch input, FBX converter)
- **Last Updated**: February 2026
