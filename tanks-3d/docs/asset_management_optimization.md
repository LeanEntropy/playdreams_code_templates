# 3D Asset Management Optimization Tracker

**Purpose**: Track learnings, optimizations, and best practices for the 3D Asset Manager skill

**Skill**: 3D Asset Manager for Godot 4.4 (vendor-neutral)

---

## Version History

### v1.0 - Initial Setup (2025-10-30)
- Created comprehensive 3D Asset Manager skill
- Established vendor-neutral approach
- Documented Kenney.nl as reference standard
- Integrated with existing Godot 4.4 template

---

## Asset Organization Standards

### Directory Structure (Two-Tier System)

#### Staging Directory (assets_bank/)
- **Purpose**: Source material storage, never referenced in code
- **Organization**: By vendor/source for easy asset pack management
- **Status**: Outside Godot project scope

#### Active Directory (assets/3d_models/)
- **Purpose**: Active project assets, always use res:// paths
- **Organization**: By function (buildings, props, terrain, etc.)
- **Status**: Part of Godot project, included in builds

### Why Two-Tier?
- **Separation of concerns**: Source vs. active assets
- **Vendor neutrality**: Don't lock project to specific asset pack names
- **Flexibility**: Easy to swap asset sources
- **Clarity**: Clear distinction between staging and production

---

## Known Asset Sources

### Kenney.nl (Reference Standard)
- **Status**: Reference implementation for organization
- **Characteristics**:
  - Free and paid options
  - Modular component design
  - Consistent scale and pivot points
  - Clean materials
  - Well-organized categories
- **Categories**: Buildings, props, terrain, vehicles, characters, nature

### Quaternius
- **Status**: Compatible
- **Characteristics**: Free low-poly models, good for prototyping
- **Integration**: Works with skill when organized properly

### Synty Studios
- **Status**: Compatible
- **Characteristics**: Paid modular packs, professional quality
- **Integration**: Requires functional reorganization after import

### Custom Models
- **Status**: Compatible if following standards
- **Requirements**:
  - Proper scale (2m player reference)
  - Correct pivot points
  - Clean materials
  - Functional organization

---

## Asset Type Classification

### Complete Models
**Characteristics**:
- Self-contained, ready to place
- No assembly required
- Examples: trees, rocks, furniture, vehicles

**Workflow**:
1. Import to functional category
2. Instance in scene
3. Add collision if needed
4. Done

**Performance Notes**:
- Use simple collision shapes
- Consider LOD for distant objects (future)
- Instance reuse for duplicates

### Modular Components
**Characteristics**:
- Designed to combine into structures
- Require assembly logic
- Examples: walls, floors, roofs, building kits

**Workflow**:
1. Import to subcategory (buildings/walls/, etc.)
2. Create assembly scene
3. Position with snapping
4. Add unified collision
5. Save as prefab

**Performance Notes**:
- Group collision shapes when possible
- Use grid snapping for alignment
- Create reusable prefabs to avoid duplication

---

## Effective Placement Strategies

### Grid-Based Placement
- **Use for**: Buildings, modular structures, urban environments
- **Grid size**: Typically 0.5m, 1m, or 2m
- **Tools**: Godot editor snap settings
- **Benefits**: Clean alignment, easy assembly

### Organic Placement
- **Use for**: Nature, props, terrain features
- **Approach**: Manual positioning with slight variations
- **Tools**: Random rotation, scale variation
- **Benefits**: Natural, non-repetitive appearance

### Strategic Clustering
- **Use for**: Forests, rock formations, prop groups
- **Approach**: Group similar objects in clusters
- **Benefits**: Visual interest, performance grouping

---

## Collision Best Practices

### Shape Selection Priority
1. **BoxShape3D**: Buildings, walls, crates, platforms
2. **CapsuleShape3D**: Trees, poles, columns
3. **SphereShape3D**: Rocks, boulders, round objects
4. **ConcavePolygonShape3D**: Only for complex terrain (performance cost)

### Performance Optimization
- Use simple shapes whenever possible
- Group small objects under single StaticBody3D
- Avoid mesh collision for moving objects
- Test collision in game, not just editor

