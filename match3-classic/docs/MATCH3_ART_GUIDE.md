# Match-3 Art Technical Design Document

## Overview

This document provides technical art guidelines for creating match-3 game pieces that are visually distinct, accessible, and functional within the game grid. The primary goal is to ensure players can quickly identify and differentiate between piece types under all conditions, including colorblindness and small screen sizes.

---

## 1. The Shape Differentiation Principle

### Why Shape Matters More Than Color

Color alone is insufficient for piece identification. Approximately 8% of men and 0.5% of women have some form of color vision deficiency. Beyond accessibility, shape differentiation improves gameplay for all players:

- **Faster recognition**: Unique silhouettes register faster than color processing
- **Reduced eye strain**: Players can identify pieces peripherally without focusing
- **Better cascading readability**: During fast cascade animations, shapes remain identifiable
- **Consistent experience**: Works across different screen calibrations and lighting conditions

### The Stop Sign Principle

Effective visual design uses redundant identifiers. A stop sign uses:
1. **Color** - Red
2. **Shape** - Unique octagon (no other road sign uses this shape)
3. **Text** - "STOP"

Any single element is sufficient for identification. Match-3 pieces should follow this pattern with at minimum two distinct identifiers per piece type.

---

## 2. Shape Design Approaches

### Approach A: Different Shapes, Same Theme

All pieces belong to the same category (gems, candies, etc.) but each has a fundamentally different shape.

**Example - Gem Theme:**
| Piece | Shape | Silhouette Description |
|-------|-------|----------------------|
| 1 | Round Brilliant | Circular with radiating facets |
| 2 | Emerald Cut | Rectangular with stepped corners |
| 3 | Marquise | Pointed oval/football shape |
| 4 | Pear/Teardrop | Rounded bottom, pointed top |
| 5 | Heart | Classic heart silhouette |
| 6 | Hexagonal | Six-sided geometric |

**Advantages:**
- Strong thematic cohesion
- Each piece instantly recognizable by outline alone
- Works well for "premium" or "elegant" game aesthetics

**Implementation Notes:**
- Ensure silhouettes are distinct when viewed as solid black shapes
- Avoid shapes that become similar when rotated (square vs diamond)
- Test at target display size before finalizing

### Approach B: Different Objects, Same Theme

Each piece is a completely different object united by a common theme.

**Example - Fruit Theme:**
| Piece | Object | Silhouette Description |
|-------|--------|----------------------|
| 1 | Apple | Round with stem indent and leaf |
| 2 | Orange | Perfectly round with texture dot |
| 3 | Grape Cluster | Multiple small circles grouped |
| 4 | Banana | Curved crescent |
| 5 | Cherry | Two circles with joined stems |
| 6 | Strawberry | Triangular with crown |

**Advantages:**
- Maximum silhouette differentiation
- Familiar objects require no learning
- Appeals to casual game audiences

**Implementation Notes:**
- Each object should be recognizable independent of the others
- Maintain consistent rendering style across all objects
- Size normalization is critical (banana and cherry should feel equally "weighted")

### Approach C: Same Container, Different Symbol

All pieces share an identical outer shape with unique internal symbols or patterns.

**Example - Tile with Symbol:**
| Piece | Symbol | Description |
|-------|--------|-------------|
| 1 | Star | Five-pointed star |
| 2 | Circle | Simple filled circle |
| 3 | Triangle | Equilateral triangle |
| 4 | Square | Rotated 45 degrees (diamond) |
| 5 | Cross | Plus sign shape |
| 6 | Crescent | Moon shape |

**Advantages:**
- Cleanest grid appearance
- Easiest to produce variations
- Works well with abstract/minimalist aesthetics

**Implementation Notes:**
- Container should have subtle styling to avoid "flat" appearance
- Symbols must have sufficient size within container (minimum 60% of container area)
- Consider adding subtle color tinting to containers as secondary identifier

---

## 3. Color Palette Guidelines

### Primary Palette Selection

Select six colors with maximum perceptual distance. Avoid placing similar colors adjacent in the piece lineup.

**Recommended Base Palette:**
| Slot | Color | Hex Value | Notes |
|------|-------|-----------|-------|
| 1 | Red | #E63946 | Warm, high saturation |
| 2 | Orange | #F4A261 | Distinct from red, warm |
| 3 | Yellow | #E9C46A | Bright, high value |
| 4 | Green | #2A9D8F | Blue-green to separate from yellow |
| 5 | Blue | #264653 | Deep, distinct from green |
| 6 | Purple | #9B5DE5 | Distinct from blue and red |

### Colorblind-Safe Modifications

For deuteranopia (red-green) and protanopia (red-green) accessibility:

- **Never** place red and green adjacent without shape differentiation
- Use **blue-yellow** as reliable contrast pair
- Add **value contrast** (light vs dark) as backup differentiator
- Consider **pattern overlays** for additional distinction

