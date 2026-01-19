# Migrating from Godot 4.4 to Godot 4.5.1

This document details the steps required to migrate this project from Godot 4.4 to Godot 4.5.1, including issues encountered and their solutions.

## Overview

Godot 4.5 is generally backwards-compatible with 4.4, but there are some breaking changes related to how autoloads and global class names are resolved at parse time. This project required specific changes to work correctly.

---

## Migration Steps

### Step 1: Update project.godot Version

Change the `config/features` line in `project.godot`:

```ini
# Before (4.4)
config/features=PackedStringArray("4.4")

# After (4.5)
config/features=PackedStringArray("4.5")
```

### Step 2: Delete the .godot Cache Folder

Before opening the project in Godot 4.5.1, delete the `.godot` folder in the project root. This folder contains cached data from Godot 4.4 that can cause import/conversion issues.

```bash
# Windows (PowerShell)
Remove-Item -Recurse -Force .godot

# Linux/macOS
rm -rf .godot
```

The editor will regenerate this folder when you open the project.

### Step 3: Resolve Logger Class Name Conflict

**Problem:** Godot 4.5 introduced an internal `Logger` class. If your project has a custom Logger class (like this template did), you'll see errors like:

```
Static function "error()" not found in base "GDScriptNativeClass"
Static function "info()" not found in base "GDScriptNativeClass"
```

**Solution:** Rename your custom Logger class to avoid the conflict.

#### 3a. Update the Logger Script

In `code/logger.gd`, make the following changes:

1. Add `class_name Log` at the top
2. Convert all methods to `static`
3. Convert instance variables to `static var`

**Before (4.4):**
```gdscript
extends Node

enum LogLevel { INFO, WARNING, ERROR, PERFORMANCE }

var performance_timers = {}

func log(level, message):
    # ...

func info(message):
    self.log(LogLevel.INFO, message)

func warning(message):
    self.log(LogLevel.WARNING, message)

func error(message):
    self.log(LogLevel.ERROR, message)
```

**After (4.5):**
```gdscript
class_name Log
extends Node

enum LogLevel { INFO, WARNING, ERROR, PERFORMANCE }

static var performance_timers: Dictionary = {}

static func _log(level: LogLevel, message: String) -> void:
    var timestamp = Time.get_datetime_string_from_system(false, true)
    var log_level_str = LogLevel.keys()[level]
    var formatted_message = "[%s] [%s] %s" % [timestamp, log_level_str, message]

    match level:
        LogLevel.INFO:
            print(formatted_message)
        LogLevel.WARNING:
            print_rich("[color=yellow]%s[/color]" % formatted_message)
        LogLevel.ERROR:
            printerr(formatted_message)
        LogLevel.PERFORMANCE:
            print_rich("[color=cyan]%s[/color]" % formatted_message)

static func info(message: String) -> void:
    _log(LogLevel.INFO, message)

static func warning(message: String) -> void:
    _log(LogLevel.WARNING, message)

static func error(message: String) -> void:
    _log(LogLevel.ERROR, message)

static func performance(message: String) -> void:
    _log(LogLevel.PERFORMANCE, message)

static func start_performance_check(check_name: String) -> void:
    performance_timers[check_name] = Time.get_ticks_usec()
    performance("Starting performance check: '%s'" % check_name)

static func end_performance_check(check_name: String) -> void:
    if performance_timers.has(check_name):
        var start_time = performance_timers[check_name]
        var end_time = Time.get_ticks_usec()
        var duration_ms = (end_time - start_time) / 1000.0
        performance("'%s' took %.4f ms" % [check_name, duration_ms])
        performance_timers.erase(check_name)
    else:
        warning("Performance check '%s' ended without being started." % check_name)

# Aliases for backwards compatibility
static func start_timer(label: String) -> void:
    start_performance_check(label)

static func end_timer(label: String) -> void:
    end_performance_check(label)
```

