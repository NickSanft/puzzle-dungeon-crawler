extends Control

const DungeonScene := preload("res://scenes/dungeon/dungeon.tscn")
const NonogramBoardScene := preload("res://scenes/puzzles/nonogram_board.tscn")
const SudokuBoardScene := preload("res://scenes/puzzles/sudoku_board.tscn")
const WordleBoardScene := preload("res://scenes/puzzles/wordle_board.tscn")
const ShopScene := preload("res://scenes/ui/shop.tscn")
const PuzzleChoiceScene := preload("res://scenes/ui/puzzle_choice.tscn")
const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")

const FLOOR_NAMES := ["The Margin", "The Library", "The Ink Well"]
const FLOOR_QUOTES := [
	"Where apprentices scratch first clues into the vellum.",
	"Taller shelves. Older bindings. Puzzles that watch you back.",
	"At the heart of every book: the well that drinks you in.",
]

const GLIMBO_REWARD_PER_SIZE := {5: 3, 7: 5, 10: 8, 15: 15}
const SUDOKU_REWARD := 10
const BOSS_SIZE := 10

@onready var _hud: Label = $HUD/HPGlimbos
@onready var _message: Label = $HUD/Message
@onready var _reveal_btn: Button = $HUD/DebugRow/RevealMap
@onready var _dungeon_layer: Node2D = $DungeonLayer
@onready var _overlay: Control = $Overlay
@onready var _backdrop: ColorRect = $Overlay/Backdrop

var _dungeon: Node2D
var _current_board: Node
var _current_room_type: String = "PUZZLE"
var _current_shop: GlimboShop
var _current_boss_name: String = ""
var _puzzles_solved_on_floor: int = 0
var _pending_reward_mult: float = 1.0
var _resuming: bool = false
var _paused: bool = false
var _pause_menu: Control

func _ready() -> void:
	_dungeon = DungeonScene.instantiate()
	_dungeon_layer.add_child(_dungeon)
	_dungeon.trigger_entered.connect(_on_trigger_entered)
	RunManager.floor_started.connect(_on_floor_started)
	RunManager.floor_completed.connect(_on_floor_completed)
	RunManager.puzzle_remaining_changed.connect(_on_puzzle_remaining_changed)
	GameState.run_ended.connect(_on_run_ended)
	GameState.hp_changed.connect(func(_c, _m): _update_hud())
	GameState.glimbos_earned.connect(func(_a, _b): _update_hud())
	_reveal_btn.toggled.connect(_on_reveal_toggled)
	if _resuming and SaveSystem.has_saved_run():
		_restore_from_save()
	else:
		RunManager.begin_floor()
	_update_hud()
	Audio.start_ambient(0.45)

func begin_resume() -> void:
	_resuming = true

func _restore_from_save() -> void:
	var snap: Dictionary = SaveSystem.saved_run()
	GameState.character_id = str(snap.get("character_id", GameState.character_id))
	GameState.current_floor = int(snap.get("floor", 1))
	GameState.max_hp = int(snap.get("max_hp", GameState.max_hp))
	GameState.hp = int(snap.get("hp", GameState.max_hp))
	GameState.glimbos_this_run = int(snap.get("glimbos_run", 0))
	GameState.puzzles_this_run = int(snap.get("puzzles_run", 0))
	GameState.puzzles_solved_on_floor = int(snap.get("puzzles_on_floor", 0))
	GameState.curse_on_floor = int(snap.get("curse", 0))
	GameState.is_daily_run = bool(snap.get("is_daily", false))
	GameState.daily_date_key = str(snap.get("daily_key", ""))
	var elapsed: float = float(snap.get("elapsed_sec", 0.0))
	GameState.run_started_ticks = Time.get_ticks_msec() - int(elapsed * 1000.0)
	_puzzles_solved_on_floor = GameState.puzzles_solved_on_floor
	_dungeon.restore(snap.get("dungeon", {}))
	_dungeon.set_active(true)
	_dungeon.set_character_reveal_all(
		bool(Characters.effect(GameState.character_id, "reveal_maze", false)))
	RunManager.set_puzzles_remaining(int(snap.get("puzzles_remaining_on_floor", 0)))
	_clear_overlay()
	_set_backdrop(false)
	_message.text = "Continuing your run on floor %d." % GameState.current_floor

