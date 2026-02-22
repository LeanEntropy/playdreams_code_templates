# CivArrows - Game Design Document

## Concept
Hyper-casual puzzle game. Player clears arrows from a grid by tapping them in the correct order. Arrows move only in the direction they point and block each other. The challenge is figuring out the removal sequence.

## Platform & Viewport
- Godot 4.6, GL Compatibility renderer
- Portrait mode: 720x1280
- Stretch mode: `canvas_items`, aspect: `expand`
- Touch input via Godot's `emulate_mouse_from_touch`

---

## Visual Design

### Board / Grid
- **Clean white/transparent background** - no visible cell grid, no grey cell rectangles
- **Fixed cell size** (65px base) so arrows always look the **same size** at game start across all levels
- Grids are centered on screen; larger grids auto-zoom-out to fit
- Smaller grids have more whitespace around them (NOT stretched to fill)
- Empty cells (no arrow) show a small **dot** at the cell center (#CCCCCC)
- Dots appear as arrows are cleared, showing where arrows used to be
- Support **non-rectangular shapes** via inactive cells (shape boundary acts like grid edge)

### Zoom & Pan
- **Zoom in/out**: mouse wheel on desktop, pinch on mobile (range: 0.5x to 2.0x)
- **Drag to pan**: when zoomed in, drag the board left/right/up/down to scroll
- Board must always remain at least **25% visible** on screen (clamped pan)
- Tap vs drag distinguished by 10px movement threshold
- Tap detected on **release** (not press) to avoid accidental taps during drag

### Arrows (thin uniform line-art style)
- Arrows are drawn in **one solid color** (black #000000), both body and head
- Failed arrows turn **red** (#E53935) immediately on first wrong tap
- Arrow style is **thin, uniform, clean line-art** (NOT thick filled shapes):
  - **Body**: rectangular segment (~20% of cell width) - uniform weight
  - **Head**: filled triangle arrowhead (~38% of cell width, ~25% cell length)
  - **NO neck** - body connects directly to arrowhead base
  - At **bends** (L-shaped arrows): square fill at corner joints
- Body and head have the **same visual weight** - uniform throughout
- Arrows are **small-medium** in size within cells, not filling the entire cell
- Multi-cell arrows: body segments connect cell centers, head is a small triangle at leading edge
- Single-cell arrows: body from tail (~60% of half-cell) to arrowhead base, then small triangle tip

### Color Palette
- Background: White (#FFFFFF)
- Arrows: Black (#000000)
- Arrow exit: Royal Blue (#4D6AFF) - color transition during exit
- Failed arrows: Red (#E53935)
- Cell backgrounds: **Transparent** (no grey)
- Empty cell dots: Grey (#CCCCCC)
- Hearts (full): Red (#E53935)
- Hearts (empty): Grey (#CCCCCC)
- Title text: Dark blue (#1B2A4A)
- Accent/buttons: Periwinkle (#7B8CDE)

### Animations

#### Exit (successful tap)
1. **Color transition**: Arrow stroke instantly shifts from Black to Royal Blue (#4D6AFF) over ~100ms
2. **Translation**: Arrow moves along its forward vector at **constant velocity** (4800 px/s) - linear, no easing, snappy feel
3. **Multi-cell**: Snake-like exit - head leads, body follows through the path (sliding-window)
4. **Single-cell**: Entire arrow translates at constant speed
5. **Destruction**: Arrow destroyed when bounding box is fully outside the viewport
6. No particle trail - the fast blue motion creates a visual streak

#### Nudge (blocked tap)
1. **Multi-cell**: Snake-like forward motion - head leads forward toward blocker, body follows
2. **Return**: Decaying sine oscillation - head springs back past origin, bounces with decreasing amplitude (~3 bounces), settles to rest
3. **Single-cell**: Simple position tween forward/back with sine easing
4. Duration: ~0.3s total

#### Other
- **Entrance**: Scale from 0 to 1 with TRANS_BACK overshoot, staggered 0.05s per arrow
- **Screen shake**: Subtle 3px shake on blocked tap (0.1s)
- Multiple arrows can animate simultaneously (no global animation lock)

#### Victory Transition
1. **Celebration**: Confetti + random positive message (scale-up), no dark overlay, no button
2. **Fade to white**: After 2s, full-screen white overlay fades in over 0.5s
3. **Screen switch**: Victory screen hidden, main menu shown behind white overlay
4. **Fade from white**: White overlay fades out over 0.5s revealing main menu
5. **Level animation**: After 1s pause, old level number slides down out of view while new number slides in from above (0.4s, clipped to label area)
6. **Tier transition**: If tier changes for new level, tier label fades in after level number animates
7. No user interaction needed — entire transition is automatic

---

## Gameplay

### Core Mechanic
1. Player taps an arrow on the grid
2. If the path ahead (in arrow's direction) is clear to the grid edge -> arrow turns blue, slides off and is removed
3. If another arrow blocks the path -> arrow nudges toward blocker with snake-like spring-back (wrong move)
4. Goal: remove all arrows from the board

### Hearts System
- Player starts each level with **3 hearts** (configurable via Config)
- Each wrong tap on a **unique arrow** costs **1 heart** and marks that arrow as **failed** (turns red immediately)
- **Re-tapping an already-failed (red) arrow does NOT cost another heart** - only plays nudge animation
- At **0 hearts**: game over dialog appears with:
  - "Continue" button: restores 3 hearts, keeps current progress
  - "Exit Level" button: returns to start screen
- Hearts display in HUD using filled/empty heart symbols

### Level Rules
- **All cells** on the board must be filled with arrows at level start (no empty cells initially)
- Every level must have **at least 1 arrow** that can be cleared immediately (no initial deadlock)
- Every level must be **solvable** (has a valid removal sequence)
- **Minimize single-cell arrows** - prefer multi-cell arrows (2+ cells)
- Include **L-shaped/bent arrows** (not only straight) for variety
- Support **non-rectangular shapes** (inactive cells marked -2 in grid)

### Multi-Cell Arrow Formats (in levels.json)
- Single-cell: `{"col": 2, "row": 3, "dir": "R"}`
- Multi-cell straight: `{"col": 1, "row": 1, "dir": "R", "length": 3}`
- Complex/bent: `{"cells": [[2,0],[2,1],[3,1]], "dir": "D", "head": [3,1]}`
- Waypoint format: `{"path": [[0,0],[0,4],[3,4]], "dir": "R"}` - corners expanded at runtime
- Non-rectangular: level includes `"shape": [[col,row], ...]` listing active cells

---

## Screens

### Start Screen
- White background
- **Title**: "PlayDreams Arrows" in dark blue (#1B2A4A), ~42px
- **Level label**: "Level X" in periwinkle (#7B8CDE), ~32px
- **Tier label**: tier name below level (Easy=green, Medium=orange, Hard=cyan, Expert=red), ~22px
  - Tier thresholds: 1-4 Easy, 5-7 Medium, 8-11 Hard, 12+ Expert
- **Continue button**: Large pill-shaped, periwinkle bg (#7B8CDE), white text ~28px, wide padding
- **Bottom nav bar** (shared with Settings): light grey-blue bg (#F0F2F8), 90px tall, Home (selected) + Settings items

### Settings Screen
- Same white background, no header title
- Scrollable list of rounded cards (#E8ECF4 bg, 16px corner radius)
- **Card 1**: Language (English >), Vibrations (toggle), Sounds (toggle), Dark mode (toggle), Native Refresh Rate (toggle)
- **Card 2**: Rate us, Write us (tappable rows)
- **Card 3**: Account Connection (toggle)
- **Card 4**: Remove Ads (toggle), Restore purchases (tappable)
- **Card 5**: Privacy (tappable)
- Row style: icon left, label, toggle/chevron right
- Toggle off: dark grey track, white knob. Toggle on: periwinkle track, white knob
- Bottom nav bar: Settings selected, Home unselected
- Settings persist to `user://settings.json`
- Sounds/Vibrations toggles control AudioManager muting

### Bottom Nav Bar (shared component)
- Light grey-blue strip (#F0F2F8), 90px tall, fixed at bottom
- Two items: Home (house icon) + Settings (gear icon)
- Active item: light pill bg behind icon (#E0E4EF), dark icon/text (#1B2A4A)
- Inactive item: grey icon/text (#8E95A9), no pill

### HUD (during gameplay)
- No opaque background bar — HUD elements float over the board
- **Top-left**: Two circular icon buttons (~48px, light grey-blue #E0E4EF bg)
  - Back button (◀) — returns to start screen
  - Reset button (↻) — restarts current level
- **Top-center**: Tier label (colored by tier) + hearts row (red ❤) below
- **Bottom-right**: Guide lines toggle (#) button
  - OFF: circular shape, tapping enables guide lines
  - ON: rounded-rectangle shape, guide lines visible
  - Tapping any arrow while guides are ON turns them OFF immediately
- No level number or moves counter displayed during gameplay

### Guide Lines Feature
- Toggle via # button in bottom-right HUD
- When active: lavender guide lines (same width as arrow bodies, Color(0.80, 0.82, 0.90, 0.6)) extend from each arrow's head cell center in its pointing direction to the viewport edge
- Shows the trajectory each arrow would take if cleared
- Auto-deactivates after any arrow tap (success or failure)
- Button shape changes: circle when off, rounded rectangle when on

### Victory Screen
- Random positive message with scale-up animation
- Confetti particles (CPUParticles2D)
- "Completed in X moves" text
- "Next Level" button appears after 1.5s delay
- Tap anywhere to advance

### Game Over Dialog
- Semi-transparent overlay
- "Out of Hearts!" title
- "Continue (3 new hearts)" button
- "Exit Level" button

---

## Level Generator

### Algorithm
- **Hamiltonian path** through all active cells using DFS + Warnsdorf's heuristic
- Path split into N segments (arrows), each min 3 cells
- Head/direction picked to align with body flow (no perpendicular heads)
- **No self-blocking**: arrow's exit path must not cross its own cells
- **Solvability verified** via backtracking solver
- Retry structure: 50 outer attempts x 5 splits x 30 head/dir assignments

### Generator Screen (F6 to run standalone)
- Tier selector (Easy/Medium/Hard/Expert) with configurable grid size ranges
- Manual grid size and arrow count overrides
- Seed input for reproducible generation
- **Mask-based shape editing**: load image, adjust grid resolution (3-20), generate non-rectangular levels
- Play-test mode, solution overlay, approve/reject workflow
- Approved levels saved to levels.json

### Tier Definitions (generator_rules.json)
- Easy: 4-5 cols, 4-5 rows, 3-5 arrows
- Medium: 5-6 cols, 5-7 rows, 4-6 arrows
- Hard: 6-8 cols, 7-9 rows, 4-6 arrows
- Expert: 7-9 cols, 8-10 rows, 4-7 arrows

---

## Level Progression (15 levels)

### Levels 1-4: Original Reference Designs
These levels match exact reference images provided:

1. **Tap to Move** (4x8, tutorial): 2 vertical arrows, length 5 each
2. **Chain** (5x6): 3 L-shaped arrows
3. **The Loop** (5x5): 4 arrows forming a loop around edges
4. **Maze** (7x8): 7 arrows with bends, complex routing

### Levels 5-15: Progressive Difficulty
5-7: Multiple interlocking multi-cell arrows
8-11: Longer arrows, more complex blocking patterns
12-15: L-shaped arrows, spirals, large grid puzzles

---

## Technical Architecture

### Scene Tree
```
Main (Node2D)
+-- Background (ColorRect, white, full viewport)
+-- StartScreen (CanvasLayer)
+-- GameBoard (Node2D, hidden initially)
|   +-- ArrowContainer (Node2D)
|   +-- TrailContainer (Node2D)
+-- HUD (CanvasLayer, hidden initially)
|   +-- TopBarBG (ColorRect, white, clips board content)
|   +-- TopBar (VBoxContainer)
+-- VictoryScreen (CanvasLayer, hidden initially)
```

### Key Classes
- **Config** (class_name, static constants) - NOT an autoload. Central file for all tunable gameplay parameters.
- **GameManager** (autoload) - level loading, progress save/load
- **AudioManager** (autoload) - SFX playback, haptics
- **GridSystem** (RefCounted) - pure data grid logic, path checking, inactive cells (-2)
- **Arrow** (Area2D) - multi-cell entity, custom _draw(), snake exit/nudge animations
- **GameBoard** (Node2D) - board orchestrator, input routing, level loading, zoom/pan
- **LevelGenerator** (RefCounted) - Hamiltonian path algorithm, forward-placement + solver
- **GeneratorScreen** (Node2D) - standalone tool scene for level generation

### Input Handling
- Input handled at **GameBoard level** via `_unhandled_input`, NOT per-arrow
- Screen position converted to grid cell, then looked up in GridSystem
- Grid state updates **immediately on tap** (before animation starts)
- Tap detected on mouse button **release** (not press) to distinguish from drag
- Drag-to-pan begins after 10px movement threshold

### Config Parameters (config.gd)
All key gameplay-tunable values are centralized:
- Viewport, grid layout, cell size
- Hearts (max, start count)
- Zoom/pan limits and thresholds
- Arrow geometry ratios (body width, head width/length, tail length)
- Animation speeds and durations (exit, nudge, entrance, shake)
- Trail and cell dot sizes
- All colors

### Save Format
```json
{"version": 2, "current_level": 3, "max_unlocked": 3}
```
Saved to `user://progress.json`
