class_name Arrow
extends Area2D

signal exit_finished(arrow_id: int)

var arrow_id: int = -1
var direction: String = ""
var dir_vector: Vector2i = Vector2i.ZERO
var cells: Array[Vector2i] = []
var head_cell: Vector2i = Vector2i.ZERO
var cell_size: float = 0.0
var is_multi_cell: bool = false
var is_exiting: bool = false
var is_failed: bool = false

# Per-arrow color for rounded/pastel theme (ignored in sharp theme)
var block_color: Color = Color.WHITE

# Exit animation state
var _exit_active: bool = false
var _exit_color: Color = Config.COLOR_ARROW
var _snake_path: Array[Vector2] = []     # waypoints: original cell centers, head-to-tail (local coords)
var _snake_head_advance: float = 0.0     # how far head has moved beyond its start
var _snake_draw_pos: Array[Vector2] = [] # computed positions for drawing each frame
var _cells_head_to_tail: Array[Vector2i] = []

# Nudge animation state (snake-like forward/back for multi-cell)
var _nudge_active: bool = false
var _nudge_forward: bool = true
var _nudge_distance: float = 0.0
var _nudge_speed_fwd: float = 0.0
var _nudge_return_time: float = 0.0
const NUDGE_OSCILLATION_FREQ := 35.0   # rad/s -- oscillation speed
const NUDGE_OSCILLATION_DECAY := 7.0   # damping factor


func setup(id: int, p_cells: Array, dir: String, head: Vector2i, p_cell_size: float, color_idx: int = -1) -> void:
	arrow_id = id
	direction = dir
	dir_vector = Config.DIR_VECTORS[dir]
	head_cell = head
	cell_size = p_cell_size

	cells.clear()
	for c in p_cells:
		cells.append(c as Vector2i)

	is_multi_cell = cells.size() > 1
	_build_head_to_tail_order()

	# Assign palette color for rounded theme
	var theme: Dictionary = Config.get_theme()
	var palette: Array = theme.get("arrow_palette", [])
	if palette.size() > 0:
		if color_idx >= 0 and color_idx < palette.size():
			block_color = palette[color_idx]
		else:
			block_color = palette[id % palette.size()]

	_update_collision_shape()
	queue_redraw()


func _build_head_to_tail_order() -> void:
	_cells_head_to_tail.clear()
	if cells.size() <= 1 or cells[0] == head_cell:
		_cells_head_to_tail = cells.duplicate()
		return
	if cells[-1] == head_cell:
		_cells_head_to_tail = cells.duplicate()
		_cells_head_to_tail.reverse()
		return

	# General case: trace from head through adjacent cells
	_cells_head_to_tail.append(head_cell)
	var visited: Dictionary = {head_cell: true}
	while _cells_head_to_tail.size() < cells.size():
		var current: Vector2i = _cells_head_to_tail[-1]
		var found := false
		for c in cells:
			if visited.has(c):
				continue
			if absi(c.x - current.x) + absi(c.y - current.y) == 1:
				_cells_head_to_tail.append(c)
				visited[c] = true
				found = true
				break
		if not found:
			break


func _grid_to_local(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos - cells[0]) * cell_size + Vector2(cell_size * 0.5, cell_size * 0.5)


func _update_collision_shape() -> void:
	var col_shape: CollisionShape2D = $CollisionShape2D
	var rect := RectangleShape2D.new()

	if cells.size() == 1:
		rect.size = Vector2(cell_size, cell_size) * 0.9
		col_shape.position = Vector2(cell_size, cell_size) * 0.5
	else:
		var min_cell := cells[0]
		var max_cell := cells[0]
		for c in cells:
			min_cell.x = mini(min_cell.x, c.x)
			min_cell.y = mini(min_cell.y, c.y)
			max_cell.x = maxi(max_cell.x, c.x)
			max_cell.y = maxi(max_cell.y, c.y)

		var offset := min_cell - cells[0]
		var span := max_cell - min_cell + Vector2i.ONE

		rect.size = Vector2(span) * cell_size * 0.9
		col_shape.position = Vector2(offset) * cell_size + Vector2(span) * cell_size * 0.5

	col_shape.shape = rect


