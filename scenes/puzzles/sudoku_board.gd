class_name SudokuBoard
extends Control

signal solved(wrong_cells: int)
signal failed(wrong_cells: int)

const CELL_SIZE := 40

const COLOR_GIVEN := Color(0.12, 0.12, 0.15)
const COLOR_BLANK := Color(0.22, 0.22, 0.28)
const COLOR_SELECTED := Color(0.35, 0.45, 0.7)
const COLOR_TEXT_GIVEN := Color(0.95, 0.95, 0.95)
const COLOR_TEXT_ENTERED := Color(0.55, 0.85, 1.0)
const COLOR_BORDER_THICK := Color(0.5, 0.5, 0.6)

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
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	_cell_buttons = []

	var root := HBoxContainer.new()
	add_child(root)

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
			b.custom_minimum_size = Vector2(CELL_SIZE + pad_right, CELL_SIZE + pad_bottom)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_on_cell_pressed.bind(x, y))
			grid_panel.add_child(b)
			row_btns.append(b)
		_cell_buttons.append(row_btns)
	_repaint_all()

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(200, 0)
	side.add_theme_constant_override("separation", 6)
	root.add_child(side)

	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 4)
	pad.add_theme_constant_override("v_separation", 4)
	side.add_child(pad)
	for n in range(1, 10):
		var nb := Button.new()
		nb.text = str(n)
		nb.custom_minimum_size = Vector2(40, 40)
		nb.pressed.connect(_on_pad_num.bind(n))
		pad.add_child(nb)
	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_pad_num.bind(0))
	side.add_child(clear_btn)

	_status = Label.new()
	_status.text = "Click a blank cell, then a number."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(200, 0)
	side.add_child(_status)
	_submit_btn = Button.new()
	_submit_btn.text = "Submit"
	_submit_btn.pressed.connect(_on_submit)
	side.add_child(_submit_btn)
	var solve_btn := Button.new()
	solve_btn.text = "Auto-Solve"
	solve_btn.pressed.connect(_auto_solve)
	side.add_child(solve_btn)

func _auto_solve() -> void:
	for y in SudokuPuzzle.SIZE:
		for x in SudokuPuzzle.SIZE:
			_state[y][x] = int(puzzle.solution[y][x])
			_paint_cell(x, y)
	_on_submit()

func _on_cell_pressed(x: int, y: int) -> void:
	if bool(puzzle.givens[y][x]):
		return
	_selected = Vector2i(x, y)
	_repaint_all()

func _on_pad_num(n: int) -> void:
	if _selected.x < 0:
		return
	if bool(puzzle.givens[_selected.y][_selected.x]):
		return
	_state[_selected.y][_selected.x] = n
	Audio.play_click()
	_paint_cell(_selected.x, _selected.y)

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

func _paint_cell(x: int, y: int) -> void:
	var b: Button = _cell_buttons[y][x]
	var val: int = int(_state[y][x])
	var is_given: bool = bool(puzzle.givens[y][x])
	b.text = str(val) if val > 0 else ""
	var bg: Color
	if _selected == Vector2i(x, y):
		bg = COLOR_SELECTED
	elif is_given:
		bg = COLOR_GIVEN
	else:
		bg = COLOR_BLANK
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = COLOR_BORDER_THICK
	if x % 3 == 2 and x != SudokuPuzzle.SIZE - 1:
		sb.border_width_right = 3
	if y % 3 == 2 and y != SudokuPuzzle.SIZE - 1:
		sb.border_width_bottom = 3
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT_GIVEN if is_given else COLOR_TEXT_ENTERED)

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
		solved.emit(0)
	else:
		_status.text = "Wrong or blank cells: %d" % wrong
		Audio.play_damage()
		failed.emit(wrong)
