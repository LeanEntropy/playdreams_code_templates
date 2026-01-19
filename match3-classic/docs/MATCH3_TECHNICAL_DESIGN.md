# Match-3 Technical Design Document (Godot 4.5)

## Overview

This document provides a complete technical specification for implementing a Candy Crush Saga-style match-3 puzzle game in Godot 4.5. It serves as a reference for building any match-3 game with the following features:

- 8x8 grid-based puzzle gameplay
- Minimum 3-in-a-row matching
- Special gems (Striped, Wrapped, Color Bomb)
- Special gem combinations with unique effects
- Cascade/chain reaction system
- Booster power-ups
- Configurable theming system
- Responsive portrait/landscape layout

---

## Architecture

### Design Principles

1. **Separation of Concerns**: Game logic (GameManager) is separate from visual representation (GameBoard, Gem)
2. **Configuration-Driven**: All gameplay parameters are externalized to resource files
3. **Signal-Based Communication**: Loose coupling between components via Godot signals
4. **Autoload Singletons**: Global managers accessible from anywhere

### Recommended Directory Structure

```
your_match3_project/
├── config/
│   ├── game_config.tres      # Gameplay settings resource
│   └── theme_default.tres    # Visual theme resource
├── scripts/
│   ├── autoload/
│   │   ├── ConfigManager.gd  # Configuration access singleton
│   │   ├── GameManager.gd    # Core game state & logic singleton
│   │   └── BoosterManager.gd # Booster inventory singleton
│   ├── board/
│   │   ├── GameBoard.gd      # Visual board, animations, input
│   │   ├── Gem.gd            # Individual gem visuals & input
│   │   └── SpecialCombinations.gd  # Special gem combo logic
│   ├── config/
│   │   ├── GameConfig.gd     # Game settings resource class
│   │   └── ThemeConfig.gd    # Theme resource class
│   ├── Enums.gd              # Global enumerations
│   └── Main.gd               # Main scene controller, UI
├── scenes/
│   ├── Main.tscn             # Main game scene
│   ├── GameBoard.tscn        # Board scene
│   └── Gem.tscn              # Gem prefab scene
└── assets/
    ├── gems/                 # Gem textures (gem_1.png - gem_6.png)
    ├── backgrounds/          # Background images
    ├── ui/                   # UI textures
    └── audio/                # Sound effects
```

### Autoload Order (project.godot)

```gdscript
ConfigManager = "res://scripts/autoload/ConfigManager.gd"  # First - others depend on it
GameManager = "res://scripts/autoload/GameManager.gd"
BoosterManager = "res://scripts/autoload/BoosterManager.gd"
```

---

## Data Structures

### Enums (scripts/Enums.gd)

```gdscript
class_name Enums

enum GemColor {
    NONE = 0,    # Empty cell
    RED = 1,
    ORANGE = 2,
    YELLOW = 3,
    GREEN = 4,
    BLUE = 5,
    PURPLE = 6
}

enum SpecialType {
    NONE = 0,
    STRIPED_H = 1,   # Horizontal striped - clears row
    STRIPED_V = 2,   # Vertical striped - clears column
    WRAPPED = 3,     # Wrapped - 3x3 explosion
    COLOR_BOMB = 4   # Color bomb - clears all of one color
}

enum BoosterType {
    NONE = 0,
    LOLLIPOP_HAMMER = 1,    # Destroy single gem
    FREE_SWITCH = 2,        # Swap without match requirement
    SHUFFLE = 3,            # Reshuffle board
    COLOR_BOMB_START = 4,   # Place color bomb on board
    EXTRA_MOVES = 5         # Add +5 moves
}
```

### Grid Data Structure (GameManager)

The game grid is a 2D array of dictionaries:

```gdscript
var grid: Array[Array] = []  # grid[x][y]

# Each cell contains:
{
    "color": Enums.GemColor,    # Gem color (NONE = empty)
    "special": Enums.SpecialType  # Special type (NONE = regular)
}
```

**Coordinate System:**
- Origin (0,0) is top-left
- X increases rightward (columns)
- Y increases downward (rows)
- Standard access: `grid[x][y]`

### Match Data Structure

Matches are represented as dictionaries:

```gdscript
{
    "cells": Array[Vector2i],  # All positions in the match
    "direction": String,       # "horizontal" or "vertical"
    "length": int              # Number of gems matched
}
```

### Special Pattern Detection Result

```gdscript
{
    "type": Enums.SpecialType,  # Type of special to create
    "position": Vector2i,       # Where to create it
    "color": Enums.GemColor     # Color of the special gem
}
```

---

## Core Systems

### 1. Grid Management (GameManager)

#### Initialization

```gdscript
func start_new_game() -> void:
    # 1. Initialize empty grid
    grid.clear()
    for x in range(grid_width):
        var column: Array[Dictionary] = []
        for y in range(grid_height):
            column.append({"color": Enums.GemColor.NONE, "special": Enums.SpecialType.NONE})
        grid.append(column)

    # 2. Fill with random colors (no initial matches)
    for x in range(grid_width):
        for y in range(grid_height):
            grid[x][y]["color"] = _get_random_color_no_match(x, y)

    # 3. Ensure at least one valid move exists
    if not has_possible_moves():
        shuffle_board()

    # 4. Reset game state
    score = 0
    moves_left = starting_moves
    combo_count = 0
```

#### Random Color Without Match

```gdscript
func _get_random_color_no_match(x: int, y: int) -> Enums.GemColor:
    var available_colors: Array[Enums.GemColor] = [
        Enums.GemColor.RED, Enums.GemColor.ORANGE, Enums.GemColor.YELLOW,
        Enums.GemColor.GREEN, Enums.GemColor.BLUE, Enums.GemColor.PURPLE
    ]

    # Remove colors that would create horizontal match
    if x >= 2:
        var c1 = grid[x-1][y]["color"]
        var c2 = grid[x-2][y]["color"]
        if c1 == c2 and c1 in available_colors:
            available_colors.erase(c1)

    # Remove colors that would create vertical match
    if y >= 2:
        var c1 = grid[x][y-1]["color"]
        var c2 = grid[x][y-2]["color"]
        if c1 == c2 and c1 in available_colors:
            available_colors.erase(c1)

    return available_colors[randi() % available_colors.size()]
```

### 2. Match Detection Algorithm

The match detection scans the entire grid for horizontal and vertical matches of 3+ gems.