func _process(delta: float) -> void:
	if _nudge_active:
		_process_nudge(delta)
		return
	if not _exit_active:
		return
	_process_exit(delta)


func _process_exit(delta: float) -> void:
	var dir_f := Vector2(dir_vector)
	var margin := cell_size * 2.0

	if is_multi_cell:
		_snake_head_advance += Config.EXIT_SPEED * delta
		_update_snake_draw_pos()
		queue_redraw()

		var tail_local := _snake_draw_pos[-1]
		var tail_world := position + tail_local
		if tail_world.x < -margin or tail_world.x > Config.VIEWPORT_WIDTH + margin \
				or tail_world.y < -margin or tail_world.y > Config.VIEWPORT_HEIGHT + margin:
			_exit_active = false
			_on_exit_complete()
	else:
		position += dir_f * Config.EXIT_SPEED * delta
		queue_redraw()

		var center := position + Vector2(cell_size, cell_size) * 0.5
		if center.x < -margin or center.x > Config.VIEWPORT_WIDTH + margin \
				or center.y < -margin or center.y > Config.VIEWPORT_HEIGHT + margin:
			_exit_active = false
			_on_exit_complete()


func _process_nudge(delta: float) -> void:
	if _nudge_forward:
		_snake_head_advance += _nudge_speed_fwd * delta
		if _snake_head_advance >= _nudge_distance:
			_snake_head_advance = _nudge_distance
			_nudge_forward = false
			_nudge_return_time = 0.0
	else:
		# Decaying sine: head springs back with juicy oscillation
		_nudge_return_time += delta
		var t := _nudge_return_time
		_snake_head_advance = _nudge_distance * exp(-NUDGE_OSCILLATION_DECAY * t) * cos(NUDGE_OSCILLATION_FREQ * t)

		# Done when oscillation is negligible
		if absf(_snake_head_advance) < 0.5 and t > 0.15:
			_snake_head_advance = 0.0
			_nudge_active = false
			_snake_draw_pos.clear()
			queue_redraw()
			return

	_update_snake_draw_pos()
	queue_redraw()


func _update_snake_draw_pos() -> void:
	var dir_f := Vector2(dir_vector)
	var body_length := float(_cells_head_to_tail.size() - 1) * cell_size

	_snake_draw_pos.clear()
	_snake_draw_pos.append(_snake_path[0] + dir_f * _snake_head_advance)

	var cum_dist := _snake_head_advance
	for i in range(_snake_path.size()):
		if i > 0:
			cum_dist += _snake_path[i - 1].distance_to(_snake_path[i])
		if cum_dist > 0.001 and cum_dist < body_length - 0.001:
			_snake_draw_pos.append(_snake_path[i])

	_snake_draw_pos.append(_point_along_path(body_length))


func _point_along_path(dist: float) -> Vector2:
	## Walk `dist` pixels from the current head position backward through the path.
	var dir_f := Vector2(dir_vector)
	var head_pos := _snake_path[0] + dir_f * _snake_head_advance

	var remaining := dist
	var seg_start := head_pos

	for i in range(_snake_path.size()):
		var seg_end := _snake_path[i]
		var seg_len := seg_start.distance_to(seg_end)
		if seg_len > 0.001 and remaining <= seg_len:
			return seg_start.lerp(seg_end, remaining / seg_len)
		remaining -= seg_len
		seg_start = seg_end

	return _snake_path[-1]


# =============================================================================
# Drawing — dispatches to sharp or rounded based on theme
# =============================================================================

func _draw() -> void:
	var theme: Dictionary = Config.get_theme()
	if theme["arrow_style"] == "rounded":
		_draw_rounded()
	else:
		_draw_sharp()


# =============================================================================
# Sharp style (minimal theme) — thin body line + triangle arrowhead
# =============================================================================

