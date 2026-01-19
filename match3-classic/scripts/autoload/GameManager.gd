extends Node
## GameManager - Core game state and matching logic singleton

signal score_changed(new_score: int)
signal combo_changed(combo: int)
signal moves_changed(moves_left: int)
signal game_over
signal level_won
signal match_found(positions: Array[Vector2i], is_special: bool)
signal special_created(position: Vector2i, special_type: Enums.SpecialType)
signal board_settled
signal board_resized
signal goal_progress_changed(current: int, target: int, label: String)

var score: int = 0
var combo_count: int = 0
var moves_left: int = 30
var target_score: int = 10000
var processing_moves: bool = false

# Level goal tracking
var gems_cleared: int = 0
var combos_achieved: int = 0
var specials_created: int = 0
var color_gems_collected: Dictionary = {}
var grid_width: int = 8
var grid_height: int = 8
var min_match: int = 3
var gem_types_count: int = 6  # Number of gem colors for current level
var grid: Array[Array] = []

func _ready() -> void:
	randomize()
	await get_tree().process_frame
	_load_config_values()
	_initialize_grid()

func _load_config_values() -> void:
	grid_width = ConfigManager.get_grid_width()
	grid_height = ConfigManager.get_grid_height()
	min_match = ConfigManager.get_min_match()

func start_new_game(moves: int = -1, target: int = -1) -> void:
	_load_config_values()

	var level := ConfigManager.get_current_level()

	score = 0
	combo_count = 0
	moves_left = level.max_moves if level else (moves if moves > 0 else ConfigManager.get_starting_moves())
	target_score = level.target_score if level else (target if target > 0 else ConfigManager.get_target_score())
	gem_types_count = level.gem_types_count if level else 6
	processing_moves = false
	_level_won_emitted = false

	# Reset goal tracking
	gems_cleared = 0
	combos_achieved = 0
	specials_created = 0
	color_gems_collected.clear()

	_initialize_grid()
	_fill_grid_random()

	score_changed.emit(score)
	moves_changed.emit(moves_left)
	combo_changed.emit(combo_count)
	_emit_goal_progress()

func get_gem_data(pos: Vector2i) -> Dictionary:
	if not _is_valid_position(pos):
		return {"color": Enums.GemColor.NONE, "special": Enums.SpecialType.NONE}
	return grid[pos.x][pos.y]

func set_gem_data(pos: Vector2i, color: Enums.GemColor, special: Enums.SpecialType = Enums.SpecialType.NONE) -> void:
	if _is_valid_position(pos):
		grid[pos.x][pos.y] = {"color": color, "special": special}

func can_swap(pos1: Vector2i, pos2: Vector2i) -> bool:
	if not _is_valid_position(pos1) or not _is_valid_position(pos2):
		return false
	return _are_adjacent(pos1, pos2)

func swap_gems(pos1: Vector2i, pos2: Vector2i) -> bool:
	if not can_swap(pos1, pos2):
		return false

	var temp: Dictionary = grid[pos1.x][pos1.y]
	grid[pos1.x][pos1.y] = grid[pos2.x][pos2.y]
	grid[pos2.x][pos2.y] = temp
	return true

func find_matches() -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	matches.append_array(_find_line_matches(true))
	matches.append_array(_find_line_matches(false))
	return matches

func _find_line_matches(horizontal: bool) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	var primary_size := grid_height if horizontal else grid_width
	var secondary_size := grid_width if horizontal else grid_height

	for primary in range(primary_size):
		var streak_start := 0
		var streak_color: Enums.GemColor = Enums.GemColor.NONE
		var streak_count := 0

		for secondary in range(secondary_size + 1):
			var pos := Vector2i(secondary, primary) if horizontal else Vector2i(primary, secondary)
			var current_color: Enums.GemColor = grid[pos.x][pos.y]["color"] if secondary < secondary_size else Enums.GemColor.NONE

			if current_color == streak_color and current_color != Enums.GemColor.NONE:
				streak_count += 1
			else:
				if streak_count >= min_match and streak_color != Enums.GemColor.NONE:
					var cells: Array[Vector2i] = []
					for i in range(streak_start, streak_start + streak_count):
						cells.append(Vector2i(i, primary) if horizontal else Vector2i(primary, i))
					matches.append({"cells": cells, "count": streak_count, "direction": "horizontal" if horizontal else "vertical"})
				streak_start = secondary
				streak_color = current_color
				streak_count = 1

	return matches

