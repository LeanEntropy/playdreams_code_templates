extends Node
class_name Enums
## Global enums and constants for the Match-3 game

enum GemColor { NONE, RED, ORANGE, YELLOW, GREEN, BLUE, PURPLE }
enum SpecialType { NONE, STRIPED_H, STRIPED_V, WRAPPED, COLOR_BOMB }
enum BoosterType { NONE, LOLLIPOP_HAMMER, FREE_SWITCH, SHUFFLE, COLOR_BOMB_START, EXTRA_MOVES }
enum LevelType { SCORE_TARGET, CLEAR_COUNT, COMBO_CHALLENGE, SPECIAL_CREATION, COLOR_COLLECTION }

const GEM_COLOR_COUNT := 6
const GRID_WIDTH := 8
const GRID_HEIGHT := 8
const MIN_MATCH := 3

const SWAP_DURATION := 0.2
const DROP_DURATION := 0.15
const EXPLODE_DURATION := 0.3
const SPAWN_DURATION := 0.25
const MATCH_HIGHLIGHT_TIME := 0.1

const SCORE_PER_GEM := 10
const COMBO_MULTIPLIER := 1.5
const SPECIAL_4_BONUS := 50
const SPECIAL_5_BONUS := 100
const SPECIAL_LT_BONUS := 150

const BASE_GEM_SIZE := 64
const GEM_SPACING := 4

static func get_random_color(max_types: int = GEM_COLOR_COUNT) -> GemColor:
	var clamped_max := clampi(max_types, 1, GEM_COLOR_COUNT)
	return (randi() % clamped_max + 1) as GemColor

static func color_to_string(color: GemColor) -> String:
	return ["None", "Red", "Orange", "Yellow", "Green", "Blue", "Purple"][color]

static func special_to_string(special: SpecialType) -> String:
	return ["Normal", "Striped (Horizontal)", "Striped (Vertical)", "Wrapped", "Color Bomb"][special]