### Common Patterns
```gdscript
# Pattern 1: Simple Static Object
StaticObject (StaticBody3D)
├── Mesh (MeshInstance3D)
└── Collision (CollisionShape3D - BoxShape3D)

# Pattern 2: Complex Structure (multiple collision)
Building (StaticBody3D)
├── Walls (Node3D)
│   └── [wall meshes]
├── Floors (Node3D)
│   └── [floor meshes]
├── WallCollision (CollisionShape3D)
└── FloorCollision (CollisionShape3D)

# Pattern 3: Grouped Props
PropCluster (Node3D)
├── Tree01 (StaticBody3D)
│   ├── Mesh
│   └── Collision (CapsuleShape3D)
├── Tree02 (StaticBody3D)
│   ├── Mesh
│   └── Collision (CapsuleShape3D)
```

---

## Assembly Patterns That Work

### Pattern: Modular House
**Components**: Walls, floors, roof sections
**Steps**:
1. Create root Node3D: `HouseModular01`
2. Add organizational groups: `Walls`, `Floors`, `Roof`
3. Position walls on 2m grid
4. Add floor tiles to fit wall boundaries
5. Cap with roof sections
6. Add unified StaticBody3D with simple collision boxes
7. Save as prefab in `/assets/prefabs/`

**Result**: Reusable house prefab

### Pattern: Forest Scene
**Components**: Ground, trees, rocks
**Steps**:
1. Create ground plane (StaticBody3D + plane mesh + box collision)
2. Instance tree scenes from catalog
3. Distribute with organic placement
4. Add rock clusters for variation
5. Use capsule collision for trees
6. Group trees under `Trees` node for organization

**Result**: Natural forest environment

### Pattern: Village Layout
**Components**: Buildings, props, terrain, spawn points
**Steps**:
1. Create organizational structure (Buildings, Props, Terrain, SpawnPoints)
2. Place ground terrain
3. Position buildings with spacing
4. Add props (trees, crates, barrels)
5. Add player spawn (Marker3D)
6. Test with multiple controller modes

**Result**: Complete playable environment

---

## Workflow Optimizations

### Batch Operations
- Import entire asset packs at once
- Create multiple instances in single scene setup
- Use Godot's duplicate feature (Ctrl+D) for similar placements

### Template Scenes
- Create base environment template (`environment_base.tscn`)
- Include standard organizational structure
- Start new scenes from template

### Prefab Library
- Build library of reusable structures
- Document each prefab in `assembly_patterns.md`
- Quick assembly from prefab instances

---

## Documentation Standards

### Asset Inventory
**File**: `assets/3d_models/asset_inventory.md`
**Contents**: Master list with basic info
**Format**: Table or list with name, type, category, source

### Asset Catalog
**File**: `assets/3d_models/catalog.md`
**Contents**: Detailed metadata per asset
**Format**: Markdown sections with comprehensive details

### Assembly Patterns
**File**: `assets/3d_models/assembly_patterns.md`
**Contents**: Step-by-step assembly guides for modular structures
**Format**: Procedural instructions with examples

### Quick Reference
**File**: `assets/3d_models/quick_reference.md`
**Contents**: Common patterns and quick lookup
**Format**: Condensed cheat sheet

---

## Learnings Log

### Session 1: Skill Creation (2025-10-30)
- Created vendor-neutral 3D Asset Manager skill
- Established two-tier directory system (staging + active)
- Documented Kenney.nl as reference organizational standard
- Integrated with existing Godot 4.4 template architecture
- Created comprehensive workflow patterns

**Key Insight**: Vendor-neutrality is critical for professional template. Users should be able to use any asset source that follows the modular organization standard.

---

## Patterns That Work Well

### Organizational
- ✅ Two-tier directory system (staging + active)
- ✅ Functional organization (buildings/, props/) over source organization
- ✅ Clear separation: assets_bank/ never referenced in code
- ✅ Always use res:// paths in scenes

### Technical
- ✅ Simple collision shapes (box, capsule, sphere)
- ✅ Grouped collision under single StaticBody3D
- ✅ Node3D organizational groups (Buildings, Props, Terrain)
- ✅ Marker3D for spawn points
- ✅ PascalCase node naming

### Workflow
- ✅ Analyze before importing
- ✅ Catalog after importing
- ✅ Test with multiple controller modes
- ✅ Document assembly patterns
- ✅ Create reusable prefabs

---

## Patterns That Don't Work

### Organizational
- ❌ Organizing by source (kenney/, quaternius/) - breaks vendor neutrality
- ❌ Referencing assets_bank/ in scenes - breaks portability
- ❌ Absolute file system paths - Godot requires res://
- ❌ Generic node names (Node3D, MeshInstance3D2) - poor maintainability

