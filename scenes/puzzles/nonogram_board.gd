class_name NonogramBoard
extends Control

signal solved(wrong_cells: int)
signal failed(wrong_cells: int)

const CELL_EMPTY := 0
const CELL_FILLED := 1
const CELL_MARKED := -1

const NONO_CELL_NORMAL := 44
const NONO_CELL_LARGE := 56
const CELL_GAP := 2

static func _cell_size() -> int:
	return NONO_CELL_LARGE if bool(SaveSystem.setting("large_cells", false)) else NONO_CELL_NORMAL

# Colorblind-mode symbol set — each colour index gets a distinct glyph so
# the puzzle is still solvable without colour perception.
const COLORBLIND_GLYPHS := ["", "●", "▲", "■", "◆", "✚", "★"]

var puzzle: NonogramPuzzle
var _accent: Color = PuzzleStyle.NONO_ACCENT
var _modifier: Dictionary = {}
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
var _touch_mark_mode: bool = false  # when true, left-click marks instead of fills
var _timer_label: Label
var _timer_remaining: float = 0.0
var _timer_active: bool = false
var _fogged_clues: Dictionary = {}  # Label -> bool (true = hidden)

func set_accent(c: Color) -> void:
	_accent = c

func set_modifier(mod: Dictionary) -> void:
	_modifier = mod