#### 3b. Remove Logger from Autoloads

Since `Log` is now a static class with `class_name`, it doesn't need to be an autoload. Remove it from `project.godot`:

```ini
# Before
[autoload]
Logger="*res://code/logger.gd"
GameConfig="*res://code/game_config.gd"
SceneManager="*res://code/scene_manager.gd"

# After
[autoload]
GameConfig="*res://code/game_config.gd"
SceneManager="*res://code/scene_manager.gd"
```

#### 3c. Update All Logger References

Find and replace all occurrences of `Logger.` with `Log.` across the codebase.

**Files that needed updating in this project:**
- `code/game_config.gd`
- `code/scene_manager.gd`
- `code/main.gd`
- `code/player_controller.gd`
- `code/projectile.gd`
- `code/projectile_hit_effect.gd`
- `code/tank_projectile.gd`
- `code/UI/launcher.gd`
- `code/UI/title_screen.gd`
- `code/UI/main_menu.gd`
- `code/components/weapon_component.gd`
- `code/components/aiming_helper.gd`
- `code/components/shooting_component.gd`
- `code/player_controllers/first_person_controller.gd`
- `code/player_controllers/third_person_controller.gd`
- `code/player_controllers/over_the_shoulder_controller.gd`
- `code/player_controllers/top_down_controller.gd`
- `code/player_controllers/isometric_controller.gd`
- `code/player_controllers/free_camera_controller.gd`
- `code/player_controllers/tank_controller.gd`

**Example change:**
```gdscript
# Before
Logger.info("Player spawned")
Logger.error("Failed to load config")

# After
Log.info("Player spawned")
Log.error("Failed to load config")
```

### Step 4: Delete .godot Cache Again

After making all the code changes, delete the `.godot` folder again before opening in Godot 4.5.1:

```bash
rm -rf .godot
```

### Step 5: Open Project in Godot 4.5.1

1. Launch Godot 4.5.1
2. Import the project
3. The editor will regenerate the cache and update scene files automatically
4. Verify the project runs without errors

---

## Why These Changes Were Needed

### Godot 4.5 Internal Logger Class

Godot 4.5 introduced an internal `Logger` class in the engine. When scripts referenced `Logger.info()`, the parser would find the engine's `Logger` class instead of the project's autoload, causing the "Static function not found" errors.

### Static Class Pattern

Converting to a static class with `class_name Log` solves this because:

1. `class_name` makes the class globally available at **parse time** (not just runtime like autoloads)
2. Static methods can be called directly on the class without an instance
3. No autoload registration is needed, avoiding any naming conflicts

### Autoload Order (Alternative Approach)

If you prefer to keep Logger as an autoload (non-static), you could try:

1. Rename the autoload to something unique like `GameLogger`
2. Update all references to use `GameLogger.info()` etc.

However, the static class approach is cleaner and more performant for utility classes.

---

## Verification Checklist

After migration, verify:

- [ ] Project opens without parser errors
- [ ] Game runs and loads the main scene
- [ ] Log messages appear in the console
- [ ] All controller modes work (first_person, third_person, tank, etc.)
- [ ] Scene transitions work via SceneManager
- [ ] No warnings about deprecated APIs

---

## Additional Notes

### Other Godot 4.5 Changes

Godot 4.5 also includes:

- **ParallaxBackground/ParallaxLayer deprecated** - If your project uses these, consider alternatives
- **Physics interpolation changes** - The 3D physics interpolation was moved from RenderingServer to SceneTree (API unchanged)
- **Android 16KB page support** - Required for Google Play after Nov 2025

### Resources

- [Official Migration Guide](https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.5.html)
- [Godot 4.5 Release Notes](https://godotengine.org/releases/4.5/)
- [Interactive Changelog](https://godotengine.github.io/godot-interactive-changelog/)

---

## Version History

| Date | Change |
|------|--------|
| January 2026 | Initial migration from 4.4 to 4.5.1 |