```gdscript
func find_matches() -> Array[Dictionary]:
    var matches: Array[Dictionary] = []
    var matched_cells: Dictionary = {}  # Track already-matched cells

    # Scan horizontal matches
    for y in range(grid_height):
        var x = 0
        while x < grid_width:
            var color = grid[x][y]["color"]
            if color == Enums.GemColor.NONE:
                x += 1
                continue

            # Count consecutive same-color gems
            var match_length = 1
            while x + match_length < grid_width and grid[x + match_length][y]["color"] == color:
                match_length += 1

            if match_length >= min_match:
                var cells: Array[Vector2i] = []
                for i in range(match_length):
                    cells.append(Vector2i(x + i, y))
                    matched_cells[Vector2i(x + i, y)] = true
                matches.append({
                    "cells": cells,
                    "direction": "horizontal",
                    "length": match_length
                })

            x += max(1, match_length)

    # Scan vertical matches (same logic, swapped axes)
    for x in range(grid_width):
        var y = 0
        while y < grid_height:
            var color = grid[x][y]["color"]
            if color == Enums.GemColor.NONE:
                y += 1
                continue

            var match_length = 1
            while y + match_length < grid_height and grid[x][y + match_length]["color"] == color:
                match_length += 1

            if match_length >= min_match:
                var cells: Array[Vector2i] = []
                for i in range(match_length):
                    cells.append(Vector2i(x, y + i))
                matches.append({
                    "cells": cells,
                    "direction": "vertical",
                    "length": match_length
                })

            y += max(1, match_length)

    return matches
```

### 3. Special Gem Creation

Special gems are created based on match patterns:

| Pattern | Special Type | Effect |
|---------|--------------|--------|
| 4 horizontal | STRIPED_V | Clears entire column when matched |
| 4 vertical | STRIPED_H | Clears entire row when matched |
| 5 in L or T shape | WRAPPED | Explodes 3x3 area twice |
| 5 in a line | COLOR_BOMB | Clears all gems of swapped color |

```gdscript
func detect_special_pattern(matches: Array[Dictionary], swapped_pos: Vector2i) -> Dictionary:
    var result = {"type": Enums.SpecialType.NONE, "position": Vector2i(-1, -1), "color": Enums.GemColor.NONE}

    # Collect all matched cells and find intersections
    var all_cells: Dictionary = {}
    var intersection_cells: Array[Vector2i] = []

    for match_info in matches:
        for cell in match_info["cells"]:
            if all_cells.has(cell):
                intersection_cells.append(cell)
            all_cells[cell] = true

    # Check for L/T shape (intersection of horizontal and vertical)
    if not intersection_cells.is_empty():
        var best_pos = _find_best_special_position(intersection_cells, swapped_pos)
        result = {
            "type": Enums.SpecialType.WRAPPED,
            "position": best_pos,
            "color": grid[best_pos.x][best_pos.y]["color"]
        }
        return result

    # Check for 5-in-a-line (Color Bomb)
    for match_info in matches:
        if match_info["length"] >= 5:
            var pos = _find_best_special_position(match_info["cells"], swapped_pos)
            result = {
                "type": Enums.SpecialType.COLOR_BOMB,
                "position": pos,
                "color": grid[pos.x][pos.y]["color"]
            }
            return result

    # Check for 4-in-a-line (Striped)
    for match_info in matches:
        if match_info["length"] == 4:
            var pos = _find_best_special_position(match_info["cells"], swapped_pos)
            var special_type = Enums.SpecialType.STRIPED_V if match_info["direction"] == "horizontal" else Enums.SpecialType.STRIPED_H
            result = {
                "type": special_type,
                "position": pos,
                "color": grid[pos.x][pos.y]["color"]
            }
            return result

    return result

func _find_best_special_position(cells: Array, swapped_pos: Vector2i) -> Vector2i:
    # Prefer swapped position if it's in the match
    for cell in cells:
        if cell == swapped_pos:
            return cell
    # Otherwise return middle cell
    return cells[cells.size() / 2]
```

### 4. Special Gem Activation

When a special gem is matched, it activates its effect:

```gdscript
func get_special_activation_targets(pos: Vector2i, special_type: Enums.SpecialType) -> Array[Vector2i]:
    var targets: Array[Vector2i] = []

    match special_type:
        Enums.SpecialType.STRIPED_H:
            # Clear entire row
            for x in range(grid_width):
                if Vector2i(x, pos.y) != pos:
                    targets.append(Vector2i(x, pos.y))

        Enums.SpecialType.STRIPED_V:
            # Clear entire column
            for y in range(grid_height):
                if Vector2i(pos.x, y) != pos:
                    targets.append(Vector2i(pos.x, y))

        Enums.SpecialType.WRAPPED:
            # Clear 3x3 area
            for dx in range(-1, 2):
                for dy in range(-1, 2):
                    var target = Vector2i(pos.x + dx, pos.y + dy)
                    if _is_valid_position(target) and target != pos:
                        targets.append(target)

        Enums.SpecialType.COLOR_BOMB:
            # Handled separately - needs adjacent gem color
            pass

    return targets

func get_color_bomb_targets(target_color: Enums.GemColor) -> Array[Vector2i]:
    var targets: Array[Vector2i] = []
    for x in range(grid_width):
        for y in range(grid_height):
            if grid[x][y]["color"] == target_color:
                targets.append(Vector2i(x, y))
    return targets
```

### 5. Special Combinations (SpecialCombinations.gd)

When two special gems are swapped together, they create powerful combo effects:

| Combination | Effect |
|-------------|--------|
| Striped + Striped | Clears row AND column (cross pattern) |
| Wrapped + Wrapped | Large 5x5 explosion |
| Striped + Wrapped | Clears 3 rows AND 3 columns |
| Color Bomb + Striped | All gems of color become striped, then activate |
| Color Bomb + Wrapped | All gems of color become wrapped, then activate |
| Color Bomb + Color Bomb | Clears entire board |
| Color Bomb + Regular | Clears all gems of that color |