func _on_reveal_toggled(on: bool) -> void:
	_dungeon.set_debug_reveal_all(on)
	_reveal_btn.text = "Hide Map [DEBUG]" if on else "Reveal Map [DEBUG]"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _paused:
			_close_pause()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()

func _open_pause() -> void:
	if _paused:
		return
	_paused = true
	_dungeon.set_active(false)
	_pause_menu = PauseMenuScene.instantiate()
	_pause_menu.resumed.connect(_close_pause)
	_pause_menu.abandoned.connect(_abandon_run)
	add_child(_pause_menu)

func _close_pause() -> void:
	if not _paused:
		return
	_paused = false
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
		_pause_menu = null
	# Only re-enable dungeon if no puzzle/shop overlay is active.
	if _current_board == null and _current_shop == null:
		_dungeon.set_active(true)

func _abandon_run() -> void:
	_paused = false
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	SaveSystem.clear_run()
	Audio.stop_ambient()
	get_tree().change_scene_to_file("res://scenes/ui/main.tscn")

func _on_floor_started(floor_num: int, tiles: Array, triggers: Array, entrance: Vector2i) -> void:
	_puzzles_solved_on_floor = 0
	GameState.on_floor_changed()
	_dungeon.load_maze(tiles, triggers, entrance)
	_dungeon.set_character_reveal_all(
		bool(Characters.effect(GameState.character_id, "reveal_maze", false)))
	_show_act_intro(floor_num)
	_autosave()
	_dungeon.set_active(true)
	_clear_overlay()
	_message.text = "Floor %d / %d — %d puzzles, a shop, and a boss." % [
		floor_num, RunManager.FLOORS_PER_RUN, RunManager.puzzles_remaining(),
	]
	_update_hud()

func _on_puzzle_remaining_changed(_remaining: int) -> void:
	_update_hud()

func _on_trigger_entered(trigger_data: Dictionary) -> void:
	var trigger_type: String = str(trigger_data.get("type", "PUZZLE"))
	_current_room_type = trigger_type
	match trigger_type:
		"PUZZLE":
			_open_puzzle(RunManager.puzzle_size_for(GameState.current_floor))
		"SHOP":
			_open_shop()
		"BOSS":
			_open_boss()
		"TRAP":
			_handle_trap()
		"LORE":
			_handle_lore(trigger_data)

func _on_floor_completed(floor_num: int) -> void:
	_clear_overlay()
	_dungeon.set_active(false)
	var banner := Label.new()
	banner.text = "FLOOR %d COMPLETE" % floor_num
	banner.add_theme_font_size_override("font_size", 42)
	banner.anchor_left = 0.5
	banner.anchor_top = 0.5
	banner.offset_left = -200
	banner.offset_top = -30
	banner.offset_right = 200
	banner.offset_bottom = 30
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(banner)
	await get_tree().create_timer(1.8).timeout
	banner.queue_free()
	if GameState.current_floor > floor_num:
		RunManager.begin_floor()

func _open_puzzle(puzzle_size: int) -> void:
	_clear_overlay()
	_set_backdrop(true)
	var ptype: String = _pick_puzzle_type()
	match ptype:
		"sudoku":
			_pending_reward_mult = 1.0
			_open_sudoku()
		"wordle":
			_pending_reward_mult = 1.0
			_open_wordle()
		_:
			# Nonogram: show size choice screen.
			var choice: PuzzleChoice = PuzzleChoiceScene.instantiate()
			_overlay.add_child(choice)
			choice.show_choice(puzzle_size, GameState.current_floor)
			choice.chosen.connect(func(opt: Dictionary):
				choice.queue_free()
				_pending_reward_mult = float(opt.reward_mult)
				var density: float = clamp(
					RunManager.density_for(GameState.current_floor) + float(opt.density_delta),
					0.4, 0.78)
				_spawn_nonogram(int(opt.size), density)
			)

func _spawn_nonogram(puzzle_size: int, density: float) -> void:
	var use_color: bool = SaveSystem.has_unlock("color_nonograms") and _puzzles_solved_on_floor >= 2
	var puzzle: NonogramPuzzle
	if use_color:
		puzzle = NonogramGenerator.generate_color(puzzle_size, density)
	else:
		puzzle = NonogramGenerator.generate(puzzle_size, density, true)
	var board: NonogramBoard = NonogramBoardScene.instantiate()
	_overlay.add_child(board)
	board.set_accent(PuzzleStyle.accent_for_floor(GameState.current_floor))
	var mod: Dictionary = RoomModifiers.roll()
	if not mod.is_empty():
		board.set_modifier(mod)
	board.load_puzzle(puzzle, _starting_hints())
	board.solved.connect(_on_puzzle_solved.bind(puzzle_size))
	board.failed.connect(_on_puzzle_failed)
	_current_board = board

