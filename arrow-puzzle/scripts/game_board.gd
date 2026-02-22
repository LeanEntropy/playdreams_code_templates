extends Node2D

signal all_arrows_cleared
signal hearts_changed(hearts: int)
signal hearts_depleted
signal guides_turned_off

const ArrowScene := preload("res://scenes/arrow.tscn")

var grid_system: GridSystem
var arrows: Dictionary = {}  # id -> Arrow node
var cell_size: float = 0.0
var grid_origin: Vector2 = Vector2.ZERO
var grid_columns: int = 0
var grid_rows: int = 0
var move_count: int = 0
var _exiting_count: int = 0
var _next_arrow_id: int = 0
var _tutorial_label: Label = null
var hearts: int = Config.HEARTS_START
var test_mode: bool = false
var _shape_preview: Dictionary = {}  # Vector2i -> true, for shape preview mode
var show_guides: bool = false

# Zoom
var _zoom_level: float = 1.0

# Pan (drag to scroll when zoomed in)
var _pan_offset: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _touch_down: bool = false

@onready var _arrow_container: Node2D = $ArrowContainer
@onready var _trail_container: Node2D = $TrailContainer


func load_level(level_data: Dictionary) -> void:
	_clear_board()

	grid_columns = int(level_data.get("columns", 5))
	grid_rows = int(level_data.get("rows", 5))
	_calculate_grid_layout()

	# Parse shape (non-rectangular levels)
	var active_cells: Array = []
	if level_data.has("shape"):
		for sc in level_data["shape"]:
			active_cells.append(Vector2i(int(sc[0]), int(sc[1])))

	grid_system = GridSystem.new(grid_columns, grid_rows, active_cells)

	var arrow_defs: Array = level_data.get("arrows", [])
	for i in range(arrow_defs.size()):
		var def: Dictionary = arrow_defs[i]
		var arrow_id := _next_arrow_id
		_next_arrow_id += 1

		var dir_str: String = def.get("dir", "R")
		var dir_vec: Vector2i = Config.DIR_VECTORS.get(dir_str, Vector2i.RIGHT)
		var arrow_cells: Array[Vector2i] = []
		var head_cell: Vector2i

		if def.has("path"):
			# Waypoint format: {path: [[col,row],...], dir}
			# Head is always the last waypoint
			arrow_cells = _expand_path(def["path"])
			head_cell = arrow_cells[-1]
		elif def.has("cells"):
			# Full cell list: {cells: [[col,row],...], dir, head}
			for rc in def["cells"]:
				arrow_cells.append(Vector2i(int(rc[0]), int(rc[1])))
			var raw_head: Array = def.get("head", def["cells"][0])
			head_cell = Vector2i(int(raw_head[0]), int(raw_head[1]))
		elif def.has("length"):
			# Multi-cell straight: {col, row, dir, length}
			var origin := Vector2i(int(def["col"]), int(def["row"]))
			var length := int(def["length"])
			for l in range(length):
				arrow_cells.append(origin + dir_vec * l)
			head_cell = arrow_cells[-1]
		else:
			# Single-cell: {col, row, dir}
			var origin := Vector2i(int(def["col"]), int(def["row"]))
			arrow_cells.append(origin)
			head_cell = origin

		# Place in grid
		grid_system.place_arrow(arrow_id, arrow_cells)

		# Instantiate Arrow scene
		var arrow_node: Arrow = ArrowScene.instantiate()
		_arrow_container.add_child(arrow_node)

		# Position at first cell
		arrow_node.position = grid_origin + Vector2(arrow_cells[0]) * cell_size
		arrow_node.setup(arrow_id, arrow_cells, dir_str, head_cell, cell_size, i)
		arrow_node.exit_finished.connect(_on_arrow_exit_finished)

		arrows[arrow_id] = arrow_node

		# Entrance animation with stagger
		arrow_node.animate_entrance(i * Config.ENTRANCE_STAGGER)

	# Emit initial hearts
	hearts_changed.emit(hearts)
	queue_redraw()

	# Tutorial
	if level_data.get("tutorial", false):
		_show_tutorial()