```gdscript
enum ComboType {
    NONE,
    STRIPED_STRIPED,
    WRAPPED_WRAPPED,
    STRIPED_WRAPPED,
    COLORBOMB_STRIPED,
    COLORBOMB_WRAPPED,
    COLORBOMB_COLORBOMB,
    COLORBOMB_REGULAR
}

static func detect_combination(gem1: Gem, gem2: Gem) -> ComboType:
    var s1 = gem1.special_type
    var s2 = gem2.special_type

    # Sort so color bomb checks work regardless of order
    if s2 == Enums.SpecialType.COLOR_BOMB and s1 != Enums.SpecialType.COLOR_BOMB:
        var temp = s1
        s1 = s2
        s2 = temp

    # Color bomb combinations
    if s1 == Enums.SpecialType.COLOR_BOMB:
        if s2 == Enums.SpecialType.COLOR_BOMB:
            return ComboType.COLORBOMB_COLORBOMB
        elif s2 in [Enums.SpecialType.STRIPED_H, Enums.SpecialType.STRIPED_V]:
            return ComboType.COLORBOMB_STRIPED
        elif s2 == Enums.SpecialType.WRAPPED:
            return ComboType.COLORBOMB_WRAPPED
        elif s2 == Enums.SpecialType.NONE:
            return ComboType.COLORBOMB_REGULAR

    # Striped combinations
    var is_striped_1 = s1 in [Enums.SpecialType.STRIPED_H, Enums.SpecialType.STRIPED_V]
    var is_striped_2 = s2 in [Enums.SpecialType.STRIPED_H, Enums.SpecialType.STRIPED_V]

    if is_striped_1 and is_striped_2:
        return ComboType.STRIPED_STRIPED
    if is_striped_1 and s2 == Enums.SpecialType.WRAPPED:
        return ComboType.STRIPED_WRAPPED
    if s1 == Enums.SpecialType.WRAPPED and is_striped_2:
        return ComboType.STRIPED_WRAPPED

    # Wrapped combinations
    if s1 == Enums.SpecialType.WRAPPED and s2 == Enums.SpecialType.WRAPPED:
        return ComboType.WRAPPED_WRAPPED

    return ComboType.NONE
```

### 6. Cascade System

The cascade system handles chain reactions after matches:

```gdscript
# In GameBoard.gd
func _process_cascade(swapped_pos: Vector2i) -> void:
    for cascade_depth in 50:  # Safety limit
        var matches := GameManager.find_matches()
        if matches.is_empty():
            break

        GameManager.increment_combo()
        var special_info := GameManager.detect_special_pattern(matches, swapped_pos)

        # 1. Highlight matched gems
        await _highlight_matches(matches)

        # 2. Activate any special gems in the matches
        await _activate_specials_in_matches(matches)

        # 3. Remove matched gems and create special if applicable
        var removed_count := GameManager.remove_matches(matches, special_info)
        GameManager.add_score(removed_count)

        # 4. Animate destruction
        await _animate_match_destruction(matches, special_info)

        # 5. Apply gravity - gems fall down
        await _animate_gravity(GameManager.apply_gravity())

        # 6. Refill empty spaces from top
        await _animate_refill(GameManager.fill_empty_spaces())

        # Next iteration checks for new matches
        swapped_pos = Vector2i(-1, -1)  # No swapped position for cascades
```

### 7. Gravity System

```gdscript
func apply_gravity() -> Array[Dictionary]:
    var movements: Array[Dictionary] = []

    # Process each column from bottom to top
    for x in range(grid_width):
        var write_y = grid_height - 1  # Bottom position to write to

        # Scan from bottom to top
        for read_y in range(grid_height - 1, -1, -1):
            if grid[x][read_y]["color"] != Enums.GemColor.NONE:
                if read_y != write_y:
                    # Move gem down
                    movements.append({
                        "from": Vector2i(x, read_y),
                        "to": Vector2i(x, write_y)
                    })
                    grid[x][write_y] = grid[x][read_y].duplicate()
                    grid[x][read_y] = {"color": Enums.GemColor.NONE, "special": Enums.SpecialType.NONE}
                write_y -= 1

    return movements

func fill_empty_spaces() -> Array[Vector2i]:
    var filled: Array[Vector2i] = []

    for x in range(grid_width):
        for y in range(grid_height):
            if grid[x][y]["color"] == Enums.GemColor.NONE:
                grid[x][y]["color"] = _get_random_color()
                grid[x][y]["special"] = Enums.SpecialType.NONE
                filled.append(Vector2i(x, y))

    return filled
```

### 8. Move Validation

```gdscript
func can_swap(pos1: Vector2i, pos2: Vector2i) -> bool:
    # Must be adjacent (Manhattan distance = 1)
    var diff = (pos1 - pos2).abs()
    if diff.x + diff.y != 1:
        return false

    # Both positions must be valid
    if not _is_valid_position(pos1) or not _is_valid_position(pos2):
        return false

    return true

func has_possible_moves() -> bool:
    # Check every position for potential swaps
    for x in range(grid_width):
        for y in range(grid_height):
            # Check swap right
            if x < grid_width - 1:
                if _would_create_match(Vector2i(x, y), Vector2i(x + 1, y)):
                    return true
            # Check swap down
            if y < grid_height - 1:
                if _would_create_match(Vector2i(x, y), Vector2i(x, y + 1)):
                    return true
    return false

func _would_create_match(pos1: Vector2i, pos2: Vector2i) -> bool:
    # Temporarily swap
    var temp = grid[pos1.x][pos1.y].duplicate()
    grid[pos1.x][pos1.y] = grid[pos2.x][pos2.y].duplicate()
    grid[pos2.x][pos2.y] = temp

    # Check for matches
    var has_match = not find_matches().is_empty()

    # Swap back
    temp = grid[pos1.x][pos1.y].duplicate()
    grid[pos1.x][pos1.y] = grid[pos2.x][pos2.y].duplicate()
    grid[pos2.x][pos2.y] = temp

    return has_match
```

---

## Visual System (GameBoard & Gem)

### Board Layout Calculation

The board automatically adapts to screen size:

```gdscript
func _calculate_layout() -> void:
    var viewport_size := get_viewport_rect().size
    var margins := ConfigManager.get_margins(viewport_size)

    # Available space after margins
    var available_width: float = viewport_size.x - margins["sides"] * 2
    var available_height: float = viewport_size.y - margins["top"] - margins["bottom"]

    # Calculate tile size to fit grid
    tile_size = min(
        available_width / GameManager.grid_width,
        available_height / GameManager.grid_height
    )

    # Clamp to min/max
    tile_size = clamp(tile_size, ConfigManager.get_min_tile_size(), ConfigManager.get_max_tile_size())

    # Center the board
    var board_size := Vector2(tile_size * GameManager.grid_width, tile_size * GameManager.grid_height)
    grid_offset = Vector2(
        (viewport_size.x - board_size.x) / 2.0,
        margins["top"] + (available_height - board_size.y) / 2.0
    )
```

### Gem Visual Management

Gems handle their own texture loading and scaling:

