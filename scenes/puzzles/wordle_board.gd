class_name WordleBoard
extends Control

signal solved(wrong_cells: int)
signal failed(wrong_cells: int)

const CELL_SIZE := 48
const CELL_GAP := 4
const KEY_W := 36
const KEY_H := 40

const COLOR_GREEN := Color(0.42, 0.68, 0.44)
const COLOR_YELLOW := Color(0.78, 0.72, 0.34)
const COLOR_GREY := Color(0.3, 0.3, 0.32)
const COLOR_EMPTY := Color(0.18, 0.18, 0.22)
const COLOR_PENDING := Color(0.32, 0.32, 0.38)
const COLOR_KEY_BG := Color(0.28, 0.28, 0.32)

const KEYBOARD_ROWS := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
const WORDLE_REWARD := {1: 12, 2: 10, 3: 8, 4: 6, 5: 4, 6: 3}

var puzzle: WordlePuzzle
var _guesses: Array[String] = []
var _current_input: String = ""
var _grid_cells: Array = []  # [row][col] of Label
var _key_buttons: Dictionary = {}  # letter -> Button
var _key_states: Dictionary = {}   # letter -> best Feedback
var _status: Label
var _submit_btn: Button
var _is_finished: bool = false

func load_puzzle(p: WordlePuzzle) -> void:
	puzzle = p
	_guesses.clear()
	_current_input = ""
	_key_states.clear()
	_is_finished = false
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	_grid_cells = []
	_key_buttons.clear()

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		PuzzleStyle.panel_style(PuzzleStyle.NONO_PANEL, COLOR_GREEN))
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Wordle — %d Letters" % puzzle.word_length
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# Letter grid.
	var grid := GridContainer.new()
	grid.columns = puzzle.word_length
	grid.add_theme_constant_override("h_separation", CELL_GAP)
	grid.add_theme_constant_override("v_separation", CELL_GAP)
	root.add_child(grid)
	for row in puzzle.max_guesses:
		var row_cells: Array = []
		for col in puzzle.word_length:
			var cell := _make_cell()
			grid.add_child(cell)
			row_cells.append(cell)
		_grid_cells.append(row_cells)

	# On-screen keyboard.
	for kb_row in KEYBOARD_ROWS:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 3)
		root.add_child(h)
		for ch in kb_row:
			var key := Button.new()
			key.text = ch
			key.custom_minimum_size = Vector2(KEY_W, KEY_H)
			key.focus_mode = Control.FOCUS_NONE
			key.add_theme_font_size_override("font_size", 14)
			PuzzleStyle.apply_button_style(key,
				PuzzleStyle.button_style(COLOR_KEY_BG, 0.15))
			key.pressed.connect(_on_key.bind(ch))
			h.add_child(key)
			_key_buttons[ch] = key
	# Action row: Backspace + Enter.
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 6)
	root.add_child(action_row)
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(70, KEY_H)
	PuzzleStyle.apply_button_style(back_btn,
		PuzzleStyle.button_style(COLOR_EMPTY, 0.12))
	back_btn.pressed.connect(_on_backspace)
	action_row.add_child(back_btn)
	_submit_btn = Button.new()
	_submit_btn.text = "Enter"
	_submit_btn.custom_minimum_size = Vector2(70, KEY_H)
	PuzzleStyle.apply_button_style(_submit_btn,
		PuzzleStyle.button_style(COLOR_GREEN.darkened(0.25), 0.18, COLOR_GREEN))
	_submit_btn.pressed.connect(_on_submit)
	action_row.add_child(_submit_btn)

	_status = Label.new()
	_status.text = "Type or click letters. Enter to submit."
	_status.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)

	var solve_btn := Button.new()
	solve_btn.text = "Auto-Solve"
	PuzzleStyle.apply_button_style(solve_btn,
		PuzzleStyle.button_style(COLOR_EMPTY, 0.12))
	solve_btn.pressed.connect(_auto_solve)
	root.add_child(solve_btn)

func _make_cell() -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_stylebox_override("normal",
		PuzzleStyle.cell_style(COLOR_EMPTY, 4, 1, Color(1, 1, 1, 0.06)))
	return lbl

func _unhandled_input(event: InputEvent) -> void:
	if _is_finished:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_BACKSPACE:
		_on_backspace()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_on_submit()
	else:
		var ch: String = char(event.unicode).to_upper()
		if ch.length() == 1 and ch >= "A" and ch <= "Z":
			_on_key(ch)

func _on_key(ch: String) -> void:
	if _is_finished:
		return
	if _current_input.length() >= puzzle.word_length:
		return
	_current_input += ch
	Audio.play_click(_current_input.length() % 8)
	_refresh_current_row()

func _on_backspace() -> void:
	if _is_finished or _current_input.is_empty():
		return
	_current_input = _current_input.substr(0, _current_input.length() - 1)
	Audio.play_mark()
	_refresh_current_row()