func _calculate_grid_layout() -> void:
	var viewport_width := float(Config.VIEWPORT_WIDTH)
	var viewport_height := float(Config.VIEWPORT_HEIGHT)
	var margin := float(Config.GRID_MARGIN)
	var top_margin := Config.GRID_TOP_MARGIN
	var max_width := viewport_width - margin * 2.0
	var max_height := viewport_height * Config.GRID_VERTICAL_RATIO

	# Fixed cell size so arrows always look the same size across all levels
	var base := Config.FIXED_CELL_SIZE

	# Auto-zoom out if grid doesn't fit at default cell size
	var needed_width := base * float(grid_columns)
	var needed_height := base * float(grid_rows)
	var auto_zoom := 1.0
	if needed_width > max_width or needed_height > max_height:
		auto_zoom = minf(max_width / needed_width, max_height / needed_height)

	# Apply auto-zoom and user zoom
	cell_size = base * auto_zoom * _zoom_level

	# Center grid on screen, then apply pan offset
	var grid_width := cell_size * float(grid_columns)
	var grid_height := cell_size * float(grid_rows)
	var centered := Vector2(
		(viewport_width - grid_width) * 0.5,
		top_margin + (max_height - grid_height) * 0.5
	)

	# Clamp pan so at least 25% of viewport shows the board
	var vis := Config.PAN_VISIBLE_RATIO
	var min_x := vis * viewport_width - grid_width - centered.x
	var max_x := (1.0 - vis) * viewport_width - centered.x
	var min_y := vis * viewport_height - grid_height - centered.y
	var max_y := (1.0 - vis) * viewport_height - centered.y
	_pan_offset.x = clampf(_pan_offset.x, min_x, max_x)
	_pan_offset.y = clampf(_pan_offset.y, min_y, max_y)

	grid_origin = centered + _pan_offset


func _clear_board() -> void:
	for child in _arrow_container.get_children():
		child.queue_free()
	for child in _trail_container.get_children():
		child.queue_free()
	arrows.clear()
	grid_system = null
	move_count = 0
	_exiting_count = 0
	_next_arrow_id = 0
	hearts = Config.HEARTS_START
	_zoom_level = 1.0
	_pan_offset = Vector2.ZERO
	_is_dragging = false
	_touch_down = false
	_shape_preview.clear()
	show_guides = false
	_remove_tutorial()
	queue_redraw()


func show_shape_preview(cols: int, rows: int, active: Array[Vector2i]) -> void:
	_clear_board()
	grid_columns = cols
	grid_rows = rows
	_calculate_grid_layout()
	grid_system = null
	_shape_preview.clear()
	for c in active:
		_shape_preview[c] = true
	queue_redraw()


func clear_shape_preview() -> void:
	_shape_preview.clear()
	queue_redraw()


func _draw() -> void:
	# Shape preview mode
	if not _shape_preview.is_empty():
		for row_idx in range(grid_rows):
			for col_idx in range(grid_columns):
				var pos := grid_origin + Vector2(col_idx, row_idx) * cell_size
				var cell := Vector2i(col_idx, row_idx)
				if _shape_preview.has(cell):
					draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), Color(0, 0, 0, 0.12))
					var center := pos + Vector2(cell_size, cell_size) * 0.5
					draw_circle(center, cell_size * Config.CELL_DOT_RATIO, Config.COLOR_CELL_DOT)
				# Draw cell border for all cells in bounding box
				draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), Color(0, 0, 0, 0.06), false, 1.0)
		return

	if grid_system == null:
		return

	# Draw guide lines (behind arrows, before dots)
	if show_guides:
		_draw_guide_lines()

	# Draw dots on active empty cells (no arrow, not inactive)
	var dot_radius := cell_size * Config.CELL_DOT_RATIO
	for row_idx in range(grid_rows):
		for col_idx in range(grid_columns):
			var cell_val: int = grid_system.get_arrow_at(col_idx, row_idx)
			if cell_val == -1:
				var center := grid_origin + Vector2(col_idx, row_idx) * cell_size + Vector2(cell_size, cell_size) * 0.5
				draw_circle(center, dot_radius, Config.COLOR_CELL_DOT)


func set_show_guides(active: bool) -> void:
	show_guides = active
	queue_redraw()


