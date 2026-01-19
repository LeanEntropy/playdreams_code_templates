extends Node2D
class_name GameBoard
## Visual game board for match-3 puzzle with responsive layout

signal move_completed
signal board_idle
signal gems_destroyed(count: int)
signal layout_changed

var gems: Array[Array] = []
var selected_gem: Gem = null
var tile_size: float = 64.0
var grid_offset: Vector2 = Vector2.ZERO
var _last_viewport_size: Vector2 = Vector2.ZERO
var _input_enabled: bool = true

const GEM_SCENE := preload("res://scenes/Gem.tscn")

func _ready() -> void:
	await get_tree().process_frame
	_calculate_layout()
	_create_board()
	GameManager.special_created.connect(_on_special_created)
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_last_viewport_size = get_viewport_rect().size

func _draw() -> void:
	_draw_board_background()

func _on_viewport_size_changed() -> void:
	var new_size := get_viewport_rect().size
	if (new_size - _last_viewport_size).abs().length() > 50:
		_last_viewport_size = new_size
		_recalculate_layout()

func initialize_board() -> void:
	_clear_gems()
	GameManager.start_new_game()
	_sync_gems_to_grid()

func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_deselect_gem()

func get_gem_at(pos: Vector2i) -> Gem:
	if pos.x < 0 or pos.x >= GameManager.grid_width or pos.y < 0 or pos.y >= GameManager.grid_height:
		return null
	return gems[pos.x][pos.y]

func _calculate_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var margins := ConfigManager.get_margins(viewport_size)
	var available_width: float = viewport_size.x - margins["sides"] * 2
	var available_height: float = viewport_size.y - margins["top"] - margins["bottom"]

	tile_size = min(available_width / GameManager.grid_width, available_height / GameManager.grid_height)
	tile_size = clamp(tile_size, ConfigManager.get_min_tile_size(), ConfigManager.get_max_tile_size())

	var board_size := Vector2(tile_size * GameManager.grid_width, tile_size * GameManager.grid_height)
	grid_offset = Vector2(
		(viewport_size.x - board_size.x) / 2.0,
		margins["top"] + (available_height - board_size.y) / 2.0
	)

func _recalculate_layout() -> void:
	if GameManager.processing_moves:
		await GameManager.board_settled

	_calculate_layout()
	var scale_factor := tile_size / ConfigManager.get_base_gem_size()
	for x in range(GameManager.grid_width):
		for y in range(GameManager.grid_height):
			var gem: Gem = gems[x][y] if x < gems.size() and y < gems[x].size() else null
			if gem:
				gem.position = _grid_to_world(Vector2i(x, y))
				gem._tile_scale = scale_factor
				gem._update_visual()
	queue_redraw()
	layout_changed.emit()

func _create_board() -> void:
	gems.clear()
	for x in range(GameManager.grid_width):
		var column: Array[Gem] = []
		column.resize(GameManager.grid_height)
		gems.append(column)
	GameManager.start_new_game()
	_sync_gems_to_grid()
	queue_redraw()

func _sync_gems_to_grid() -> void:
	for x in range(GameManager.grid_width):
		for y in range(GameManager.grid_height):
			var gem_data := GameManager.get_gem_data(Vector2i(x, y))
			gems[x][y] = _create_gem(x, y, gem_data["color"], gem_data["special"])

func _create_gem(x: int, y: int, color: Enums.GemColor, special: Enums.SpecialType = Enums.SpecialType.NONE) -> Gem:
	var gem: Gem = GEM_SCENE.instantiate()
	add_child(gem)
	gem.setup(color, Vector2i(x, y), tile_size / ConfigManager.get_base_gem_size())
	gem.position = _grid_to_world(Vector2i(x, y))
	if special != Enums.SpecialType.NONE:
		gem.set_special(special)
	gem.clicked.connect(_on_gem_clicked)
	gem.swiped.connect(_on_gem_swiped)
	return gem

func _clear_gems() -> void:
	for x in range(GameManager.grid_width):
		for y in range(GameManager.grid_height):
			if gems[x][y]:
				gems[x][y].queue_free()
				gems[x][y] = null

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return grid_offset + Vector2(grid_pos.x * tile_size + tile_size / 2.0, grid_pos.y * tile_size + tile_size / 2.0)

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var local := world_pos - grid_offset
	return Vector2i(int(local.x / tile_size), int(local.y / tile_size))

