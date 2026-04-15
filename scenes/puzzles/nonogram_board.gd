class_name NonogramBoard
extends Control

signal solved(wrong_cells: int)
signal failed(wrong_cells: int)

const CELL_EMPTY := 0
const CELL_FILLED := 1
const CELL_MARKED := -1

const CELL_SIZE := 36
const CELL_GAP := 2

@export var cell_colors := {
	CELL_EMPTY: Color(0.15, 0.15, 0.18),
	CELL_FILLED: Color(0.9, 0.9, 0.95),
	CELL_MARKED: Color(0.4, 0.2, 0.2),
}

var puzzle: NonogramPuzzle
var _state: Array = []
var _cell_buttons: Array = []
var _grid: GridContainer
var _row_clues_box: VBoxContainer
var _col_clues_box: HBoxContainer
var _status: Label
var _submit_btn: Button
var _selected_color: int = 1  # used only for color puzzles

func load_puzzle(p: NonogramPuzzle, starting_hints: int = 0) -> void:
	puzzle = p
	_state = []
	for y in p.height:
		var row: Array = []
		row.resize(p.width)
		row.fill(CELL_EMPTY)
		_state.append(row)
	_apply_hints(starting_hints)
	_build_ui()

func _apply_hints(n: int) -> void:
	if n <= 0:
		return
	var filled_cells: Array = []
	for y in puzzle.height:
		for x in puzzle.width:
			var v = puzzle.solution[y][x]
			if (typeof(v) == TYPE_BOOL and v) or (typeof(v) != TYPE_BOOL and int(v) != 0):
				filled_cells.append(Vector2i(x, y))
	filled_cells.shuffle()
	for i in min(n, filled_cells.size()):
		var c: Vector2i = filled_cells[i]
		var sol = puzzle.solution[c.y][c.x]
		_state[c.y][c.x] = CELL_FILLED if typeof(sol) == TYPE_BOOL else int(sol)

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	_cell_buttons = []

	var max_row_clues := 1
	for rc in puzzle.row_clues:
		max_row_clues = max(max_row_clues, rc.size())
	var max_col_clues := 1
	for cc in puzzle.col_clues:
		max_col_clues = max(max_col_clues, cc.size())
	if puzzle.is_color:
		max_row_clues = max(1, max_row_clues + 1)
	var row_clue_width: int = max_row_clues * 20 + 8
	var col_clue_height: int = max_col_clues * 20 + 8

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 0)
	root.add_child(top_row)

	var corner := Control.new()
	corner.custom_minimum_size = Vector2(row_clue_width, col_clue_height)
	top_row.add_child(corner)

	_col_clues_box = HBoxContainer.new()
	_col_clues_box.add_theme_constant_override("separation", CELL_GAP)
	top_row.add_child(_col_clues_box)
	for x in puzzle.width:
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(CELL_SIZE, col_clue_height)
		v.alignment = BoxContainer.ALIGNMENT_END
		v.add_theme_constant_override("separation", 0)
		for entry in puzzle.col_clues[x]:
			v.add_child(_clue_label(entry, true))
		_col_clues_box.add_child(v)

	var mid_row := HBoxContainer.new()
	mid_row.add_theme_constant_override("separation", 0)
	root.add_child(mid_row)

	_row_clues_box = VBoxContainer.new()
	_row_clues_box.add_theme_constant_override("separation", CELL_GAP)
	mid_row.add_child(_row_clues_box)
	for y in puzzle.height:
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(row_clue_width, CELL_SIZE)
		h.alignment = BoxContainer.ALIGNMENT_END
		h.add_theme_constant_override("separation", 4)
		for entry in puzzle.row_clues[y]:
			h.add_child(_clue_label(entry, false))
		_row_clues_box.add_child(h)

	_grid = GridContainer.new()
	_grid.columns = puzzle.width
	_grid.add_theme_constant_override("h_separation", CELL_GAP)
	_grid.add_theme_constant_override("v_separation", CELL_GAP)
	mid_row.add_child(_grid)
	for y in puzzle.height:
		var row_btns: Array = []
		for x in puzzle.width:
			var b := Button.new()
			b.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			b.toggle_mode = false
			b.focus_mode = Control.FOCUS_NONE
			b.gui_input.connect(_on_cell_input.bind(x, y))
			_grid.add_child(b)
			row_btns.append(b)
			_paint_cell(x, y)
		_cell_buttons.append(row_btns)

	if puzzle.is_color:
		var palette_box := HBoxContainer.new()
		root.add_child(palette_box)
		var palette_label := Label.new()
		palette_label.text = "Color:"
		palette_box.add_child(palette_label)
		for ci in range(1, puzzle.palette.size()):
			var swatch := Button.new()
			swatch.custom_minimum_size = Vector2(32, 32)
			swatch.focus_mode = Control.FOCUS_NONE
			var sb := StyleBoxFlat.new()
			sb.bg_color = puzzle.palette[ci]
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.border_width_top = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(1, 1, 1, 0.9) if ci == _selected_color else Color(0, 0, 0, 0)
			swatch.add_theme_stylebox_override("normal", sb)
			swatch.add_theme_stylebox_override("hover", sb)
			swatch.add_theme_stylebox_override("pressed", sb)
			swatch.pressed.connect(_on_select_color.bind(ci))
			palette_box.add_child(swatch)

	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	_status = Label.new()
	_status.text = "Left click = fill, right click = mark"
	bottom.add_child(_status)
	_submit_btn = Button.new()
	_submit_btn.text = "Submit"
	_submit_btn.pressed.connect(_on_submit)
	bottom.add_child(_submit_btn)
	var solve_btn := Button.new()
	solve_btn.text = "Auto-Solve [DEBUG]"
	solve_btn.pressed.connect(_auto_solve)
	bottom.add_child(solve_btn)

