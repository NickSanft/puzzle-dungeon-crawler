class_name NonogramBoard
extends Control

signal solved(wrong_cells: int)
signal failed(wrong_cells: int)

const CELL_EMPTY := 0
const CELL_FILLED := 1
const CELL_MARKED := -1

const CELL_SIZE := 36
const CELL_GAP := 2

var puzzle: NonogramPuzzle
var _accent: Color = PuzzleStyle.NONO_ACCENT
var _state: Array = []
var _cell_buttons: Array = []
var _grid: GridContainer
var _row_clues_box: VBoxContainer
var _col_clues_box: HBoxContainer
var _row_clue_rows: Array = []  # HBoxContainer per row, for dimming done lines
var _col_clue_cols: Array = []  # VBoxContainer per col
var _status: Label
var _submit_btn: Button
var _selected_color: int = 1

func set_accent(c: Color) -> void:
	_accent = c

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
	_refresh_clue_dim()
	_play_entrance()

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
	_row_clue_rows = []
	_col_clue_cols = []

	var max_row_clues := 1
	for rc in puzzle.row_clues:
		max_row_clues = max(max_row_clues, rc.size())
	var max_col_clues := 1
	for cc in puzzle.col_clues:
		max_col_clues = max(max_col_clues, cc.size())
	if puzzle.is_color:
		max_row_clues = max(1, max_row_clues + 1)
	var row_clue_width: int = max_row_clues * 22 + 10
	var col_clue_height: int = max_col_clues * 22 + 10

	# Fullscreen centerer so the panel shrink-wraps to content and stays
	# centered on any viewport size.
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		PuzzleStyle.panel_style(PuzzleStyle.NONO_PANEL, _accent))
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

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
		v.add_theme_constant_override("separation", 1)
		for entry in puzzle.col_clues[x]:
			v.add_child(_clue_label(entry, true))
		_col_clues_box.add_child(v)
		_col_clue_cols.append(v)

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
		_row_clue_rows.append(h)

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
		palette_box.add_theme_constant_override("separation", 6)
		root.add_child(palette_box)
		var palette_label := Label.new()
		palette_label.text = "Color:"
		palette_label.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
		palette_box.add_child(palette_label)
		for ci in range(1, puzzle.palette.size()):
			var swatch := Button.new()
			swatch.custom_minimum_size = Vector2(34, 34)
			swatch.focus_mode = Control.FOCUS_NONE
			var border: Color = Color(1, 1, 1, 0.9) if ci == _selected_color else Color(1, 1, 1, 0.1)
			var sb: StyleBoxFlat = PuzzleStyle.cell_style(puzzle.palette[ci], 6, 2, border)
			swatch.add_theme_stylebox_override("normal", sb)
			swatch.add_theme_stylebox_override("hover", sb)
			swatch.add_theme_stylebox_override("pressed", sb)
			swatch.pressed.connect(_on_select_color.bind(ci))
			palette_box.add_child(swatch)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	_status = Label.new()
	_status.text = "Left click = fill, right click = mark"
	_status.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_status)
	_submit_btn = Button.new()
	_submit_btn.text = "Submit"
	PuzzleStyle.apply_button_style(_submit_btn,
		PuzzleStyle.button_style(_accent.darkened(0.25), 0.18, _accent))
	_submit_btn.pressed.connect(_on_submit)
	bottom.add_child(_submit_btn)
	var solve_btn := Button.new()
	solve_btn.text = "Auto-Solve"
	PuzzleStyle.apply_button_style(solve_btn,
		PuzzleStyle.button_style(PuzzleStyle.NONO_CELL_EMPTY, 0.12))
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
	_refresh_clue_dim()
	_on_submit()

