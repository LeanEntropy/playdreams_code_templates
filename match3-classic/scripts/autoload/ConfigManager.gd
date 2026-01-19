extends Node
## ConfigManager - Loads and provides access to game configuration

var game_config: GameConfig
var theme_config: ThemeConfig
var current_level: LevelConfig

const DEFAULT_CONFIG_PATH := "res://config/game_config.tres"
const DEFAULT_THEME_PATH := "res://config/theme_royal.tres"
const LEVELS_PATH := "res://config/levels/"
const MAX_LEVELS := 5

# Metallic ring colors matching mockup
const FALLBACK_GEM_COLORS := [
	Color.WHITE,                      # NONE
	Color(0.85, 0.15, 0.15),         # RED - deep metallic red
	Color(0.9, 0.7, 0.15),           # ORANGE - metallic gold
	Color(0.2, 0.7, 0.3),            # YELLOW -> GREEN - rich green
	Color(0.15, 0.4, 0.85),          # GREEN -> BLUE - deep blue
	Color(0.95, 0.95, 0.95),         # BLUE -> WHITE - silver/white
	Color(0.6, 0.25, 0.7)            # PURPLE - metallic purple
]
const FALLBACK_COMBO_MESSAGES := ["", "", "Awesome!", "Amazing!", "Incredible!", "Insane!", "GODLIKE!"]

func _ready() -> void:
	_load_config()
	_load_theme()

func _cfg(property: String, fallback: Variant) -> Variant:
	return game_config.get(property) if game_config else fallback

func _theme(property: String, fallback: Variant) -> Variant:
	return theme_config.get(property) if theme_config else fallback

func get_grid_width() -> int: return _cfg("grid_width", 8)
func get_grid_height() -> int: return _cfg("grid_height", 8)
func get_min_match() -> int: return _cfg("min_match", 3)
func get_swap_duration() -> float: return _cfg("swap_duration", 0.1)
func get_drop_duration() -> float: return _cfg("drop_duration", 0.05)
func get_explode_duration() -> float: return _cfg("explode_duration", 0.12)
func get_spawn_duration() -> float: return _cfg("spawn_duration", 0.06)
func get_match_highlight_time() -> float: return _cfg("match_highlight_time", 0.02)
func get_special_flash_duration() -> float: return _cfg("special_flash_duration", 0.05)
func get_special_shrink_duration() -> float: return _cfg("special_shrink_duration", 0.08)
func get_selection_pulse_duration() -> float: return _cfg("selection_pulse_duration", 0.15)
func get_hover_scale_duration() -> float: return _cfg("hover_scale_duration", 0.08)
func get_transform_delay() -> float: return _cfg("transform_delay", 0.0)
func get_combo_text_duration() -> float: return _cfg("combo_text_duration", 0.5)
func get_score_per_gem() -> int: return _cfg("score_per_gem", 10)
func get_combo_multiplier() -> float: return _cfg("combo_multiplier", 1.5)
func get_special_4_bonus() -> int: return _cfg("special_4_bonus", 50)
func get_special_5_bonus() -> int: return _cfg("special_5_bonus", 100)
func get_special_lt_bonus() -> int: return _cfg("special_lt_bonus", 150)
func get_base_gem_size() -> int: return _cfg("base_gem_size", 64)
func get_gem_spacing() -> int: return _cfg("gem_spacing", 4)
func get_min_tile_size() -> float: return _cfg("min_tile_size", 40.0)
func get_max_tile_size() -> float: return _cfg("max_tile_size", 100.0)
func get_starting_moves() -> int: return _cfg("starting_moves", 30)
func get_target_score() -> int: return _cfg("target_score", 10000)
func get_grid_line_color() -> Color: return _cfg("grid_line_color", Color(0.3, 0.3, 0.4, 0.5))

func get_board_background_color() -> Color:
	if theme_config and theme_config.board_background_color:
		return theme_config.board_background_color
	return _cfg("board_background_color", Color(0.15, 0.15, 0.25, 0.9))