func _on_gem_clicked(gem: Gem) -> void:
	if not _input_enabled or GameManager.processing_moves:
		return

	# Handle active booster
	if BoosterManager.is_booster_active():
		_handle_booster_click(gem)
		return

	if selected_gem == null:
		_select_gem(gem)
	elif selected_gem == gem:
		_deselect_gem()
	elif GameManager.can_swap(selected_gem.grid_position, gem.grid_position):
		_perform_swap(selected_gem, gem)
	else:
		_deselect_gem()
		_select_gem(gem)

func _on_gem_swiped(gem: Gem, direction: Vector2) -> void:
	if not _input_enabled or GameManager.processing_moves:
		return
	var target_gem := get_gem_at(gem.grid_position + Vector2i(int(direction.x), int(direction.y)))
	if target_gem:
		_perform_swap(gem, target_gem)

func _select_gem(gem: Gem) -> void:
	selected_gem = gem
	gem.set_selected(true)

func _deselect_gem() -> void:
	if selected_gem:
		selected_gem.set_selected(false)
		selected_gem = null

func _perform_swap(gem1: Gem, gem2: Gem) -> void:
	_deselect_gem()
	GameManager.processing_moves = true
	SoundManager.play_swap()

	var pos1 := gem1.grid_position
	var pos2 := gem2.grid_position

	var tween1 := gem1.animate_swap_to(gem2.position)
	gem2.animate_swap_to(gem1.position)
	if tween1:
		await tween1.finished

	GameManager.swap_gems(pos1, pos2)
	gem1.grid_position = pos2
	gem2.grid_position = pos1
	gems[pos1.x][pos1.y] = gem2
	gems[pos2.x][pos2.y] = gem1

	var combo_type := SpecialCombinations.detect_combination(gem1, gem2)
	if combo_type != SpecialCombinations.ComboType.NONE:
		GameManager.use_move()
		GameManager.reset_combo()
		await _execute_special_combination(combo_type, pos1, pos2, gem1, gem2)
		await _finish_move()
		return

	var matches := GameManager.find_matches()
	if matches.is_empty():
		await _revert_swap(gem1, gem2, pos1, pos2)
		GameManager.processing_moves = false
		return

	GameManager.use_move()
	GameManager.reset_combo()
	await _process_cascade(pos2)
	await _finish_move()

func _finish_move() -> void:
	GameManager.processing_moves = false
	move_completed.emit()
	if not GameManager.has_possible_moves():
		await _shuffle_until_valid()
	board_idle.emit()

func _revert_swap(gem1: Gem, gem2: Gem, original_pos1: Vector2i, original_pos2: Vector2i) -> void:
	GameManager.swap_gems(gem1.grid_position, gem2.grid_position)
	var tween1 := gem1.animate_swap_to(_grid_to_world(original_pos1))
	gem2.animate_swap_to(_grid_to_world(original_pos2))
	if tween1:
		await tween1.finished
	gem1.grid_position = original_pos1
	gem2.grid_position = original_pos2
	gems[original_pos1.x][original_pos1.y] = gem1
	gems[original_pos2.x][original_pos2.y] = gem2

func _process_cascade(swapped_pos: Vector2i) -> void:
	for cascade_depth in 50:
		var matches := GameManager.find_matches()
		if matches.is_empty():
			break

		GameManager.increment_combo()
		if cascade_depth > 0:
			GameManager.track_combo()  # Track cascade for combo challenge

		var special_info := GameManager.detect_special_pattern(matches, swapped_pos)

		if cascade_depth > 0:
			SoundManager.play_cascade()
		else:
			SoundManager.play_match()

		await _highlight_matches(matches)
		await _activate_specials_in_matches(matches)

		# Collect colors for tracking before removal
		var colors_cleared: Array[Enums.GemColor] = []
		for match_info in matches:
			for cell in match_info["cells"]:
				var gem_data := GameManager.get_gem_data(cell)
				if gem_data["color"] != Enums.GemColor.NONE:
					colors_cleared.append(gem_data["color"])

		var removed_count := GameManager.remove_matches(matches, special_info)
		GameManager.add_score(removed_count)
		GameManager.track_gems_cleared(removed_count, colors_cleared)

		await _animate_match_destruction(matches, special_info)
		await _animate_gravity(GameManager.apply_gravity())
		await _animate_refill(GameManager.fill_empty_spaces())

		swapped_pos = Vector2i(-1, -1)

