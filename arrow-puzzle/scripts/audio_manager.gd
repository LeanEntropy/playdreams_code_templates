extends Node

var sounds_enabled: bool = true
var vibrations_enabled: bool = true

var _players := {}

const SOUND_NAMES := [
	"tap_arrow",
	"arrow_exit",
	"arrow_blocked",
	"level_clear",
	"ui_click",
]


func _ready() -> void:
	for sound_name in SOUND_NAMES:
		var path := "res://assets/audio/%s.ogg" % sound_name
		if ResourceLoader.exists(path):
			var player := AudioStreamPlayer.new()
			player.stream = load(path)
			player.bus = "Master"
			add_child(player)
			_players[sound_name] = player


func play(sound_name: String) -> void:
	if sounds_enabled and _players.has(sound_name):
		_players[sound_name].play()


func haptic(duration_ms: int = 50) -> void:
	if vibrations_enabled:
		Input.vibrate_handheld(duration_ms)