func load_puzzle(p: NonogramPuzzle, starting_hints: int = 0) -> void:
	puzzle = p
	_state = []
	for y in p.height:
		var row: Array = []
		row.resize(p.width)
		row.fill(CELL_EMPTY)
		_state.append(row)
	if str(_modifier.get("id", "")) == "mirrored":
		_mirror_puzzle()
	_apply_hints(starting_hints)
	_build_ui()
	_refresh_clue_dim()
	_apply_modifier_effects()
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
		v.custom_minimum_size = Vector2(_cell_size(), col_clue_height)
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
		h.custom_minimum_size = Vector2(row_clue_width, _cell_size())
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
			b.custom_minimum_size = Vector2(_cell_size(), _cell_size())
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

	# Fill / Mark toggle for touch devices (no right-click on mobile).
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(mode_row)
	var fill_btn := Button.new()
	fill_btn.text = "Fill"
	fill_btn.toggle_mode = true
	fill_btn.button_pressed = not _touch_mark_mode
	fill_btn.custom_minimum_size = Vector2(80, 44)
	PuzzleStyle.apply_button_style(fill_btn,
		PuzzleStyle.button_style(PuzzleStyle.NONO_CELL_FILLED.darkened(0.3), 0.15, PuzzleStyle.NONO_CELL_FILLED))
	fill_btn.pressed.connect(func(): _touch_mark_mode = false; _refresh_mode_buttons(fill_btn, mark_btn))
	mode_row.add_child(fill_btn)
	var mark_btn := Button.new()
	mark_btn.text = "Mark X"
	mark_btn.toggle_mode = true
	mark_btn.button_pressed = _touch_mark_mode
	mark_btn.custom_minimum_size = Vector2(80, 44)
	PuzzleStyle.apply_button_style(mark_btn,
		PuzzleStyle.button_style(PuzzleStyle.NONO_CELL_MARKED.darkened(0.2), 0.15, PuzzleStyle.NONO_CELL_MARKED))
	mark_btn.pressed.connect(func(): _touch_mark_mode = true; _refresh_mode_buttons(fill_btn, mark_btn))
	mode_row.add_child(mark_btn)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	_status = Label.new()
	_status.text = "Tap to fill, or toggle Mark X for marking."
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
	lbl.custom_minimum_size = Vector2(_cell_size() if center else 0, 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", PuzzleStyle.FONT_CLUE)
	if typeof(entry) == TYPE_DICTIONARY:
		var color_idx: int = int(entry.color)
		var count: int = int(entry.count)
		if bool(SaveSystem.setting("colorblind", false)):
			var glyph: String = COLORBLIND_GLYPHS[color_idx % COLORBLIND_GLYPHS.size()]
			lbl.text = "%d%s" % [count, glyph]
		else:
			lbl.text = str(count)
		var col: Color = puzzle.palette[color_idx] if color_idx < puzzle.palette.size() else Color.WHITE
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

func _refresh_mode_buttons(fill_btn: Button, mark_btn: Button) -> void:
	fill_btn.button_pressed = not _touch_mark_mode
	mark_btn.button_pressed = _touch_mark_mode

func _on_cell_input(event: InputEvent, x: int, y: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _touch_mark_mode:
				_cycle(x, y, CELL_MARKED)
			else:
				var target: int = _selected_color if puzzle.is_color else CELL_FILLED
				_cycle(x, y, target)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cycle(x, y, CELL_MARKED)

func _cycle(x: int, y: int, target: int) -> void:
	_state[y][x] = CELL_EMPTY if _state[y][x] == target else target
	_paint_cell(x, y)
	_fade_in_cell(x, y)
	_refresh_clue_dim_for(x, y)
	_reveal_fog_for(x, y)
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
	# Colorblind mode: render a distinct glyph per colour index on filled cells.
	if puzzle.is_color and is_filled and bool(SaveSystem.setting("colorblind", false)):
		b.text = COLORBLIND_GLYPHS[val % COLORBLIND_GLYPHS.size()]
		b.add_theme_color_override("font_color", PuzzleStyle.contrast_text(col))
	else:
		b.text = ""

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
	if bool(SaveSystem.setting("reduced_motion", false)):
		return
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
	if bool(SaveSystem.setting("reduced_motion", false)):
		return
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

# --- Room Modifiers -------------------------------------------------------

func _mirror_puzzle() -> void:
	# Flip every row in the solution horizontally. Clues are re-derived so
	# they stay accurate — the player just has to think "backwards".
	for y in puzzle.height:
		puzzle.solution[y].reverse()
	if puzzle.is_color:
		puzzle.row_clues = []
		for y in puzzle.height:
			puzzle.row_clues.append(NonogramPuzzle._line_to_color_clues(puzzle.solution[y]))
	else:
		puzzle.row_clues = []
		for y in puzzle.height:
			puzzle.row_clues.append(NonogramPuzzle._line_to_clues(puzzle.solution[y]))

func _apply_modifier_effects() -> void:
	var mod_id: String = str(_modifier.get("id", ""))
	if mod_id == "fogged":
		_apply_fog()
	elif mod_id == "timed":
		_start_timer()
	# Show modifier badge in the status bar.
	if mod_id != "":
		_status.text = "[%s] %s" % [str(_modifier.get("name", "")), str(_modifier.get("desc", ""))]

func _apply_fog() -> void:
	# Hide ~40% of clue labels randomly. They reveal when the player fills
	# a cell in the same row or column.
	_fogged_clues.clear()
	for y in puzzle.height:
		var row_container: Container = _row_clue_rows[y]
		for child in row_container.get_children():
			if RNG.randf() < 0.4:
				child.modulate = Color(1, 1, 1, 0)
				_fogged_clues[child] = true
	for x in puzzle.width:
		var col_container: Container = _col_clue_cols[x]
		for child in col_container.get_children():
			if RNG.randf() < 0.4:
				child.modulate = Color(1, 1, 1, 0)
				_fogged_clues[child] = true

func _reveal_fog_for(x: int, y: int) -> void:
	if _fogged_clues.is_empty():
		return
	# Reveal clues in the same row and column as the filled cell.
	if y < _row_clue_rows.size():
		var row_c: Container = _row_clue_rows[y]
		for child in row_c.get_children():
			if _fogged_clues.has(child):
				child.modulate = Color(1, 1, 1, 1)
				_fogged_clues.erase(child)
	if x < _col_clue_cols.size():
		var col_c: Container = _col_clue_cols[x]
		for child in col_c.get_children():
			if _fogged_clues.has(child):
				child.modulate = Color(1, 1, 1, 1)
				_fogged_clues.erase(child)

func _start_timer() -> void:
	_timer_remaining = 60.0
	_timer_active = true
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 22)
	_timer_label.add_theme_color_override("font_color", _accent)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Insert near the top of the first child tree (after the center wrapper).
	add_child(_timer_label)
	_timer_label.position = Vector2(10, 10)
	_timer_label.z_index = 20
	set_process(true)

func _process(delta: float) -> void:
	if not _timer_active:
		set_process(false)
		return
	_timer_remaining -= delta
	if _timer_remaining <= 0:
		_timer_remaining = 0.0
		_timer_active = false
	if _timer_label != null:
		var color: Color = _accent if _timer_remaining > 10.0 else Color(0.95, 0.35, 0.35)
		_timer_label.add_theme_color_override("font_color", color)
		_timer_label.text = "Time: %d:%02d" % [int(_timer_remaining) / 60, int(_timer_remaining) % 60]

func is_timed_bonus() -> bool:
	# Returns true if the puzzle was timed and the player beat it in time.
	return str(_modifier.get("id", "")) == "timed" and _timer_remaining > 0.0

func _shake() -> void:
	if bool(SaveSystem.setting("reduced_motion", false)):
		return
	var base: Vector2 = position
	var tw := create_tween()
	for i in 6:
		var offset := Vector2(randf_range(-6, 6), randf_range(-6, 6))
		tw.tween_property(self, "position", base + offset, 0.04)
	tw.tween_property(self, "position", base, 0.06)
