extends Resource
class_name LevelConfig
## Configuration resource for individual level settings

@export_group("Level Info")
@export var level_number: int = 1
@export var level_type: Enums.LevelType = Enums.LevelType.SCORE_TARGET
@export var max_moves: int = 25
@export var goal_description: String = "Reach the target score!"
@export_range(3, 6) var gem_types_count: int = 6  # Number of gem colors (3-6)

@export_group("Score Target")
@export var target_score: int = 5000

@export_group("Clear Count")
@export var target_clears: int = 50

@export_group("Combo Challenge")
@export var target_combos: int = 5

@export_group("Special Creation")
@export var target_specials: int = 3

@export_group("Color Collection")
@export var target_color_1: Enums.GemColor = Enums.GemColor.RED
@export var target_color_1_count: int = 20
@export var target_color_2: Enums.GemColor = Enums.GemColor.BLUE
@export var target_color_2_count: int = 20

@export_group("Star Thresholds")
@export var star_1_threshold: int = 1
@export var star_2_threshold: int = 5000
@export var star_3_threshold: int = 10000

func get_goal_target() -> int:
	match level_type:
		Enums.LevelType.SCORE_TARGET:
			return target_score
		Enums.LevelType.CLEAR_COUNT:
			return target_clears
		Enums.LevelType.COMBO_CHALLENGE:
			return target_combos
		Enums.LevelType.SPECIAL_CREATION:
			return target_specials
		Enums.LevelType.COLOR_COLLECTION:
			return target_color_1_count + target_color_2_count
	return 0

func get_level_type_name() -> String:
	match level_type:
		Enums.LevelType.SCORE_TARGET:
			return "Score Target"
		Enums.LevelType.CLEAR_COUNT:
			return "Clear Count"
		Enums.LevelType.COMBO_CHALLENGE:
			return "Combo Challenge"
		Enums.LevelType.SPECIAL_CREATION:
			return "Special Creation"
		Enums.LevelType.COLOR_COLLECTION:
			return "Color Collection"
	return "Unknown"