func _draw_sharp() -> void:
	var half := cell_size * 0.5
	var color: Color = _get_sharp_color()
	var body_w := cell_size * Config.ARROW_BODY_WIDTH
	var head_w := cell_size * Config.ARROW_HEAD_WIDTH
	var head_len := cell_size * Config.ARROW_HEAD_LENGTH
	var dir_f := Vector2(dir_vector)
	var perp := Vector2(-dir_f.y, dir_f.x)

	if is_multi_cell:
		if (_exit_active or _nudge_active) and _snake_draw_pos.size() >= 2:
			# Snake exit: draw body segments between key vertices
			for i in range(_snake_draw_pos.size() - 1):
				_draw_body_segment(_snake_draw_pos[i], _snake_draw_pos[i + 1], body_w, color)

			# Corner fills at intermediate vertices
			for i in range(1, _snake_draw_pos.size() - 1):
				draw_rect(Rect2(
					_snake_draw_pos[i] - Vector2(body_w, body_w) * 0.5,
					Vector2(body_w, body_w)), color)

			# Arrowhead at head (index 0)
			var head_pos := _snake_draw_pos[0]
			var tip := head_pos + dir_f * head_len
			var left := head_pos + perp * head_w * 0.5
			var right := head_pos - perp * head_w * 0.5
			draw_colored_polygon(PackedVector2Array([tip, left, right]), color)
		else:
			# Normal multi-cell draw
			var head_idx := cells.size() - 1
			for i in range(cells.size()):
				if cells[i] == head_cell:
					head_idx = i
					break

			for i in range(cells.size() - 1):
				var from_local := Vector2(cells[i] - cells[0]) * cell_size + Vector2(half, half)
				var to_local := Vector2(cells[i + 1] - cells[0]) * cell_size + Vector2(half, half)
				_draw_body_segment(from_local, to_local, body_w, color)

			for i in range(1, cells.size() - 1):
				if i == head_idx:
					continue
				var prev_d := cells[i] - cells[i - 1]
				var next_d := cells[i + 1] - cells[i]
				if prev_d != next_d:
					var center := Vector2(cells[i] - cells[0]) * cell_size + Vector2(half, half)
					draw_rect(Rect2(center - Vector2(body_w, body_w) * 0.5, Vector2(body_w, body_w)), color)

			var head_local := Vector2(head_cell - cells[0]) * cell_size + Vector2(half, half)
			var tip := head_local + dir_f * head_len
			var left := head_local + perp * head_w * 0.5
			var right := head_local - perp * head_w * 0.5
			draw_colored_polygon(PackedVector2Array([tip, left, right]), color)

	else:
		# Single cell arrow
		var center := Vector2(half, half)
		var tail_pt := center - dir_f * half * Config.ARROW_TAIL_LENGTH
		_draw_body_segment(tail_pt, center, body_w, color)

		var tip := center + dir_f * head_len
		var left := center + perp * head_w * 0.5
		var right := center - perp * head_w * 0.5
		draw_colored_polygon(PackedVector2Array([tip, left, right]), color)


func _get_sharp_color() -> Color:
	if is_exiting:
		return _exit_color
	if is_failed:
		return Config.COLOR_ARROW_FAILED
	return Config.COLOR_ARROW


