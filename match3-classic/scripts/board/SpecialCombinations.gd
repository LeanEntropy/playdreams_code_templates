extends RefCounted
class_name SpecialCombinations
## Handles special gem combination effects

enum ComboType {
	NONE, STRIPED_STRIPED, WRAPPED_WRAPPED, COLORBOMB_COLORBOMB,
	STRIPED_WRAPPED, COLORBOMB_STRIPED, COLORBOMB_WRAPPED, COLORBOMB_REGULAR
}

const COMBO_SCORES := [0, 200, 300, 1000, 500, 400, 600, 100]

static func detect_combination(gem1: Gem, gem2: Gem) -> ComboType:
	if not ConfigManager.are_special_combinations_enabled() or gem1 == null or gem2 == null:
		return ComboType.NONE

	var s1 := gem1.special_type
	var s2 := gem2.special_type

	if s1 == Enums.SpecialType.NONE and s2 == Enums.SpecialType.NONE:
		return ComboType.NONE

	var combo_checks := [
		[_both_colorbomb(s1, s2), "colorbomb_colorbomb", ComboType.COLORBOMB_COLORBOMB],
		[_is_combo(s1, s2, Enums.SpecialType.COLOR_BOMB, _is_striped), "colorbomb_striped", ComboType.COLORBOMB_STRIPED],
		[_is_combo(s1, s2, Enums.SpecialType.COLOR_BOMB, func(s): return s == Enums.SpecialType.WRAPPED), "colorbomb_wrapped", ComboType.COLORBOMB_WRAPPED],
		[_is_combo(s1, s2, Enums.SpecialType.COLOR_BOMB, func(s): return s == Enums.SpecialType.NONE), "colorbomb_regular", ComboType.COLORBOMB_REGULAR],
		[_is_striped(s1) and _is_striped(s2), "striped_striped", ComboType.STRIPED_STRIPED],
		[s1 == Enums.SpecialType.WRAPPED and s2 == Enums.SpecialType.WRAPPED, "wrapped_wrapped", ComboType.WRAPPED_WRAPPED],
		[(_is_striped(s1) and s2 == Enums.SpecialType.WRAPPED) or (_is_striped(s2) and s1 == Enums.SpecialType.WRAPPED), "striped_wrapped", ComboType.STRIPED_WRAPPED],
	]

	for check in combo_checks:
		if check[0] and ConfigManager.is_combo_enabled(check[1]):
			return check[2]

	return ComboType.NONE

static func get_combination_targets(combo_type: ComboType, pos1: Vector2i, pos2: Vector2i, gem1: Gem, gem2: Gem) -> Dictionary:
	var result := {"targets": [] as Array[Vector2i], "transform_to": Enums.SpecialType.NONE, "transform_color": Enums.GemColor.NONE, "clear_all": false}
	var center := pos2

	match combo_type:
		ComboType.STRIPED_STRIPED:
			result["targets"] = _get_cross_targets(center)
		ComboType.WRAPPED_WRAPPED:
			result["targets"] = _get_area_targets(center, 2)
		ComboType.COLORBOMB_COLORBOMB:
			result["clear_all"] = true
			result["targets"] = _get_all_board_targets()
		ComboType.STRIPED_WRAPPED:
			result["targets"] = _get_three_lines_targets(center)
		ComboType.COLORBOMB_STRIPED, ComboType.COLORBOMB_WRAPPED, ComboType.COLORBOMB_REGULAR:
			var target_color := gem2.gem_color if gem1.special_type == Enums.SpecialType.COLOR_BOMB else gem1.gem_color
			result["transform_color"] = target_color
			result["targets"] = GameManager.get_color_bomb_targets(target_color)
			if combo_type == ComboType.COLORBOMB_STRIPED:
				result["transform_to"] = Enums.SpecialType.STRIPED_H
			elif combo_type == ComboType.COLORBOMB_WRAPPED:
				result["transform_to"] = Enums.SpecialType.WRAPPED

	return result

static func get_combo_score_bonus(combo_type: ComboType) -> int:
	return COMBO_SCORES[combo_type]

static func _is_striped(special: Enums.SpecialType) -> bool:
	return special == Enums.SpecialType.STRIPED_H or special == Enums.SpecialType.STRIPED_V

static func _both_colorbomb(s1: Enums.SpecialType, s2: Enums.SpecialType) -> bool:
	return s1 == Enums.SpecialType.COLOR_BOMB and s2 == Enums.SpecialType.COLOR_BOMB

static func _is_combo(s1: Enums.SpecialType, s2: Enums.SpecialType, target: Enums.SpecialType, check: Callable) -> bool:
	return (s1 == target and check.call(s2)) or (s2 == target and check.call(s1))

static func _get_cross_targets(center: Vector2i) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for x in range(GameManager.grid_width):
		targets.append(Vector2i(x, center.y))
	for y in range(GameManager.grid_height):
		if y != center.y:
			targets.append(Vector2i(center.x, y))
	return targets

static func _get_area_targets(center: Vector2i, radius: int) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var pos := Vector2i(center.x + dx, center.y + dy)
			if pos.x >= 0 and pos.x < GameManager.grid_width and pos.y >= 0 and pos.y < GameManager.grid_height:
				targets.append(pos)
	return targets

static func _get_three_lines_targets(center: Vector2i) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for offset in range(-1, 2):
		var row: int = center.y + offset
		var col: int = center.x + offset
		if row >= 0 and row < GameManager.grid_height:
			for x in range(GameManager.grid_width):
				var pos := Vector2i(x, row)
				if pos not in targets:
					targets.append(pos)
		if col >= 0 and col < GameManager.grid_width:
			for y in range(GameManager.grid_height):
				var pos := Vector2i(col, y)
				if pos not in targets:
					targets.append(pos)
	return targets

static func _get_all_board_targets() -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for x in range(GameManager.grid_width):
		for y in range(GameManager.grid_height):
			targets.append(Vector2i(x, y))
	return targets