func _activate_specials_in_matches(matches: Array[Dictionary]) -> void:
	var specials_to_activate: Array[Gem] = []
	for match_info in matches:
		for cell in match_info["cells"]:
			var gem := get_gem_at(cell)
			if gem and gem.is_special() and gem not in specials_to_activate:
				specials_to_activate.append(gem)

	for gem in specials_to_activate:
		await _activate_special_gem(gem)

func _activate_special_gem(gem: Gem) -> void:
	SoundManager.play_special()
	var pos := gem.grid_position
	var targets: Array[Vector2i] = []

	if gem.special_type == Enums.SpecialType.COLOR_BOMB:
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var adj_gem := get_gem_at(pos + offset)
			if adj_gem and adj_gem.gem_color != Enums.GemColor.NONE:
				targets = GameManager.get_color_bomb_targets(adj_gem.gem_color)
				break
	else:
		targets = GameManager.get_special_activation_targets(pos, gem.special_type)

	var tween := gem.animate_special_activation()
	if tween:
		await tween.finished

	_remove_gem(gem)

	if targets.is_empty():
		return

	var gems_to_destroy: Array[Gem] = []
	var chain_specials: Array[Gem] = []
	for target_pos in targets:
		var target_gem := get_gem_at(target_pos)
		if target_gem and is_instance_valid(target_gem):
			gems_to_destroy.append(target_gem)
			GameManager.set_gem_data(target_pos, Enums.GemColor.NONE)
			if target_gem.is_special():
				chain_specials.append(target_gem)

	await _animate_destruction(gems_to_destroy.filter(func(g): return g not in chain_specials))
	GameManager.add_score(gems_to_destroy.size())
	gems_destroyed.emit(gems_to_destroy.size())

	for chain_gem in chain_specials:
		if chain_gem and is_instance_valid(chain_gem):
			await _activate_special_gem(chain_gem)

func _remove_gem(gem: Gem) -> void:
	var pos := gem.grid_position
	GameManager.set_gem_data(pos, Enums.GemColor.NONE)
	gems[pos.x][pos.y] = null
	gem.queue_free()

func _animate_destruction(gems_list: Array) -> void:
	var tweens: Array[Tween] = []
	for gem in gems_list:
		var t: Tween = gem.animate_destroy()
		if t:
			tweens.append(t)
	if not tweens.is_empty():
		await tweens[0].finished
	for gem in gems_list:
		if gem and is_instance_valid(gem):
			gems[gem.grid_position.x][gem.grid_position.y] = null
			gem.queue_free()

func _execute_special_combination(combo_type: SpecialCombinations.ComboType, pos1: Vector2i, pos2: Vector2i, gem1: Gem, gem2: Gem) -> void:
	var combo_data := SpecialCombinations.get_combination_targets(combo_type, pos1, pos2, gem1, gem2)
	var targets: Array[Vector2i] = combo_data["targets"]
	var transform_to: Enums.SpecialType = combo_data["transform_to"]

	GameManager.add_score_raw(SpecialCombinations.get_combo_score_bonus(combo_type))

	var combine_tweens: Array[Tween] = []
	for g in [gem1, gem2]:
		if g and is_instance_valid(g):
			var t: Tween = g.animate_special_activation()
			if t:
				combine_tweens.append(t)

	if not combine_tweens.is_empty():
		await combine_tweens[0].finished

	for g in [gem1, gem2]:
		if g and is_instance_valid(g):
			_remove_gem(g)

	if transform_to != Enums.SpecialType.NONE:
		await _execute_transform_combination(targets, transform_to)
	else:
		await _execute_destruction_combination(targets)

	await _animate_gravity(GameManager.apply_gravity())
	await _animate_refill(GameManager.fill_empty_spaces())
	await _process_cascade(pos2)

func _execute_transform_combination(targets: Array[Vector2i], transform_to: Enums.SpecialType) -> void:
	var gems_to_transform: Array[Gem] = []
	var alternate := false

	for target_pos in targets:
		var gem := get_gem_at(target_pos)
		if gem and is_instance_valid(gem):
			var actual_type := transform_to
			if transform_to == Enums.SpecialType.STRIPED_H:
				actual_type = Enums.SpecialType.STRIPED_V if alternate else Enums.SpecialType.STRIPED_H
				alternate = not alternate
			gem.set_special(actual_type)
			gems_to_transform.append(gem)

	var delay := ConfigManager.get_transform_delay()
	if delay > 0:
		await get_tree().create_timer(delay).timeout

	for gem in gems_to_transform:
		if gem and is_instance_valid(gem):
			await _activate_special_gem(gem)