func detect_special_pattern(matches: Array[Dictionary], swapped_pos: Vector2i) -> Dictionary:
	if matches.is_empty():
		return {}

	var lt_result := _check_lt_shape(matches, swapped_pos)
	if lt_result["found"]:
		return {"type": Enums.SpecialType.WRAPPED, "position": lt_result["position"]}

	for match_info in matches:
		if match_info["count"] >= 5:
			var pos: Vector2i = swapped_pos if swapped_pos in match_info["cells"] else match_info["cells"][match_info["count"] / 2]
			return {"type": Enums.SpecialType.COLOR_BOMB, "position": pos}

	for match_info in matches:
		if match_info["count"] >= 4:
			var pos: Vector2i = swapped_pos if swapped_pos in match_info["cells"] else match_info["cells"][match_info["count"] / 2]
			var stripe_type := Enums.SpecialType.STRIPED_V if match_info["direction"] == "horizontal" else Enums.SpecialType.STRIPED_H
			return {"type": stripe_type, "position": pos}

	return {}

func remove_matches(matches: Array[Dictionary], special_info: Dictionary = {}) -> int:
	var removed_count := 0
	var special_pos: Vector2i = special_info.get("position", Vector2i(-1, -1))

	var cells_to_remove: Array[Vector2i] = []
	for match_info in matches:
		for cell in match_info["cells"]:
			if cell not in cells_to_remove:
				cells_to_remove.append(cell)

	for cell in cells_to_remove:
		if cell == special_pos:
			continue
		if grid[cell.x][cell.y]["color"] != Enums.GemColor.NONE:
			grid[cell.x][cell.y] = {"color": Enums.GemColor.NONE, "special": Enums.SpecialType.NONE}
			removed_count += 1

	if not special_info.is_empty():
		var color: Enums.GemColor = grid[special_pos.x][special_pos.y]["color"]
		grid[special_pos.x][special_pos.y] = {"color": color, "special": special_info["type"]}
		special_created.emit(special_pos, special_info["type"])

	return removed_count

func apply_gravity() -> Array[Dictionary]:
	var movements: Array[Dictionary] = []
	for x in range(grid_width):
		var write_y := grid_height - 1
		for read_y in range(grid_height - 1, -1, -1):
			if grid[x][read_y]["color"] != Enums.GemColor.NONE:
				if read_y != write_y:
					grid[x][write_y] = grid[x][read_y]
					grid[x][read_y] = {"color": Enums.GemColor.NONE, "special": Enums.SpecialType.NONE}
					movements.append({"from": Vector2i(x, read_y), "to": Vector2i(x, write_y)})
				write_y -= 1
	return movements

func fill_empty_spaces() -> Array[Vector2i]:
	var filled: Array[Vector2i] = []
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y]["color"] == Enums.GemColor.NONE:
				grid[x][y] = {"color": Enums.get_random_color(gem_types_count), "special": Enums.SpecialType.NONE}
				filled.append(Vector2i(x, y))
	return filled

func add_score(gems_matched: int) -> void:
	score += int(gems_matched * Enums.SCORE_PER_GEM * pow(Enums.COMBO_MULTIPLIER, combo_count))
	score_changed.emit(score)
	_check_win_condition()

func add_score_raw(points: int) -> void:
	score += points
	score_changed.emit(score)
	_check_win_condition()

func use_move() -> void:
	moves_left -= 1
	moves_changed.emit(moves_left)
	if moves_left <= 0 and score < target_score:
		game_over.emit()

func add_moves(amount: int) -> void:
	moves_left += amount
	moves_changed.emit(moves_left)

func set_special_type(pos: Vector2i, special: Enums.SpecialType) -> void:
	if _is_valid_position(pos):
		grid[pos.x][pos.y]["special"] = special

