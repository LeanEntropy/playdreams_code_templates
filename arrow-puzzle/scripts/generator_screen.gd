extends Node2D

## Level generator tool UI. Run this scene standalone (F6) to generate levels.
## Supports mask-based shape editing, level browsing, and level management.

const LEVELS_PATH := "res://data/levels.json"

var _generator: LevelGenerator
var _rules: Dictionary = {}
var _current_tier_index: int = 0
var _is_play_testing: bool = false
var _showing_solution: bool = false
var _solution_labels: Array[Label] = []
var _has_valid_level: bool = false

# Mask / shape state
var _mask_image: Image = null
var _mask_texture: ImageTexture = null
var _shape_cells: Array[Vector2i] = []
var _shape_cols: int = 0
var _shape_rows: int = 0
var _shape_resolution: int = 8  # Max dimension in cells
var _editing_shape: bool = false

# Browse state
var _levels_data: Array = []       # In-memory copy of levels.json["levels"]
var _browse_index: int = -1        # -1 = not browsing, 0+ = viewing existing level
var _board_source: String = ""     # "generated" or "browsed"
var _pending_generated: Dictionary = {}  # Buffered generated level data for save-to-slot

@onready var _game_board: Node2D = $GameBoard
@onready var _info_label: Label = %InfoLabel
@onready var _tier_selector: OptionButton = %TierSelector
@onready var _seed_input: LineEdit = %SeedInput
@onready var _cols_input: LineEdit = %ColsInput
@onready var _rows_input: LineEdit = %RowsInput
@onready var _arrows_input: LineEdit = %ArrowsInput
@onready var _generate_btn: Button = %GenerateButton
@onready var _approve_btn: Button = %ApproveButton
@onready var _reject_btn: Button = %RejectButton
@onready var _play_test_btn: Button = %PlayTestButton
@onready var _stop_test_btn: Button = %StopTestButton
@onready var _show_solution_btn: Button = %ShowSolutionBtn
@onready var _load_mask_btn: Button = %LoadMaskBtn
@onready var _clear_mask_btn: Button = %ClearMaskBtn
@onready var _res_down_btn: Button = %ResDownBtn
@onready var _res_up_btn: Button = %ResUpBtn
@onready var _res_label: Label = %ResLabel
@onready var _solution_overlay: CanvasLayer = $SolutionOverlay

# Browse UI refs
@onready var _prev_level_btn: Button = %PrevLevelBtn
@onready var _next_level_btn: Button = %NextLevelBtn
@onready var _level_index_label: Label = %LevelIndexLabel
@onready var _insert_before_btn: Button = %InsertBeforeBtn
@onready var _duplicate_btn: Button = %DuplicateBtn
@onready var _delete_level_btn: Button = %DeleteLevelBtn
@onready var _move_up_btn: Button = %MoveUpBtn
@onready var _move_down_btn: Button = %MoveDownBtn


func _ready() -> void:
	_generator = LevelGenerator.new()
	_load_rules()
	_load_levels_from_disk()
	_setup_tier_selector()
	_connect_signals()

	# Disable game board input initially
	_game_board.test_mode = true
	_game_board.visible = false

	# Set initial placeholders
	_on_tier_selected(0)
	_update_mask_ui()
	_update_browse_ui()

	# Auto-generate first level
	_on_generate_pressed()


func _load_rules() -> void:
	var path := "res://data/generator_rules.json"
	if not FileAccess.file_exists(path):
		push_error("generator_rules.json not found")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open generator_rules.json")
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("Failed to parse generator_rules.json: %s" % json.get_error_message())
		return
	_rules = json.data


func _setup_tier_selector() -> void:
	_tier_selector.clear()
	var tiers: Array = _rules.get("tiers", [])
	for tier in tiers:
		_tier_selector.add_item(tier["name"])
	if _tier_selector.item_count > 0:
		_tier_selector.selected = 0