func _execute_destruction_combination(targets: Array[Vector2i]) -> void:
	var gems_to_destroy: Array[Gem] = []
	var chain_specials: Array[Gem] = []

	for target_pos in targets:
		var gem := get_gem_at(target_pos)
		if gem and is_instance_valid(gem):
			gems_to_destroy.append(gem)
			if gem.is_special():
				chain_specials.append(gem)

	var regular_gems := gems_to_destroy.filter(func(g): return g not in chain_specials)
	for gem in regular_gems:
		GameManager.set_gem_data(gem.grid_position, Enums.GemColor.NONE)

	await _animate_destruction(regular_gems)
	GameManager.add_score(regular_gems.size())
	gems_destroyed.emit(regular_gems.size())

	for chain_gem in chain_specials:
		if chain_gem and is_instance_valid(chain_gem):
			await _activate_special_gem(chain_gem)

func _highlight_matches(matches: Array[Dictionary]) -> void:
	var tweens: Array[Tween] = []
	for match_info in matches:
		for cell in match_info["cells"]:
			var gem := get_gem_at(cell)
			if gem and is_instance_valid(gem):
				var t := gem.animate_match_highlight()
				if t:
					tweens.append(t)
	if not tweens.is_empty():
		await tweens[0].finished

func _animate_match_destruction(matches: Array[Dictionary], special_info: Dictionary) -> void:
	var special_pos: Vector2i = special_info.get("position", Vector2i(-1, -1))
	var tweens: Array[Tween] = []
	var special_gem: Gem = null

	for match_info in matches:
		for cell in match_info["cells"]:
			var gem := get_gem_at(cell)
			if not gem or not is_instance_valid(gem):
				continue
			if cell == special_pos:
				gem.set_special(special_info["type"])
				special_gem = gem
			else:
				var t := gem.animate_destroy()
				if t:
					tweens.append(t)

	# Animate special creation simultaneously with destruction
	if special_gem:
		var special_tween := special_gem.animate_special_creation()
		if special_tween:
			tweens.append(special_tween)

	if not tweens.is_empty():
		await tweens[0].finished

	for match_info in matches:
		for cell in match_info["cells"]:
			if cell == special_pos:
				continue
			var gem := get_gem_at(cell)
			if gem and is_instance_valid(gem):
				gems[cell.x][cell.y] = null
				gem.queue_free()

func _animate_gravity(movements: Array[Dictionary]) -> void:
	if movements.is_empty():
		return

	var tweens: Array[Tween] = []
	for movement in movements:
		var from_pos: Vector2i = movement["from"]
		var to_pos: Vector2i = movement["to"]
		var gem: Gem = gems[from_pos.x][from_pos.y]
		if not gem or not is_instance_valid(gem):
			continue

		gems[from_pos.x][from_pos.y] = null
		gems[to_pos.x][to_pos.y] = gem
		gem.grid_position = to_pos

		var duration: float = abs(to_pos.y - from_pos.y) * ConfigManager.get_drop_duration()
		var t: Tween = gem.animate_to_position(_grid_to_world(to_pos), duration)
		if t:
			tweens.append(t)

	if not tweens.is_empty():
		await tweens[0].finished

func _animate_refill(filled: Array[Vector2i]) -> void:
	if filled.is_empty():
		return

	var tweens: Array[Tween] = []
	for pos in filled:
		var gem_data := GameManager.get_gem_data(pos)
		var gem := _create_gem(pos.x, pos.y, gem_data["color"])
		gem.position = _grid_to_world(Vector2i(pos.x, -1))
		gems[pos.x][pos.y] = gem

		var t := gem.animate_to_position(_grid_to_world(pos), ConfigManager.get_drop_duration() * (pos.y + 1))
		if t:
			tweens.append(t)

	if not tweens.is_empty():
		await tweens[0].finished

func _shuffle_until_valid() -> void:
	for attempt in 100:
		GameManager.shuffle_board()
		if GameManager.find_matches().is_empty() and GameManager.has_possible_moves():
			break

	var scale_factor := tile_size / ConfigManager.get_base_gem_size()
	for x in range(GameManager.grid_width):
		for y in range(GameManager.grid_height):
			var gem: Gem = gems[x][y]
			if gem:
				gem.setup(GameManager.get_gem_data(Vector2i(x, y))["color"], Vector2i(x, y), scale_factor)

func _draw_board_background() -> void:
	# Background is now handled by GridBackground TextureRect in Main.tscn
	# This function is kept for compatibility but does nothing
	pass

