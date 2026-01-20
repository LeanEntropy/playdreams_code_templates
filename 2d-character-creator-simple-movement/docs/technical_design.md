# Technical Design Document
## Customizable Character System with 2D Movement - Godot 4.5

---

## 1. Project Architecture

### 1.1 Scene Structure
```
Game/
├── Scenes/
│   ├── CharacterCreator.tscn    # Main menu / character customization
│   ├── Main.tscn                # Game world scene
│   └── Player.tscn              # Player character (instanced in Main)
├── Scripts/
│   ├── Global.gd                # Autoload singleton for game state
│   ├── CharacterCreator.gd      # Character customization logic
│   ├── Player.gd                # Player movement and initialization
│   └── Main.gd                  # Main scene logic
└── Assets/
    ├── body/                    # Body sprite sheets
    ├── hair/                    # Hair sprite sheets
    ├── outfit/                  # Outfit sprite sheets
    └── accessories/             # Accessory sprite sheets
```

### 1.2 Autoload Configuration
```gdscript
# In project.godot
[autoload]
Global="*res://Scripts/Global.gd"
```

---

## 2. Sprite Sheet Specification

### 2.1 Sprite Sheet Format
- **Dimensions**: 512x512 pixels (8x8 grid)
- **Frame Size**: 64x64 pixels per frame
- **Total Frames**: 64 frames per sprite sheet
- **Format**: PNG with transparency

### 2.2 Frame Layout (8 columns x 8 rows)
```
Row 1-4: Idle poses, emotes, and other animations
Row 5 (frames 32-39): Walk Down animation
Row 6 (frames 40-47): Walk Up animation
Row 7 (frames 48-55): Walk Right animation
Row 8 (frames 56-63): Walk Left animation
```

### 2.3 Animation Frame Mapping (0-indexed)
| Animation    | Row | Frame Range | Frame Indices      |
|--------------|-----|-------------|-------------------|
| Walk Down    | 5   | 1-6         | 32, 33, 34, 35, 36, 37 |
| Walk Up      | 6   | 1-6         | 40, 41, 42, 43, 44, 45 |
| Walk Right   | 7   | 1-6         | 48, 49, 50, 51, 52, 53 |
| Walk Left    | 8   | 1-6         | 56, 57, 58, 59, 60, 61 |
| Run Down     | 5   | 7-8         | 38, 39 |
| Run Up       | 6   | 7-8         | 46, 47 |
| Run Right    | 7   | 7-8         | 54, 55 |
| Run Left     | 8   | 7-8         | 62, 63 |

### 2.4 Idle Frame Indices
- Idle Down: 32
- Idle Up: 40
- Idle Right: 48
- Idle Left: 56

---

## 3. Character Layer System

### 3.1 Layer Hierarchy (Bottom to Top)
```
1. Body      (base layer - always visible)
2. Outfit    (clothing layer)
3. Hair      (hair layer - can be null for "bald")
4. Accessory (hat/accessory layer - can be null)
```

### 3.2 Sprite2D Configuration
Each layer requires identical settings for proper alignment:
```gdscript
hframes = 8        # Columns in sprite sheet
vframes = 8        # Rows in sprite sheet
frame = 32         # Default frame (idle down)
centered = true    # Center sprite on origin
```

### 3.3 Animation Synchronization
All layers must animate together using the same frame indices:
```gdscript
# AnimationPlayer tracks for each animation
tracks/0/path = NodePath("Skeleton/Body:frame")
tracks/1/path = NodePath("Skeleton/Outfit:frame")
tracks/2/path = NodePath("Skeleton/Hair:frame")
tracks/3/path = NodePath("Skeleton/Accessory:frame")
```

---

## 4. Global State Management (Global.gd)

### 4.1 Asset Collections
```gdscript
# Sprite collections using preload for performance
var bodies_collection = {
    "01": preload("res://Assets/body/char_a_p1_0bas_humn_v01.png")
}

var hair_collection = {
    "none": null,  # Option for no hair
    "01": preload("res://Assets/hair/char_a_p1_4har_bob1_v01.png"),
    "02": preload("res://Assets/hair/char_a_p1_4har_dap1_v01.png"),
}

var outfit_collection = {
    "01": preload("res://Assets/outfit/char_a_p1_1out_boxr_v01.png"),
    "02": preload("res://Assets/outfit/char_a_p1_1out_fstr_v04.png"),
    # ... more outfits
}

var accessory_collection = {
    "none": null,  # Option for no accessory
    "01": preload("res://Assets/accessories/char_a_p1_5hat_pfht_v04.png"),
    "02": preload("res://Assets/accessories/char_a_p1_5hat_pnty_v04.png"),
}
```