func _draw_body_segment(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var seg_dir := (to - from).normalized()
	if seg_dir.is_zero_approx():
		return
	var seg_perp := Vector2(-seg_dir.y, seg_dir.x)
	var offset := seg_perp * width * 0.5
	draw_colored_polygon(PackedVector2Array([
		from - offset, from + offset, to + offset, to - offset
	]), color)


# =============================================================================
# Rounded style (pastel theme) — pill shapes + shadow + chevron
# =============================================================================

func _draw_rounded() -> void:
	var theme: Dictionary = Config.get_theme()
	var color: Color = _get_rounded_color(theme)

	if is_multi_cell:
		if (_exit_active or _nudge_active) and _snake_draw_pos.size() >= 2:
			_draw_rounded_snake(theme, color)
		else:
			_draw_rounded_static(theme, color)
	else:
		_draw_rounded_single(theme, color)


func _get_rounded_color(theme: Dictionary) -> Color:
	if is_exiting:
		return theme["arrow_exit"]
	if is_failed:
		return theme["arrow_failed"]
	return block_color


func _draw_rounded_single(theme: Dictionary, color: Color) -> void:
	var center := Vector2(cell_size * 0.5, cell_size * 0.5)
	var gap: float = theme["cell_gap"]
	var radius := (cell_size - gap) * 0.5

	# Shadow
	if theme["shadow_enabled"]:
		var s_offset: Vector2 = theme["shadow_offset"]
		var s_darken: float = theme["shadow_darken"]
		draw_circle(center + s_offset, radius, color.darkened(s_darken))

	# Main circle
	draw_circle(center, radius, color)

	# Chevron
	if theme["chevron_enabled"]:
		_draw_chevron(center, theme)


func _draw_rounded_static(theme: Dictionary, color: Color) -> void:
	var gap: float = theme["cell_gap"]
	var half_gap := gap * 0.5
	var segments := _get_straight_segments()
	var corner_cells := _get_corner_cells()
	var corner_r := (cell_size - gap) * 0.5

	# Shadow pass
	if theme["shadow_enabled"]:
		var s_offset: Vector2 = theme["shadow_offset"]
		var s_color := color.darkened(theme["shadow_darken"])
		for seg in segments:
			_draw_segment_pill(seg, half_gap, s_color, s_offset)
		for cc: Vector2i in corner_cells:
			var local := Vector2(cc - cells[0]) * cell_size
			var rect := Rect2(local.x + half_gap + s_offset.x, local.y + half_gap + s_offset.y,
				cell_size - gap, cell_size - gap)
			_draw_rounded_rect(rect, corner_r, s_color)

	# Color pass
	for seg in segments:
		_draw_segment_pill(seg, half_gap, color, Vector2.ZERO)
	for cc: Vector2i in corner_cells:
		var local := Vector2(cc - cells[0]) * cell_size
		var rect := Rect2(local.x + half_gap, local.y + half_gap, cell_size - gap, cell_size - gap)
		_draw_rounded_rect(rect, corner_r, color)

	# Chevron on head cell
	if theme["chevron_enabled"]:
		var head_local := Vector2(head_cell - cells[0]) * cell_size + Vector2(cell_size * 0.5, cell_size * 0.5)
		_draw_chevron(head_local, theme)


func _draw_rounded_snake(theme: Dictionary, color: Color) -> void:
	var gap: float = theme["cell_gap"]
	var half_gap := gap * 0.5
	var block_half := (cell_size - gap) * 0.5
	var segments := _get_snake_segments()
	var corner_positions := _get_snake_corners()
	var corner_r := block_half

	# Shadow pass
	if theme["shadow_enabled"]:
		var s_offset: Vector2 = theme["shadow_offset"]
		var s_color := color.darkened(theme["shadow_darken"])
		for seg in segments:
			_draw_snake_segment_pill(seg, half_gap, s_color, s_offset)
		for cp: Vector2 in corner_positions:
			var rect := Rect2(cp.x - block_half + s_offset.x, cp.y - block_half + s_offset.y,
				cell_size - gap, cell_size - gap)
			_draw_rounded_rect(rect, corner_r, s_color)

	# Color pass
	for seg in segments:
		_draw_snake_segment_pill(seg, half_gap, color, Vector2.ZERO)
	for cp: Vector2 in corner_positions:
		var rect := Rect2(cp.x - block_half, cp.y - block_half, cell_size - gap, cell_size - gap)
		_draw_rounded_rect(rect, corner_r, color)

	# Chevron at head
	if theme["chevron_enabled"]:
		_draw_chevron(_snake_draw_pos[0], theme)


# =============================================================================
# Rounded geometry helpers
# =============================================================================

func _get_straight_segments() -> Array:
	## Group _cells_head_to_tail into collinear runs. Each segment is Array[Vector2i].
	var segments: Array = []
	if _cells_head_to_tail.size() <= 1:
		segments.append(_cells_head_to_tail.duplicate())
		return segments

	var current_seg: Array[Vector2i] = [_cells_head_to_tail[0]]
	var prev_dir := Vector2i.ZERO

	for i in range(1, _cells_head_to_tail.size()):
		var step := _cells_head_to_tail[i] - _cells_head_to_tail[i - 1]
		var axis := Vector2i(signi(step.x), signi(step.y))
		if prev_dir == Vector2i.ZERO or axis == prev_dir:
			current_seg.append(_cells_head_to_tail[i])
			prev_dir = axis
		else:
			segments.append(current_seg)
			current_seg = [_cells_head_to_tail[i - 1], _cells_head_to_tail[i]]
			prev_dir = axis

	segments.append(current_seg)
	return segments


func _get_corner_cells() -> Array[Vector2i]:
	## Cells where the path changes direction (shared by two segments).
	var corners: Array[Vector2i] = []
	if _cells_head_to_tail.size() < 3:
		return corners
	for i in range(1, _cells_head_to_tail.size() - 1):
		var prev_step := _cells_head_to_tail[i] - _cells_head_to_tail[i - 1]
		var next_step := _cells_head_to_tail[i + 1] - _cells_head_to_tail[i]
		if Vector2i(signi(prev_step.x), signi(prev_step.y)) != Vector2i(signi(next_step.x), signi(next_step.y)):
			corners.append(_cells_head_to_tail[i])
	return corners


func _draw_segment_pill(seg: Array, gap: float, color: Color, offset: Vector2) -> void:
	## Draw collinear cells as one pill/capsule shape.
	if seg.size() == 0:
		return
	var origin: Vector2i = cells[0]
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for c: Vector2i in seg:
		var local := Vector2(c - origin) * cell_size
		min_pos.x = minf(min_pos.x, local.x)
		min_pos.y = minf(min_pos.y, local.y)
		max_pos.x = maxf(max_pos.x, local.x + cell_size)
		max_pos.y = maxf(max_pos.y, local.y + cell_size)

	var cell_gap: float = Config.get_theme()["cell_gap"]
	var rect := Rect2(
		Vector2(min_pos.x + gap + offset.x, min_pos.y + gap + offset.y),
		Vector2(max_pos.x - min_pos.x - cell_gap, max_pos.y - min_pos.y - cell_gap)
	)
	var corner_r := minf(rect.size.x, rect.size.y) * 0.5
	_draw_rounded_rect(rect, corner_r, color)


func _get_snake_segments() -> Array:
	## Group _snake_draw_pos into collinear runs.
	var segments: Array = []
	if _snake_draw_pos.size() == 0:
		return segments

	var current_seg: Array[Vector2] = [_snake_draw_pos[0]]
	var prev_axis := -1  # 0 = horizontal, 1 = vertical

	for i in range(1, _snake_draw_pos.size()):
		var diff := _snake_draw_pos[i] - _snake_draw_pos[i - 1]
		var axis: int = 1 if absf(diff.y) > absf(diff.x) else 0
		if prev_axis == -1 or axis == prev_axis:
			current_seg.append(_snake_draw_pos[i])
			prev_axis = axis
		else:
			segments.append(current_seg)
			current_seg = [_snake_draw_pos[i - 1], _snake_draw_pos[i]]
			prev_axis = axis

	segments.append(current_seg)
	return segments


func _get_snake_corners() -> Array[Vector2]:
	## Positions where the snake path changes direction.
	var corners: Array[Vector2] = []
	if _snake_draw_pos.size() < 3:
		return corners
	for i in range(1, _snake_draw_pos.size() - 1):
		var d1 := _snake_draw_pos[i] - _snake_draw_pos[i - 1]
		var d2 := _snake_draw_pos[i + 1] - _snake_draw_pos[i]
		var a1 := 0 if absf(d1.x) >= absf(d1.y) else 1
		var a2 := 0 if absf(d2.x) >= absf(d2.y) else 1
		if a1 != a2:
			corners.append(_snake_draw_pos[i])
	return corners


func _draw_snake_segment_pill(seg: Array, gap: float, color: Color, offset: Vector2) -> void:
	## Draw collinear snake positions as one pill.
	if seg.size() == 0:
		return
	var half := cell_size * 0.5
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for center: Vector2 in seg:
		min_pos.x = minf(min_pos.x, center.x - half)
		min_pos.y = minf(min_pos.y, center.y - half)
		max_pos.x = maxf(max_pos.x, center.x + half)
		max_pos.y = maxf(max_pos.y, center.y + half)

	var cell_gap: float = Config.get_theme()["cell_gap"]
	var rect := Rect2(
		Vector2(min_pos.x + gap + offset.x, min_pos.y + gap + offset.y),
		Vector2(max_pos.x - min_pos.x - cell_gap, max_pos.y - min_pos.y - cell_gap)
	)
	var corner_r := minf(rect.size.x, rect.size.y) * 0.5
	_draw_rounded_rect(rect, corner_r, color)


# =============================================================================
# Drawing primitives (shared by rounded style)
# =============================================================================

func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if r < 0.5:
		draw_rect(rect, color)
		return
	var arc_segments := 16
	_add_arc(points, rect.position + Vector2(r, r), r, PI, PI * 1.5, arc_segments)
	_add_arc(points, rect.position + Vector2(rect.size.x - r, r), r, PI * 1.5, PI * 2.0, arc_segments)
	_add_arc(points, rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, 0, PI * 0.5, arc_segments)
	_add_arc(points, rect.position + Vector2(r, rect.size.y - r), r, PI * 0.5, PI, arc_segments)
	draw_colored_polygon(points, color)


func _add_arc(points: PackedVector2Array, center: Vector2, radius: float,
		angle_start: float, angle_end: float, segments: int) -> void:
	for i in range(segments + 1):
		var angle := angle_start + (angle_end - angle_start) * float(i) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)


