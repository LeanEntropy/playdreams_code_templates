class_name LevelGenerator
extends RefCounted

## Level generation using Hamiltonian path splitting.
## Produces 100%-filled grids where no arrow blocks itself.
## Supports non-rectangular shapes via active cell masks.

const DIRECTIONS := ["U", "D", "L", "R"]
const DIR_VECS := {
	"U": Vector2i(0, -1),
	"D": Vector2i(0, 1),
	"L": Vector2i(-1, 0),
	"R": Vector2i(1, 0),
}
const NEIGHBORS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

var rng := RandomNumberGenerator.new()
var last_seed: int = 0

# Generation result
var generated_arrows: Array = []  # Array of {cells, dir, head, id}
var solution_order: Array = []    # Arrow IDs in solve order
var grid_cols: int = 0
var grid_rows: int = 0
var metrics: Dictionary = {}

# Shape: which cells are part of the puzzle
var _active_cells: Array[Vector2i] = []
var _active_set: Dictionary = {}  # Vector2i -> true for O(1) lookup

var _solve_iterations: int = 0
const SOLVE_BUDGET := 50000
var _hamiltonian_steps: int = 0
const HAMILTONIAN_BUDGET := 500000


# --- Main API ---

func generate(tier: Dictionary, seed_val: int = 0, shape: Array = []) -> bool:
	if seed_val == 0:
		seed_val = randi()
	last_seed = seed_val
	rng.seed = seed_val

	var cols: int = rng.randi_range(int(tier["grid_columns"][0]), int(tier["grid_columns"][1]))
	var rows: int = rng.randi_range(int(tier["grid_rows"][0]), int(tier["grid_rows"][1]))
	var count: int = rng.randi_range(int(tier["arrow_count"][0]), int(tier["arrow_count"][1]))
	return generate_filled(cols, rows, count, seed_val, shape)


func generate_filled(cols: int, rows: int, arrow_count: int,
		seed_val: int = 0, shape: Array = []) -> bool:
	if seed_val == 0:
		seed_val = randi()
	last_seed = seed_val
	grid_cols = cols
	grid_rows = rows

	# Build active cell set
	_active_cells.clear()
	_active_set.clear()
	if shape.is_empty():
		# Full rectangle
		for r in range(rows):
			for c in range(cols):
				var cell := Vector2i(c, r)
				_active_cells.append(cell)
				_active_set[cell] = true
	else:
		for sc in shape:
			var cell: Vector2i = sc as Vector2i
			_active_cells.append(cell)
			_active_set[cell] = true

	var total_cells := _active_cells.size()
	if arrow_count < 1 or total_cells < arrow_count * 2:
		return false

	for _attempt in range(50):
		rng.seed = seed_val + _attempt * 7919
		if _try_generate_filled(arrow_count):
			last_seed = seed_val + _attempt * 7919
			return true

	return false


# --- Generation ---

func _try_generate_filled(target_count: int) -> bool:
	generated_arrows.clear()
	solution_order.clear()

	# Step 1: Find Hamiltonian path through active cells
	var path := _find_hamiltonian_path()
	if path.is_empty():
		return false

	# Step 2: Try different splits and head/dir assignments
	for _split in range(5):
		var segments := _split_path(path, target_count)
		if segments.is_empty():
			continue

		# Place segments on grid
		var grid := _make_grid()
		for i in range(segments.size()):
			var seg: Array[Vector2i] = segments[i]
			for c in seg:
				grid[c.y][c.x] = i

		# Step 3: Try random head/dir assignments
		for _assign in range(30):
			generated_arrows.clear()
			var all_valid := true

			for i in range(segments.size()):
				var seg: Array[Vector2i] = segments[i]
				var hd := _pick_head_and_dir(seg)
				if hd.is_empty():
					all_valid = false
					break
				generated_arrows.append({
					"cells": seg,
					"dir": hd["dir"],
					"head": hd["head"],
					"id": i,
				})

			if not all_valid:
				continue

			# Step 4: Verify solvability
			var order := _find_solve_order()
			if not order.is_empty():
				solution_order = order
				_compute_metrics()
				return true

	return false