func _connect_signals() -> void:
	_generate_btn.pressed.connect(_on_generate_pressed)
	_approve_btn.pressed.connect(_on_save_pressed)
	_reject_btn.pressed.connect(_on_reject_pressed)
	_play_test_btn.pressed.connect(_on_play_test_pressed)
	_stop_test_btn.pressed.connect(_on_stop_test_pressed)
	_show_solution_btn.pressed.connect(_on_show_solution_pressed)
	_tier_selector.item_selected.connect(_on_tier_selected)
	_game_board.all_arrows_cleared.connect(_on_test_cleared)
	_load_mask_btn.pressed.connect(_on_load_mask_pressed)
	_clear_mask_btn.pressed.connect(_on_clear_mask_pressed)
	_res_down_btn.pressed.connect(_on_res_down)
	_res_up_btn.pressed.connect(_on_res_up)

	# Browse signals
	_prev_level_btn.pressed.connect(_on_prev_pressed)
	_next_level_btn.pressed.connect(_on_next_pressed)
	_insert_before_btn.pressed.connect(_on_insert_before_pressed)
	_duplicate_btn.pressed.connect(_on_duplicate_pressed)
	_delete_level_btn.pressed.connect(_on_delete_pressed)
	_move_up_btn.pressed.connect(_on_move_up_pressed)
	_move_down_btn.pressed.connect(_on_move_down_pressed)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_LEFT:
			if not _prev_level_btn.disabled:
				_on_prev_pressed()
				get_viewport().set_input_as_handled()
		KEY_RIGHT:
			if not _next_level_btn.disabled:
				_on_next_pressed()
				get_viewport().set_input_as_handled()
		KEY_SPACE:
			if not _generate_btn.disabled:
				_on_generate_pressed()
				get_viewport().set_input_as_handled()
		KEY_ENTER:
			if not _approve_btn.disabled:
				_on_save_pressed()
				get_viewport().set_input_as_handled()
		KEY_DELETE:
			if not _delete_level_btn.disabled:
				_on_delete_pressed()
				get_viewport().set_input_as_handled()
		KEY_P:
			if _is_play_testing:
				_on_stop_test_pressed()
			elif not _play_test_btn.disabled:
				_on_play_test_pressed()
			get_viewport().set_input_as_handled()
		KEY_S:
			if not _show_solution_btn.disabled:
				_on_show_solution_pressed()
				get_viewport().set_input_as_handled()


func _on_tier_selected(index: int) -> void:
	_current_tier_index = index
	var tiers: Array = _rules.get("tiers", [])
	if index < tiers.size():
		var tier: Dictionary = tiers[index]
		_cols_input.placeholder_text = "%d-%d" % [int(tier["grid_columns"][0]), int(tier["grid_columns"][1])]
		_rows_input.placeholder_text = "%d-%d" % [int(tier["grid_rows"][0]), int(tier["grid_rows"][1])]
		_arrows_input.placeholder_text = "%d-%d" % [int(tier["arrow_count"][0]), int(tier["arrow_count"][1])]


# --- Centralized Level I/O ---

func _load_levels_from_disk() -> void:
	_levels_data = []
	if not FileAccess.file_exists(LEVELS_PATH):
		return
	var file := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if data is Dictionary and data.has("levels"):
		_levels_data = data["levels"]


func _flush_levels_to_disk() -> void:
	# Create backup first
	if FileAccess.file_exists(LEVELS_PATH):
		var src := FileAccess.open(LEVELS_PATH, FileAccess.READ)
		if src:
			var backup := FileAccess.open(LEVELS_PATH + ".bak", FileAccess.WRITE)
			if backup:
				backup.store_string(src.get_as_text())

	var file := FileAccess.open(LEVELS_PATH, FileAccess.WRITE)
	if not file:
		push_error("Cannot write to levels.json")
		return
	file.store_string(JSON.stringify({"levels": _levels_data}, "  "))


# --- Browse Navigation ---

func _on_prev_pressed() -> void:
	if _levels_data.is_empty():
		return
	if _board_source == "generated" and _has_valid_level:
		_confirm_discard_generated(func() -> void: _navigate_prev())
		return
	_navigate_prev()


