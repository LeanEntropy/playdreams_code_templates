class_name Config
extends RefCounted

# =============================================================================
# Theme System
# =============================================================================
# Switch between "minimal" (sharp black/white) and "pastel" (rounded colorful).
# All color and style lookups go through get_theme().

const THEME: String = "minimal"

const THEMES: Dictionary = {
	"minimal": {
		"bg": Color.WHITE,
		"arrow_normal": Color("#000000"),
		"arrow_exit": Color("#4D6AFF"),
		"arrow_failed": Color("#E53935"),
		"arrow_palette": [],  # not used — single color (arrow_normal)
		"guide_line": Color(0.80, 0.82, 0.90, 0.6),
		"heart": Color("#E53935"),
		"heart_empty": Color("#CCCCCC"),
		"cell_dot": Color("#CCCCCC"),
		"title": Color("#1B2A4A"),
		"accent": Color("#7B8CDE"),
		"body": Color("#E0E0E0"),
		# Nav bar
		"nav_bg": Color("#F0F2F8"),
		"nav_icon": Color("#8E95A9"),
		"nav_icon_active": Color("#1B2A4A"),
		"nav_pill": Color("#E0E4EF"),
		# Settings cards
		"card_bg": Color("#E8ECF4"),
		"toggle_on": Color("#7B8CDE"),
		"toggle_off": Color("#8E95A9"),
		# Tier colors
		"tier_easy": Color("#4CAF50"),
		"tier_medium": Color("#FF9800"),
		"tier_hard": Color("#00BCD4"),
		"tier_expert": Color("#E53935"),
		# Victory overlay
		"victory_overlay": Color(1, 1, 1, 0.65),
		"victory_text": Color("#1B2A4A"),
		# Arrow rendering style
		"arrow_style": "sharp",
		"shadow_enabled": false,
		"shadow_offset": Vector2.ZERO,
		"shadow_darken": 0.0,
		"chevron_enabled": false,
		"cell_gap": 0.0,
		"chevron_size_ratio": 0.0,
		"chevron_stroke_width": 0.0,
		"chevron_color": Color.WHITE,
	},
	"pastel": {
		"bg": Color("#2B2D3A"),
		"arrow_normal": Color("#7B8FBD"),  # default single color (palette[0])
		"arrow_exit": Color.WHITE,
		"arrow_failed": Color("#D44A3A"),
		"arrow_palette": [
			Color("#7B8FBD"), Color("#D9917B"), Color("#E0D8A0"),
			Color("#E4B0B8"), Color("#96CDE0"), Color("#6DBFA0"),
			Color("#BDC84A"), Color("#C8C5BD"),
		],
		"guide_line": Color(1, 1, 1, 0.2),
		"heart": Color("#D44A3A"),
		"heart_empty": Color(1, 1, 1, 0.3),
		"cell_dot": Color(1, 1, 1, 0.15),
		"title": Color.WHITE,
		"accent": Color("#BFEF45"),
		"body": Color("#3A3D4A"),
		# Nav bar
		"nav_bg": Color("#3A3D4A"),
		"nav_icon": Color("#A0A4B8"),
		"nav_icon_active": Color.WHITE,
		"nav_pill": Color("#4A4D5A"),
		# Settings cards
		"card_bg": Color("#3A3D4A"),
		"toggle_on": Color("#BFEF45"),
		"toggle_off": Color("#A0A4B8"),
		# Tier colors
		"tier_easy": Color("#4CAF50"),
		"tier_medium": Color("#FF9800"),
		"tier_hard": Color("#00BCD4"),
		"tier_expert": Color("#D44A3A"),
		# Victory overlay
		"victory_overlay": Color(0.17, 0.18, 0.23, 0.65),
		"victory_text": Color.WHITE,
		# Arrow rendering style
		"arrow_style": "rounded",
		"shadow_enabled": true,
		"shadow_offset": Vector2(0, 6),
		"shadow_darken": 0.3,
		"chevron_enabled": true,
		"cell_gap": 8.0,
		"chevron_size_ratio": 0.40,
		"chevron_stroke_width": 2.5,
		"chevron_color": Color(1.0, 1.0, 1.0, 0.85),
	},
}

# Theme helper — returns the active theme dictionary
static func get_theme() -> Dictionary:
	return THEMES[THEME]

# =============================================================================
# Color aliases (read from active theme for backward compatibility)
# =============================================================================

