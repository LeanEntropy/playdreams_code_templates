# Arrow Puzzle - AI Development Guide

## Project Overview

A grid-based arrow puzzle where players tap arrows to clear them when their exit path is unblocked. Arrows point in a direction (U/D/L/R) and can only be removed when no other arrow blocks their path to the grid edge. Incorrect taps cost hearts. Portrait orientation (720x1280), mobile-optimized, GL Compatibility renderer.

### Core Architecture

```
Main (Node2D) - scripts/main.gd
  Orchestrates screen transitions via signals
  +-- StartScreen - Home screen with play button
  +-- GameBoard (Node2D) - Grid, arrows, tap handling, zoom/pan
  |   +-- ArrowContainer - Holds Arrow (Area2D) instances
  |   +-- TrailContainer - Fade-out dot trails
  +-- HUD (CanvasLayer) - Hearts, tier, guide toggle
  +-- VictoryScreen - Level complete with confetti
  +-- SettingsScreen - Sound/vibration/dark mode toggles
Autoloads:
  GameManager - Level data, progress persistence (save/load)
  AudioManager - 5 sound effects + haptic feedback
```

## Theme System

A compile-time constant in `scripts/config.gd` selects the active visual theme:

```gdscript
const THEME: String = "minimal"  # "minimal" or "pastel"
```

Theme data lives in the `THEMES` dictionary in `config.gd`. Each theme defines:
- Background color, arrow colors (normal/exit/failed), guide line color
- Heart colors (full/empty), UI colors
- `arrow_style`: `"sharp"` (thin lines, triangle heads) or `"rounded"` (pill shapes, chevrons)
- `shadow_enabled`, `chevron_enabled`: rendering flags for pastel style
- `arrow_palette`: array of rotating per-arrow colors (pastel only)

**To add a custom theme:** Add a new entry to the `THEMES` dictionary with the same keys, then set `THEME` to its name. Only `arrow.gd` branches on `arrow_style`; all other scripts just read color values from the theme.

## Arrow Rendering

`scripts/arrow.gd` reads `Config.THEMES[Config.THEME]["arrow_style"]` and branches in `_draw()`:

- **"sharp"** (minimal): Thin body rectangles drawn via `_draw_body_segment()`, triangle head via `draw_colored_polygon()`. Single-cell arrows have a short tail stub.
- **"rounded"** (pastel): Rounded pill bodies with gaps between cells, drop shadows (offset by `shadow_offset`), white chevron on the arrow head. Per-arrow colors from `arrow_palette`.

Multi-cell arrows use a snake-like drawing system. On exit, the head advances at `EXIT_SPEED` while the tail follows the original cell path. Nudge animations use a decaying sine oscillation for blocked feedback.

## Level Data Format

Levels are stored in `data/levels.json` as `{"levels": [...]}`. Each level:

