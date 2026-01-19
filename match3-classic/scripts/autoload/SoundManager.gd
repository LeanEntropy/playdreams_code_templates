extends Node
## SoundManager - Handles all game audio with enable/disable support

signal sound_toggled(enabled: bool)
signal music_toggled(enabled: bool)

var _sound_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
const MAX_SOUND_PLAYERS := 8

func _ready() -> void:
	# Create pool of sound players for concurrent sounds
	for i in MAX_SOUND_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sound_players.append(player)

	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

func play_sound(sound: AudioStream, volume_db: float = 0.0) -> void:
	if not ConfigManager.is_sound_enabled() or sound == null:
		return

	var player := _get_available_player()
	if player:
		player.stream = sound
		player.volume_db = volume_db + linear_to_db(ConfigManager.get_sound_volume())
		player.play()

func play_swap() -> void:
	play_sound(ConfigManager.get_swap_sound())

func play_match() -> void:
	play_sound(ConfigManager.get_match_sound())

func play_special() -> void:
	play_sound(ConfigManager.get_special_sound())

func play_cascade() -> void:
	play_sound(ConfigManager.get_cascade_sound())

func play_button_click() -> void:
	# Generic UI click sound - could be configured in theme
	play_sound(ConfigManager.get_swap_sound(), -6.0)

func play_music(music: AudioStream, fade_in: bool = true) -> void:
	if not ConfigManager.is_music_enabled() or music == null:
		return

	_music_player.stream = music
	_music_player.volume_db = linear_to_db(ConfigManager.get_music_volume())

	if fade_in:
		_music_player.volume_db = -40.0
		_music_player.play()
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", linear_to_db(ConfigManager.get_music_volume()), 1.0)
	else:
		_music_player.play()

func stop_music(fade_out: bool = true) -> void:
	if fade_out and _music_player.playing:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -40.0, 0.5)
		tween.tween_callback(_music_player.stop)
	else:
		_music_player.stop()

func set_sound_enabled(enabled: bool) -> void:
	ConfigManager.set_sound_enabled(enabled)
	sound_toggled.emit(enabled)

func set_music_enabled(enabled: bool) -> void:
	ConfigManager.set_music_enabled(enabled)
	if not enabled:
		stop_music(false)
	music_toggled.emit(enabled)

func toggle_sound() -> void:
	set_sound_enabled(not ConfigManager.is_sound_enabled())

func toggle_music() -> void:
	set_music_enabled(not ConfigManager.is_music_enabled())

func _get_available_player() -> AudioStreamPlayer:
	for player in _sound_players:
		if not player.playing:
			return player
	# All players busy, return oldest one
	return _sound_players[0]