func get_gem_fallback_color(gem_type: int) -> Color:
	if game_config:
		return game_config.get_gem_fallback_color(gem_type)
	return FALLBACK_GEM_COLORS[gem_type] if gem_type >= 0 and gem_type < FALLBACK_GEM_COLORS.size() else Color.WHITE

func are_special_combinations_enabled() -> bool:
	return _cfg("enable_special_combinations", true)

func is_combo_enabled(combo_name: String) -> bool:
	if not are_special_combinations_enabled():
		return false
	return _cfg("combo_" + combo_name, true) if game_config else true

func get_margins(viewport_size: Vector2) -> Dictionary:
	if game_config:
		return game_config.get_margins(viewport_size)
	var portrait := viewport_size.y > viewport_size.x
	return {"top": 180.0 if portrait else 80.0, "bottom": 100.0 if portrait else 60.0, "sides": 20.0 if portrait else 200.0}

func is_portrait(viewport_size: Vector2) -> bool:
	return viewport_size.y > viewport_size.x

func get_combo_message(combo_count: int) -> String:
	if game_config:
		return game_config.get_combo_message(combo_count)
	if combo_count >= 6:
		return "GODLIKE!"
	return FALLBACK_COMBO_MESSAGES[combo_count] if combo_count >= 0 and combo_count < FALLBACK_COMBO_MESSAGES.size() else ""

func get_gem_texture(gem_type: int) -> Texture2D:
	return theme_config.get_gem_texture(gem_type) if theme_config else null

func get_special_overlay(special_type: int) -> Texture2D:
	return theme_config.get_special_overlay(special_type) if theme_config else null

func get_selection_ring_texture() -> Texture2D:
	return _theme("selection_ring_texture", null)

func get_selection_ring_color() -> Color:
	return _theme("selection_ring_color", Color.YELLOW)

func get_background_color() -> Color:
	return _theme("background_color", Color(0.12, 0.12, 0.18, 1))

func get_background_texture() -> Texture2D:
	return _theme("background_texture", null)

func get_swap_sound() -> AudioStream: return _theme("swap_sound", null)
func get_match_sound() -> AudioStream: return _theme("match_sound", null)
func get_special_sound() -> AudioStream: return _theme("special_sound", null)

# UI Theme accessors
func get_ui_panel_color() -> Color: return _theme("ui_panel_color", Color(0.15, 0.17, 0.25, 0.95))
func get_ui_panel_border_color() -> Color: return _theme("ui_panel_border_color", Color(0.76, 0.6, 0.32, 1.0))
func get_ui_button_color() -> Color: return _theme("ui_button_color", Color(0.35, 0.5, 0.75, 1.0))
func get_ui_button_hover_color() -> Color: return _theme("ui_button_hover_color", Color(0.45, 0.6, 0.85, 1.0))
func get_ui_button_pressed_color() -> Color: return _theme("ui_button_pressed_color", Color(0.25, 0.4, 0.65, 1.0))
func get_ui_accent_color() -> Color: return _theme("ui_accent_color", Color(0.9, 0.75, 0.4, 1.0))
func get_ui_success_color() -> Color: return _theme("ui_success_color", Color(0.4, 0.85, 0.4, 1.0))
func get_ui_fail_color() -> Color: return _theme("ui_fail_color", Color(0.9, 0.35, 0.35, 1.0))
func get_ui_text_color() -> Color: return _theme("ui_text_color", Color.WHITE)
func get_ui_text_secondary_color() -> Color: return _theme("ui_text_secondary_color", Color(0.7, 0.7, 0.8, 1.0))
func get_ui_overlay_color() -> Color: return _theme("ui_overlay_color", Color(0.0, 0.0, 0.0, 0.7))
func get_star_filled_texture() -> Texture2D: return _theme("star_filled_texture", null)
func get_star_empty_texture() -> Texture2D: return _theme("star_empty_texture", null)
func get_level_complete_title() -> String: return _theme("level_complete_title", "Level Complete!")
func get_level_failed_title() -> String: return _theme("level_failed_title", "Out of Moves!")
func get_pause_title() -> String: return _theme("pause_title", "Paused")
func get_close_message() -> String: return _theme("close_message", "So close!")
func get_try_again_message() -> String: return _theme("try_again_message", "Try again!")