func _find_hamiltonian_path() -> Array[Vector2i]:
	var total := _active_cells.size()

	# Build valid starting cells (respect bipartite coloring for odd totals)
	var valid_starts: Array[Vector2i] = []
	if total % 2 == 1:
		# Odd total: must start from larger color class
		for c in _active_cells:
			if (c.x + c.y) % 2 == 0:
				valid_starts.append(c)
	else:
		valid_starts = _active_cells.duplicate()

	_shuffle(valid_starts)

	for i in range(mini(15, valid_starts.size())):
		_hamiltonian_steps = 0
		var visited: Dictionary = {}
		var path: Array[Vector2i] = []
		if _hamiltonian_dfs(valid_starts[i], visited, path, total):
			return path

	return []


func _hamiltonian_dfs(pos: Vector2i, visited: Dictionary,
		path: Array[Vector2i], total: int) -> bool:
	visited[pos] = true
	path.append(pos)

	if path.size() == total:
		return true

	_hamiltonian_steps += 1
	if _hamiltonian_steps > HAMILTONIAN_BUDGET:
		path.pop_back()
		visited.erase(pos)
		return false

	# Get unvisited active neighbors with Warnsdorf ordering
	var neighbor_data: Array = []
	for d in NEIGHBORS:
		var next: Vector2i = pos + Vector2i(d)
		if _active_set.has(next) and not visited.has(next):
			neighbor_data.append({
				"cell": next,
				"degree": _count_unvisited(next, visited),
				"rand": rng.randi(),
			})

	if neighbor_data.is_empty():
		path.pop_back()
		visited.erase(pos)
		return false

	# Sort by degree ascending, random tiebreak
	neighbor_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["degree"] != b["degree"]:
			return a["degree"] < b["degree"]
		return a["rand"] < b["rand"]
	)

	for data in neighbor_data:
		var next: Vector2i = data["cell"]
		if _hamiltonian_dfs(next, visited, path, total):
			return true

	path.pop_back()
	visited.erase(pos)
	return false


func _count_unvisited(pos: Vector2i, visited: Dictionary) -> int:
	var count := 0
	for d in NEIGHBORS:
		var next: Vector2i = pos + Vector2i(d)
		if _active_set.has(next) and not visited.has(next):
			count += 1
	return count


func _split_path(path: Array[Vector2i], count: int) -> Array:
	var total := path.size()
	var min_size := 3
	if min_size * count > total:
		min_size = 2
	if min_size * count > total:
		return []

	var sizes: Array[int] = []
	for _i in range(count):
		sizes.append(min_size)

	var remaining := total - min_size * count
	for _i in range(remaining):
		sizes[rng.randi() % count] += 1

	var segments: Array = []
	var pos := 0
	for i in range(count):
		var segment: Array[Vector2i] = []
		for _j in range(sizes[i]):
			segment.append(path[pos])
			pos += 1
		segments.append(segment)
	return segments


func _pick_head_and_dir(cells: Array[Vector2i]) -> Dictionary:
	# Direction must align with body flow at the head end
	var options: Array = []

	if cells.size() < 2:
		for dir in DIRECTIONS:
			options.append({"head": cells[0], "dir": dir})
	else:
		# Try last cell as head: dir = last - second_to_last
		var head_last := cells[-1]
		var dir_last := _vec_to_dir(head_last - cells[-2])
		if not dir_last.is_empty() and _check_no_self_blocking(cells, head_last, dir_last):
			options.append({"head": head_last, "dir": dir_last})

		# Try first cell as head: dir = first - second
		var head_first := cells[0]
		var dir_first := _vec_to_dir(head_first - cells[1])
		if not dir_first.is_empty() and _check_no_self_blocking(cells, head_first, dir_first):
			options.append({"head": head_first, "dir": dir_first})

	if options.is_empty():
		return {}
	return options[rng.randi() % options.size()]