```gdscript
func _update_visual() -> void:
    var theme_texture := ConfigManager.get_gem_texture(gem_color)
    if theme_texture:
        sprite.texture = theme_texture
        # Scale based on actual texture size vs target tile size
        var tex_size := float(theme_texture.get_width())
        var target_size := float(ConfigManager.get_base_gem_size()) * _tile_scale
        _sprite_scale = target_size / tex_size
        sprite.scale = Vector2(_sprite_scale, _sprite_scale)
    else:
        # Fallback: procedurally generated colored circle
        sprite.texture = _create_circle_texture()
        sprite.modulate = ConfigManager.get_gem_fallback_color(gem_color)
        _sprite_scale = _tile_scale
        sprite.scale = Vector2(_sprite_scale, _sprite_scale)
```

### Animation System

All animations use Godot Tweens for smooth interpolation:

```gdscript
# Swap animation
func animate_swap_to(target_pos: Vector2, duration: float) -> Tween:
    var tween := create_tween()
    tween.tween_property(self, "position", target_pos, duration).set_ease(Tween.EASE_IN_OUT)
    return tween

# Destroy animation (shrink + rotate + fade)
func animate_destroy() -> Tween:
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(sprite, "scale", Vector2.ZERO, duration)
    tween.tween_property(sprite, "rotation", TAU, duration)
    tween.tween_property(self, "modulate:a", 0.0, duration)
    return tween

# Drop animation (gravity)
func animate_to_position(target_pos: Vector2, duration: float) -> Tween:
    var tween := create_tween()
    tween.tween_property(self, "position", target_pos, duration).set_ease(Tween.EASE_OUT)
    return tween

# Spawn animation (scale up with bounce)
func animate_spawn() -> Tween:
    sprite.scale = Vector2.ZERO
    var tween := create_tween()
    tween.tween_property(sprite, "scale", Vector2(_sprite_scale, _sprite_scale), duration)
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    return tween
```

### Input Handling

Gems detect both clicks and swipes:

```gdscript
func _input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
        return

    if event.pressed:
        # Start potential swipe
        var local_pos := to_local(event.global_position)
        if _get_click_rect().has_point(local_pos):
            _swipe_start_pos = event.global_position
            _touch_started = true
    elif _touch_started:
        var swipe_vector: Vector2 = event.global_position - _swipe_start_pos
        if swipe_vector.length() >= SWIPE_THRESHOLD:
            # Emit swipe in cardinal direction
            swiped.emit(self, _get_swipe_direction(swipe_vector))
        else:
            # Treat as click
            clicked.emit(self)
        _touch_started = false

func _get_swipe_direction(swipe_vector: Vector2) -> Vector2:
    if abs(swipe_vector.x) > abs(swipe_vector.y):
        return Vector2(sign(swipe_vector.x), 0)
    else:
        return Vector2(0, sign(swipe_vector.y))
```

---

## Configuration System

### GameConfig Resource

All gameplay parameters are externalized to a Resource file:

```gdscript
extends Resource
class_name GameConfig

# Grid dimensions and match rules
@export var grid_width: int = 8
@export var grid_height: int = 8
@export var min_match: int = 3

# Animation timing (seconds) - tune for game feel
@export var swap_duration: float = 0.2
@export var drop_duration: float = 0.15      # Per row of gravity
@export var explode_duration: float = 0.3
@export var spawn_duration: float = 0.25
@export var match_highlight_time: float = 0.1

# Scoring
@export var score_per_gem: int = 10
@export var combo_multiplier: float = 1.5    # Exponential per cascade

# Visual sizing
@export var base_gem_size: int = 64          # Reference size for scaling
@export var min_tile_size: float = 40.0
@export var max_tile_size: float = 100.0

# Win/lose conditions
@export var starting_moves: int = 30
@export var target_score: int = 10000

# Responsive margins (varies by orientation)
@export var margin_top_portrait: float = 180.0
@export var margin_bottom_portrait: float = 100.0
@export var margin_sides_portrait: float = 20.0
@export var margin_top_landscape: float = 80.0
@export var margin_bottom_landscape: float = 60.0
@export var margin_sides_landscape: float = 200.0

# Feature toggles - each special combination can be disabled
@export var enable_special_combinations: bool = true
@export var combo_striped_striped: bool = true
@export var combo_wrapped_wrapped: bool = true
@export var combo_colorbomb_colorbomb: bool = true
@export var combo_striped_wrapped: bool = true
@export var combo_colorbomb_striped: bool = true
@export var combo_colorbomb_wrapped: bool = true
@export var combo_colorbomb_regular: bool = true

# Booster toggles and inventory
@export var enable_boosters: bool = true
@export var booster_lollipop_hammer: bool = true
@export var booster_free_switch: bool = true
@export var booster_shuffle: bool = true
@export var booster_color_bomb_start: bool = true
@export var booster_extra_moves: bool = true
@export var extra_moves_amount: int = 5
@export var start_lollipop_hammer: int = 3
@export var start_free_switch: int = 3
@export var start_shuffle: int = 2
@export var start_color_bomb_start: int = 1
@export var start_extra_moves: int = 2
```

### Theme System

The theme system allows complete visual reskinning without code changes:

**ThemeConfig Resource Structure:**
- `gem_texture_1` through `gem_texture_6`: Texture2D for each gem color
- `striped_h_overlay`, `striped_v_overlay`, `wrapped_overlay`, `color_bomb_texture`: Special type overlays
- `background_texture`, `background_color`, `board_background_color`: Background visuals
- `swap_sound`, `match_sound`, `special_sound`: Audio streams

**How Theme Loading Works:**

1. ConfigManager loads theme resource on startup
2. Gem.gd queries ConfigManager for textures
3. If theme texture exists, use it with automatic scaling
4. If no texture, fall back to procedurally generated colored circles

**Critical: Texture Scaling**

Theme textures can be ANY size. The Gem must calculate scale factor:

```gdscript
var tex_size := float(texture.get_width())
var target_size := float(base_gem_size) * tile_scale
var sprite_scale := target_size / tex_size
sprite.scale = Vector2(sprite_scale, sprite_scale)
```

This ensures a 226x226 texture displays the same as a 64x64 texture.

### Configuration Philosophy

Not everything should be configurable. Over-configuration leads to bloated, hard-to-maintain code. Follow these guidelines:

**Always Configure (externalize to resource files):**
- Timing values (animation durations, delays)
- Scoring formulas and multipliers
- Grid dimensions and match rules
- Win/lose conditions (moves, targets)
- Feature toggles (enable/disable mechanics)
- Visual sizing and margins
- Audio volume levels