func _navigate_prev() -> void:
	if _browse_index < 0:
		# Entering browse mode from generated level
		_browse_index = _levels_data.size() - 1
	elif _browse_index > 0:
		_browse_index -= 1
	else:
		return
	_load_browsed_level()


func _on_next_pressed() -> void:
	if _levels_data.is_empty():
		return
	if _board_source == "generated" and _has_valid_level:
		_confirm_discard_generated(func() -> void: _navigate_next())
		return
	_navigate_next()


func _navigate_next() -> void:
	if _browse_index < 0:
		# Entering browse mode from generated level
		_browse_index = 0
	elif _browse_index < _levels_data.size() - 1:
		_browse_index += 1
	else:
		return
	_load_browsed_level()


func _confirm_discard_generated(on_confirmed: Callable) -> void:
	# Generated level is already buffered in _pending_generated — just navigate
	_has_valid_level = false
	_board_source = ""
	on_confirmed.call()


func _load_browsed_level() -> void:
	_stop_play_test()
	_clear_solution_overlay()

	var level_data: Dictionary = _levels_data[_browse_index]
	_game_board.visible = true
	_game_board.test_mode = true
	_game_board.load_level(level_data)
	_game_board.set_process_unhandled_input(false)

	_board_source = "browsed"
	_has_valid_level = true

	var level_name: String = level_data.get("name", "Untitled")
	var cols: int = int(level_data.get("columns", 0))
	var rows: int = int(level_data.get("rows", 0))
	var arrow_count: int = (level_data.get("arrows", []) as Array).size()
	var pending_hint: String = " [generated level ready to save]" if not _pending_generated.is_empty() else ""
	_info_label.text = "Browsing: \"%s\" | %dx%d | %d arrows%s" % [level_name, cols, rows, arrow_count, pending_hint]

	_update_browse_ui()


func _update_browse_ui() -> void:
	var count := _levels_data.size()
	var browsing := _browse_index >= 0

	if count == 0:
		_level_index_label.text = "No levels"
		_prev_level_btn.disabled = true
		_next_level_btn.disabled = true
	elif browsing:
		var level_name: String = _levels_data[_browse_index].get("name", "Untitled")
		_level_index_label.text = "Level %d / %d - \"%s\"" % [_browse_index + 1, count, level_name]
		_prev_level_btn.disabled = _browse_index <= 0
		_next_level_btn.disabled = _browse_index >= count - 1
	else:
		_level_index_label.text = "%d levels (generated)" % count
		_prev_level_btn.disabled = count == 0
		_next_level_btn.disabled = count == 0

	# Browse action buttons
	var has_data_to_save: bool = _has_valid_level or not _pending_generated.is_empty()
	_insert_before_btn.disabled = not browsing or not has_data_to_save
	_duplicate_btn.disabled = not browsing
	_delete_level_btn.disabled = not browsing
	_move_up_btn.disabled = not browsing or _browse_index <= 0
	_move_down_btn.disabled = not browsing or _browse_index >= count - 1

	# Save enabled when there's something to save (generated or pending)
	_approve_btn.disabled = not has_data_to_save

	# Show Solution only works for generated levels (generator state must match)
	_show_solution_btn.disabled = _board_source == "browsed"


# --- Browse Actions ---

