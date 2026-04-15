class_name NonogramBoard
extends Control

signal solved(wrong_cells: int)
signal failed(wrong_cells: int)

const CELL_EMPTY := 0
const CELL_FILLED := 1
const CELL_MARKED := 2

const CELL_SIZE := 36

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

func load_puzzle(p: NonogramPuzzle) -> void:
	puzzle = p
	_state = []
	for y in p.height:
		var row: Array = []
		row.resize(p.width)
		row.fill(CELL_EMPTY)
		_state.append(row)
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	_cell_buttons = []

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	var top_row := HBoxContainer.new()
	root.add_child(top_row)

	var corner := Control.new()
	corner.custom_minimum_size = Vector2(CELL_SIZE * 3, CELL_SIZE * 3)
	top_row.add_child(corner)

	_col_clues_box = HBoxContainer.new()
	_col_clues_box.add_theme_constant_override("separation", 0)
	top_row.add_child(_col_clues_box)
	for x in puzzle.width:
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE * 3)
		v.alignment = BoxContainer.ALIGNMENT_END
		for n in puzzle.col_clues[x]:
			var lbl := Label.new()
			lbl.text = str(n)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(lbl)
		_col_clues_box.add_child(v)

	var mid_row := HBoxContainer.new()
	root.add_child(mid_row)

	_row_clues_box = VBoxContainer.new()
	_row_clues_box.add_theme_constant_override("separation", 0)
	mid_row.add_child(_row_clues_box)
	for y in puzzle.height:
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(CELL_SIZE * 3, CELL_SIZE)
		h.alignment = BoxContainer.ALIGNMENT_END
		for n in puzzle.row_clues[y]:
			var lbl := Label.new()
			lbl.text = str(n)
			h.add_child(lbl)
		_row_clues_box.add_child(h)

	_grid = GridContainer.new()
	_grid.columns = puzzle.width
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
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

	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	_status = Label.new()
	_status.text = "Left click = fill, right click = mark"
	bottom.add_child(_status)
	_submit_btn = Button.new()
	_submit_btn.text = "Submit"
	_submit_btn.pressed.connect(_on_submit)
	bottom.add_child(_submit_btn)

func _on_cell_input(event: InputEvent, x: int, y: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_cycle(x, y, CELL_FILLED)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cycle(x, y, CELL_MARKED)

func _cycle(x: int, y: int, target: int) -> void:
	_state[y][x] = CELL_EMPTY if _state[y][x] == target else target
	_paint_cell(x, y)

func _paint_cell(x: int, y: int) -> void:
	var b: Button = _cell_buttons[y][x] if y < _cell_buttons.size() else null
	if b == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = cell_colors[_state[y][x]]
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)

func _on_submit() -> void:
	var wrong := 0
	for y in puzzle.height:
		for x in puzzle.width:
			var player_filled: bool = _state[y][x] == CELL_FILLED
			var should_fill: bool = puzzle.solution[y][x]
			if player_filled != should_fill:
				wrong += 1
	if wrong == 0:
		_status.text = "Solved!"
		_submit_btn.disabled = true
		solved.emit(0)
	else:
		_status.text = "Wrong cells: %d" % wrong
		failed.emit(wrong)