func _draw_guide_lines() -> void:
	var vw := float(Config.VIEWPORT_WIDTH)
	var vh := float(Config.VIEWPORT_HEIGHT)
	var line_w := cell_size * Config.ARROW_BODY_WIDTH
	var half_w := line_w * 0.5
	for id in arrows:
		var arrow: Arrow = arrows[id]
		if arrow.is_exiting:
			continue
		var head_center := grid_origin + Vector2(arrow.head_cell) * cell_size + Vector2(cell_size, cell_size) * 0.5
		var dir_f := Vector2(arrow.dir_vector)
		var end_pos := head_center
		# Extend to viewport edge
		if dir_f.x > 0:
			end_pos = Vector2(vw, head_center.y)
		elif dir_f.x < 0:
			end_pos = Vector2(0.0, head_center.y)
		elif dir_f.y > 0:
			end_pos = Vector2(head_center.x, vh)
		elif dir_f.y < 0:
			end_pos = Vector2(head_center.x, 0.0)
		# Draw as filled rectangle for consistent width with arrow bodies
		var perp := Vector2(-dir_f.y, dir_f.x)
		var offset := perp * half_w
		draw_colored_polygon(PackedVector2Array([
			head_center - offset, head_center + offset,
			end_pos + offset, end_pos - offset
		]), Config.COLOR_GUIDE_LINE)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if grid_system == null:
		return

	# Zoom: mouse wheel
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(_zoom_level + Config.ZOOM_STEP)
				return
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(_zoom_level - Config.ZOOM_STEP)
				return

	# Zoom: pinch gesture (mobile)
	if event is InputEventMagnifyGesture:
		var gesture := event as InputEventMagnifyGesture
		_apply_zoom(_zoom_level * gesture.factor)
		return

	# Touch/click: drag to pan, tap on release
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_touch_down = true
				_is_dragging = false
				_drag_start_pos = mb.position
			else:
				# Release: tap if we didn't drag
				if _touch_down and not _is_dragging:
					_process_tap(mb.position)
				_touch_down = false
				_is_dragging = false

	# Drag: pan the board
	if event is InputEventMouseMotion and _touch_down:
		var motion := event as InputEventMouseMotion
		if not _is_dragging:
			if motion.position.distance_to(_drag_start_pos) > Config.PAN_DRAG_THRESHOLD:
				_is_dragging = true
		if _is_dragging:
			_pan_offset += motion.relative
			_calculate_grid_layout()
			_reposition_arrows()
			queue_redraw()

	# Mobile: direct screen drag (bypasses mouse emulation for smoother feel)
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_is_dragging = true
		_pan_offset += drag.relative
		_calculate_grid_layout()
		_reposition_arrows()
		queue_redraw()


func _process_tap(pos: Vector2) -> void:
	var local_pos: Vector2 = pos - grid_origin
	var col := floori(local_pos.x / cell_size)
	var row := floori(local_pos.y / cell_size)

	var arrow_id := grid_system.get_arrow_at(col, row)
	if arrow_id < 0:
		return

	_handle_arrow_tap(arrow_id)


func _handle_arrow_tap(arrow_id: int) -> void:
	if not arrows.has(arrow_id):
		return
	var arrow: Arrow = arrows[arrow_id]
	if arrow.is_exiting:
		return

	# Turn off guide lines on any tap
	if show_guides:
		show_guides = false
		guides_turned_off.emit()
		queue_redraw()

	var dir_vec := Vector2i(arrow.dir_vector)
	if grid_system.is_path_clear(arrow_id, arrow.head_cell, dir_vec):
		# Clear path: exit the arrow
		move_count += 1

		# Remove from grid immediately
		grid_system.remove_arrow(arrow_id, arrow.cells)

		# Spawn trail at arrow head position
		_spawn_trail(arrow)

		# Animate exit
		_exiting_count += 1
		arrow.animate_exit()

		AudioManager.play("tap_arrow")

		# Redraw board to show dots on freed cells
		queue_redraw()

		# Remove tutorial on first successful tap
		_remove_tutorial()
	else:
		# Blocked - find what's blocking and animate toward it
		var blocker_cell := grid_system.find_blocking_cell(arrow_id, arrow.head_cell, dir_vec)
		if blocker_cell != Vector2i(-1, -1):
			var blocker_world := grid_origin + Vector2(blocker_cell) * cell_size + Vector2(cell_size, cell_size) * 0.5
			arrow.animate_nudge_to(blocker_world)
		else:
			arrow.animate_nudge()

		# Lose a heart only on first failed tap per arrow (skip in test mode)
		if not test_mode and not arrow.is_failed:
			hearts -= 1
			hearts_changed.emit(hearts)
			if hearts <= 0:
				hearts_depleted.emit()

		# Mark failed immediately so re-tapping won't cost another heart
		arrow.is_failed = true
		arrow.queue_redraw()

		AudioManager.play("arrow_blocked")
		AudioManager.haptic(30)
		_shake()