### 4.2 Color Options
```gdscript
# Skin tones (applied to body via modulate)
var body_color_options = [
    Color(1, 1, 1),           # Default/Original
    Color(0.96, 0.80, 0.69),  # Light
    Color(0.72, 0.54, 0.39),  # Medium
    Color(0.45, 0.34, 0.27),  # Dark
]

# Hair colors
var hair_color_options = [
    Color(1, 1, 1),           # Default
    Color(0.1, 0.1, 0.1),     # Black
    Color(0.4, 0.2, 0.1),     # Brown
    Color(0.9, 0.6, 0.2),     # Blonde
    Color(0.5, 0.25, 0),      # Auburn
]

# General colors for outfit/accessories
var color_options = [
    Color(1, 1, 1),           # Default
    Color(1, 0, 0),           # Red
    Color(0, 1, 0),           # Green
    Color(0, 0, 1),           # Blue
    Color(0, 0, 0),           # Black
]
```

### 4.3 Selected State Variables
```gdscript
var selected_body = "01"
var selected_hair = "none"
var selected_outfit = "01"
var selected_accessory = "none"
var selected_body_color = Color(1, 1, 1)
var selected_hair_color = Color(1, 1, 1)
var selected_outfit_color = Color(1, 1, 1)
var selected_accessory_color = Color(1, 1, 1)
var player_name = "Player"
```

---

## 5. Player Scene Structure

### 5.1 Node Hierarchy
```
Player (CharacterBody2D)
├── Skeleton (Node2D)
│   ├── Body (Sprite2D)
│   ├── Outfit (Sprite2D)
│   ├── Hair (Sprite2D)
│   ├── Accessory (Sprite2D)
│   └── NameLabel (Label)
├── CollisionShape2D
└── AnimationPlayer
```

### 5.2 Player Initialization
```gdscript
func initialize_player():
    # Body
    body.texture = Global.bodies_collection[Global.selected_body]
    body.hframes = 8
    body.vframes = 8
    body.modulate = Global.selected_body_color

    # Hair (handle null case)
    if Global.selected_hair != "none":
        hair.texture = Global.hair_collection[Global.selected_hair]
        hair.hframes = 8
        hair.vframes = 8
        hair.modulate = Global.selected_hair_color
    else:
        hair.texture = null

    # Outfit
    outfit.texture = Global.outfit_collection[Global.selected_outfit]
    outfit.hframes = 8
    outfit.vframes = 8
    outfit.modulate = Global.selected_outfit_color

    # Accessory (handle null case)
    if Global.selected_accessory != "none":
        accessory.texture = Global.accessory_collection[Global.selected_accessory]
        accessory.hframes = 8
        accessory.vframes = 8
        accessory.modulate = Global.selected_accessory_color
    else:
        accessory.texture = null

    name_label.text = Global.player_name
```

---

## 6. Movement System

### 6.1 Input Configuration (project.godot)
```
ui_left: Arrow Left, A key
ui_right: Arrow Right, D key
ui_up: Arrow Up, W key
ui_down: Arrow Down, S key
```

### 6.2 Movement Logic
```gdscript
const SPEED = 200
var last_direction = Vector2.DOWN

func _physics_process(_delta):
    var direction = Vector2.ZERO
    direction.x = Input.get_axis("ui_left", "ui_right")
    direction.y = Input.get_axis("ui_up", "ui_down")

    # Store last direction for idle animation
    if direction != Vector2.ZERO:
        last_direction = direction

    # Normalize for consistent diagonal speed
    velocity = direction.normalized() * SPEED

    # Animation selection based on movement
    if direction != Vector2.ZERO:
        if abs(direction.x) > abs(direction.y):
            # Horizontal movement dominates
            if direction.x < 0:
                animation_player.play("walk_left")
            else:
                animation_player.play("walk_right")
        else:
            # Vertical movement dominates
            if direction.y < 0:
                animation_player.play("walk_up")
            else:
                animation_player.play("walk_down")
    else:
        # Idle animation based on last direction
        play_idle_animation()

    move_and_slide()
```

### 6.3 Idle Animation Selection
```gdscript
func play_idle_animation():
    if abs(last_direction.x) > abs(last_direction.y):
        if last_direction.x < 0:
            animation_player.play("idle_left")
        else:
            animation_player.play("idle_right")
    else:
        if last_direction.y < 0:
            animation_player.play("idle_up")
        else:
            animation_player.play("idle_down")
```