func increment_combo() -> void:
	combo_count += 1
	combo_changed.emit(combo_count)

func reset_combo() -> void:
	combo_count = 0
	combo_changed.emit(combo_count)

func has_possible_moves() -> bool:
	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			if x < grid_width - 1 and _would_create_match(pos, Vector2i(x + 1, y)):
				return true
			if y < grid_height - 1 and _would_create_match(pos, Vector2i(x, y + 1)):
				return true
	return false

func shuffle_board() -> void:
	var all_colors: Array[Enums.GemColor] = []
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y]["special"] == Enums.SpecialType.NONE:
				all_colors.append(grid[x][y]["color"])

	all_colors.shuffle()

	var idx := 0
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y]["special"] == Enums.SpecialType.NONE:
				grid[x][y]["color"] = all_colors[idx]
				idx += 1

func get_special_activation_targets(pos: Vector2i, special: Enums.SpecialType) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	match special:
		Enums.SpecialType.STRIPED_H:
			for x in range(grid_width):
				targets.append(Vector2i(x, pos.y))
		Enums.SpecialType.STRIPED_V:
			for y in range(grid_height):
				targets.append(Vector2i(pos.x, y))
		Enums.SpecialType.WRAPPED:
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var target := Vector2i(pos.x + dx, pos.y + dy)
					if _is_valid_position(target):
						targets.append(target)
	return targets

func get_color_bomb_targets(target_color: Enums.GemColor) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y]["color"] == target_color:
				targets.append(Vector2i(x, y))
	return targets

func _initialize_grid() -> void:
	grid.clear()
	for x in range(grid_width):
		var column: Array[Dictionary] = []
		for y in range(grid_height):
			column.append({"color": Enums.GemColor.NONE, "special": Enums.SpecialType.NONE})
		grid.append(column)

func _fill_grid_random() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			grid[x][y] = {"color": _get_safe_random_color(x, y), "special": Enums.SpecialType.NONE}

func _get_safe_random_color(x: int, y: int) -> Enums.GemColor:
	for attempt in 50:
		var color := Enums.get_random_color(gem_types_count)
		if not _would_create_initial_match(x, y, color):
			return color
	return Enums.GemColor.RED

func _would_create_initial_match(x: int, y: int, color: Enums.GemColor) -> bool:
	var h_count := 1
	var check_x := x - 1
	while check_x >= 0 and grid[check_x][y]["color"] == color:
		h_count += 1
		check_x -= 1

	var v_count := 1
	var check_y := y - 1
	while check_y >= 0 and grid[x][check_y]["color"] == color:
		v_count += 1
		check_y -= 1

	return h_count >= min_match or v_count >= min_match

func _is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func _are_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	var diff := (pos1 - pos2).abs()
	return (diff.x == 1 and diff.y == 0) or (diff.x == 0 and diff.y == 1)

func _would_create_match(pos1: Vector2i, pos2: Vector2i) -> bool:
	swap_gems(pos1, pos2)
	var has_match := not find_matches().is_empty()
	swap_gems(pos1, pos2)
	return has_match

func _check_lt_shape(matches: Array[Dictionary], swapped_pos: Vector2i) -> Dictionary:
	var h_matches := matches.filter(func(m): return m["direction"] == "horizontal")
	var v_matches := matches.filter(func(m): return m["direction"] == "vertical")

	if h_matches.is_empty() or v_matches.is_empty():
		return {"found": false, "position": Vector2i.ZERO}

	for h_match in h_matches:
		for v_match in v_matches:
			for h_cell in h_match["cells"]:
				if h_cell in v_match["cells"]:
					var pos: Vector2i = swapped_pos if (swapped_pos in h_match["cells"] or swapped_pos in v_match["cells"]) else h_cell
					return {"found": true, "position": pos}

	return {"found": false, "position": Vector2i.ZERO}

var _level_won_emitted: bool = false

func _check_win_condition() -> void:
	if _level_won_emitted:
		return
	if is_level_complete():
		_level_won_emitted = true
		level_won.emit()