func _clue_label(entry, center: bool) -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(CELL_SIZE if center else 0, 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", PuzzleStyle.FONT_CLUE)
	if typeof(entry) == TYPE_DICTIONARY:
		lbl.text = str(int(entry.count))
		var col: Color = puzzle.palette[int(entry.color)] if int(entry.color) < puzzle.palette.size() else Color.WHITE
		var sb: StyleBoxFlat = PuzzleStyle.cell_style(col, 3, 0, Color(0, 0, 0, 0))
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		lbl.add_theme_stylebox_override("normal", sb)
		lbl.add_theme_color_override("font_color", PuzzleStyle.contrast_text(col))
	else:
		lbl.text = str(int(entry))
		lbl.add_theme_color_override("font_color", PuzzleStyle.NONO_CLUE_FG)
	return lbl

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
	_fade_in_cell(x, y)
	_refresh_clue_dim_for(x, y)
	var pitch_idx: int = (x + y) % 8
	if target == CELL_MARKED:
		Audio.play_mark(pitch_idx)
	else:
		Audio.play_click(pitch_idx)

func _fade_in_cell(x: int, y: int) -> void:
	# Short alpha fade on every click so the cell feels "inked in".
	var b: Button = _cell_buttons[y][x]
	b.modulate = Color(1, 1, 1, 0.55)
	var tw := create_tween()
	tw.tween_property(b, "modulate:a", 1.0, 0.12)

func _on_select_color(idx: int) -> void:
	_selected_color = idx
	_build_ui()

func _paint_cell(x: int, y: int) -> void:
	var b: Button = _cell_buttons[y][x] if y < _cell_buttons.size() else null
	if b == null:
		return
	var val: int = int(_state[y][x])
	var col: Color
	var is_filled := false
	if val == CELL_EMPTY:
		col = PuzzleStyle.NONO_CELL_EMPTY
	elif val == CELL_MARKED:
		col = PuzzleStyle.NONO_CELL_MARKED
	elif puzzle.is_color and val > 0:
		col = puzzle.palette[val]
		is_filled = true
	else:
		col = PuzzleStyle.NONO_CELL_FILLED
		is_filled = true
	# Subtle per-tile variation on filled cells so the picture isn't flat.
	if is_filled:
		col = PuzzleStyle.variegate(col, x, y, 0.08)
	var sb: StyleBoxFlat = PuzzleStyle.cell_style(col, 4, 1, PuzzleStyle.NONO_CELL_BORDER)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)

func _on_submit() -> void:
	var wrong := 0
	var wrong_cells: Array[Vector2i] = []
	for y in puzzle.height:
		for x in puzzle.width:
			var s: int = int(_state[y][x])
			var is_wrong := false
			if puzzle.is_color:
				var expected: int = int(puzzle.solution[y][x])
				var got: int = 0 if s <= 0 else s
				is_wrong = got != expected
			else:
				var player_filled: bool = s == CELL_FILLED
				var should_fill: bool = puzzle.solution[y][x]
				is_wrong = player_filled != should_fill
			if is_wrong:
				wrong += 1
				wrong_cells.append(Vector2i(x, y))
	if wrong == 0:
		_status.text = "Solved!"
		_submit_btn.disabled = true
		Audio.play_solve()
		_play_solve_ceremony()
		solved.emit(0)
	else:
		_status.text = "Wrong cells: %d" % wrong
		Audio.play_damage()
		_outline_wrong_cells(wrong_cells)
		_shake()
		failed.emit(wrong)

func _outline_wrong_cells(cells: Array[Vector2i]) -> void:
	# Flash a red outline on incorrectly-filled cells so the player sees which.
	for c in cells:
		var b: Button = _cell_buttons[c.y][c.x]
		var val: int = int(_state[c.y][c.x])
		var base: Color
		if val == CELL_EMPTY:
			base = PuzzleStyle.NONO_CELL_EMPTY
		elif val == CELL_MARKED:
			base = PuzzleStyle.NONO_CELL_MARKED
		elif puzzle.is_color and val > 0:
			base = puzzle.palette[val]
		else:
			base = PuzzleStyle.NONO_CELL_FILLED
		var outline: StyleBoxFlat = PuzzleStyle.outlined_cell_style(base,
			PuzzleStyle.NONO_CELL_WRONG_OUTLINE, 3, 4)
		b.add_theme_stylebox_override("normal", outline)
		b.add_theme_stylebox_override("hover", outline)
		b.add_theme_stylebox_override("pressed", outline)
	# Revert after a short delay.
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func():
		for c in cells:
			_paint_cell(c.x, c.y)
	)

# --- Satisfied-clue dimming ------------------------------------------------