```json
{
  "name": "Level Name",
  "columns": 5,
  "rows": 6,
  "arrows": [
    {"path": [[col, row], [col, row], ...], "dir": "U"},
    {"path": [[2, 4], [2, 2]], "dir": "R"}
  ],
  "shape": [[0,0], [1,0], [2,0], ...],
  "palette": ["#4A7A8C", "#6EA8B8"],
  "tutorial": true
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name |
| `columns` | Yes | Grid width |
| `rows` | Yes | Grid height |
| `arrows` | Yes | Array of arrow definitions |
| `shape` | No | Active cells for non-rectangular grids (default: full rectangle) |
| `palette` | No | Color override for pastel theme |
| `tutorial` | No | Show "Tap an arrow!" hint |

**Arrow definition** uses waypoint format: `{"path": [[col,row], ...], "dir": "U/D/L/R"}`. Path lists waypoints from tail to head; intermediate cells are interpolated. The `dir` field is the direction the arrow head points (exit direction).

Alternative formats supported: `{col, row, dir}` (single-cell), `{col, row, dir, length}` (multi-cell straight), `{cells: [...], dir, head}` (explicit cells).

## Level Editor

Run `generator_screen.tscn` standalone (F6 in Godot editor) to generate and manage levels.

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Space | Generate new level |
| Enter | Save current level |
| P | Toggle play-test mode |
| S | Toggle solution overlay |
| Left/Right arrows | Browse existing levels |
| Delete | Delete current browsed level |

### Features
- Tier selection dropdown (Easy/Medium/Hard/Expert)
- Custom seed, grid size, and arrow count inputs
- Image mask loading for non-rectangular shapes (with resolution controls)
- Browse/reorder/duplicate/delete existing levels
- Play-test levels in-editor (hearts disabled)
- Solution overlay showing clear order numbers

## Procedural Generation

`scripts/level_generator.gd` uses Hamiltonian path splitting:

1. Find a Hamiltonian path through all active cells (Warnsdorf heuristic with DFS)
2. Split the path into N segments (one per arrow)
3. Assign head cell and direction to each segment (must not self-block)
4. Verify the puzzle is solvable via backtracking solver
5. Compute difficulty metrics (choice width, blocking depth)

Tier rules in `data/generator_rules.json`:

| Tier | Columns | Rows | Arrows |
|------|---------|------|--------|
| Easy | 4-5 | 4-5 | 3-5 |
| Medium | 5-6 | 5-7 | 4-6 |
| Hard | 6-8 | 7-9 | 4-6 |
| Expert | 7-9 | 8-10 | 4-7 |

## Config Tuning (scripts/config.gd)

| Constant | Default | Purpose |
|----------|---------|---------|
| `HEARTS_MAX` | 3 | Maximum hearts |
| `HEARTS_START` | 3 | Hearts at level start |
| `EXIT_SPEED` | 4800.0 | Arrow exit velocity (px/s) |
| `NUDGE_DURATION` | 0.3 | Blocked nudge time (s) |
| `ENTRANCE_DURATION` | 0.3 | Arrow entrance animation (s) |
| `ENTRANCE_STAGGER` | 0.05 | Delay between arrow entrances (s) |
| `ZOOM_MIN / ZOOM_MAX` | 0.5 / 2.0 | Zoom range |
| `FIXED_CELL_SIZE` | 65.0 | Base cell size (auto-zooms for large grids) |
| `GRID_MARGIN` | 40 | Pixel margin around grid |
| `VICTORY_DELAY` | 1.5 | Delay before victory screen (s) |

## Key Files

| File | Responsibility |
|------|---------------|
| `scripts/config.gd` | All constants, theme data, color definitions |
| `scripts/main.gd` | Screen flow orchestration and transitions |
| `scripts/game_board.gd` | Grid rendering, tap handling, zoom/pan, arrow lifecycle |
| `scripts/arrow.gd` | Arrow drawing (sharp/rounded), exit/nudge animations |
| `scripts/grid_system.gd` | Grid state, path-clear checks, collision detection |
| `scripts/level_generator.gd` | Hamiltonian path procedural generation + solver |
| `scripts/game_manager.gd` | Autoload: level data loading, progress save/load |
| `scripts/audio_manager.gd` | Autoload: 5 sounds (tap, exit, blocked, clear, click) + haptics |
| `scripts/hud.gd` | Hearts display, tier label, guide toggle |
| `scripts/start_screen.gd` | Home screen with play button and level info |
| `scripts/victory_screen.gd` | Victory animation with confetti |
| `scripts/settings_screen.gd` | Sound/vibration/dark mode toggles |
| `scripts/generator_screen.gd` | Level editor tool with browse/generate/test |
| `scripts/trail_effect.gd` | Fade-out dot trail on arrow exit |
| `data/levels.json` | Pre-designed level definitions |
| `data/generator_rules.json` | Tier parameters for procedural generation |

## Autoloads

| Name | Script | Purpose |
|------|--------|---------|
| GameManager | `scripts/game_manager.gd` | Loads levels.json, tracks current level + max unlocked, save/load to `user://progress.json` |
| AudioManager | `scripts/audio_manager.gd` | Loads .ogg files from `assets/audio/`, provides `play(name)` and `haptic(ms)` |

## Customization Guide

**Add a new visual theme:** Add a new entry to `THEMES` in `config.gd` with all required keys (copy an existing theme as a starting point). Set `THEME` constant to the new name. If the new theme needs a different arrow style, add a branch in `arrow.gd:_draw()`.

**Change grid sizes:** Edit tier ranges in `data/generator_rules.json`. For pre-designed levels, edit `columns`/`rows` in `data/levels.json`.

**Add new arrow types:** Extend `arrow.gd:_draw()` with new rendering logic. Add direction vectors to `Config.DIR_VECTORS` if adding diagonal arrows. Update `grid_system.gd:is_path_clear()` for new movement patterns.

**Create custom levels:** Use the level editor (F6 on `generator_screen.tscn`) or manually add entries to `data/levels.json` following the level data format above.

**Adjust difficulty:** Modify tier rules in `generator_rules.json` (grid sizes, arrow counts). Tune `HEARTS_START`/`HEARTS_MAX` in `config.gd`. Lower choice width = harder (fewer arrows clearable at each step).

**Change sounds:** Replace .ogg files in `assets/audio/`. Sound names are: `tap_arrow`, `arrow_exit`, `arrow_blocked`, `level_clear`, `ui_click`. AudioManager gracefully handles missing files.

**Non-rectangular grids:** Add a `"shape"` array to level JSON listing active `[col, row]` cells. Or use the mask-loading feature in the level editor to generate shapes from images.