func _pick_puzzle_type() -> String:
	var idx: int = _puzzles_solved_on_floor + GameState.current_floor
	match idx % 3:
		1: return "sudoku"
		2: return "wordle"
		_: return "nonogram"

func _open_sudoku() -> void:
	_set_backdrop(true)
	var blanks: int = 40 + GameState.current_floor * 3
	var puzzle: SudokuPuzzle = SudokuGenerator.generate(blanks)
	var board: SudokuBoard = SudokuBoardScene.instantiate()
	_overlay.add_child(board)
	board.load_puzzle(puzzle)
	board.solved.connect(_on_sudoku_solved)
	board.failed.connect(_on_puzzle_failed)
	_current_board = board

func _open_wordle() -> void:
	_set_backdrop(true)
	var puzzle: WordlePuzzle = WordleGenerator.generate(GameState.current_floor)
	var board: WordleBoard = WordleBoardScene.instantiate()
	_overlay.add_child(board)
	board.load_puzzle(puzzle)
	board.solved.connect(_on_wordle_solved)
	board.failed.connect(_on_puzzle_failed)
	_current_board = board

func _on_wordle_solved(_wrong: int) -> void:
	var guesses: int = 6
	if _current_board != null and _current_board.has_method("guesses_used"):
		guesses = _current_board.guesses_used()
	var reward: int = WordleBoard.WORDLE_REWARD.get(guesses, 3)
	GameState.award_glimbos(reward)
	_puzzles_solved_on_floor += 1
	if _current_board != null and _current_board.has_method("show_reward_counter"):
		_current_board.show_reward_counter(reward)
	await get_tree().create_timer(0.9).timeout
	_resume_exploration("PUZZLE")

func _on_sudoku_solved(_wrong: int) -> void:
	GameState.award_glimbos(SUDOKU_REWARD)
	_puzzles_solved_on_floor += 1
	if _current_board != null and _current_board.has_method("show_reward_counter"):
		_current_board.show_reward_counter(SUDOKU_REWARD)
	await get_tree().create_timer(0.9).timeout
	_resume_exploration("PUZZLE")

func _starting_hints() -> int:
	var n: int = 0
	if SaveSystem.has_unlock("puzzle_hint"):
		n += 1
	n += int(Characters.effect(GameState.character_id, "bonus_hint_per_puzzle", 0))
	return n

func _on_puzzle_solved(_wrong: int, puzzle_size: int) -> void:
	var base_reward: int = GLIMBO_REWARD_PER_SIZE.get(puzzle_size, 3)
	var reward: int = max(1, int(round(float(base_reward) * _pending_reward_mult)))
	# Timed modifier bonus: +50% if solved before time ran out.
	if _current_board != null and _current_board.has_method("is_timed_bonus"):
		if _current_board.is_timed_bonus():
			reward = int(round(float(reward) * 1.5))
	GameState.award_glimbos(reward)
	_puzzles_solved_on_floor += 1
	if _current_board != null and _current_board.has_method("show_reward_counter"):
		_current_board.show_reward_counter(reward)
	await get_tree().create_timer(0.9).timeout
	_resume_exploration("PUZZLE")

func _open_boss() -> void:
	_clear_overlay()
	_set_backdrop(true)
	var use_color: bool = SaveSystem.has_unlock("color_nonograms")
	var boss: Dictionary = NonogramGenerator.from_boss_pattern(use_color)
	_current_boss_name = str(boss.name)
	var curse_suffix := ""
	if GameState.curse_on_floor >= 3:
		curse_suffix = "  (cursed ×%d)" % GameState.curse_on_floor
	_message.text = "BOSS: %s%s" % [boss.name, curse_suffix]
	var board: NonogramBoard = NonogramBoardScene.instantiate()
	_overlay.add_child(board)
	board.set_accent(PuzzleStyle.accent_for_floor(GameState.current_floor))
	board.load_puzzle(boss.puzzle, _starting_hints())
	board.solved.connect(_on_boss_solved)
	board.failed.connect(_on_puzzle_failed)
	_current_board = board

