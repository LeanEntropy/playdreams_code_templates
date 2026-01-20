# Game Design Guide
## Customizable Character System with 2D Movement

---

## 1. Overview

### 1.1 Core Concept
A character customization system that allows players to create personalized avatars by mixing and matching visual elements, combined with simple 2D top-down movement in a game world.

### 1.2 Target Experience
- **Accessibility**: Easy to understand, click-to-cycle customization
- **Expression**: Meaningful choices that create distinct characters
- **Immediacy**: Real-time preview of all changes
- **Persistence**: Character choices carry into gameplay

---

## 2. Character Customization System

### 2.1 Customization Categories

#### Body (Required)
- **Purpose**: The base character model
- **Options**: Different body types/shapes
- **Color**: Skin tone variations
- **Design Note**: Always visible, forms the foundation for all other layers

#### Hair (Optional)
- **Purpose**: Major visual identity element
- **Options**: Multiple hairstyles + "none" option
- **Color**: Natural and unnatural hair colors
- **Design Note**: One of the most recognizable features for character identity

#### Outfit (Required)
- **Purpose**: Clothing and primary fashion expression
- **Options**: Various clothing styles
- **Color**: Wide range of colors for personalization
- **Design Note**: Large visual area, significant impact on character look

#### Accessories (Optional)
- **Purpose**: Additional flair and personality
- **Options**: Hats, headwear + "none" option
- **Color**: Matching or contrasting with outfit
- **Design Note**: Small but impactful detail that adds uniqueness

### 2.2 Layer Hierarchy
```
Top:     Accessories (hats sit on top of hair)
         Hair (covers back of head, frames face)
         Outfit (covers body)
Bottom:  Body (base layer, always present)
```

### 2.3 Color System Design

#### Skin Tones
| Name    | Purpose                           |
|---------|-----------------------------------|
| Default | Original sprite colors            |
| Light   | Fair/light skin representation    |
| Medium  | Medium skin representation        |
| Dark    | Dark skin representation          |

**Design Rationale**: Inclusive representation while keeping options simple and respectful.

#### Hair Colors
| Color   | Style Association                 |
|---------|-----------------------------------|
| Default | Original/natural                  |
| Black   | Classic, common                   |
| Brown   | Natural, warm                     |
| Blonde  | Light, bright                     |
| Auburn  | Reddish-brown, distinctive        |

**Design Rationale**: Natural colors that work well with skin tones.

#### Outfit/Accessory Colors
| Color   | Mood/Association                  |
|---------|-----------------------------------|
| Default | Original design colors            |
| Red     | Bold, energetic                   |
| Green   | Natural, calm                     |
| Blue    | Cool, trustworthy                 |
| Black   | Sleek, mysterious                 |
| White   | Clean, pure                       |

**Design Rationale**: Primary colors plus neutrals for maximum combinability.

---

## 3. Character Creator UI/UX

### 3.1 Screen Layout
```
┌─────────────────────────────────────────────────────────┐
│                    CHARACTER CREATOR                     │
├──────────────────┬─────────────────┬────────────────────┤
│                  │                 │                    │
│   Customization  │    Character    │    Name Entry      │
│   Buttons        │    Preview      │    & Start         │
│                  │    (Large)      │                    │
│   - Body         │                 │    [Name Field]    │
│   - Hair         │                 │                    │
│   - Outfit       │                 │    [Start Game]    │
│   - Accessories  │                 │                    │
│                  │                 │                    │
└──────────────────┴─────────────────┴────────────────────┘
```

### 3.2 Interaction Design

#### Button Layout Per Category
```
[Category Label]
[Style Button] [Color Button]
```

**Interaction Pattern**:
- Click "Style" to cycle through available options
- Click "Color" to cycle through color variations
- Changes apply immediately to preview

#### Preview Behavior
- Character displayed at 4x scale for clarity
- Shows idle pose (facing forward/down)
- All layers update in real-time
- Positioned centrally for focus

### 3.3 Design Principles

1. **Immediate Feedback**: Every click shows instant results
2. **No Dead Ends**: Cycling wraps around (last item → first item)
3. **Clear Labels**: Button text indicates what it changes
4. **Visual Hierarchy**: Character preview is the focal point
5. **Commitment Point**: Single "Start Game" button to confirm choices

---

## 4. Movement System Design

### 4.1 Movement Feel

#### Speed
- **Value**: 200 units/second
- **Feel**: Brisk walking pace, responsive but not frantic
- **Rationale**: Fast enough to explore, slow enough to control precisely

#### Diagonal Movement
- Normalized to prevent faster diagonal movement
- Same speed in all 8 directions
- Smooth transitions between directions

### 4.2 Direction Priority
When moving diagonally, animation shows:
- Horizontal animation if |X| > |Y|
- Vertical animation if |Y| > |X|

**Rationale**: Prevents animation flickering, maintains clear visual direction.

### 4.3 Idle Behavior
- Character stops immediately when input released
- Idle animation faces the last movement direction
- **Rationale**: Character "remembers" where they were going, feels natural

---

## 5. Animation Design

### 5.1 Walk Cycle
- **Frame Count**: 6 frames per direction
- **Duration**: 0.6 seconds per cycle (0.1s per frame)
- **Feel**: Smooth, natural walking rhythm