func _vec_to_dir(v: Vector2i) -> String:
	for dir in DIRECTIONS:
		if DIR_VECS[dir] == v:
			return dir
	return ""


func _check_no_self_blocking(cells: Array[Vector2i], head: Vector2i,
		dir: String) -> bool:
	var dir_vec: Vector2i = DIR_VECS[dir]
	var cell_set: Dictionary = {}
	for c in cells:
		cell_set[c] = true

	var check := head + dir_vec
	while check.x >= 0 and check.x < grid_cols and check.y >= 0 and check.y < grid_rows:
		if not _active_set.has(check):  # Left the shape = clear
			return true
		if cell_set.has(check):
			return false
		check += dir_vec
	return true


# --- Solver ---

func _find_solve_order(budget: int = SOLVE_BUDGET) -> Array:
	var sim_grid := _make_grid()
	var arrow_lookup: Dictionary = {}
	for arrow in generated_arrows:
		var aid: int = arrow["id"]
		arrow_lookup[aid] = arrow
		for c in arrow["cells"]:
			var cell: Vector2i = c
			sim_grid[cell.y][cell.x] = aid

	var remaining_ids: Array[int] = []
	for arrow in generated_arrows:
		remaining_ids.append(int(arrow["id"]))

	_solve_iterations = 0
	return _solve_recursive(sim_grid, arrow_lookup, remaining_ids, [], budget)


func _solve_recursive(sim_grid: Array, arrow_lookup: Dictionary,
		remaining_ids: Array[int], order: Array, budget: int) -> Array:
	if remaining_ids.is_empty():
		return order

	_solve_iterations += 1
	if _solve_iterations > budget:
		return []

	var clearable: Array[int] = []
	for aid in remaining_ids:
		var arrow: Dictionary = arrow_lookup[aid]
		var head: Vector2i = arrow["head"]
		var dir_vec: Vector2i = DIR_VECS[arrow["dir"]]
		if _is_path_to_edge_clear(sim_grid, head, dir_vec, aid):
			clearable.append(aid)

	if clearable.is_empty():
		return []

	_shuffle(clearable)

	for aid in clearable:
		var arrow: Dictionary = arrow_lookup[aid]
		for c in arrow["cells"]:
			var cell: Vector2i = c
			sim_grid[cell.y][cell.x] = -1

		var new_remaining: Array[int] = []
		for rid in remaining_ids:
			if rid != aid:
				new_remaining.append(rid)

		var new_order := order.duplicate()
		new_order.append(aid)

		var result := _solve_recursive(sim_grid, arrow_lookup,
				new_remaining, new_order, budget)
		if not result.is_empty():
			return result

		for c in arrow["cells"]:
			var cell: Vector2i = c
			sim_grid[cell.y][cell.x] = aid

	return []


func _is_path_to_edge_clear(grid: Array, from: Vector2i,
		dir_vec: Vector2i, ignore_id: int) -> bool:
	var check := from + dir_vec
	while check.x >= 0 and check.x < grid_cols and check.y >= 0 and check.y < grid_rows:
		var val: int = grid[check.y][check.x]
		if val == -2:  # Inactive cell = shape boundary = clear
			return true
		if val != -1 and val != ignore_id:
			return false
		check += dir_vec
	return true


# --- Metrics ---