func is_level_complete() -> bool:
	var level := ConfigManager.get_current_level()
	if not level:
		return score >= target_score

	match level.level_type:
		Enums.LevelType.SCORE_TARGET:
			return score >= level.target_score
		Enums.LevelType.CLEAR_COUNT:
			return gems_cleared >= level.target_clears
		Enums.LevelType.COMBO_CHALLENGE:
			return combos_achieved >= level.target_combos
		Enums.LevelType.SPECIAL_CREATION:
			return specials_created >= level.target_specials
		Enums.LevelType.COLOR_COLLECTION:
			var c1: int = color_gems_collected.get(level.target_color_1, 0)
			var c2: int = color_gems_collected.get(level.target_color_2, 0)
			return c1 >= level.target_color_1_count and c2 >= level.target_color_2_count
	return false

func get_goal_progress() -> Dictionary:
	var level := ConfigManager.get_current_level()
	if not level:
		return {"current": score, "target": target_score, "label": "Score"}

	match level.level_type:
		Enums.LevelType.SCORE_TARGET:
			return {"current": score, "target": level.target_score, "label": "Score"}
		Enums.LevelType.CLEAR_COUNT:
			return {"current": gems_cleared, "target": level.target_clears, "label": "Cleared"}
		Enums.LevelType.COMBO_CHALLENGE:
			return {"current": combos_achieved, "target": level.target_combos, "label": "Combos"}
		Enums.LevelType.SPECIAL_CREATION:
			return {"current": specials_created, "target": level.target_specials, "label": "Specials"}
		Enums.LevelType.COLOR_COLLECTION:
			var c1: int = color_gems_collected.get(level.target_color_1, 0)
			var c2: int = color_gems_collected.get(level.target_color_2, 0)
			return {
				"current": c1 + c2,
				"target": level.target_color_1_count + level.target_color_2_count,
				"label": "Colors",
				"color1_current": c1,
				"color1_target": level.target_color_1_count,
				"color1_type": level.target_color_1,
				"color2_current": c2,
				"color2_target": level.target_color_2_count,
				"color2_type": level.target_color_2
			}
	return {"current": 0, "target": 1, "label": "Goal"}

func _emit_goal_progress() -> void:
	var progress := get_goal_progress()
	goal_progress_changed.emit(progress["current"], progress["target"], progress["label"])

func track_gems_cleared(count: int, colors: Array[Enums.GemColor] = []) -> void:
	gems_cleared += count
	for color in colors:
		if color != Enums.GemColor.NONE:
			color_gems_collected[color] = color_gems_collected.get(color, 0) + 1
	_emit_goal_progress()
	_check_win_condition()

func track_combo() -> void:
	combos_achieved += 1
	_emit_goal_progress()
	_check_win_condition()

func track_special_created() -> void:
	specials_created += 1
	_emit_goal_progress()
	_check_win_condition()

func calculate_stars(final_score: int) -> int:
	var level := ConfigManager.get_current_level()
	if not level:
		var ratio := float(final_score) / float(target_score) if target_score > 0 else 0.0
		if ratio >= 3.0: return 3
		elif ratio >= 1.5: return 2
		elif ratio >= 1.0: return 1
		return 0

	# For non-score levels, use the level-specific thresholds
	var value: int
	match level.level_type:
		Enums.LevelType.SCORE_TARGET:
			value = final_score
		Enums.LevelType.CLEAR_COUNT:
			value = gems_cleared
		Enums.LevelType.COMBO_CHALLENGE:
			value = combos_achieved
		Enums.LevelType.SPECIAL_CREATION:
			value = specials_created
		Enums.LevelType.COLOR_COLLECTION:
			var c1: int = color_gems_collected.get(level.target_color_1, 0)
			var c2: int = color_gems_collected.get(level.target_color_2, 0)
			value = c1 + c2
		_:
			value = final_score

	if value >= level.star_3_threshold:
		return 3
	elif value >= level.star_2_threshold:
		return 2
	elif value >= level.star_1_threshold:
		return 1
	return 0
