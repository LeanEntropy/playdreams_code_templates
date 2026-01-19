# 3D Asset Manager Skill - Usage Guide

## Overview

The **3D Asset Manager** is a professional Claude Code skill for managing 3D assets in your Godot 4.4 game project. It's vendor-neutral but follows the Kenney.nl organizational standard.

**Location**: `.claude/skills/3d-asset-manager.md`

---

## How to Use This Skill

### Method 1: Automatic Activation

Simply mention 3D asset-related tasks in your prompts. The skill will automatically activate when you say things like:

- "Analyze available 3D assets"
- "Import the Kenney building kit"
- "Build a village scene with 4 houses"
- "Create a forest environment"
- "Assemble a modular house"
- "Catalog all 3D models"

**Activation Keywords**:
- 3D assets, models, environment, scene
- import assets, analyze models, place objects
- assemble building, modular components, prefabs
- catalog, inventory, asset management

### Method 2: Manual Invocation (if available)

If Claude Code supports manual skill invocation:
```
/skill 3d-asset-manager
```

Then follow up with your specific request.

---

## Core Capabilities

### 1. Asset Analysis
**What it does**: Scans your asset staging area and categorizes everything

**Example prompts**:
- "Analyze the 3D assets in assets_bank"
- "What 3D models do we have available?"
- "Scan and categorize all assets"

**Output**: Detailed report with asset types, categories, and recommendations

---

### 2. Asset Import & Organization
**What it does**: Copies assets from staging to your active project with proper organization

**Example prompts**:
- "Import the Kenney building pack"
- "Copy forest assets to the project"
- "Import modular building components"

**Output**: Organized assets in `assets/3d_models/` with proper functional categorization

**Key Pattern**:
- Assets copied FROM: `assets_bank/3D_assets/kenney/`
- Assets copied TO: `assets/3d_models/buildings/` (organized by function!)

---

### 3. Asset Cataloging
**What it does**: Creates comprehensive documentation of your asset library

**Example prompts**:
- "Catalog all 3D assets"
- "Create asset documentation"
- "Generate asset inventory"

**Output Files**:
- `assets/3d_models/asset_inventory.md` - Master list
- `assets/3d_models/catalog.md` - Detailed metadata
- `assets/3d_models/assembly_patterns.md` - Assembly guides
- `assets/3d_models/quick_reference.md` - Quick lookup

---

### 4. Environment Building
**What it does**: Creates game scenes by placing and assembling 3D assets

**Example prompts**:
- "Build a village scene with 3 houses, trees, and rocks"
- "Create a forest environment for the player to explore"
- "Make a test arena for tank combat"

**Output**: Production-ready `.tscn` files in `assets/environments/`

**Includes**:
- Proper node hierarchy (Buildings, Props, Terrain, SpawnPoints)
- Collision setup (StaticBody3D + CollisionShape3D)
- Player spawn points (Marker3D)
- Tested with all 7 controller modes

---

### 5. Structure Assembly
**What it does**: Combines modular components into reusable prefab structures

**Example prompts**:
- "Assemble a house from modular wall, floor, and roof pieces"
- "Create a castle wall prefab"
- "Build a two-story modular building"

**Output**: Reusable `.tscn` prefabs in `assets/prefabs/`

**Features**:
- Grid-aligned components
- Unified collision
- Logical hierarchy (Walls, Floors, Roof)
- Assembly documentation

---

## Directory Structure

### Two-Tier System

#### Staging Area (Never Referenced in Code)
```
assets_bank/3D_assets/
├── kenney/                    # Kenney asset packs
├── quaternius/                # Quaternius models
├── synty/                     # Synty Studios
├── custom/                    # Custom models
└── purchased/                 # Other paid assets
```

#### Active Project (Always Use res:// Paths)
```
assets/3d_models/              # Organized by FUNCTION
├── buildings/
│   ├── walls/
│   ├── floors/
│   ├── roofs/
│   └── complete/
├── props/
│   ├── furniture/
│   ├── decorative/
│   └── interactive/
├── terrain/
│   ├── ground/
│   ├── rocks/
│   └── vegetation/
├── vehicles/
├── characters/
└── nature/
```

**Critical Rules**:
- ✅ Organize by FUNCTION (buildings/, props/, terrain/)
- ✅ Always use `res://assets/3d_models/...` in scenes
- ❌ NEVER organize by source (kenney/, quaternius/)
- ❌ NEVER reference `assets_bank/` in scenes or code

---

## Common Workflows

### Workflow 1: Starting Fresh
```
1. "Analyze available 3D assets in assets_bank"
   → Get report of what you have

2. "Import [specific pack] assets"
   → Copy to active project

3. "Catalog all 3D models"
   → Create documentation

4. "Build a test environment"
   → Create first playable scene
```

### Workflow 2: Building an Environment
```
1. "Create a village scene"
   → Specify: number of buildings, props, terrain features

2. Test in Godot editor with different controller modes

3. "Add more trees to the village scene"
   → Iterative refinement

4. "Create spawn points for enemies"
   → Add gameplay elements
```

