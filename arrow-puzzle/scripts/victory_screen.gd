extends CanvasLayer

signal advance_requested

const MESSAGES := [
	"Brilliant!",
	"Well Done!",
	"Perfect!",
	"Amazing!",
	"Superb!",
	"Excellent!",
	"Fantastic!",
	"Great Job!",
	"Wonderful!",
	"Outstanding!",
]

@onready var overlay: ColorRect = %Overlay
@onready var message_label: Label = %MessageLabel
@onready var confetti: CPUParticles2D = %Confetti

var _is_dark: bool = Config.THEME == "pastel"


func _ready() -> void:
	visible = false
	# Apply theme colors to overlay and message
	if overlay:
		overlay.color = Color(0.17, 0.18, 0.23, 0.85) if _is_dark else Color(1, 1, 1, 0.85)
	if message_label:
		message_label.add_theme_color_override("font_color", Color.WHITE if _is_dark else Config.COLOR_TITLE)


func _unhandled_input(_event: InputEvent) -> void:
	if not visible:
		return
	# Consume ALL input when victory screen is visible
	get_viewport().set_input_as_handled()


func show_victory(_move_count: int) -> void:
	visible = true

	# Set random message
	message_label.text = MESSAGES.pick_random()

	# Animate message scale-up
	message_label.pivot_offset = message_label.size / 2.0
	message_label.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(message_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Start confetti (use arrow palette for colorful confetti in pastel theme)
	if confetti:
		if _is_dark:
			var t: Dictionary = Config.get_theme()
			var palette: Array = t.get("arrow_palette", [])
			if palette.size() > 0:
				confetti.color = palette.pick_random()
		confetti.restart()
		confetti.emitting = true

	# Auto-advance after show duration
	await get_tree().create_timer(Config.VICTORY_SHOW_DURATION).timeout
	advance_requested.emit()


func hide_screen() -> void:
	visible = false