func _on_special_created(position: Vector2i, special_type: Enums.SpecialType) -> void:
	var gem := get_gem_at(position)
	if gem:
		gem.set_special(special_type)
		GameManager.track_special_created()  # Track for special creation challenge

func _handle_booster_click(gem: Gem) -> void:
	var booster := BoosterManager.get_active_booster()
	match booster:
		Enums.BoosterType.LOLLIPOP_HAMMER:
			await _use_lollipop_hammer(gem)
		Enums.BoosterType.FREE_SWITCH:
			_handle_free_switch(gem)
		_:
			BoosterManager.cancel_booster()

func _use_lollipop_hammer(gem: Gem) -> void:
	BoosterManager.use_booster()
	GameManager.processing_moves = true

	var pos := gem.grid_position
	GameManager.set_gem_data(pos, Enums.GemColor.NONE)

	var tween := gem.animate_destroy()
	if tween:
		await tween.finished

	gems[pos.x][pos.y] = null
	gem.queue_free()

	GameManager.add_score(1)
	gems_destroyed.emit(1)

	var movements := GameManager.apply_gravity()
	await _animate_gravity(movements)

	var filled := GameManager.fill_empty_spaces()
	await _animate_refill(filled)

	await _process_cascade(Vector2i(-1, -1))
	await _finish_move()

func _handle_free_switch(gem: Gem) -> void:
	if selected_gem == null:
		_select_gem(gem)
	elif selected_gem == gem:
		_deselect_gem()
	elif GameManager.can_swap(selected_gem.grid_position, gem.grid_position):
		BoosterManager.use_booster()
		_perform_free_swap(selected_gem, gem)
	else:
		_deselect_gem()
		_select_gem(gem)

func _perform_free_swap(gem1: Gem, gem2: Gem) -> void:
	_deselect_gem()
	GameManager.processing_moves = true
	SoundManager.play_swap()

	var pos1 := gem1.grid_position
	var pos2 := gem2.grid_position

	var tween1 := gem1.animate_swap_to(gem2.position)
	gem2.animate_swap_to(gem1.position)
	if tween1:
		await tween1.finished

	GameManager.swap_gems(pos1, pos2)
	gem1.grid_position = pos2
	gem2.grid_position = pos1
	gems[pos1.x][pos1.y] = gem2
	gems[pos2.x][pos2.y] = gem1

	# Check for special combinations first
	var combo_type := SpecialCombinations.detect_combination(gem1, gem2)
	if combo_type != SpecialCombinations.ComboType.NONE:
		GameManager.reset_combo()
		await _execute_special_combination(combo_type, pos1, pos2, gem1, gem2)
		await _finish_move()
		return

	# Check for matches (free swap doesn't revert if no match)
	var matches := GameManager.find_matches()
	if not matches.is_empty():
		GameManager.reset_combo()
		await _process_cascade(pos2)

	await _finish_move()

func use_shuffle_booster() -> void:
	if not BoosterManager.has_booster(Enums.BoosterType.SHUFFLE):
		return
	if GameManager.processing_moves:
		return

	BoosterManager.activate_booster(Enums.BoosterType.SHUFFLE)
	BoosterManager.use_booster()
	GameManager.processing_moves = true

	_shuffle_until_valid()
	GameManager.processing_moves = false

func use_extra_moves_booster() -> void:
	if not BoosterManager.has_booster(Enums.BoosterType.EXTRA_MOVES):
		return

	BoosterManager.activate_booster(Enums.BoosterType.EXTRA_MOVES)
	BoosterManager.use_booster()
	GameManager.add_moves(ConfigManager.get_extra_moves_amount())

func use_color_bomb_start() -> void:
	if not BoosterManager.has_booster(Enums.BoosterType.COLOR_BOMB_START):
		return

	BoosterManager.activate_booster(Enums.BoosterType.COLOR_BOMB_START)
	BoosterManager.use_booster()

	# Find a random non-special gem and convert it to color bomb
	var candidates: Array[Vector2i] = []
	for x in range(GameManager.grid_width):
		for y in range(GameManager.grid_height):
			var gem := get_gem_at(Vector2i(x, y))
			if gem and not gem.is_special():
				candidates.append(Vector2i(x, y))

	if not candidates.is_empty():
		var pos: Vector2i = candidates[randi() % candidates.size()]
		var gem := get_gem_at(pos)
		if gem:
			gem.set_special(Enums.SpecialType.COLOR_BOMB)
			GameManager.set_special_type(pos, Enums.SpecialType.COLOR_BOMB)
			gem.animate_special_creation()