func _spawn_trail(arrow: Arrow) -> void:
	var trail := Node2D.new()
	var trail_script := preload("res://scripts/trail_effect.gd")
	trail.set_script(trail_script)
	_trail_container.add_child(trail)

	# Build list of cell centers (in world coords) for each cell the arrow occupied
	var cell_centers: Array[Vector2] = []
	for c in arrow.cells:
		var center := grid_origin + Vector2(c) * cell_size + Vector2(cell_size, cell_size) * 0.5
		cell_centers.append(center)

	trail.position = Vector2.ZERO
	trail.setup(cell_centers, cell_size)


func _on_arrow_exit_finished(arrow_id: int) -> void:
	arrows.erase(arrow_id)
	_exiting_count -= 1

	# Redraw to show dots on newly empty cells
	queue_redraw()

	if grid_system and grid_system.is_cleared() and _exiting_count <= 0:
		AudioManager.play("level_clear")
		AudioManager.haptic(50)
		all_arrows_cleared.emit()


func _apply_zoom(new_zoom: float) -> void:
	_zoom_level = clampf(new_zoom, Config.ZOOM_MIN, Config.ZOOM_MAX)
	_calculate_grid_layout()
	_reposition_arrows()
	queue_redraw()


func _reposition_arrows() -> void:
	for id in arrows:
		var arrow: Arrow = arrows[id]
		if arrow.is_exiting:
			continue
		arrow.position = grid_origin + Vector2(arrow.cells[0]) * cell_size
		arrow.cell_size = cell_size
		arrow._update_collision_shape()
		arrow.queue_redraw()


func _shake() -> void:
	var original_pos := position
	var tween := create_tween()
	tween.tween_property(self, "position",
		original_pos + Vector2(randf_range(-Config.SHAKE_AMOUNT, Config.SHAKE_AMOUNT),
		randf_range(-Config.SHAKE_AMOUNT, Config.SHAKE_AMOUNT)),
		Config.SHAKE_DURATION * 0.5)
	tween.tween_property(self, "position", original_pos, Config.SHAKE_DURATION * 0.5)


func _expand_path(waypoints: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in range(waypoints.size()):
		var wp := Vector2i(int(waypoints[i][0]), int(waypoints[i][1]))
		if i == 0:
			cells.append(wp)
			continue
		var prev := cells[-1]
		var step: Vector2i
		if wp.x != prev.x:
			step = Vector2i(signi(wp.x - prev.x), 0)
		else:
			step = Vector2i(0, signi(wp.y - prev.y))
		var current := prev + step
		while true:
			cells.append(current)
			if current == wp:
				break
			current += step
	return cells


func _show_tutorial() -> void:
	_remove_tutorial()
	_tutorial_label = Label.new()
	_tutorial_label.text = "Tap an arrow!"
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.add_theme_font_size_override("font_size", 28)
	_tutorial_label.add_theme_color_override("font_color", Config.COLOR_TITLE)

	var label_pos_y := grid_origin.y + cell_size * float(grid_rows) + 30.0
	_tutorial_label.position = Vector2(0, label_pos_y)
	_tutorial_label.size = Vector2(Config.VIEWPORT_WIDTH, 40)
	add_child(_tutorial_label)


func _remove_tutorial() -> void:
	if _tutorial_label and is_instance_valid(_tutorial_label):
		var tween := create_tween()
		var label_ref := _tutorial_label
		tween.tween_property(label_ref, "modulate:a", 0.0, 0.3)
		tween.tween_callback(label_ref.queue_free)
		_tutorial_label = null