func _on_boss_solved(_wrong: int) -> void:
	var base: float = float(GLIMBO_REWARD_PER_SIZE.get(BOSS_SIZE, 8)) * 2.0
	var char_mult: float = float(Characters.effect(GameState.character_id, "boss_reward_mult", 1.0))
	var reward: int = int(round(base * GameState.boss_reward_multiplier() * char_mult))
	if SaveSystem.has_unlock("extra_reward"):
		reward *= 2
	GameState.award_glimbos(reward)
	Audio.play_boss_win()
	if _current_board != null and _current_board.has_method("show_reward_counter"):
		_current_board.show_reward_counter(reward)
	var accent: Color = PuzzleStyle.accent_for_floor(GameState.current_floor)
	var banner_panel := PanelContainer.new()
	banner_panel.anchor_left = 0.5
	banner_panel.anchor_top = 0.5
	banner_panel.offset_left = -320
	banner_panel.offset_top = 100
	banner_panel.offset_right = 320
	banner_panel.offset_bottom = 200
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_panel.add_theme_stylebox_override("panel",
		PuzzleStyle.panel_style(PuzzleStyle.NONO_PANEL, accent))
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	banner_panel.add_child(bv)
	var eyebrow := Label.new()
	eyebrow.text = "DEFEATED"
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(eyebrow)
	var name_lbl := Label.new()
	name_lbl.text = _current_boss_name
	name_lbl.add_theme_font_size_override("font_size", PuzzleStyle.FONT_DISPLAY)
	name_lbl.add_theme_color_override("font_color", accent)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(name_lbl)
	_overlay.add_child(banner_panel)
	if not bool(SaveSystem.setting("reduced_motion", false)):
		banner_panel.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(banner_panel, "modulate:a", 1.0, 0.35)
	await get_tree().create_timer(2.2).timeout
	_resume_exploration("BOSS")

func _open_shop() -> void:
	_clear_overlay()
	_set_backdrop(true)
	_current_shop = ShopScene.instantiate()
	_overlay.add_child(_current_shop)
	_current_shop.closed.connect(_on_shop_closed)

func _on_shop_closed() -> void:
	_clear_overlay()
	_resume_exploration("SHOP")

func _resume_exploration(kind: String) -> void:
	_clear_overlay()
	_set_backdrop(false)
	RunManager.on_trigger_resolved(kind)
	# For BOSS, RunManager queues the floor transition; keep input paused until
	# floor_completed handler runs. Otherwise, hand control back to the player.
	if kind != "BOSS":
		_dungeon.set_active(true)
		_autosave()

func _on_puzzle_failed(wrong: int) -> void:
	# Cursed bosses hit harder: every wrong cell stings more.
	var amount: int = wrong
	if _current_room_type == "BOSS" and GameState.curse_on_floor >= 3:
		amount = int(ceil(float(wrong) * (1.0 + GameState.boss_density_bonus() * 2.0)))
	GameState.take_damage(amount)
	_flash_damage()

func _handle_trap() -> void:
	_message.text = "TRAP! You stumbled onto a snare."
	GameState.take_damage(2)
	_flash_damage()
	Audio.play_damage()
	# Brief lock, then back to exploration.
	await get_tree().create_timer(0.6).timeout
	_dungeon.set_active(true)
	_autosave()

func _handle_lore(data: Dictionary) -> void:
	var lore_id: String = str(data.get("lore_id", ""))
	var lore_text: String = str(data.get("lore_text", ""))
	Lore.mark_collected(lore_id)
	_clear_overlay()
	_set_backdrop(true)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		PuzzleStyle.panel_style(PuzzleStyle.NONO_PANEL, PuzzleStyle.accent_for_floor(GameState.current_floor)))
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var eyebrow := Label.new()
	eyebrow.text = "Lore Page Discovered"
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color(0.55, 0.85, 0.65))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(eyebrow)
	var body := Label.new()
	body.text = lore_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(380, 0)
	body.add_theme_font_size_override("font_size", 16)
	v.add_child(body)
	# Check if all floor pages collected for bonus.
	if Lore.all_floor_collected(GameState.current_floor):
		var bonus_lbl := Label.new()
		bonus_lbl.text = "All lore on this floor collected! +%d Glimbos" % Lore.COLLECT_ALL_BONUS
		bonus_lbl.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
		bonus_lbl.add_theme_color_override("font_color", PuzzleStyle.NONO_ACCENT)
		bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(bonus_lbl)
		SaveSystem.add_glimbos(Lore.COLLECT_ALL_BONUS)
	var close := Button.new()
	close.text = "Continue"
	PuzzleStyle.apply_button_style(close,
		PuzzleStyle.button_style(PuzzleStyle.NONO_CELL_EMPTY, 0.12))
	close.pressed.connect(func():
		_clear_overlay()
		_set_backdrop(false)
		_dungeon.set_active(true)
		_autosave()
	)
	v.add_child(close)

