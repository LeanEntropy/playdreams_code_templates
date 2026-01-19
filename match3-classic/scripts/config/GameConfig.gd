extends Resource
class_name GameConfig
## Configuration resource for Match-3 game settings

@export_group("Grid")
@export var grid_width: int = 8
@export var grid_height: int = 8
@export var min_match: int = 3

@export_group("Timing")
@export var swap_duration: float = 0.08
@export var drop_duration: float = 0.04
@export var explode_duration: float = 0.08
@export var spawn_duration: float = 0.06
@export var match_highlight_time: float = 0.02
@export var special_flash_duration: float = 0.05
@export var special_shrink_duration: float = 0.08
@export var selection_pulse_duration: float = 0.15
@export var hover_scale_duration: float = 0.08
@export var transform_delay: float = 0.0  # Delay before activating transformed specials (0 = no delay)
@export var combo_text_duration: float = 0.5  # How long combo text ("Amazing!") stays visible

@export_group("Scoring")
@export var score_per_gem: int = 10
@export var combo_multiplier: float = 1.5
@export var special_4_bonus: int = 50
@export var special_5_bonus: int = 100
@export var special_lt_bonus: int = 150

@export_group("Visual")
@export var base_gem_size: int = 64
@export var gem_spacing: int = 4
@export var min_tile_size: float = 40.0
@export var max_tile_size: float = 100.0

@export_group("Game Rules")
@export var starting_moves: int = 30
@export var target_score: int = 10000

@export_group("Special Combinations")
@export var enable_special_combinations: bool = true
@export var combo_striped_striped: bool = true
@export var combo_wrapped_wrapped: bool = true
@export var combo_colorbomb_colorbomb: bool = true
@export var combo_striped_wrapped: bool = true
@export var combo_colorbomb_striped: bool = true
@export var combo_colorbomb_wrapped: bool = true
@export var combo_colorbomb_regular: bool = true

@export_group("UI Margins (Portrait)")
@export var margin_top_portrait: float = 180.0
@export var margin_bottom_portrait: float = 100.0
@export var margin_sides_portrait: float = 20.0

@export_group("UI Margins (Landscape)")
@export var margin_top_landscape: float = 80.0
@export var margin_bottom_landscape: float = 60.0
@export var margin_sides_landscape: float = 200.0

@export_group("Colors")
@export var board_background_color: Color = Color(0.15, 0.15, 0.25, 0.9)
@export var grid_line_color: Color = Color(0.3, 0.3, 0.4, 0.5)

@export_group("Gem Colors")
@export var gem_color_red: Color = Color(0.9, 0.2, 0.2)
@export var gem_color_orange: Color = Color(0.95, 0.5, 0.1)
@export var gem_color_yellow: Color = Color(0.95, 0.9, 0.2)
@export var gem_color_green: Color = Color(0.2, 0.8, 0.3)
@export var gem_color_blue: Color = Color(0.2, 0.4, 0.9)
@export var gem_color_purple: Color = Color(0.6, 0.2, 0.8)

@export_group("Combo Messages")
@export var combo_message_2: String = "Awesome!"
@export var combo_message_3: String = "Amazing!"
@export var combo_message_4: String = "Incredible!"
@export var combo_message_5: String = "Insane!"
@export var combo_message_6: String = "GODLIKE!"

@export_group("Boosters")
@export var enable_boosters: bool = true
@export var booster_lollipop_hammer: bool = true
@export var booster_free_switch: bool = true
@export var booster_shuffle: bool = true
@export var booster_color_bomb_start: bool = true
@export var booster_extra_moves: bool = true
@export var extra_moves_amount: int = 5

@export_group("Starting Booster Inventory")
@export var start_lollipop_hammer: int = 3
@export var start_free_switch: int = 3
@export var start_shuffle: int = 2
@export var start_color_bomb_start: int = 1
@export var start_extra_moves: int = 2

var _gem_colors: Array[Color]:
	get: return [Color.WHITE, gem_color_red, gem_color_orange, gem_color_yellow, gem_color_green, gem_color_blue, gem_color_purple]

var _combo_messages: Array[String]:
	get: return ["", "", combo_message_2, combo_message_3, combo_message_4, combo_message_5, combo_message_6]

func get_gem_fallback_color(gem_color: int) -> Color:
	return _gem_colors[gem_color] if gem_color >= 0 and gem_color < _gem_colors.size() else Color.WHITE

func get_margins(viewport_size: Vector2) -> Dictionary:
	var portrait := viewport_size.y > viewport_size.x
	return {
		"top": margin_top_portrait if portrait else margin_top_landscape,
		"bottom": margin_bottom_portrait if portrait else margin_bottom_landscape,
		"sides": margin_sides_portrait if portrait else margin_sides_landscape
	}

func get_combo_message(combo_count: int) -> String:
	if combo_count >= 6:
		return combo_message_6
	return _combo_messages[combo_count] if combo_count >= 0 and combo_count < _combo_messages.size() else ""