---

## 7. Animation System

### 7.1 Animation Configuration
```gdscript
# Walk animation settings
length = 0.6              # 6 frames at 0.1s each
loop_mode = 1             # Loop animation

# Idle animation settings
length = 0.1              # Single frame
loop_mode = 1             # Loop (holds frame)
```

### 7.2 Animation Track Structure
Each animation requires 4 tracks (one per layer):
```
tracks/0/path = NodePath("Skeleton/Body:frame")
tracks/1/path = NodePath("Skeleton/Outfit:frame")
tracks/2/path = NodePath("Skeleton/Hair:frame")
tracks/3/path = NodePath("Skeleton/Accessory:frame")
```

### 7.3 Keyframe Format
```gdscript
tracks/0/keys = {
    "times": PackedFloat32Array(0, 0.1, 0.2, 0.3, 0.4, 0.5),
    "transitions": PackedFloat32Array(1, 1, 1, 1, 1, 1),
    "update": 1,  # Discrete update mode
    "values": [32, 33, 34, 35, 36, 37]  # Frame indices
}
```

---

## 8. Character Creator Implementation

### 8.1 Preview System
```gdscript
# Scale up for visibility in creator
$CharacterPreview.scale = Vector2(4, 4)

# Direct sprite references for live preview
@onready var body_sprite = $CharacterPreview/Body
@onready var hair_sprite = $CharacterPreview/Hair
@onready var outfit_sprite = $CharacterPreview/Outfit
@onready var accessory_sprite = $CharacterPreview/Accessory
```

### 8.2 Cycling Through Options
```gdscript
var body_keys = []
var body_index = 0

func _ready():
    body_keys = Global.bodies_collection.keys()

func _on_body_type_pressed():
    body_index = (body_index + 1) % body_keys.size()
    update_body()

func update_body():
    var key = body_keys[body_index]
    body_sprite.texture = Global.bodies_collection[key]
    body_sprite.modulate = Global.body_color_options[body_color_index]
    Global.selected_body = key
    Global.selected_body_color = Global.body_color_options[body_color_index]
```

### 8.3 Handling Nullable Layers
```gdscript
func update_hair():
    var key = hair_keys[hair_index]
    if key == "none":
        hair_sprite.texture = null
    else:
        hair_sprite.texture = Global.hair_collection[key]
        hair_sprite.modulate = Global.hair_color_options[hair_color_index]
    Global.selected_hair = key
```

---

## 9. Scene Transitions

### 9.1 From Creator to Game
```gdscript
func _on_confirm_button_pressed():
    if player_name.strip_edges() != "":
        Global.player_name = player_name
    get_tree().change_scene_to_file("res://Scenes/Main.tscn")
```

### 9.2 From Game to Creator
```gdscript
func _on_back_button_pressed():
    get_tree().change_scene_to_file("res://Scenes/CharacterCreator.tscn")
```

---

## 10. Color Modulation System

### 10.1 How Modulation Works
- `modulate` property multiplies sprite colors by the given color
- White (1,1,1) = original colors unchanged
- Other colors tint the sprite
- Works best with grayscale or light-colored base sprites

### 10.2 Application
```gdscript
# Apply skin tone
body_sprite.modulate = Global.body_color_options[color_index]

# Apply hair color
hair_sprite.modulate = Global.hair_color_options[color_index]

# Apply outfit/accessory color
outfit_sprite.modulate = Global.color_options[color_index]
```

---

## 11. Collision Setup

### 11.1 Player Collision
```gdscript
# CollisionShape2D configuration
position = Vector2(0, 16)  # Offset to character's feet
shape = RectangleShape2D(size = Vector2(24, 16))
```

### 11.2 World Boundaries
```gdscript
# StaticBody2D with CollisionShape2D for walls
# Use RectangleShape2D sized to screen edges
```

---

## 12. Camera Setup

### 12.1 Following Camera
```gdscript
# Camera2D as child of Player
zoom = Vector2(2, 2)  # 2x zoom for pixel art
```

---

## 13. Best Practices

### 13.1 Performance
- Use `preload()` for assets loaded at startup
- Keep sprite sheets as power-of-2 dimensions
- Use texture atlases when possible

### 13.2 Extensibility
- Store asset references in dictionaries for easy addition
- Use string keys for serialization compatibility
- Separate visual (Sprite2D) from logic (scripts)

### 13.3 Maintainability
- Keep Global.gd focused on state only
- Use signals for loose coupling between scenes
- Document frame indices in comments