func _draw_chevron(center: Vector2, theme: Dictionary) -> void:
	var size_ratio: float = theme["chevron_size_ratio"]
	var stroke_w: float = theme["chevron_stroke_width"]
	var chev_color: Color = theme["chevron_color"]
	var size := cell_size * size_ratio * 0.5
	var pts: PackedVector2Array
	match direction:
		"R":
			pts = PackedVector2Array([
				center + Vector2(-size, -size),
				center + Vector2(size, 0),
				center + Vector2(-size, size),
			])
		"L":
			pts = PackedVector2Array([
				center + Vector2(size, -size),
				center + Vector2(-size, 0),
				center + Vector2(size, size),
			])
		"U":
			pts = PackedVector2Array([
				center + Vector2(-size, size),
				center + Vector2(0, -size),
				center + Vector2(size, size),
			])
		"D":
			pts = PackedVector2Array([
				center + Vector2(-size, -size),
				center + Vector2(0, size),
				center + Vector2(size, -size),
			])
		_:
			return

	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], chev_color, stroke_w, true)


# =============================================================================
# Animation triggers (public API)
# =============================================================================

func animate_exit() -> void:
	is_exiting = true
	_exit_active = true

	var theme: Dictionary = Config.get_theme()
	if theme["arrow_style"] == "sharp":
		# Color transition: normal -> exit color over 100ms
		_exit_color = Config.COLOR_ARROW
		var tween := create_tween()
		tween.tween_property(self, "_exit_color", Config.COLOR_ARROW_EXIT, Config.EXIT_COLOR_DURATION)

	if is_multi_cell:
		_snake_head_advance = 0.0
		_snake_path.clear()
		for c in _cells_head_to_tail:
			_snake_path.append(_grid_to_local(c))