### Workflow 3: Creating Prefabs
```
1. "Analyze building components"
   → Understand what modular pieces exist

2. "Assemble a house from components"
   → Create first prefab

3. "Create 3 house variations"
   → Build prefab library

4. "Use house prefabs to build a village"
   → Compose scene from prefabs
```

---

## Quality Standards

### Assets Must:
- ✅ Have proper scale (2m player character reference)
- ✅ Include collision where needed
- ✅ Use logical node names (PascalCase)
- ✅ Be organized by function, not source
- ✅ Work with all 7 controller modes

### Scenes Must:
- ✅ Clear node hierarchy
- ✅ Include spawn points (Marker3D)
- ✅ Have collision for solid objects
- ✅ Be performance-conscious
- ✅ Be production-ready

### Documentation Must:
- ✅ Be accurate and current
- ✅ Include practical examples
- ✅ Document assembly patterns
- ✅ Provide quick reference

---

## Compatible Asset Sources

### Primary (Reference Standard)
- **Kenney.nl**: Free/paid modular assets
- Well-organized, consistent scale, clean materials

### Also Compatible
- **Quaternius**: Free low-poly models
- **Synty Studios**: Paid professional packs
- **Custom models**: If following organization standard
- **Any modular pack**: With proper structure

---

## Integration with Template

This skill integrates seamlessly with your Godot 4.4 template:

- ✅ Works with all 7 controller modes
- ✅ Compatible with three-camera architecture
- ✅ Follows template naming conventions
- ✅ Uses Logger for debugging
- ✅ Respects GameConfig patterns
- ✅ Maintains CLAUDE.md standards

---

## Performance Best Practices

### Collision Optimization
- Use **simple shapes** (box, capsule, sphere)
- Avoid mesh collision when possible
- Group small objects under single StaticBody3D

### Polygon Budget
- **Low-poly**: 500-2,000 polys (Kenney, Quaternius)
- **Mid-poly**: 5,000-15,000 polys (Synty)
- **Scene target**: <500k total polys

### Draw Call Optimization
- Instance similar objects
- Share materials
- Group related objects

---

## Learning & Optimization

The skill tracks learnings in: `docs/asset_management_optimization.md`

Captured automatically:
- Effective placement strategies
- Assembly patterns that work
- Performance optimizations
- Common pitfalls
- Workflow improvements

---

## Example Prompts

### Beginner
```
"I have Kenney assets in assets_bank. Help me get started."
"Create a simple test environment with ground and some trees."
"Show me what 3D assets are available."
```

### Intermediate
```
"Build a village with 4 houses, trees, rocks, and a central plaza."
"Assemble a modular castle using wall and tower components."
"Import the city pack and organize it properly."
```

### Advanced
```
"Create a procedural forest using available tree assets with varied placement."
"Build a two-story modular building with interior and exterior."
"Generate a complete asset catalog with assembly documentation."
```

---

## Troubleshooting

### "Assets not showing in Godot"
- Check that assets are in `assets/3d_models/`, not `assets_bank/`
- Verify `.import` files were generated
- Restart Godot editor to refresh imports

### "Collision not working"
- Ensure StaticBody3D is parent of CollisionShape3D
- Check collision shape has proper size
- Verify collision layer/mask settings

### "Wrong scale"
- Player character should be ~2m tall
- Test assets against player in scene
- Scale assets uniformly (not stretched)

### "Can't find asset"
- Check `assets/3d_models/asset_inventory.md`
- Search by function (buildings/, props/) not source
- Use catalog.md for detailed search

---

## Quick Reference

### Directory Rules
| ✅ DO | ❌ DON'T |
|-------|----------|
| `res://assets/3d_models/buildings/wall.glb` | `res://assets_bank/kenney/wall.glb` |
| Organize by function | Organize by source |
| Use simple collision | Use mesh collision everywhere |
| PascalCase node names | Generic names (Node3D) |

### Common Patterns
```gdscript
# Load asset
var tree_scene = load("res://assets/3d_models/nature/tree_oak.tscn")
var tree = tree_scene.instantiate()
tree.position = Vector3(5, 0, 10)
add_child(tree)

# Create collision
var static_body = StaticBody3D.new()
var mesh = MeshInstance3D.new()
var collision = CollisionShape3D.new()
collision.shape = BoxShape3D.new()
static_body.add_child(mesh)
static_body.add_child(collision)
```

---

## Professional Context

This skill is designed for **production-quality** game development:

- ✅ Suitable for commercial projects
- ✅ Vendor-neutral for flexibility
- ✅ Well-documented for teams
- ✅ Performance-conscious
- ✅ Industry best practices

Not a hobbyist tool - this is professional game development infrastructure.

---

## Next Steps

1. **If you have assets**: "Analyze available 3D assets"
2. **If you need to import**: "Import [pack name] from assets_bank"
3. **If you want to build**: "Create a [type] environment"
4. **If you need docs**: "Catalog all 3D assets"

---

## Support & Learning

- **Skill file**: `.claude/skills/3d-asset-manager.md`
- **Optimization tracker**: `docs/asset_management_optimization.md`
- **Original workflows**: `docs/polybott_rules.md`
- **Template guide**: `CLAUDE.md`

---

**Skill Version**: 1.0
**Created**: 2025-10-30
**Status**: Ready for use