### 5.2 Idle Animation
- **Frame Count**: 1 frame (static pose)
- **Purpose**: Clear "at rest" state
- **Direction**: Matches last movement direction

### 5.3 Four-Directional System
| Direction | Description              |
|-----------|--------------------------|
| Down      | Character faces camera   |
| Up        | Character faces away     |
| Right     | Character faces right    |
| Left      | Character faces left     |

**Design Note**: Four directions provide clear visual feedback while keeping animation workload manageable.

---

## 6. Sprite Sheet Design Guidelines

### 6.1 Asset Requirements

#### Consistent Sizing
- All sprite sheets must be identical dimensions
- All frames must align perfectly across layers
- Character must be centered in each frame

#### Layer Compatibility
- Each customization piece (hair, outfit, etc.) must:
  - Match the body's animation frames exactly
  - Have transparent backgrounds
  - Align with the body's pivot point

### 6.2 Animation Row Organization
```
Rows 1-4: Special poses, emotes, actions
Row 5:    Walk Down (frames 1-6) + Run Down (frames 7-8)
Row 6:    Walk Up (frames 1-6) + Run Up (frames 7-8)
Row 7:    Walk Right (frames 1-6) + Run Right (frames 7-8)
Row 8:    Walk Left (frames 1-6) + Run Left (frames 7-8)
```

### 6.3 Frame Breakdown Per Row
| Frame | Content                    |
|-------|----------------------------|
| 1     | Walk start / Contact pose  |
| 2     | Walk cycle frame 2         |
| 3     | Walk cycle frame 3         |
| 4     | Walk cycle frame 4         |
| 5     | Walk cycle frame 5         |
| 6     | Walk cycle frame 6         |
| 7     | Run frame 1                |
| 8     | Run frame 2                |

---

## 7. Visual Design Guidelines

### 7.1 Art Style Considerations
- **Pixel Art**: Small sprites (64x64) with limited color palettes
- **Consistency**: All assets should share the same art style
- **Readability**: Character silhouette should be clear at game zoom level

### 7.2 Color Design for Modulation
When creating sprites intended for color modulation:
- Use grayscale or desaturated base colors
- Avoid pure black (won't tint)
- Lighter colors tint more dramatically
- Test with all intended tint colors

### 7.3 Layer Separation
Each customization layer should:
- Not overlap unnecessarily with other layers
- Have clear visual boundaries
- Work with ALL other layer options (combinatorial testing)

---

## 8. Player Identity Features

### 8.1 Name Display
- Player name shown above character
- Centered horizontally
- Visible at game zoom level
- **Purpose**: Reinforces ownership and identity

### 8.2 Character Persistence
- Customization choices stored globally
- Survives scene transitions
- Could be extended to save/load from disk

---

## 9. Game World Design

### 9.1 Camera
- **Type**: Following camera (attached to player)
- **Zoom**: 2x for pixel art clarity
- **Movement**: Locked to player position

### 9.2 World Boundaries
- Invisible collision walls at screen edges
- Prevents player from leaving play area
- Could be replaced with visible walls/environment

### 9.3 Environment
- Simple colored background for prototype
- Can be extended with:
  - Tiled terrain
  - Environmental objects
  - NPCs
  - Interactive elements

---

## 10. Expandability Considerations

### 10.1 Additional Customization
Easy to add:
- More body types
- Additional hairstyles
- New outfits
- More accessories
- New color options

Structure to add:
- Facial features (eyes, mouth)
- Multiple accessory slots
- Front/back hair layers

### 10.2 Gameplay Extensions
- Inventory system for outfit changes
- Unlockable customization options
- NPC interactions
- Quest system
- Multiple areas/maps

### 10.3 Animation Extensions
- Run animation (frames 7-8 already in sprite sheet)
- Attack animations
- Emotes and expressions
- Sitting/sleeping poses

---

## 11. Accessibility Considerations

### 11.1 Controls
- Multiple input options (WASD + Arrow keys)
- Simple click-based customization
- No time pressure in character creator

### 11.2 Visual
- Large preview in character creator
- Clear button labels
- High contrast UI elements

### 11.3 Future Considerations
- Keyboard navigation for UI
- Screen reader support for menus
- Colorblind-friendly UI elements
- Remappable controls

---

## 12. Design Checklist for New Assets

### 12.1 New Sprite Sheet
- [ ] 512x512 pixels (8x8 grid of 64x64 frames)
- [ ] PNG with transparency
- [ ] Walk animations in rows 5-8
- [ ] Frames align with existing body sprite
- [ ] Tested with all existing layers

### 12.2 New Color Option
- [ ] Works with light sprites (not too dark)
- [ ] Visually distinct from existing options
- [ ] Tested with multiple sprite types
- [ ] Appropriate for category (natural for hair, etc.)

### 12.3 New Customization Category
- [ ] Clear visual purpose
- [ ] Doesn't conflict with existing layers
- [ ] Has "none" option if appropriate
- [ ] UI space allocated for controls
- [ ] Added to Global state management

---

## 13. Summary

This system provides a foundation for character customization that is:

1. **Modular**: Easy to add new options
2. **Intuitive**: Simple click-to-change interface
3. **Expressive**: Meaningful customization choices
4. **Performant**: Efficient sprite-based rendering
5. **Extensible**: Clear patterns for adding features

The layered sprite approach allows for combinatorial variety while maintaining consistent visual quality and animation synchronization.
