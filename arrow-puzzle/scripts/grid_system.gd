class_name GridSystem
extends RefCounted

var columns: int
var rows: int
var grid: Array  # 2D array of int (arrow_id, -1=empty, -2=inactive)
var arrow_count: int = 0


func _init(cols: int, r: int, active_cells: Array = []) -> void:
	columns = cols
	rows = r
	grid = []

	if active_cells.is_empty():
		# All cells active (rectangular grid)
		for row_idx in range(rows):
			var row_arr: Array = []
			row_arr.resize(cols)
			row_arr.fill(-1)
			grid.append(row_arr)
	else:
		# Non-rectangular shape: inactive by default
		for row_idx in range(rows):
			var row_arr: Array = []
			row_arr.resize(cols)
			row_arr.fill(-2)
			grid.append(row_arr)
		for cell in active_cells:
			var c: Vector2i = cell as Vector2i
			if c.y >= 0 and c.y < rows and c.x >= 0 and c.x < cols:
				grid[c.y][c.x] = -1


func place_arrow(id: int, cells: Array) -> void:
	for cell in cells:
		var c: Vector2i = cell as Vector2i
		grid[c.y][c.x] = id
	arrow_count += 1


func remove_arrow(id: int, cells: Array) -> void:
	for cell in cells:
		var c: Vector2i = cell as Vector2i
		if grid[c.y][c.x] == id:
			grid[c.y][c.x] = -1
	arrow_count -= 1


func is_path_clear(arrow_id: int, head_cell: Vector2i, direction: Vector2i) -> bool:
	var check := head_cell + direction
	while check.x >= 0 and check.x < columns and check.y >= 0 and check.y < rows:
		var cell_val: int = grid[check.y][check.x]
		if cell_val == -2:  # Inactive cell = shape boundary = clear
			return true
		if cell_val != -1 and cell_val != arrow_id:
			return false
		check += direction
	return true


func find_blocking_cell(arrow_id: int, head_cell: Vector2i, direction: Vector2i) -> Vector2i:
	var check := head_cell + direction
	while check.x >= 0 and check.x < columns and check.y >= 0 and check.y < rows:
		var cell_val: int = grid[check.y][check.x]
		if cell_val == -2:  # Shape boundary
			return Vector2i(-1, -1)
		if cell_val != -1 and cell_val != arrow_id:
			return check
		check += direction
	return Vector2i(-1, -1)


func get_arrow_at(col: int, row: int) -> int:
	if col < 0 or col >= columns or row < 0 or row >= rows:
		return -1
	return grid[row][col]


func is_cleared() -> bool:
	return arrow_count <= 0