static var COLOR_BG: Color = THEMES[THEME]["bg"]
static var COLOR_ARROW: Color = THEMES[THEME]["arrow_normal"]
static var COLOR_ARROW_EXIT: Color = THEMES[THEME]["arrow_exit"]
static var COLOR_ARROW_FAILED: Color = THEMES[THEME]["arrow_failed"]
static var COLOR_BODY: Color = THEMES[THEME]["body"]
static var COLOR_TITLE: Color = THEMES[THEME]["title"]
static var COLOR_ACCENT: Color = THEMES[THEME]["accent"]
static var COLOR_HEART: Color = THEMES[THEME]["heart"]
static var COLOR_HEART_EMPTY: Color = THEMES[THEME]["heart_empty"]
static var COLOR_CELL_DOT: Color = THEMES[THEME]["cell_dot"]
static var COLOR_GUIDE_LINE: Color = THEMES[THEME]["guide_line"]
static var COLOR_NAV_BG: Color = THEMES[THEME]["nav_bg"]
static var COLOR_NAV_ICON: Color = THEMES[THEME]["nav_icon"]
static var COLOR_NAV_ICON_ACTIVE: Color = THEMES[THEME]["nav_icon_active"]
static var COLOR_NAV_PILL: Color = THEMES[THEME]["nav_pill"]
static var COLOR_CARD_BG: Color = THEMES[THEME]["card_bg"]
static var COLOR_TOGGLE_ON: Color = THEMES[THEME]["toggle_on"]
static var COLOR_TOGGLE_OFF: Color = THEMES[THEME]["toggle_off"]

# Tier colors (always same across themes for now, but still theme-driven)
static var COLOR_TIER_EASY: Color = THEMES[THEME]["tier_easy"]
static var COLOR_TIER_MEDIUM: Color = THEMES[THEME]["tier_medium"]
static var COLOR_TIER_HARD: Color = THEMES[THEME]["tier_hard"]
static var COLOR_TIER_EXPERT: Color = THEMES[THEME]["tier_expert"]

# =============================================================================
# Viewport
# =============================================================================

const VIEWPORT_WIDTH := 720
const VIEWPORT_HEIGHT := 1280

# =============================================================================
# Grid
# =============================================================================

const GRID_MARGIN := 40
const GRID_VERTICAL_RATIO := 0.65
const GRID_TOP_MARGIN := 80.0
const MIN_CELL_SIZE := 60
const FIXED_CELL_SIZE := 65.0  # arrows always look same size at start

# =============================================================================
# Gameplay
# =============================================================================

const HEARTS_MAX := 3
const HEARTS_START := 3

# =============================================================================
# Zoom & Pan
# =============================================================================

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1
const PAN_DRAG_THRESHOLD := 10.0
const PAN_VISIBLE_RATIO := 0.25  # board must stay at least 25% visible

# =============================================================================
# Arrow geometry — sharp style (ratios to cell_size)
# =============================================================================

const ARROW_BODY_WIDTH := 0.20
const ARROW_HEAD_WIDTH := 0.38
const ARROW_HEAD_LENGTH := 0.25
const ARROW_TAIL_LENGTH := 0.6  # single-cell tail stub length ratio

# =============================================================================
# Arrow animation
# =============================================================================

const EXIT_SPEED := 4800.0        # px/s, constant velocity
const EXIT_COLOR_DURATION := 0.1  # color transition time (s)
const NUDGE_DURATION := 0.3
const NUDGE_DISTANCE := 30
const ENTRANCE_DURATION := 0.3
const ENTRANCE_STAGGER := 0.05
const SHAKE_AMOUNT := 3.0
const SHAKE_DURATION := 0.1

# =============================================================================
# Trail
# =============================================================================

const TRAIL_DOT_RATIO := 0.06    # dot radius relative to cell_size
const TRAIL_FADE_DURATION := 1.0  # seconds

# =============================================================================
# Cell dots
# =============================================================================

const CELL_DOT_RATIO := 0.05     # dot radius relative to cell_size

# =============================================================================
# Victory
# =============================================================================

const VICTORY_DELAY := 1.5
const VICTORY_SHOW_DURATION := 2.0    # how long confetti + message shows
const TRANSITION_FADE_DURATION := 0.5 # fade to/from white duration
const LEVEL_ANIM_DURATION := 0.4      # level number change animation

# =============================================================================
# Direction vectors
# =============================================================================

const DIR_VECTORS := {
	"U": Vector2i(0, -1),
	"D": Vector2i(0, 1),
	"L": Vector2i(-1, 0),
	"R": Vector2i(1, 0),
}

# =============================================================================
# UI - Nav Bar
# =============================================================================

const NAV_BAR_HEIGHT := 90

# =============================================================================
# Save
# =============================================================================

const SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 2
const SETTINGS_SAVE_PATH := "user://settings.json"


# =============================================================================
# Helpers
# =============================================================================

static func get_tier_name(level_index: int) -> String:
	if level_index < 4:
		return "Easy"
	elif level_index < 7:
		return "Medium"
	elif level_index < 11:
		return "Hard"
	return "Expert"


static func get_tier_color(tier_name: String) -> Color:
	match tier_name:
		"Easy": return COLOR_TIER_EASY
		"Medium": return COLOR_TIER_MEDIUM
		"Hard": return COLOR_TIER_HARD
		"Expert": return COLOR_TIER_EXPERT
	return COLOR_ACCENT


static func set_corner_radius(style: StyleBoxFlat, radius: int) -> void:
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