func _on_submit() -> void:
	if _is_finished:
		return
	if _current_input.length() != puzzle.word_length:
		_status.text = "Not enough letters."
		return
	if not WordleWordList.is_valid_word(_current_input):
		_status.text = "Not in word list."
		return
	var guess: String = _current_input.to_upper()
	var feedback: Array = WordlePuzzle.evaluate(guess, puzzle.target_word)
	_guesses.append(guess)
	_current_input = ""
	_animate_feedback(_guesses.size() - 1, guess, feedback)

func _animate_feedback(row: int, guess: String, feedback: Array) -> void:
	for col in puzzle.word_length:
		var cell: Label = _grid_cells[row][col]
		var fb: int = int(feedback[col])
		var col_color: Color = _feedback_color(fb)
		cell.text = guess[col]
		var delay: float = col * 0.15
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			cell.add_theme_stylebox_override("normal",
				PuzzleStyle.cell_style(col_color, 4, 1, Color(1, 1, 1, 0.08)))
			cell.add_theme_color_override("font_color", PuzzleStyle.contrast_text(col_color))
		)
		# Update keyboard key to best state for this letter.
		var letter: String = guess[col]
		var prev_fb: int = int(_key_states.get(letter, WordlePuzzle.Feedback.EMPTY))
		if fb > prev_fb:
			_key_states[letter] = fb
	# Wait for reveal, then check win/loss.
	var reveal_time: float = puzzle.word_length * 0.15 + 0.1
	var check_tw := create_tween()
	check_tw.tween_interval(reveal_time)
	check_tw.tween_callback(_after_feedback.bind(guess, feedback))

func _after_feedback(guess: String, feedback: Array) -> void:
	_update_keyboard_colors()
	var all_green := true
	for fb in feedback:
		if int(fb) != WordlePuzzle.Feedback.GREEN:
			all_green = false
			break
	if all_green:
		_is_finished = true
		_status.text = "Solved in %d guesses!" % _guesses.size()
		Audio.play_solve()
		_play_solve_ceremony()
		solved.emit(0)
	elif _guesses.size() >= puzzle.max_guesses:
		_is_finished = true
		_status.text = "The word was: %s" % puzzle.target_word
		Audio.play_damage()
		var blanks: int = puzzle.word_length
		failed.emit(blanks)
	else:
		_status.text = "%d guesses remaining." % (puzzle.max_guesses - _guesses.size())

func _refresh_current_row() -> void:
	var row: int = _guesses.size()
	if row >= puzzle.max_guesses:
		return
	for col in puzzle.word_length:
		var cell: Label = _grid_cells[row][col]
		if col < _current_input.length():
			cell.text = _current_input[col]
			cell.add_theme_stylebox_override("normal",
				PuzzleStyle.cell_style(COLOR_PENDING, 4, 1, Color(1, 1, 1, 0.1)))
		else:
			cell.text = ""
			cell.add_theme_stylebox_override("normal",
				PuzzleStyle.cell_style(COLOR_EMPTY, 4, 1, Color(1, 1, 1, 0.06)))

func _update_keyboard_colors() -> void:
	for letter in _key_buttons.keys():
		var btn: Button = _key_buttons[letter]
		var fb: int = int(_key_states.get(letter, WordlePuzzle.Feedback.EMPTY))
		var col: Color = _feedback_color(fb) if fb > WordlePuzzle.Feedback.EMPTY else COLOR_KEY_BG
		PuzzleStyle.apply_button_style(btn,
			PuzzleStyle.button_style(col, 0.12))

func _feedback_color(fb: int) -> Color:
	match fb:
		WordlePuzzle.Feedback.GREEN: return COLOR_GREEN
		WordlePuzzle.Feedback.YELLOW: return COLOR_YELLOW
		WordlePuzzle.Feedback.GREY: return COLOR_GREY
		WordlePuzzle.Feedback.PENDING: return COLOR_PENDING
		_: return COLOR_EMPTY

func _play_solve_ceremony() -> void:
	if bool(SaveSystem.setting("reduced_motion", false)):
		return
	var center: Control = get_child(0) as Control
	var panel: Control = center.get_child(0) as Control if center != null and center.get_child_count() > 0 else null
	if panel != null:
		panel.pivot_offset = panel.size * 0.5
		var tw := create_tween()
		tw.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.22)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.28)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func show_reward_counter(reward: int) -> void:
	if reward <= 0:
		return
	var label := Label.new()
	label.text = "+0"
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", COLOR_GREEN)
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

func is_timed_bonus() -> bool:
	return false  # Modifiers not yet wired for wordle

func guesses_used() -> int:
	return _guesses.size()

func _auto_solve() -> void:
	_current_input = puzzle.target_word
	_refresh_current_row()
	_on_submit()