func are_boosters_enabled() -> bool:
	return _cfg("enable_boosters", true)

func is_booster_enabled(booster_type: Enums.BoosterType) -> bool:
	if not are_boosters_enabled():
		return false
	match booster_type:
		Enums.BoosterType.LOLLIPOP_HAMMER: return _cfg("booster_lollipop_hammer", true)
		Enums.BoosterType.FREE_SWITCH: return _cfg("booster_free_switch", true)
		Enums.BoosterType.SHUFFLE: return _cfg("booster_shuffle", true)
		Enums.BoosterType.COLOR_BOMB_START: return _cfg("booster_color_bomb_start", true)
		Enums.BoosterType.EXTRA_MOVES: return _cfg("booster_extra_moves", true)
		_: return false

func get_starting_boosters(booster_name: String) -> int:
	return _cfg("start_" + booster_name, 0)

func get_extra_moves_amount() -> int:
	return _cfg("extra_moves_amount", 5)

# Booster textures
func get_booster_texture(booster_type: Enums.BoosterType) -> Texture2D:
	match booster_type:
		Enums.BoosterType.LOLLIPOP_HAMMER: return _theme("booster_hammer_texture", null)
		Enums.BoosterType.FREE_SWITCH: return _theme("booster_switch_texture", null)
		Enums.BoosterType.SHUFFLE: return _theme("booster_shuffle_texture", null)
		Enums.BoosterType.COLOR_BOMB_START: return _theme("booster_bomb_texture", null)
		Enums.BoosterType.EXTRA_MOVES: return _theme("booster_moves_texture", null)
		_: return null

# Audio settings
var _sound_enabled: bool = true
var _music_enabled: bool = true

func is_sound_enabled() -> bool: return _sound_enabled
func is_music_enabled() -> bool: return _music_enabled
func get_sound_volume() -> float: return _theme("sound_volume", 1.0)
func get_music_volume() -> float: return _theme("music_volume", 0.7)
func get_cascade_sound() -> AudioStream: return _theme("cascade_sound", null)

func set_sound_enabled(enabled: bool) -> void:
	_sound_enabled = enabled

func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled

func _load_config() -> void:
	if ResourceLoader.exists(DEFAULT_CONFIG_PATH):
		game_config = load(DEFAULT_CONFIG_PATH)
	else:
		game_config = GameConfig.new()

func _load_theme() -> void:
	if ResourceLoader.exists(DEFAULT_THEME_PATH):
		theme_config = load(DEFAULT_THEME_PATH)

func load_theme(theme_path: String) -> bool:
	if ResourceLoader.exists(theme_path):
		theme_config = load(theme_path)
		return true
	return false

func reload_config() -> void:
	_load_config()
	_load_theme()

# Level loading
func load_level(level_num: int) -> LevelConfig:
	var clamped_level := clampi(level_num, 1, MAX_LEVELS)
	var level_path := LEVELS_PATH + "level_" + str(clamped_level) + ".tres"
	if ResourceLoader.exists(level_path):
		current_level = load(level_path)
	else:
		current_level = _create_default_level(clamped_level)
	return current_level

func get_current_level() -> LevelConfig:
	if not current_level:
		load_level(1)
	return current_level

func get_max_levels() -> int:
	return MAX_LEVELS

func _create_default_level(level_num: int) -> LevelConfig:
	var level := LevelConfig.new()
	level.level_number = level_num
	level.max_moves = 30
	level.target_score = 3000 + (level_num - 1) * 2000
	level.star_1_threshold = level.target_score
	level.star_2_threshold = level.target_score + 2000
	level.star_3_threshold = level.target_score + 5000
	level.goal_description = "Score %d points!" % level.target_score
	return level
