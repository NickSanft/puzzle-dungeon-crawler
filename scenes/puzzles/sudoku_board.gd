class_name SudokuBoard
extends Control

signal solved(wrong_cells: int)
signal failed(wrong_cells: int)

const SUDO_CELL_NORMAL := 40
const SUDO_CELL_LARGE := 56

static func _cell_size() -> int:
	return SUDO_CELL_LARGE if bool(SaveSystem.setting("large_cells", false)) else SUDO_CELL_NORMAL

var puzzle: SudokuPuzzle
var _state: Array = []
var _cell_buttons: Array = []
var _selected: Vector2i = Vector2i(-1, -1)
var _status: Label
var _submit_btn: Button

func load_puzzle(p: SudokuPuzzle) -> void:
	puzzle = p
	_state = []
	for y in SudokuPuzzle.SIZE:
		var row: Array = []
		for x in SudokuPuzzle.SIZE:
			row.append(int(p.initial[y][x]))
		_state.append(row)
	_selected = Vector2i(-1, -1)
	_build_ui()
	_repaint_all()
	_play_entrance()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	_cell_buttons = []

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		PuzzleStyle.panel_style(PuzzleStyle.SUDO_PANEL, PuzzleStyle.SUDO_ACCENT))
	center.add_child(panel)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	panel.add_child(root)

	var grid_panel := GridContainer.new()
	grid_panel.columns = SudokuPuzzle.SIZE
	grid_panel.add_theme_constant_override("h_separation", 1)
	grid_panel.add_theme_constant_override("v_separation", 1)
	root.add_child(grid_panel)
	for y in SudokuPuzzle.SIZE:
		var row_btns: Array = []
		for x in SudokuPuzzle.SIZE:
			var b := Button.new()
			var pad_right: int = 3 if x % 3 == 2 and x != SudokuPuzzle.SIZE - 1 else 0
			var pad_bottom: int = 3 if y % 3 == 2 and y != SudokuPuzzle.SIZE - 1 else 0
			var cs: int = _cell_size()
			b.custom_minimum_size = Vector2(cs + pad_right, cs + pad_bottom)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", PuzzleStyle.FONT_DIGIT)
			b.pressed.connect(_on_cell_pressed.bind(x, y))
			grid_panel.add_child(b)
			row_btns.append(b)
		_cell_buttons.append(row_btns)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(200, 0)
	side.add_theme_constant_override("separation", 6)
	root.add_child(side)

	var title := Label.new()
	title.text = "Sudoku"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", PuzzleStyle.SUDO_ACCENT)
	side.add_child(title)

	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 4)
	pad.add_theme_constant_override("v_separation", 4)
	side.add_child(pad)
	for n in range(1, 10):
		var nb := Button.new()
		nb.text = str(n)
		nb.custom_minimum_size = Vector2(40, 40)
		nb.add_theme_font_size_override("font_size", 18)
		PuzzleStyle.apply_button_style(nb,
			PuzzleStyle.button_style(PuzzleStyle.SUDO_CELL_BLANK, 0.15, PuzzleStyle.SUDO_ACCENT))
		nb.pressed.connect(_on_pad_num.bind(n))
		pad.add_child(nb)
	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	PuzzleStyle.apply_button_style(clear_btn,
		PuzzleStyle.button_style(PuzzleStyle.SUDO_CELL_BLANK, 0.12))
	clear_btn.pressed.connect(_on_pad_num.bind(0))
	side.add_child(clear_btn)

	_status = Label.new()
	_status.text = "Click a blank cell, then a number."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(200, 0)
	_status.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
	side.add_child(_status)
	_submit_btn = Button.new()
	_submit_btn.text = "Submit"
	PuzzleStyle.apply_button_style(_submit_btn,
		PuzzleStyle.button_style(PuzzleStyle.SUDO_ACCENT.darkened(0.3), 0.18, PuzzleStyle.SUDO_ACCENT))
	_submit_btn.pressed.connect(_on_submit)
	side.add_child(_submit_btn)
	var solve_btn := Button.new()
	solve_btn.text = "Auto-Solve"
	PuzzleStyle.apply_button_style(solve_btn,
		PuzzleStyle.button_style(PuzzleStyle.SUDO_CELL_BLANK, 0.12))
	solve_btn.pressed.connect(_auto_solve)
	side.add_child(solve_btn)

func _auto_solve() -> void:
	for y in SudokuPuzzle.SIZE:
		for x in SudokuPuzzle.SIZE:
			_state[y][x] = int(puzzle.solution[y][x])
	_repaint_all()
	_on_submit()

func _on_cell_pressed(x: int, y: int) -> void:
	# Allow selecting givens too — helps the player read the board.
	_selected = Vector2i(x, y)
	_repaint_all()

func _on_pad_num(n: int) -> void:
	if _selected.x < 0:
		return
	if bool(puzzle.givens[_selected.y][_selected.x]):
		return
	_state[_selected.y][_selected.x] = n
	Audio.play_click((_selected.x + _selected.y) % 8)
	_repaint_all()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _selected.x < 0:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		_on_pad_num(event.keycode - KEY_0)
	elif event.keycode == KEY_0 or event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE:
		_on_pad_num(0)

func _repaint_all() -> void:
	for y in SudokuPuzzle.SIZE:
		for x in SudokuPuzzle.SIZE:
			_paint_cell(x, y)

