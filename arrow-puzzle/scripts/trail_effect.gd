class_name TrailEffect
extends Node2D

var _dots: Array[Vector2] = []
var _dot_size: float = 4.0


func setup(cell_centers: Array[Vector2], p_cell_size: float) -> void:
	_dots = cell_centers
	_dot_size = p_cell_size * Config.TRAIL_DOT_RATIO

	queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, Config.TRAIL_FADE_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(queue_free)


func _draw() -> void:
	for dot_pos in _dots:
		draw_circle(dot_pos, _dot_size, Config.COLOR_ARROW)