func _clues_match(line_state: Array, expected: Array) -> bool:
	if puzzle.is_color:
		var derived: Array = NonogramPuzzle._line_to_color_clues(line_state)
		return str(derived) == str(expected)
	else:
		var bools: Array = []
		for v in line_state:
			bools.append(int(v) == CELL_FILLED)
		var derived: Array = NonogramPuzzle._line_to_clues(bools)
		return derived == expected

func _row_state(y: int) -> Array:
	var out: Array = []
	for x in puzzle.width:
		var s: int = int(_state[y][x])
		if puzzle.is_color:
			out.append(0 if s <= 0 else s)
		else:
			out.append(s == CELL_FILLED)
	return out

func _col_state(x: int) -> Array:
	var out: Array = []
	for y in puzzle.height:
		var s: int = int(_state[y][x])
		if puzzle.is_color:
			out.append(0 if s <= 0 else s)
		else:
			out.append(s == CELL_FILLED)
	return out

func _refresh_clue_dim() -> void:
	for y in puzzle.height:
		_set_line_dim(_row_clue_rows[y], _clues_match(_row_state(y), puzzle.row_clues[y]))
	for x in puzzle.width:
		_set_line_dim(_col_clue_cols[x], _clues_match(_col_state(x), puzzle.col_clues[x]))

func _refresh_clue_dim_for(x: int, y: int) -> void:
	_set_line_dim(_row_clue_rows[y], _clues_match(_row_state(y), puzzle.row_clues[y]))
	_set_line_dim(_col_clue_cols[x], _clues_match(_col_state(x), puzzle.col_clues[x]))

func _set_line_dim(container: Container, done: bool) -> void:
	if container == null:
		return
	var target: float = 0.35 if done else 1.0
	container.modulate = Color(1, 1, 1, target)

func _play_entrance() -> void:
	# Start hidden so nothing flashes in the wrong place on frame 0.
	for y in puzzle.height:
		for x in puzzle.width:
			var b: Button = _cell_buttons[y][x]
			b.modulate = Color(1, 1, 1, 0)
	# Wait for the GridContainer to lay out children; only then do button
	# positions reflect their final coordinates.
	await get_tree().process_frame
	await get_tree().process_frame
	for y in puzzle.height:
		for x in puzzle.width:
			var b: Button = _cell_buttons[y][x]
			var target_pos: Vector2 = b.position
			b.position = target_pos + Vector2(0, 12)
			var delay: float = (y * puzzle.width + x) * 0.012
			var tw := create_tween().set_parallel(true)
			tw.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(delay)
			tw.tween_property(b, "position", target_pos, 0.22)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)

func _play_solve_ceremony() -> void:
	# Wave of brightness across the board (reading order), then a gentle zoom bump.
	var center: Control = get_child(0) as Control
	var panel: Control = center.get_child(0) as Control if center != null and center.get_child_count() > 0 else null
	for y in puzzle.height:
		for x in puzzle.width:
			var b: Button = _cell_buttons[y][x]
			var delay: float = (y + x) * 0.02
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_property(b, "modulate", Color(1.6, 1.6, 1.6), 0.12)
			tw.tween_property(b, "modulate", Color(1, 1, 1), 0.22)
	if panel != null:
		panel.pivot_offset = panel.size * 0.5
		var scale_tw := create_tween()
		scale_tw.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.22)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scale_tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.28)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func show_reward_counter(reward: int) -> void:
	if reward <= 0:
		return
	var label := Label.new()
	label.text = "+0"
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", _accent)
	label.z_index = 10
	label.position = Vector2(size.x * 0.5 - 40, size.y * 0.5 - 60)
	add_child(label)
	var counter := {"v": 0.0}
	var tw := create_tween()
	tw.tween_method(func(v: float):
		counter.v = v
		label.text = "+%d" % int(round(v))
	, 0.0, float(reward), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "position:y", label.position.y - 30, 0.9)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.6)
	tw.tween_callback(label.queue_free)

func _shake() -> void:
	var base: Vector2 = position
	var tw := create_tween()
	for i in 6:
		var offset := Vector2(randf_range(-6, 6), randf_range(-6, 6))
		tw.tween_property(self, "position", base + offset, 0.04)
	tw.tween_property(self, "position", base, 0.06)