func _same_box(a: Vector2i, b: Vector2i) -> bool:
	return (a.x / 3 == b.x / 3) and (a.y / 3 == b.y / 3)

func _is_conflict(x: int, y: int) -> bool:
	# Cell is "conflict" if its current non-zero value is duplicated in its
	# row, column, or 3x3 box by another non-zero cell.
	var v: int = int(_state[y][x])
	if v == 0:
		return false
	for i in SudokuPuzzle.SIZE:
		if i != x and int(_state[y][i]) == v:
			return true
		if i != y and int(_state[i][x]) == v:
			return true
	var bx: int = x - x % 3
	var by: int = y - y % 3
	for dy in 3:
		for dx in 3:
			var nx: int = bx + dx
			var ny: int = by + dy
			if nx == x and ny == y:
				continue
			if int(_state[ny][nx]) == v:
				return true
	return false

func _paint_cell(x: int, y: int) -> void:
	var b: Button = _cell_buttons[y][x]
	var val: int = int(_state[y][x])
	var is_given: bool = bool(puzzle.givens[y][x])
	b.text = str(val) if val > 0 else ""

	var selected_val: int = -1
	if _selected.x >= 0:
		selected_val = int(_state[_selected.y][_selected.x])

	var bg: Color
	if _selected == Vector2i(x, y):
		bg = PuzzleStyle.SUDO_CELL_SELECTED
	elif _is_conflict(x, y):
		bg = PuzzleStyle.SUDO_CELL_CONFLICT_TINT
	elif _selected.x >= 0 and (_selected.x == x or _selected.y == y or _same_box(_selected, Vector2i(x, y))):
		bg = PuzzleStyle.SUDO_CELL_RELATED
	elif selected_val > 0 and val == selected_val:
		bg = PuzzleStyle.SUDO_CELL_MATCH
	elif is_given:
		bg = PuzzleStyle.SUDO_CELL_GIVEN
	else:
		bg = PuzzleStyle.SUDO_CELL_BLANK

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.border_color = PuzzleStyle.SUDO_GRID_MAJOR
	if x % 3 == 2 and x != SudokuPuzzle.SIZE - 1:
		sb.border_width_right = 3
	if y % 3 == 2 and y != SudokuPuzzle.SIZE - 1:
		sb.border_width_bottom = 3
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)

	var text_col: Color
	if _is_conflict(x, y):
		text_col = PuzzleStyle.SUDO_TEXT_CONFLICT
	elif is_given:
		text_col = PuzzleStyle.SUDO_TEXT_GIVEN
	else:
		text_col = PuzzleStyle.SUDO_TEXT_ENTERED
	b.add_theme_color_override("font_color", text_col)

func _play_entrance() -> void:
	if bool(SaveSystem.setting("reduced_motion", false)):
		return
	for y in SudokuPuzzle.SIZE:
		for x in SudokuPuzzle.SIZE:
			var b: Button = _cell_buttons[y][x]
			b.modulate = Color(1, 1, 1, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	for y in SudokuPuzzle.SIZE:
		for x in SudokuPuzzle.SIZE:
			var b: Button = _cell_buttons[y][x]
			var target_pos: Vector2 = b.position
			b.position = target_pos + Vector2(0, 10)
			var delay: float = (y * SudokuPuzzle.SIZE + x) * 0.006
			var tw := create_tween().set_parallel(true)
			tw.tween_property(b, "modulate:a", 1.0, 0.22).set_delay(delay)
			tw.tween_property(b, "position", target_pos, 0.24)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)

func _play_solve_ceremony() -> void:
	if bool(SaveSystem.setting("reduced_motion", false)):
		return
	var center: Control = get_child(0) as Control
	var panel: Control = center.get_child(0) as Control if center != null and center.get_child_count() > 0 else null
	for y in SudokuPuzzle.SIZE:
		for x in SudokuPuzzle.SIZE:
			var b: Button = _cell_buttons[y][x]
			var delay: float = (y + x) * 0.015
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_property(b, "modulate", Color(1.5, 1.6, 1.8), 0.1)
			tw.tween_property(b, "modulate", Color(1, 1, 1), 0.2)
	if panel != null:
		panel.pivot_offset = panel.size * 0.5
		var scale_tw := create_tween()
		scale_tw.tween_property(panel, "scale", Vector2(1.03, 1.03), 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scale_tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.26)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func show_reward_counter(reward: int) -> void:
	if reward <= 0:
		return
	var label := Label.new()
	label.text = "+0"
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", PuzzleStyle.SUDO_ACCENT)
	label.z_index = 10
	label.position = Vector2(size.x * 0.5 - 40, size.y * 0.5 - 60)
	add_child(label)
	var tw := create_tween()
	tw.tween_method(func(v: float):
		label.text = "+%d" % int(round(v))
	, 0.0, float(reward), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "position:y", label.position.y - 30, 0.9)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.6)
	tw.tween_callback(label.queue_free)

func _on_submit() -> void:
	var wrong := 0
	for y in SudokuPuzzle.SIZE:
		for x in SudokuPuzzle.SIZE:
			var v: int = int(_state[y][x])
			if v != int(puzzle.solution[y][x]):
				wrong += 1
	if wrong == 0:
		_status.text = "Solved!"
		_submit_btn.disabled = true
		Audio.play_solve()
		_play_solve_ceremony()
		solved.emit(0)
	else:
		_status.text = "Wrong or blank cells: %d" % wrong
		Audio.play_damage()
		failed.emit(wrong)