func _auto_solve() -> void:
	for y in puzzle.height:
		for x in puzzle.width:
			var sol = puzzle.solution[y][x]
			if typeof(sol) == TYPE_BOOL:
				_state[y][x] = CELL_FILLED if sol else CELL_EMPTY
			else:
				_state[y][x] = int(sol)
			_paint_cell(x, y)
	_on_submit()

func _clue_label(entry, center: bool) -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(CELL_SIZE if center else 0, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if typeof(entry) == TYPE_DICTIONARY:
		lbl.text = str(int(entry.count))
		var col: Color = puzzle.palette[int(entry.color)] if int(entry.color) < puzzle.palette.size() else Color.WHITE
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.corner_radius_top_left = 3
		sb.corner_radius_top_right = 3
		sb.corner_radius_bottom_left = 3
		sb.corner_radius_bottom_right = 3
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		lbl.add_theme_stylebox_override("normal", sb)
		lbl.add_theme_color_override("font_color", _contrast_text(col))
	else:
		lbl.text = str(int(entry))
	return lbl

func _contrast_text(c: Color) -> Color:
	var lum: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	return Color.BLACK if lum > 0.55 else Color.WHITE

func _on_cell_input(event: InputEvent, x: int, y: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var target: int = _selected_color if puzzle.is_color else CELL_FILLED
			_cycle(x, y, target)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cycle(x, y, CELL_MARKED)

func _cycle(x: int, y: int, target: int) -> void:
	_state[y][x] = CELL_EMPTY if _state[y][x] == target else target
	_paint_cell(x, y)
	if target == CELL_MARKED:
		Audio.play_mark()
	else:
		Audio.play_click()

func _on_select_color(idx: int) -> void:
	_selected_color = idx
	_build_ui()

func _paint_cell(x: int, y: int) -> void:
	var b: Button = _cell_buttons[y][x] if y < _cell_buttons.size() else null
	if b == null:
		return
	var val: int = int(_state[y][x])
	var col: Color
	if puzzle.is_color and val > 0:
		col = puzzle.palette[val]
	else:
		col = cell_colors.get(val, cell_colors[CELL_EMPTY])
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)

func _on_submit() -> void:
	var wrong := 0
	for y in puzzle.height:
		for x in puzzle.width:
			var s: int = int(_state[y][x])
			if puzzle.is_color:
				var expected: int = int(puzzle.solution[y][x])
				var got: int = 0 if s <= 0 else s
				if got != expected:
					wrong += 1
			else:
				var player_filled: bool = s == CELL_FILLED
				var should_fill: bool = puzzle.solution[y][x]
				if player_filled != should_fill:
					wrong += 1
	if wrong == 0:
		_status.text = "Solved!"
		_submit_btn.disabled = true
		Audio.play_solve()
		solved.emit(0)
	else:
		_status.text = "Wrong cells: %d" % wrong
		Audio.play_damage()
		_shake()
		failed.emit(wrong)

func _shake() -> void:
	var base: Vector2 = position
	var tw := create_tween()
	for i in 6:
		var offset := Vector2(randf_range(-6, 6), randf_range(-6, 6))
		tw.tween_property(self, "position", base + offset, 0.04)
	tw.tween_property(self, "position", base, 0.06)