**Alternative Accessible Palette:**
| Slot | Color | Hex Value | Shape Backup |
|------|-------|-----------|--------------|
| 1 | Coral Red | #FF6B6B | Always paired with unique shape |
| 2 | Amber | #FFB347 | Warm, distinct from coral |
| 3 | Lemon | #FFF176 | High value/brightness |
| 4 | Teal | #4DD0E1 | Blue-shifted green |
| 5 | Cobalt | #5C6BC0 | Medium value blue |
| 6 | Violet | #AB47BC | Red-shifted purple |

### Color Application Rules

1. **Saturation Consistency**: All pieces should have similar saturation levels (avoid mixing pastel with vivid)
2. **Value Range**: Keep lightness values within 30-70% range for visibility on varied backgrounds
3. **Background Contrast**: Ensure minimum 4.5:1 contrast ratio against game board
4. **Highlight/Shadow**: Use consistent lighting direction across all pieces

---

## 4. Size and Proportion Guidelines

### Grid Compatibility Requirements

| Property | Minimum | Recommended | Maximum |
|----------|---------|-------------|---------|
| Base Asset Size | 64x64 px | 128x128 px | 256x256 px |
| Safe Content Area | 80% | 85% | 90% |
| Padding from Edge | 5% | 7.5% | 10% |

### Safe Content Area

```
+---------------------------+
|         PADDING           |
|   +-------------------+   |
|   |                   |   |
|   |   SAFE CONTENT    |   |
|   |      AREA         |   |
|   |                   |   |
|   +-------------------+   |
|         PADDING           |
+---------------------------+
```

- **Safe Content Area**: Where the main visual element should be contained
- **Padding**: Buffer zone for effects, glow, selection highlights

### Size at Different Resolutions

Test pieces at these common rendered sizes:

| Device Category | Typical Tile Size | Minimum Identifiable |
|-----------------|-------------------|---------------------|
| Mobile (small) | 40-50 px | Must be clear at 40px |
| Mobile (large) | 50-70 px | Target optimization |
| Tablet | 60-90 px | Comfortable viewing |
| Desktop | 70-100 px | Maximum detail visible |

### Proportion Rules

1. **Center of Mass**: Visual center should align with geometric center
2. **Weight Balance**: All pieces should feel equally "heavy" despite different shapes
3. **Aspect Ratio**: Keep pieces within 1:1.2 aspect ratio for grid harmony
4. **Negative Space**: Maintain consistent negative space ratio across all pieces

---

## 5. Style Consistency Guidelines

### Rendering Style Checklist

All pieces in a set must share:

- [ ] Same lighting angle (recommend 45 degrees from upper-left)
- [ ] Same shadow style (drop shadow, inner shadow, or none)
- [ ] Same outline treatment (none, thin, thick)
- [ ] Same level of detail/complexity
- [ ] Same texture approach (flat, gradient, textured)
- [ ] Same highlight style (specular, soft, none)

### Style Categories

**Flat/Vector Style:**
- Solid colors with minimal shading
- Clean edges, no textures
- Works well at all sizes
- Fastest to produce

**Soft/Gradient Style:**
- Smooth gradients for depth
- Subtle highlights and shadows
- Good balance of detail and clarity
- Most common in casual games

**Rendered/3D Style:**
- Full shading and highlights
- Detailed textures possible
- Requires careful size testing
- Highest production effort

**Pixel Art Style:**
- Deliberate low-resolution aesthetic
- Sharp edges, limited palette
- Specific technical requirements
- Appeals to retro audiences

---

## 6. Accessibility Testing Checklist

### Colorblind Simulation Testing

Test all pieces through these simulation modes:

- [ ] **Deuteranopia** (green-blind, most common)
- [ ] **Protanopia** (red-blind)
- [ ] **Tritanopia** (blue-blind, rare)
- [ ] **Achromatopsia** (complete colorblindness, very rare)

**Recommended Testing Tools:**
- Color Oracle (desktop application, free)
- Coblis Color Blindness Simulator (web-based)
- Photoshop/GIMP colorblind proof modes
- Chrome DevTools Rendering > Emulate vision deficiencies

### Silhouette Test

1. Convert all pieces to solid black
2. Display at minimum game size (40px)
3. Verify each piece is uniquely identifiable
4. Test with 5-second recognition time limit

### Contrast Test

1. Place pieces on intended game board background
2. Verify no piece blends into background
3. Test on light and dark board variations
4. Check selection state visibility

### Motion Test

1. Animate pieces falling/swapping at game speed
2. Verify pieces remain identifiable during motion
3. Check cascade animations for clarity
4. Test at 0.5x and 2x speed

---

## 7. Asset Requirements

### Required Pieces

A typical match-3 game requires **6 distinct game pieces** with the following specifications:

| Asset Name | Required | Format | Size |
|------------|----------|--------|------|
| gem_1.png | Yes | PNG with transparency | 128x128 px (recommended) |
| gem_2.png | Yes | PNG with transparency | 128x128 px (recommended) |
| gem_3.png | Yes | PNG with transparency | 128x128 px (recommended) |
| gem_4.png | Yes | PNG with transparency | 128x128 px (recommended) |
| gem_5.png | Yes | PNG with transparency | 128x128 px (recommended) |
| gem_6.png | Yes | PNG with transparency | 128x128 px (recommended) |