### Technical
- ❌ Mesh collision for everything - performance nightmare
- ❌ No collision on solid objects - player falls through
- ❌ Wrong scale (not testing against 2m player) - proportion issues
- ❌ Flat hierarchy (all objects at root) - organization nightmare

### Workflow
- ❌ Import everything without analysis - asset bloat
- ❌ Skip cataloging - can't find assets later
- ❌ Test with only one controller - compatibility issues
- ❌ No documentation - knowledge loss

---

## Performance Considerations

### Polygon Budget
- **Low-poly style**: 500-2,000 polys per object (Kenney, Quaternius)
- **Mid-poly style**: 5,000-15,000 polys per object (Synty)
- **High-poly style**: 20,000+ polys per object (custom)
- **Scene target**: Aim for <500k total polys for good performance

### Collision Optimization
- Simple shapes: ~0.1ms per check
- Mesh collision: ~1-10ms per check (avoid if possible)
- Grouped collision: Better than individual collision per object

### Draw Calls
- Instancing reduces draw calls
- Shared materials reduce draw calls
- Batching similar objects helps performance

### Occlusion
- Hide interior objects when not visible
- Use occlusion culling (future enhancement)
- Consider LOD system for distant objects (future)

---

## Future Enhancements

### Short Term
- [ ] Create template environment scenes (forest, village, dungeon)
- [ ] Build prefab library (houses, structures, props)
- [ ] Document common assembly patterns
- [ ] Create quick reference guide

### Medium Term
- [ ] Implement LOD system for distant objects
- [ ] Add procedural placement helpers (forest generator, etc.)
- [ ] Create material management system
- [ ] Develop asset search/filter functionality

### Long Term
- [ ] AI-driven procedural generation using available assets
- [ ] Asset combination suggestions based on scene type
- [ ] Automated collision generation
- [ ] Performance profiling and optimization suggestions

---

## Integration with Godot 4.4 Template

### Compatible Systems
- **Controller modes**: All 7 modes (first_person, third_person, over_the_shoulder, tank, free_camera, top_down, isometric)
- **Camera system**: Three-camera architecture (PlayerCamera, ObserverCamera, TankCamera)
- **UI system**: UILayer, crosshair, pause menu
- **Config system**: GameConfig singleton

### Testing Checklist
When creating environments, test with:
- [x] First-person controller (movement through environment)
- [x] Third-person controller (camera clearance)
- [x] Tank controller (vehicle navigation)
- [x] Top-down controller (visibility and navigation)
- [x] Free camera (debug view)

### Spawn Point Standards
- **Name**: `PlayerSpawn` (Marker3D)
- **Position**: Above ground (y = 0.5 to 1.0)
- **Rotation**: Facing logical direction
- **Parent**: `SpawnPoints` group node

---

## Reference Materials

### External Documentation
- Kenney.nl asset documentation
- Godot 4.4 official docs (Node3D, StaticBody3D, CollisionShape3D)
- Project CLAUDE.md (template architecture)

### Internal Documentation
- `docs/polybott_rules.md` - Original workflow (reference)
- `docs/polybott_optimization.md` - Original tracking (reference)
- `CLAUDE.md` - Template architecture and best practices

---

## Success Metrics

A well-executed asset management workflow produces:

1. ✅ **Organized library**: Functional categorization, easy to navigate
2. ✅ **Complete docs**: Inventory, catalog, patterns, quick reference
3. ✅ **Production scenes**: Proper hierarchy, collision, spawn points
4. ✅ **Reusable prefabs**: Common structures ready to use
5. ✅ **Good performance**: Simple collision, reasonable poly counts
6. ✅ **Vendor neutral**: Not locked to specific asset source
7. ✅ **Well documented**: Patterns and learnings tracked

---

## Notes and Observations

### Vendor Neutrality Benefits
- Projects not locked to single asset source
- Easy to swap or combine asset packs
- More professional and portable
- Better for commercial projects

### Two-Tier System Benefits
- Clear separation of staging vs. production
- Easy to experiment with assets before committing
- Cleaner project organization
- No asset pack clutter in version control

### Documentation Benefits
- New team members onboard faster
- AI agents understand asset library
- Reduces "where is that asset?" questions
- Captures assembly knowledge

---

**Last Updated**: 2025-10-30
**Maintained By**: 3D Asset Manager skill
**Status**: Active development