func _compute_metrics() -> void:
	var arrow_lookup: Dictionary = {}
	for arrow in generated_arrows:
		arrow_lookup[int(arrow["id"])] = arrow

	var sim_grid := _make_grid()
	for arrow in generated_arrows:
		var aid: int = arrow["id"]
		for c in arrow["cells"]:
			var cell: Vector2i = c
			sim_grid[cell.y][cell.x] = aid

	var choice_widths: Array[int] = []
	var remaining_ids: Array[int] = []
	for arrow in generated_arrows:
		remaining_ids.append(int(arrow["id"]))

	for solve_id in solution_order:
		var clearable := 0
		for aid in remaining_ids:
			var a: Dictionary = arrow_lookup[aid]
			var h: Vector2i = a["head"]
			var dv: Vector2i = DIR_VECS[a["dir"]]
			if _is_path_to_edge_clear(sim_grid, h, dv, aid):
				clearable += 1
		choice_widths.append(clearable)

		var arrow: Dictionary = arrow_lookup[int(solve_id)]
		var aid: int = arrow["id"]
		for c in arrow["cells"]:
			var cell: Vector2i = c
			if sim_grid[cell.y][cell.x] == aid:
				sim_grid[cell.y][cell.x] = -1
		remaining_ids.erase(int(solve_id))

	var sum_width: float = 0.0
	var max_width: int = 0
	for w in choice_widths:
		sum_width += w
		max_width = maxi(max_width, w)

	var avg_width: float = sum_width / maxf(1.0, float(choice_widths.size()))

	var dirs_used: Dictionary = {}
	for arrow in generated_arrows:
		dirs_used[arrow["dir"]] = true

	metrics = {
		"avg_choice_width": snappedf(avg_width, 0.01),
		"max_choice_width": max_width,
		"blocking_depth": solution_order.size(),
		"direction_count": dirs_used.size(),
		"arrow_count": generated_arrows.size(),
		"active_cells": _active_cells.size(),
		"cell_coverage": 1.0,
		"seed": last_seed,
	}


# --- Output ---

func to_level_data(level_name: String) -> Dictionary:
	var arrow_defs: Array = []
	for arrow in generated_arrows:
		var cells: Array[Vector2i] = []
		for c in arrow["cells"]:
			cells.append(c as Vector2i)
		var head: Vector2i = arrow["head"]

		# Ensure tail-to-head order (head must be last cell)
		if cells.size() > 1 and cells[0] == head:
			var reversed: Array[Vector2i] = []
			for i in range(cells.size() - 1, -1, -1):
				reversed.append(cells[i])
			cells = reversed

		var waypoints := _cells_to_waypoints(cells)
		arrow_defs.append({
			"path": waypoints,
			"dir": arrow["dir"],
		})

	var result: Dictionary = {
		"name": level_name,
		"columns": grid_cols,
		"rows": grid_rows,
		"arrows": arrow_defs,
	}

	# Include shape only for non-rectangular levels
	if _active_cells.size() < grid_cols * grid_rows:
		var shape: Array = []
		for c in _active_cells:
			shape.append([c.x, c.y])
		result["shape"] = shape

	return result


func _cells_to_waypoints(cells: Array[Vector2i]) -> Array:
	if cells.size() <= 2:
		var wps: Array = []
		for c in cells:
			wps.append([c.x, c.y])
		return wps

	var waypoints: Array = [[cells[0].x, cells[0].y]]
	for i in range(1, cells.size() - 1):
		var prev_dir := cells[i] - cells[i - 1]
		var next_dir := cells[i + 1] - cells[i]
		if prev_dir != next_dir:
			waypoints.append([cells[i].x, cells[i].y])
	waypoints.append([cells[-1].x, cells[-1].y])
	return waypoints


func get_solution_display_order() -> Dictionary:
	var result: Dictionary = {}
	for i in range(solution_order.size()):
		result[solution_order[i]] = i + 1
	return result


# --- Grid helpers ---

func _make_grid() -> Array:
	var grid: Array = []
	for _r in range(grid_rows):
		var row: Array = []
		row.resize(grid_cols)
		row.fill(-2)  # Inactive by default
		grid.append(row)
	# Mark active cells as empty
	for c in _active_cells:
		grid[c.y][c.x] = -1
	return grid


# --- Utilities ---

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