### Technical Specifications

```
Format:         PNG-24 with alpha channel
Color Space:    sRGB
Dimensions:     Square (1:1 aspect ratio)
Minimum Size:   64x64 pixels
Recommended:    128x128 pixels
Maximum Size:   256x256 pixels
Bit Depth:      8-bit per channel (32-bit with alpha)
```

### Content Requirements

Each piece must have:

1. **Unique silhouette** - Identifiable as solid black shape
2. **Distinct color** - From the 6-color palette
3. **Consistent style** - Matching all other pieces
4. **Center alignment** - Visual center at image center
5. **Safe area compliance** - Content within 85% safe area
6. **Transparency** - Clean alpha channel, no edge artifacts

### Special Piece Overlays

Optional overlays for special gem states:

| Asset Name | Purpose | Notes |
|------------|---------|-------|
| special_1.png | Horizontal striped | Horizontal line pattern overlay |
| special_2.png | Vertical striped | Vertical line pattern overlay |
| special_3.png | Wrapped | Wrapper/package overlay |
| special_4.png | Color bomb | Rainbow/multicolor effect |

### Recommended File Location

Organize assets in a dedicated folder structure:
```
assets/
├── gems/           # Game piece textures
├── effects/        # Visual effects and overlays
├── backgrounds/    # Background images
└── audio/          # Sound effects
```

### Fallback Behavior

Consider implementing fallback graphics (e.g., colored circles or simple shapes) when custom assets are not provided. This allows:
- Rapid prototyping before art assets are complete
- Color customization through configuration
- Graceful handling of missing texture files

---

## 8. Production Workflow

### Recommended Creation Process

1. **Silhouette Phase**
   - Design 6 distinct black silhouettes
   - Test at 40px display size
   - Verify no shapes are confused with each other
   - Get approval before adding color

2. **Color Phase**
   - Apply base colors from approved palette
   - Test through colorblind simulators
   - Adjust colors if any pair is indistinguishable
   - Document final hex values

3. **Detail Phase**
   - Add shading, highlights, textures
   - Maintain style consistency
   - Keep detail level appropriate for size
   - Avoid fine details lost at small sizes

4. **Polish Phase**
   - Clean up edges and alpha channels
   - Verify alignment and centering
   - Create size variations if needed
   - Final testing in game context

### Quality Assurance Checklist

Before finalizing assets:

- [ ] All 6 pieces have unique silhouettes
- [ ] Colorblind simulation test passed
- [ ] 40px minimum size test passed
- [ ] Consistent style across all pieces
- [ ] Clean alpha channels (no halos)
- [ ] Centered within canvas
- [ ] Content within safe area
- [ ] File format and size correct
- [ ] File naming matches requirements

---

## 9. Common Mistakes to Avoid

### Shape Design Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Relying on color only | Colorblind players cannot distinguish | Add unique shape per piece |
| Similar silhouettes | Pieces confused during fast play | Exaggerate shape differences |
| Rotational ambiguity | Square looks like diamond when rotated | Use asymmetric shapes |
| Too much detail | Detail lost at small sizes | Simplify to bold shapes |

### Color Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Red and green adjacent | Common colorblindness confusion | Separate with other colors or use distinct shapes |
| Low saturation | Pieces look washed out | Maintain 60%+ saturation |
| Similar values | Pieces blend together | Vary lightness across palette |
| Inconsistent saturation | Set looks unbalanced | Normalize saturation levels |

### Technical Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Edge aliasing | Jagged edges visible | Use anti-aliasing, clean alpha |
| Halo artifacts | White/dark edge around pieces | Proper alpha channel workflow |
| Off-center content | Pieces look misaligned in grid | Center visual weight, not just bounds |
| Inconsistent padding | Some pieces crowd edges | Use consistent safe area |

---

## 10. Reference Resources

### Color Tools
- Adobe Color (color.adobe.com) - Palette generation
- Coolors (coolors.co) - Quick palette exploration
- Contrast Checker (webaim.org/resources/contrastchecker) - Accessibility testing

### Colorblind Testing
- Color Oracle (colororacle.org) - Desktop simulator
- Coblis (color-blindness.com/coblis-color-blindness-simulator) - Web simulator

### Design Inspiration
- Match-3 game art on itch.io
- Mobile game UI screenshots
- Puzzle game art asset packs

---

## Summary

Effective match-3 art requires:

1. **Unique shapes first** - Every piece must have a distinct silhouette
2. **Color as enhancement** - Color supports shape, never replaces it
3. **Consistent style** - All pieces should look like they belong together
4. **Accessibility testing** - Verify through colorblind simulation
5. **Size testing** - Confirm clarity at minimum display size
6. **Technical precision** - Clean files, proper format, correct dimensions

Following these guidelines ensures game pieces are instantly recognizable, accessible to all players, and visually cohesive within the game experience.

---

*This document provides general art guidelines for match-3 games. Adapt naming conventions, file organization, and specific requirements to your project's needs.*
