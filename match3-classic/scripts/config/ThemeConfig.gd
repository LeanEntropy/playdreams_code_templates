extends Resource
class_name ThemeConfig
## Theme configuration for easily swapping game visuals

@export_group("Theme Info")
@export var theme_name: String = "default"
@export var theme_description: String = "Default match-3 theme"

@export_group("Gem Textures")
@export var gem_texture_1: Texture2D
@export var gem_texture_2: Texture2D
@export var gem_texture_3: Texture2D
@export var gem_texture_4: Texture2D
@export var gem_texture_5: Texture2D
@export var gem_texture_6: Texture2D

@export_group("Special Overlays")
@export var striped_h_overlay: Texture2D
@export var striped_v_overlay: Texture2D
@export var wrapped_overlay: Texture2D
@export var color_bomb_texture: Texture2D

@export_group("Selection")
@export var selection_ring_texture: Texture2D
@export var selection_ring_color: Color = Color.YELLOW

@export_group("Background")
@export var background_texture: Texture2D
@export var background_color: Color = Color(0.12, 0.12, 0.18, 1)
@export var board_background_color: Color = Color(0.15, 0.15, 0.25, 0.9)

@export_group("Audio")
@export var swap_sound: AudioStream
@export var match_sound: AudioStream
@export var special_sound: AudioStream
@export var cascade_sound: AudioStream

@export_group("UI Colors")
@export var ui_panel_color: Color = Color(0.15, 0.17, 0.25, 0.95)
@export var ui_panel_border_color: Color = Color(0.76, 0.6, 0.32, 1.0)
@export var ui_button_color: Color = Color(0.35, 0.5, 0.75, 1.0)
@export var ui_button_hover_color: Color = Color(0.45, 0.6, 0.85, 1.0)
@export var ui_button_pressed_color: Color = Color(0.25, 0.4, 0.65, 1.0)
@export var ui_accent_color: Color = Color(0.9, 0.75, 0.4, 1.0)
@export var ui_success_color: Color = Color(0.4, 0.85, 0.4, 1.0)
@export var ui_fail_color: Color = Color(0.9, 0.35, 0.35, 1.0)
@export var ui_text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var ui_text_secondary_color: Color = Color(0.7, 0.7, 0.8, 1.0)
@export var ui_overlay_color: Color = Color(0.0, 0.0, 0.0, 0.7)

@export_group("UI Textures")
@export var star_filled_texture: Texture2D
@export var star_empty_texture: Texture2D
@export var button_texture: Texture2D
@export var panel_texture: Texture2D

@export_group("UI Text")
@export var level_complete_title: String = "Level Complete!"
@export var level_failed_title: String = "Out of Moves!"
@export var pause_title: String = "Paused"
@export var close_message: String = "So close!"
@export var try_again_message: String = "Try again!"

@export_group("Booster Icons")
@export var booster_hammer_texture: Texture2D
@export var booster_switch_texture: Texture2D
@export var booster_shuffle_texture: Texture2D
@export var booster_bomb_texture: Texture2D
@export var booster_moves_texture: Texture2D

@export_group("Audio Settings")
@export var sound_enabled: bool = true
@export var music_enabled: bool = true
@export var sound_volume: float = 1.0
@export var music_volume: float = 0.7

var _gem_textures: Array[Texture2D]:
	get: return [null, gem_texture_1, gem_texture_2, gem_texture_3, gem_texture_4, gem_texture_5, gem_texture_6]

var _special_overlays: Array[Texture2D]:
	get: return [null, striped_h_overlay, striped_v_overlay, wrapped_overlay, color_bomb_texture]

func get_gem_texture(gem_type: int) -> Texture2D:
	return _gem_textures[gem_type] if gem_type >= 0 and gem_type < _gem_textures.size() else null

func get_special_overlay(special_type: int) -> Texture2D:
	return _special_overlays[special_type] if special_type >= 0 and special_type < _special_overlays.size() else null