func _flash_damage() -> void:
	if bool(SaveSystem.setting("reduced_motion", false)):
		return
	var flash := ColorRect.new()
	flash.color = Color(0.9, 0.1, 0.1, 0.35)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)

func _on_run_ended(_won: bool) -> void:
	_dungeon.set_active(false)
	Audio.stop_ambient()
	SaveSystem.clear_run()
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/ui/end_screen.tscn")

func _show_act_intro(floor_num: int) -> void:
	if bool(SaveSystem.setting("reduced_motion", false)):
		return
	var idx: int = clamp(floor_num - 1, 0, FLOOR_NAMES.size() - 1)
	var accent: Color = PuzzleStyle.accent_for_floor(floor_num)
	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.offset_left = -260
	card.offset_top = -90
	card.offset_right = 260
	card.offset_bottom = 90
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stl: StyleBoxFlat = PuzzleStyle.panel_style(PuzzleStyle.NONO_PANEL, accent)
	card.add_theme_stylebox_override("panel", stl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var eyebrow := Label.new()
	eyebrow.text = "FLOOR %d" % floor_num
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(eyebrow)
	var title := Label.new()
	title.text = FLOOR_NAMES[idx]
	title.add_theme_font_size_override("font_size", PuzzleStyle.FONT_DISPLAY)
	title.add_theme_color_override("font_color", accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var quote := Label.new()
	quote.text = FLOOR_QUOTES[idx]
	quote.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
	quote.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(quote)
	_overlay.add_child(card)
	card.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.4)
	tw.tween_property(card, "modulate:a", 0.0, 0.4)
	tw.tween_callback(card.queue_free)

func _autosave() -> void:
	# Don't autosave dailies so the daily can't be save-scummed.
	if GameState.is_daily_run:
		return
	var elapsed: float = (Time.get_ticks_msec() - GameState.run_started_ticks) / 1000.0
	var snap: Dictionary = {
		"active": true,
		"character_id": GameState.character_id,
		"floor": GameState.current_floor,
		"hp": GameState.hp,
		"max_hp": GameState.max_hp,
		"glimbos_run": GameState.glimbos_this_run,
		"puzzles_run": GameState.puzzles_this_run,
		"puzzles_on_floor": GameState.puzzles_solved_on_floor,
		"curse": GameState.curse_on_floor,
		"is_daily": GameState.is_daily_run,
		"daily_key": GameState.daily_date_key,
		"elapsed_sec": elapsed,
		"puzzles_remaining_on_floor": RunManager.puzzles_remaining(),
		"dungeon": _dungeon.snapshot(),
	}
	SaveSystem.save_run(snap)

func _clear_overlay() -> void:
	for c in _overlay.get_children():
		if c == _backdrop:
			continue
		c.queue_free()
	_current_board = null
	_current_shop = null

func _set_backdrop(on: bool) -> void:
	if _backdrop == null:
		return
	_backdrop.visible = on
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE

func _update_hud() -> void:
	var daily_tag := "  [DAILY]" if GameState.is_daily_run else ""
	var curse_tag := ""
	if GameState.curse_on_floor > 0:
		curse_tag = "  Curse: %d" % GameState.curse_on_floor
	_hud.text = "HP %d/%d     Floor %d/%d     Puzzles left: %d     Glimbos: %d run / %d total%s%s" % [
		GameState.hp, GameState.max_hp,
		GameState.current_floor, RunManager.FLOORS_PER_RUN,
		RunManager.puzzles_remaining(),
		GameState.glimbos_this_run, int(SaveSystem.data.glimbos),
		curse_tag, daily_tag,
	]