**Consider Configuring:**
- Color palettes (if themes aren't enough)
- Difficulty modifiers
- Tutorial flags

**Keep Hardcoded:**
- Core algorithm logic (match detection, gravity)
- Coordinate systems and math
- State machine transitions
- Signal names and connections
- Animation easing curves (unless you need runtime tuning)

**Rule of Thumb:** If a designer or artist might want to tweak it without programmer help, make it configurable. If changing it would break game logic, keep it in code.

### Theme Management Architecture

Separating visual presentation from game logic enables:
- Multiple visual themes (candy, gems, fruit, seasonal)
- Easy reskinning for different markets
- Artist iteration without code changes
- A/B testing different art styles

**Theme Separation Layers:**

```
┌─────────────────────────────────────────────────────────────┐
│                     GAME LOGIC LAYER                         │
│  (GameManager, match detection, scoring, win conditions)     │
│  - Knows nothing about textures, colors, or sounds           │
│  - Works with abstract GemColor enum values                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Queries via ConfigManager
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    CONFIG MANAGER LAYER                      │
│  - Loads and caches theme resources                          │
│  - Provides getters: get_gem_texture(color), get_sound()     │
│  - Handles fallbacks when assets missing                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Loads from
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     THEME RESOURCE FILES                     │
│  theme_candy.tres, theme_gems.tres, theme_fruit.tres         │
│  - All visual assets: textures, colors, sounds               │
│  - Editable in Godot editor without code                     │
└─────────────────────────────────────────────────────────────┘
```

**Theme Resource Best Practices:**

```gdscript
extends Resource
class_name ThemeConfig

# Theme identification
@export var theme_name: String = "default"
@export var theme_description: String = ""

# Gem visuals - one texture per color
@export var gem_texture_1: Texture2D  # Maps to GemColor.RED
@export var gem_texture_2: Texture2D  # Maps to GemColor.ORANGE
# ... etc

# Fallback colors (used when textures are null)
@export var fallback_color_1: Color = Color.RED
@export var fallback_color_2: Color = Color.ORANGE
# ... etc

# Special overlays
@export var striped_h_overlay: Texture2D
@export var striped_v_overlay: Texture2D
@export var wrapped_overlay: Texture2D
@export var color_bomb_texture: Texture2D

# UI colors - allows complete UI reskinning
@export var ui_panel_color: Color
@export var ui_button_color: Color
@export var ui_text_color: Color
@export var ui_accent_color: Color

# Audio
@export var swap_sound: AudioStream
@export var match_sound: AudioStream
@export var special_sound: AudioStream
@export var cascade_sound: AudioStream

# Background
@export var background_texture: Texture2D
@export var background_color: Color
@export var board_background_color: Color
```

**Runtime Theme Switching:**

```gdscript
# In ConfigManager
var _current_theme: ThemeConfig

func load_theme(theme_path: String) -> bool:
    var theme = load(theme_path) as ThemeConfig
    if theme:
        _current_theme = theme
        theme_changed.emit()  # Notify all listeners to refresh visuals
        return true
    return false

func get_gem_texture(color: Enums.GemColor) -> Texture2D:
    if not _current_theme:
        return null
    match color:
        Enums.GemColor.RED: return _current_theme.gem_texture_1
        Enums.GemColor.ORANGE: return _current_theme.gem_texture_2
        # ... etc
    return null
```

---

## Level Configuration System

A robust level system separates level data from game code, enabling:
- Level designers to create content without programming
- External level editors (future tooling)
- Easy difficulty tuning and A/B testing
- Procedural level generation
- Player-created levels (if desired)

### Level Resource Structure

```gdscript
extends Resource
class_name LevelConfig

# Level identification
@export var level_number: int = 1
@export var level_name: String = ""

# Level type determines win condition
@export var level_type: Enums.LevelType = Enums.LevelType.SCORE_TARGET

# Move budget
@export var max_moves: int = 25

# Goal targets (use based on level_type)
@export var target_score: int = 5000
@export var target_clears: int = 50
@export var target_combos: int = 5
@export var target_specials: int = 3

# Collection goals (for COLOR_COLLECTION type)
@export var target_color_1: Enums.GemColor = Enums.GemColor.RED
@export var target_color_1_count: int = 20
@export var target_color_2: Enums.GemColor = Enums.GemColor.BLUE
@export var target_color_2_count: int = 20

# Difficulty tuning
@export_range(3, 6) var gem_types_count: int = 6  # Fewer colors = easier
@export var grid_width: int = 8
@export var grid_height: int = 8

# Star thresholds
@export var star_1_threshold: int = 1000
@export var star_2_threshold: int = 3000
@export var star_3_threshold: int = 5000

# Human-readable goal description
@export_multiline var goal_description: String = "Reach the target score!"

# Optional: Board layout (for shaped boards)
@export var board_mask: PackedByteArray  # 1 = playable, 0 = blocked

# Optional: Pre-placed pieces
@export var initial_pieces: Array[Dictionary]  # [{pos: Vector2i, color: int, special: int}]

# Optional: Blocker placements
@export var blockers: Array[Dictionary]  # [{pos: Vector2i, type: int, layers: int}]
```

### Level Type Enum

```gdscript
# In Enums.gd
enum LevelType {
    SCORE_TARGET,      # Reach X points
    CLEAR_COUNT,       # Clear X total gems
    COMBO_CHALLENGE,   # Achieve X cascades
    SPECIAL_CREATION,  # Create X special gems
    COLOR_COLLECTION,  # Collect specific colors
    CLEAR_BLOCKERS,    # Remove all blockers
    INGREDIENT_DROP,   # Bring items to exits
    MIXED              # Multiple objectives
}
```

### Level Loading System

```gdscript
# In ConfigManager
const LEVELS_PATH = "res://config/levels/"
var _levels_cache: Dictionary = {}  # level_number -> LevelConfig

func load_level(level_number: int) -> LevelConfig:
    # Check cache first
    if _levels_cache.has(level_number):
        return _levels_cache[level_number]

    # Try to load from file
    var path = LEVELS_PATH + "level_%d.tres" % level_number
    if ResourceLoader.exists(path):
        var level = load(path) as LevelConfig
        if level:
            _levels_cache[level_number] = level
            return level

    # Return null if not found (caller handles missing levels)
    return null

func get_max_levels() -> int:
    # Count level files or use a manifest
    var count = 0
    var dir = DirAccess.open(LEVELS_PATH)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.begins_with("level_") and file_name.ends_with(".tres"):
                count += 1
            file_name = dir.get_next()
    return count
```

### Level File Organization

```
config/
└── levels/
    ├── level_1.tres     # Tutorial: Score Target
    ├── level_2.tres     # Tutorial: Clear Count
    ├── level_3.tres     # Easy challenge
    ├── level_4.tres
    ├── level_5.tres
    ├── ...
    └── level_manifest.tres  # Optional: metadata about all levels
```

### Win Condition Checking

```gdscript
# In GameManager
func check_level_complete() -> bool:
    var level := ConfigManager.get_current_level()
    if not level:
        return score >= target_score  # Fallback

    match level.level_type:
        Enums.LevelType.SCORE_TARGET:
            return score >= level.target_score
        Enums.LevelType.CLEAR_COUNT:
            return gems_cleared >= level.target_clears
        Enums.LevelType.COMBO_CHALLENGE:
            return combos_achieved >= level.target_combos
        Enums.LevelType.SPECIAL_CREATION:
            return specials_created >= level.target_specials
        Enums.LevelType.COLOR_COLLECTION:
            var c1 = color_gems_collected.get(level.target_color_1, 0)
            var c2 = color_gems_collected.get(level.target_color_2, 0)
            return c1 >= level.target_color_1_count and c2 >= level.target_color_2_count
    return false

func get_goal_progress() -> Dictionary:
    # Returns current progress for UI display
    var level := ConfigManager.get_current_level()
    match level.level_type:
        Enums.LevelType.SCORE_TARGET:
            return {current = score, target = level.target_score, label = "Score"}
        Enums.LevelType.CLEAR_COUNT:
            return {current = gems_cleared, target = level.target_clears, label = "Cleared"}
        # ... etc
    return {}
```

### Designing for External Level Editors

To support future level editor tools, follow these principles:

**1. Human-Readable Format:**
Godot `.tres` files are text-based and can be parsed by external tools:

```
[gd_resource type="Resource" script_class="LevelConfig" ...]

[resource]
level_number = 5
level_type = 2
max_moves = 25
target_score = 3000
goal_description = "Clear 50 gems!"
```

**2. Validation Function:**
Add a validation method to catch editor mistakes:

```gdscript
# In LevelConfig
func validate() -> Array[String]:
    var errors: Array[String] = []

    if level_number < 1:
        errors.append("Level number must be positive")
    if max_moves < 5:
        errors.append("Minimum 5 moves required")
    if level_type == Enums.LevelType.SCORE_TARGET and target_score < 100:
        errors.append("Score target too low")
    # ... more validation

    return errors
```

**3. JSON Export/Import:**
For web-based editors, support JSON conversion:

```gdscript
func to_json() -> Dictionary:
    return {
        "level_number": level_number,
        "level_type": level_type,
        "max_moves": max_moves,
        "target_score": target_score,
        # ... all fields
    }

static func from_json(data: Dictionary) -> LevelConfig:
    var config = LevelConfig.new()
    config.level_number = data.get("level_number", 1)
    config.level_type = data.get("level_type", 0)
    # ... all fields
    return config
```

**4. Level Manifest:**
For editor integration, maintain a manifest file:

```gdscript
extends Resource
class_name LevelManifest

@export var total_levels: int = 0
@export var level_metadata: Array[Dictionary]  # [{number, type, difficulty, status}]
@export var last_modified: String = ""
```

---

## Signal Flow

### GameManager Signals

```gdscript
signal score_changed(new_score: int)
signal moves_changed(moves_left: int)
signal combo_changed(combo_count: int)
signal game_over()
signal special_created(position: Vector2i, special_type: Enums.SpecialType)
signal board_settled()
```

### GameBoard Signals

```gdscript
signal move_completed()
signal board_idle()
signal gems_destroyed(count: int)
signal layout_changed()
```

### Gem Signals

```gdscript
signal clicked(gem: Gem)
signal swiped(gem: Gem, direction: Vector2)
```

### BoosterManager Signals

```gdscript
signal booster_activated(booster_type: Enums.BoosterType)
signal booster_used(booster_type: Enums.BoosterType)
signal booster_cancelled()
signal inventory_changed()
```

---

## Booster System

### Booster Types

1. **Lollipop Hammer**: Click any gem to destroy it instantly
2. **Free Switch**: Swap any two adjacent gems without requiring a match
3. **Shuffle**: Instantly reshuffle the entire board
4. **Color Bomb Start**: Place a Color Bomb special on a random gem
5. **Extra Moves**: Add 5 additional moves

### Booster Flow

```gdscript
# BoosterManager.gd
var active_booster: Enums.BoosterType = Enums.BoosterType.NONE
var inventory: Dictionary = {}

func activate_booster(booster_type: Enums.BoosterType) -> bool:
    if not has_booster(booster_type):
        return false
    active_booster = booster_type
    booster_activated.emit(booster_type)
    return true

func use_booster() -> void:
    inventory[active_booster] = max(0, inventory[active_booster] - 1)
    var used_type := active_booster
    active_booster = Enums.BoosterType.NONE
    booster_used.emit(used_type)
    inventory_changed.emit()

# GameBoard.gd - Handle booster clicks
func _on_gem_clicked(gem: Gem) -> void:
    if BoosterManager.is_booster_active():
        _handle_booster_click(gem)
        return
    # Normal selection logic...

func _handle_booster_click(gem: Gem) -> void:
    match BoosterManager.get_active_booster():
        Enums.BoosterType.LOLLIPOP_HAMMER:
            await _use_lollipop_hammer(gem)
        Enums.BoosterType.FREE_SWITCH:
            _handle_free_switch(gem)
        _:
            BoosterManager.cancel_booster()
```

---

## Game Flow State Machine

```
┌─────────────────────────────────────────────────────────────┐
│                         IDLE                                 │
│  - Waiting for player input                                  │
│  - Can select gems, activate boosters                        │
└─────────────────────┬───────────────────────────────────────┘
                      │ Player swaps gems
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                      PROCESSING                              │
│  - GameManager.processing_moves = true                       │
│  - Input is blocked                                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│  SWAP ANIMATION │     │ SPECIAL COMBO   │
│                 │     │ (if two specials│
│                 │     │  swapped)       │
└────────┬────────┘     └────────┬────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    CHECK MATCHES                             │
└─────────────────────┬───────────────────────────────────────┘
         │                       │
    No matches              Has matches
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────────────────────────┐
│  REVERT SWAP    │     │            CASCADE LOOP              │
│  (animate back) │     │  1. Increment combo                  │
└────────┬────────┘     │  2. Highlight matches                │
         │              │  3. Activate special gems            │
         │              │  4. Remove & score matches           │
         │              │  5. Create special if pattern found  │
         │              │  6. Animate destruction              │
         │              │  7. Apply gravity                    │
         │              │  8. Refill from top                  │
         │              │  9. Check for new matches → repeat   │
         │              └─────────────────┬───────────────────┘
         │                                │
         └────────────────┬───────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    CHECK GAME STATE                          │
│  - If no moves left and score < target → GAME OVER          │
│  - If score >= target → WIN                                  │
│  - If no possible moves → SHUFFLE                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                         IDLE                                 │
│  - GameManager.processing_moves = false                      │
│  - board_idle signal emitted                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Complete Swap & Match Flow

This section describes the exact sequence of operations when a player makes a move.

### Step 1: Input Validation

```gdscript
# When player clicks/swipes to swap gem at pos1 with gem at pos2:
if GameManager.processing_moves:
    return  # Ignore input during animations

if not GameManager.can_swap(pos1, pos2):
    return  # Must be adjacent (Manhattan distance = 1)
```

### Step 2: Animate Swap

```gdscript
GameManager.processing_moves = true  # Block further input

# Animate both gems moving to each other's position
var tween1 := gem1.animate_swap_to(gem2.position)
gem2.animate_swap_to(gem1.position)
await tween1.finished

# Update data structures
GameManager.swap_gems(pos1, pos2)
gem1.grid_position = pos2
gem2.grid_position = pos1
gems[pos1.x][pos1.y] = gem2
gems[pos2.x][pos2.y] = gem1
```

### Step 3: Check Special Combinations

Before checking normal matches, check if two special gems were swapped:

```gdscript
var combo_type := SpecialCombinations.detect_combination(gem1, gem2)
if combo_type != SpecialCombinations.ComboType.NONE:
    GameManager.use_move()  # Deduct move
    GameManager.reset_combo()  # Start fresh combo chain
    await _execute_special_combination(combo_type, pos1, pos2, gem1, gem2)
    await _finish_move()
    return
```

### Step 4: Check for Matches

```gdscript
var matches := GameManager.find_matches()
if matches.is_empty():
    # No match - revert the swap
    await _revert_swap(gem1, gem2, original_pos1, original_pos2)
    GameManager.processing_moves = false
    return

# Valid match - consume the move
GameManager.use_move()
GameManager.reset_combo()
```

### Step 5: Cascade Loop

```gdscript
await _process_cascade(swapped_position)

func _process_cascade(swapped_pos: Vector2i) -> void:
    for cascade_depth in 50:  # Safety limit
        var matches := GameManager.find_matches()
        if matches.is_empty():
            break  # Cascade complete

        # 5a. Increment combo counter
        GameManager.increment_combo()

        # 5b. Detect if this match creates a special gem
        var special_info := GameManager.detect_special_pattern(matches, swapped_pos)

        # 5c. Brief highlight animation
        await _highlight_matches(matches)

        # 5d. If any matched gems are special, activate them first
        await _activate_specials_in_matches(matches)

        # 5e. Remove matched gems from grid, keeping special position
        var removed_count := GameManager.remove_matches(matches, special_info)
        GameManager.add_score(removed_count)

        # 5f. Animate destruction (except special gem position)
        await _animate_match_destruction(matches, special_info)

        # 5g. Apply gravity - fill gaps from above
        await _animate_gravity(GameManager.apply_gravity())

        # 5h. Spawn new gems at top
        await _animate_refill(GameManager.fill_empty_spaces())

        # Subsequent cascades don't have a "swapped" position
        swapped_pos = Vector2i(-1, -1)
```

### Step 6: Finish Move

```gdscript
func _finish_move() -> void:
    GameManager.processing_moves = false
    move_completed.emit()

    # Check if board is stuck
    if not GameManager.has_possible_moves():
        await _shuffle_until_valid()

    board_idle.emit()
```

### Step 7: Check Win/Lose Conditions

```gdscript
# In Main.gd, connected to GameManager signals:
func _on_score_changed(new_score: int) -> void:
    if new_score >= GameManager.target_score:
        _show_end_dialog("You Win!")

func _on_moves_changed(moves_left: int) -> void:
    if moves_left <= 0 and GameManager.score < GameManager.target_score:
        GameManager.game_over.emit()
```

---

## Scene Structure (Minimal)

**Main Scene**: Root Node2D with UI layer, GameBoard child, and dialogs
**GameBoard**: Node2D that dynamically spawns Gem instances as children
**Gem**: Area2D with Sprite2D for visuals and CollisionShape2D for input

Gems are instantiated from a PackedScene and added/removed dynamically during gameplay.

---

## Scoring Formula

```gdscript
func add_score(gem_count: int) -> void:
    var base_score = gem_count * score_per_gem
    var combo_bonus = pow(combo_multiplier, combo_count)
    var total = int(base_score * combo_bonus)
    score += total
    score_changed.emit(score)
```

| Gems | Combo | Multiplier | Score |
|------|-------|------------|-------|
| 3    | 0     | 1.0x       | 30    |
| 3    | 1     | 1.5x       | 45    |
| 3    | 2     | 2.25x      | 67    |
| 4    | 0     | 1.0x       | 40    |
| 5    | 0     | 1.0x       | 50    |

Special creation bonuses:
- Match-4 (Striped): +50
- Match-5 L/T (Wrapped): +150
- Match-5 line (Color Bomb): +100

---

## Performance Considerations

1. **Object Pooling**: Gems are freed and recreated. For higher performance, implement pooling.

2. **Tween Management**: Always check `_can_animate()` before creating tweens:
   ```gdscript
   func _can_animate() -> bool:
       return not is_queued_for_deletion() and is_inside_tree()
   ```

3. **Grid Operations**: Avoid redundant grid scans. The match detection is O(n*m) where n=width, m=height.

4. **Signal Connections**: Disconnect signals when gems are freed to avoid orphan connections.

---

## Testing Checklist

### Basic Mechanics
- [ ] Horizontal 3-match works
- [ ] Vertical 3-match works
- [ ] Match-4 creates correct striped type
- [ ] Match-5 line creates color bomb
- [ ] Match-5 L/T creates wrapped gem

### Special Activations
- [ ] Striped-H clears entire row
- [ ] Striped-V clears entire column
- [ ] Wrapped explodes 3x3 area
- [ ] Color bomb clears all of swapped color

### Combinations
- [ ] Striped + Striped = cross
- [ ] Wrapped + Wrapped = 5x5
- [ ] Striped + Wrapped = 3 rows + 3 cols
- [ ] Color Bomb + Striped = transform & activate
- [ ] Color Bomb + Wrapped = transform & activate
- [ ] Color Bomb + Color Bomb = clear board

### Cascade System
- [ ] Chain reactions trigger correctly
- [ ] Combo counter increments
- [ ] Gravity fills gaps properly
- [ ] New gems spawn from top

### Edge Cases
- [ ] Invalid swaps revert
- [ ] No-moves triggers shuffle
- [ ] Game over at 0 moves
- [ ] Win at target score
- [ ] Screen resize adapts layout

### Boosters
- [ ] Hammer destroys single gem
- [ ] Free switch allows any swap
- [ ] Shuffle reorganizes board
- [ ] Color bomb start places bomb
- [ ] Extra moves adds 5 moves

---

## Extension Points

### Adding New Gem Colors
1. Add enum value to `Enums.GemColor`
2. Add texture to theme config
3. Add fallback color to `GameConfig.get_gem_fallback_color()`

### Adding New Special Types
1. Add enum value to `Enums.SpecialType`
2. Implement activation logic in `GameManager.get_special_activation_targets()`
3. Add detection pattern in `GameManager.detect_special_pattern()`
4. Add visual overlay in `Gem._update_special_overlay()`

### Adding New Boosters
1. Add enum value to `Enums.BoosterType`
2. Add inventory tracking in `BoosterManager`
3. Add config options in `GameConfig`
4. Implement effect in `GameBoard._handle_booster_click()`
5. Add UI button in `Main.tscn`

### Adding Obstacles
Create new node types that integrate with the grid:
- **Ice**: Requires multiple matches to clear
- **Blocker**: Immovable obstacle
- **Locked**: Can't be swapped until adjacent match

---

## Code Style Guidelines

1. **Static Typing**: All variables and parameters use explicit types
2. **Underscore Prefix**: Private methods start with `_`
3. **Signals for Events**: Use signals for loose coupling
4. **Tweens for Animation**: All animations use `create_tween()`
5. **Config Access**: Always go through `ConfigManager`, never access resources directly
6. **Separation**: Game logic in `GameManager`, visuals in `GameBoard`/`Gem`

---

## Critical Gameplay Edge Cases

### 1. Data/Visual Synchronization

The grid data (GameManager.grid) and visual gems (GameBoard.gems) must stay synchronized:

```gdscript
# WRONG - visual updated but data not:
gems[x][y].queue_free()

# RIGHT - always update both:
GameManager.set_gem_data(pos, Enums.GemColor.NONE)  # Clear data
gems[x][y].queue_free()  # Remove visual
gems[x][y] = null  # Clear reference
```

### 2. Special Gem Self-Destruction

When a special gem activates, it must destroy itself AFTER getting its targets:

```gdscript
func _activate_special_gem(gem: Gem) -> void:
    var pos := gem.grid_position
    var targets := GameManager.get_special_activation_targets(pos, gem.special_type)

    # Animate activation
    await gem.animate_special_activation().finished

    # NOW destroy the special gem itself
    _remove_gem(gem)  # Clears data AND visual

    # Then destroy targets
    for target_pos in targets:
        # ... destroy target gems
```

### 3. Chain Activation of Specials

When a special's activation hits another special, that special must also activate:

```gdscript
var chain_specials: Array[Gem] = []
for target_pos in targets:
    var target_gem := get_gem_at(target_pos)
    if target_gem and target_gem.is_special():
        chain_specials.append(target_gem)

# Destroy non-special targets first
await _animate_destruction(regular_gems)

# Then recursively activate chained specials
for chain_gem in chain_specials:
    if chain_gem and is_instance_valid(chain_gem):
        await _activate_special_gem(chain_gem)
```

### 4. Empty Cells After Cascades

A common bug is empty cells remaining after chain reactions. Causes:
- Special gem not destroyed after activation
- Target gems removed from visual but not from grid data
- Gravity not applied after special activation

**Solution**: Always call gravity + refill after any destruction:

```gdscript
# After destroying any gems:
await _animate_gravity(GameManager.apply_gravity())
await _animate_refill(GameManager.fill_empty_spaces())
```

### 5. Color Bomb + Adjacent Gem

Color bomb needs a color to target. Get it from an adjacent gem:

```gdscript
if gem.special_type == Enums.SpecialType.COLOR_BOMB:
    # Find adjacent gem to determine target color
    for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
        var adj_gem := get_gem_at(pos + offset)
        if adj_gem and adj_gem.gem_color != Enums.GemColor.NONE:
            targets = GameManager.get_color_bomb_targets(adj_gem.gem_color)
            break
```

### 6. Preventing Invalid Board States

After every move, ensure board is playable:

```gdscript
func _finish_move() -> void:
    GameManager.processing_moves = false

    # CRITICAL: Check if any moves are possible
    if not GameManager.has_possible_moves():
        await _shuffle_until_valid()  # Reshuffle until valid

    board_idle.emit()

func _shuffle_until_valid() -> void:
    for attempt in 100:  # Safety limit
        GameManager.shuffle_board()
        # Ensure no immediate matches AND at least one valid move
        if GameManager.find_matches().is_empty() and GameManager.has_possible_moves():
            break
    # Update all gem visuals to match new grid state
    _sync_visuals_to_grid()
```

### 7. Animation Safety Checks

Always verify gems are still valid before animating:

```gdscript
func _can_animate() -> bool:
    return not is_queued_for_deletion() and is_inside_tree()

func animate_destroy() -> Tween:
    if not _can_animate():
        return null  # Gem already being destroyed
    # ... create tween
```

### 8. Combo Counter Timing

Reset combo at START of player action, increment during cascades:

```gdscript
# Player initiates swap:
GameManager.reset_combo()  # combo = 0

# First cascade match:
GameManager.increment_combo()  # combo = 1 → "Awesome!"

# Second cascade (chain reaction):
GameManager.increment_combo()  # combo = 2 → "Amazing!"
```

---

## Common Pitfalls

1. **Async/Await**: Always `await` animation tweens before modifying state
2. **Grid vs Visual**: Keep grid data (GameManager) and visuals (GameBoard) in sync
3. **Texture Scaling**: Theme textures may be any size - scale based on actual dimensions
4. **Signal Order**: Ensure signals are connected in `_ready()` before game starts
5. **Combo Reset**: Reset combo counter at start of each player move, not cascade
6. **Special Cleanup**: When activating specials, destroy the special gem itself too
7. **is_instance_valid()**: Always check before accessing potentially-freed gems
8. **Cascade Depth Limit**: Use a safety limit (e.g., 50) to prevent infinite loops

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-14 | Initial document |
| 1.1 | 2026-01-16 | Generalized for any match-3 project |
| 1.2 | 2026-01-16 | Added Configuration Philosophy, Theme Management Architecture, Level Configuration System sections |

---

*This document provides patterns and algorithms for building match-3 games in Godot 4.5. The code examples are illustrative - adapt class names, file organization, and specific implementations to your project's needs.*