func _on_insert_before_pressed() -> void:
	if _browse_index < 0:
		return
	var has_pending: bool = not _pending_generated.is_empty()
	if not has_pending and _board_source == "browsed":
		_info_label.text = "Nothing to insert — generate a level first"
		return
	var level_name: String = _levels_data[_browse_index].get("name", "Untitled")
	var source_desc: String = "generated level" if has_pending else "current board"
	var dialog := ConfirmationDialog.new()
	dialog.title = "Insert Before"
	dialog.dialog_text = "Insert %s before \"%s\" (Level %d)?" % [source_desc, level_name, _browse_index + 1]
	dialog.confirmed.connect(func() -> void:
		var new_data := _get_board_level_data("Inserted Level")
		_levels_data.insert(_browse_index, new_data)
		_pending_generated = {}
		_flush_levels_to_disk()
		_load_browsed_level()
		_info_label.text = "Inserted before level %d" % (_browse_index + 1)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _on_duplicate_pressed() -> void:
	if _browse_index < 0:
		return
	var original: Dictionary = _levels_data[_browse_index]
	var copy: Dictionary = original.duplicate(true)
	copy["name"] = str(original.get("name", "Untitled")) + " (copy)"
	_levels_data.append(copy)
	_flush_levels_to_disk()
	_browse_index = _levels_data.size() - 1
	_load_browsed_level()
	_info_label.text = "Duplicated to end as level %d" % (_browse_index + 1)


func _on_delete_pressed() -> void:
	if _browse_index < 0:
		return
	var level_name: String = _levels_data[_browse_index].get("name", "Untitled")
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Level"
	dialog.dialog_text = "Delete \"%s\" (Level %d)?" % [level_name, _browse_index + 1]
	dialog.confirmed.connect(func() -> void:
		_stop_play_test()
		_levels_data.remove_at(_browse_index)
		_flush_levels_to_disk()
		if _levels_data.is_empty():
			_browse_index = -1
			_board_source = ""
			_has_valid_level = false
			_game_board.visible = false
			_info_label.text = "All levels deleted."
		else:
			_browse_index = clampi(_browse_index, 0, _levels_data.size() - 1)
			_load_browsed_level()
		_update_browse_ui()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _on_move_up_pressed() -> void:
	if _browse_index <= 0:
		return
	var tmp: Dictionary = _levels_data[_browse_index]
	_levels_data[_browse_index] = _levels_data[_browse_index - 1]
	_levels_data[_browse_index - 1] = tmp
	_browse_index -= 1
	_flush_levels_to_disk()
	_info_label.text = "Moved to position %d" % (_browse_index + 1)
	_update_browse_ui()


func _on_move_down_pressed() -> void:
	if _browse_index < 0 or _browse_index >= _levels_data.size() - 1:
		return
	var tmp: Dictionary = _levels_data[_browse_index]
	_levels_data[_browse_index] = _levels_data[_browse_index + 1]
	_levels_data[_browse_index + 1] = tmp
	_browse_index += 1
	_flush_levels_to_disk()
	_info_label.text = "Moved to position %d" % (_browse_index + 1)
	_update_browse_ui()


func _get_board_level_data(fallback_name: String) -> Dictionary:
	if _board_source == "generated" and _has_valid_level:
		return _generator.to_level_data(fallback_name)
	# Use buffered generated level if available (user generated, then navigated to a slot)
	if not _pending_generated.is_empty():
		var data: Dictionary = _pending_generated.duplicate(true)
		data["name"] = fallback_name
		return data
	if _board_source == "browsed" and _browse_index >= 0:
		return _levels_data[_browse_index].duplicate(true)
	return {}


# --- Mask / Shape Editing ---

func _on_load_mask_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.jpg ; JPEG Images", "*.bmp ; BMP Images"])
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.size = Vector2i(600, 400)
	dialog.file_selected.connect(_on_mask_file_selected)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _on_mask_file_selected(path: String) -> void:
	# Remove the dialog
	for child in get_children():
		if child is FileDialog:
			child.queue_free()

	_mask_image = Image.load_from_file(path)
	if _mask_image == null:
		_info_label.text = "Failed to load image: %s" % path
		return

	_mask_texture = ImageTexture.create_from_image(_mask_image)
	_editing_shape = true
	_recalculate_shape()
	_show_shape_preview()
	_update_mask_ui()


func _on_clear_mask_pressed() -> void:
	_mask_image = null
	_mask_texture = null
	_shape_cells.clear()
	_shape_cols = 0
	_shape_rows = 0
	_editing_shape = false
	_game_board.clear_shape_preview()
	_game_board.visible = false
	_update_mask_ui()
	_info_label.text = "Mask cleared. Using rectangular grid."


func _on_res_down() -> void:
	_shape_resolution = maxi(3, _shape_resolution - 1)
	_recalculate_shape()
	_show_shape_preview()


func _on_res_up() -> void:
	_shape_resolution = mini(20, _shape_resolution + 1)
	_recalculate_shape()
	_show_shape_preview()


func _recalculate_shape() -> void:
	if _mask_image == null:
		return

	var img_w := _mask_image.get_width()
	var img_h := _mask_image.get_height()
	var aspect := float(img_w) / float(img_h)

	# Determine grid dimensions from resolution (max dimension)
	if aspect >= 1.0:
		_shape_cols = _shape_resolution
		_shape_rows = maxi(2, roundi(float(_shape_cols) / aspect))
	else:
		_shape_rows = _shape_resolution
		_shape_cols = maxi(2, roundi(float(_shape_rows) * aspect))

	# Sample the image to determine active cells
	_shape_cells.clear()
	for r in range(_shape_rows):
		for c in range(_shape_cols):
			if _sample_cell_active(c, r):
				_shape_cells.append(Vector2i(c, r))

	_cols_input.text = str(_shape_cols)
	_rows_input.text = str(_shape_rows)
	_res_label.text = str(_shape_resolution)
	_info_label.text = "Shape: %dx%d grid, %d active cells. Adjust resolution or Generate." % [
		_shape_cols, _shape_rows, _shape_cells.size()]


func _sample_cell_active(col: int, row: int) -> bool:
	## Sample multiple points in the cell area to determine if it overlaps the mask.
	var img_w := _mask_image.get_width()
	var img_h := _mask_image.get_height()
	var cell_w := float(img_w) / float(_shape_cols)
	var cell_h := float(img_h) / float(_shape_rows)

	# Sample 4 points (center + offset) for robustness
	var samples := [Vector2(0.5, 0.5), Vector2(0.3, 0.3), Vector2(0.7, 0.7), Vector2(0.5, 0.25)]
	var hits := 0
	for s in samples:
		var px := int((float(col) + s.x) * cell_w)
		var py := int((float(row) + s.y) * cell_h)
		px = clampi(px, 0, img_w - 1)
		py = clampi(py, 0, img_h - 1)
		var pixel := _mask_image.get_pixel(px, py)
		# Active if not transparent and not white
		if pixel.a > 0.3 and pixel.get_luminance() < 0.85:
			hits += 1

	return hits >= 2  # Majority of samples hit the shape


func _show_shape_preview() -> void:
	_game_board.visible = true
	_game_board.show_shape_preview(_shape_cols, _shape_rows, _shape_cells)


func _update_mask_ui() -> void:
	var has_mask := _mask_image != null
	_clear_mask_btn.disabled = not has_mask
	_res_down_btn.disabled = not has_mask
	_res_up_btn.disabled = not has_mask
	if has_mask:
		_res_label.text = str(_shape_resolution)
	else:
		_res_label.text = "-"


# --- Generation ---

func _on_generate_pressed() -> void:
	_stop_play_test()
	_clear_solution_overlay()
	_editing_shape = false
	_browse_index = -1
	_board_source = "generated"

	var tiers: Array = _rules.get("tiers", [])
	if _current_tier_index >= tiers.size():
		_info_label.text = "No tiers defined"
		return

	var tier: Dictionary = tiers[_current_tier_index]

	# Use user seed or random
	var seed_val: int = 0
	var seed_text := _seed_input.text.strip_edges()
	if not seed_text.is_empty():
		seed_val = seed_text.hash()

	# Read grid size overrides (fall back to tier range)
	var cols := _parse_int_or_range(_cols_input.text, tier["grid_columns"])
	var rows := _parse_int_or_range(_rows_input.text, tier["grid_rows"])
	var count := _parse_int_or_range(_arrows_input.text, tier["arrow_count"])

	# Build shape array for generator
	var shape: Array = []
	if not _shape_cells.is_empty():
		cols = _shape_cols
		rows = _shape_rows
		shape = _shape_cells.duplicate()
		# Clamp arrow count for the shape size
		var max_arrows := _shape_cells.size() / 2
		count = mini(count, maxi(2, max_arrows))

	var success := _generator.generate_filled(cols, rows, count, seed_val, shape)

	if success:
		_has_valid_level = true
		_pending_generated = _generator.to_level_data("Generated Level")
		_display_generated_level()
		_update_info()
		_seed_input.text = str(_generator.last_seed)
		_approve_btn.disabled = false
	else:
		_has_valid_level = false
		var cell_count := _shape_cells.size() if not _shape_cells.is_empty() else cols * rows
		_info_label.text = "Generation failed (%dx%d, %d cells, %d arrows). Try again." % [
			cols, rows, cell_count, count]
		_game_board.visible = false
		_approve_btn.disabled = true

	_update_browse_ui()


func _parse_int_or_range(text: String, range_arr: Array) -> int:
	var stripped := text.strip_edges()
	if stripped.is_valid_int():
		return int(stripped)
	return randi_range(int(range_arr[0]), int(range_arr[1]))


func _display_generated_level() -> void:
	_game_board.visible = true
	_game_board.test_mode = true
	_game_board.load_level(_pending_generated)
	_game_board.set_process_unhandled_input(false)


func _update_info() -> void:
	var m: Dictionary = _generator.metrics
	var tier_name: String = ""
	var tiers: Array = _rules.get("tiers", [])
	if _current_tier_index < tiers.size():
		tier_name = tiers[_current_tier_index]["name"]

	var cells_info := ""
	var active: int = int(m.get("active_cells", 0))
	var total := _generator.grid_cols * _generator.grid_rows
	if active < total:
		cells_info = " (%d cells)" % active

	_info_label.text = "%s | %dx%d%s | %d arrows | Depth: %d | Width: %.1f (max %d) | Dirs: %d" % [
		tier_name,
		_generator.grid_cols,
		_generator.grid_rows,
		cells_info,
		int(m.get("arrow_count", 0)),
		int(m.get("blocking_depth", 0)),
		float(m.get("avg_choice_width", 0)),
		int(m.get("max_choice_width", 0)),
		int(m.get("direction_count", 0)),
	]


func _on_save_pressed() -> void:
	var browsing: bool = _browse_index >= 0
	var dialog := AcceptDialog.new()
	dialog.title = "Save Level"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Level name input
	var name_label := Label.new()
	name_label.text = "Level name:"
	vbox.add_child(name_label)

	var name_input := LineEdit.new()
	name_input.text = "Level %d" % (_levels_data.size() + 1)
	if browsing:
		name_input.text = str(_levels_data[_browse_index].get("name", "Level"))
	name_input.select_all()
	vbox.add_child(name_input)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# Option 1: Append
	var append_btn := Button.new()
	append_btn.text = "Append as Level %d" % (_levels_data.size() + 1)
	append_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(append_btn)

	# Option 2: Replace current (only if browsing)
	var replace_btn: Button = null
	if browsing:
		var cur_name: String = _levels_data[_browse_index].get("name", "Untitled")
		replace_btn = Button.new()
		replace_btn.text = "Replace Level %d (\"%s\")" % [_browse_index + 1, cur_name]
		replace_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(replace_btn)

	dialog.add_child(vbox)

	# Hide the default OK button — we use our own buttons
	dialog.get_ok_button().visible = false

	append_btn.pressed.connect(func() -> void:
		var level_name := name_input.text.strip_edges()
		if level_name.is_empty():
			level_name = "Level %d" % (_levels_data.size() + 1)
		dialog.queue_free()
		_append_level(level_name)
	)

	if replace_btn:
		replace_btn.pressed.connect(func() -> void:
			var level_name := name_input.text.strip_edges()
			if level_name.is_empty():
				level_name = str(_levels_data[_browse_index].get("name", "Level"))
			dialog.queue_free()
			_replace_level(level_name)
		)

	dialog.canceled.connect(dialog.queue_free)

	add_child(dialog)
	dialog.popup_centered(Vector2i(350, 200))


func _append_level(level_name: String) -> void:
	var level_data := _get_board_level_data(level_name)
	level_data["name"] = level_name
	_levels_data.append(level_data)
	_pending_generated = {}
	_flush_levels_to_disk()

	_info_label.text = "Appended \"%s\" as level %d!" % [level_name, _levels_data.size()]
	_update_browse_ui()

	# Auto-generate next
	await get_tree().create_timer(1.5).timeout
	_on_generate_pressed()


func _replace_level(level_name: String) -> void:
	if _browse_index < 0:
		return
	var level_data := _get_board_level_data(level_name)
	level_data["name"] = level_name
	_levels_data[_browse_index] = level_data
	_pending_generated = {}
	_flush_levels_to_disk()
	_load_browsed_level()
	_info_label.text = "Replaced level %d: \"%s\"" % [_browse_index + 1, level_name]


func _on_reject_pressed() -> void:
	_on_generate_pressed()


func _on_play_test_pressed() -> void:
	if _is_play_testing or not _has_valid_level:
		return
	_is_play_testing = true

	# If browsing, reload the level fresh for play-testing
	if _board_source == "browsed" and _browse_index >= 0:
		_game_board.load_level(_levels_data[_browse_index])

	_game_board.set_process_unhandled_input(true)
	_play_test_btn.disabled = true
	_stop_test_btn.disabled = false
	_generate_btn.disabled = true
	_approve_btn.disabled = true
	# Disable browse navigation during play-test
	_prev_level_btn.disabled = true
	_next_level_btn.disabled = true
	_insert_before_btn.disabled = true
	_duplicate_btn.disabled = true
	_delete_level_btn.disabled = true
	_move_up_btn.disabled = true
	_move_down_btn.disabled = true
	_info_label.text = "Play testing... Tap arrows to solve!"


func _on_stop_test_pressed() -> void:
	_stop_play_test()
	if _board_source == "browsed" and _browse_index >= 0:
		_load_browsed_level()
	elif _board_source == "generated" and _has_valid_level:
		_display_generated_level()
		_update_info()
	else:
		# Unknown or empty source - just clear the board
		_game_board.visible = false
		_info_label.text = "No level loaded. Generate or browse."


func _stop_play_test() -> void:
	_is_play_testing = false
	_game_board.set_process_unhandled_input(false)
	_play_test_btn.disabled = false
	_stop_test_btn.disabled = true
	_generate_btn.disabled = false
	_approve_btn.disabled = not _has_valid_level
	_update_browse_ui()


func _on_test_cleared() -> void:
	_info_label.text = "Level cleared! Append or generate another."
	_stop_play_test()


func _on_show_solution_pressed() -> void:
	if _showing_solution:
		_clear_solution_overlay()
		_show_solution_btn.text = "Show Solution"
		_showing_solution = false
	else:
		_draw_solution_overlay()
		_show_solution_btn.text = "Hide Solution"
		_showing_solution = true


func _draw_solution_overlay() -> void:
	_clear_solution_overlay()

	var order := _generator.get_solution_display_order()
	var cell_size: float = _game_board.cell_size
	var origin: Vector2 = _game_board.grid_origin

	for arrow in _generator.generated_arrows:
		var arrow_id: int = arrow["id"]
		if not order.has(arrow_id):
			continue

		var step: int = order[arrow_id]
		var head: Vector2i = arrow["head"]

		var label := Label.new()
		label.text = str(step)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", int(cell_size * 0.35))
		label.add_theme_color_override("font_color", Config.COLOR_ACCENT)

		var pos := origin + Vector2(head) * cell_size
		label.position = pos
		label.size = Vector2(cell_size, cell_size)

		_solution_overlay.add_child(label)
		_solution_labels.append(label)


func _clear_solution_overlay() -> void:
	for label in _solution_labels:
		if is_instance_valid(label):
			label.queue_free()
	_solution_labels.clear()
	_showing_solution = false
	_show_solution_btn.text = "Show Solution"