func _on_exit_complete() -> void:
	exit_finished.emit(arrow_id)
	queue_free()


func animate_nudge_to(blocker_world_pos: Vector2) -> void:
	var head_world := position + Vector2(head_cell - cells[0]) * cell_size + Vector2(cell_size, cell_size) * 0.5
	var travel := (blocker_world_pos - head_world).length() * 0.5

	if is_multi_cell:
		_start_snake_nudge(travel)
	else:
		_tween_nudge(travel)


func animate_nudge() -> void:
	if is_multi_cell:
		_start_snake_nudge(float(Config.NUDGE_DISTANCE))
	else:
		_tween_nudge(float(Config.NUDGE_DISTANCE))


func _start_snake_nudge(dist: float) -> void:
	dist = maxf(dist, 10.0)
	_nudge_active = true
	_nudge_forward = true
	_nudge_distance = dist
	_nudge_speed_fwd = dist / (Config.NUDGE_DURATION * 0.4)
	_nudge_return_time = 0.0
	_snake_head_advance = 0.0
	_snake_path.clear()
	for c in _cells_head_to_tail:
		_snake_path.append(_grid_to_local(c))


func _tween_nudge(dist: float) -> void:
	var dir_f := Vector2(dir_vector)
	var original_pos := position
	var nudge_pos := position + dir_f * dist

	var tween := create_tween()
	tween.tween_property(self, "position", nudge_pos, Config.NUDGE_DURATION * 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", original_pos, Config.NUDGE_DURATION * 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func animate_entrance(delay: float) -> void:
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "scale", Vector2.ONE, Config.ENTRANCE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
