extends Control

const DungeonScene := preload("res://scenes/dungeon/dungeon.tscn")
const NonogramBoardScene := preload("res://scenes/puzzles/nonogram_board.tscn")
const SudokuBoardScene := preload("res://scenes/puzzles/sudoku_board.tscn")
const ShopScene := preload("res://scenes/ui/shop.tscn")

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
	RunManager.begin_floor()
	_update_hud()
	Audio.start_ambient(0.45)

func _on_reveal_toggled(on: bool) -> void:
	_dungeon.set_debug_reveal_all(on)
	_reveal_btn.text = "Hide Map [DEBUG]" if on else "Reveal Map [DEBUG]"

func _on_floor_started(floor_num: int, tiles: Array, triggers: Array, entrance: Vector2i) -> void:
	_puzzles_solved_on_floor = 0
	_dungeon.load_maze(tiles, triggers, entrance)
	_dungeon.set_active(true)
	_clear_overlay()
	_message.text = "Floor %d / %d — %d puzzles, a shop, and a boss." % [
		floor_num, RunManager.FLOORS_PER_RUN, RunManager.puzzles_remaining(),
	]
	_update_hud()

func _on_puzzle_remaining_changed(_remaining: int) -> void:
	_update_hud()

func _on_trigger_entered(trigger_type: String) -> void:
	_current_room_type = trigger_type
	match trigger_type:
		"PUZZLE":
			_open_puzzle(RunManager.puzzle_size_for(GameState.current_floor))
		"SHOP":
			_open_shop()
		"BOSS":
			_open_boss()

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
	if _should_use_sudoku():
		_open_sudoku()
		return
	var use_color: bool = SaveSystem.has_unlock("color_nonograms") and _puzzles_solved_on_floor >= 2
	var density: float = RunManager.density_for(GameState.current_floor)
	var puzzle: NonogramPuzzle
	if use_color:
		puzzle = NonogramGenerator.generate_color(puzzle_size, density)
	else:
		puzzle = NonogramGenerator.generate(puzzle_size, density, true)
	var board: NonogramBoard = NonogramBoardScene.instantiate()
	_overlay.add_child(board)
	board.set_accent(PuzzleStyle.accent_for_floor(GameState.current_floor))
	board.load_puzzle(puzzle, _starting_hints())
	board.solved.connect(_on_puzzle_solved.bind(puzzle_size))
	board.failed.connect(_on_puzzle_failed)
	_current_board = board

func _should_use_sudoku() -> bool:
	return (_puzzles_solved_on_floor + GameState.current_floor) % 2 == 1

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

func _on_sudoku_solved(_wrong: int) -> void:
	GameState.award_glimbos(SUDOKU_REWARD)
	_puzzles_solved_on_floor += 1
	if _current_board != null and _current_board.has_method("show_reward_counter"):
		_current_board.show_reward_counter(SUDOKU_REWARD)
	await get_tree().create_timer(0.9).timeout
	_resume_exploration("PUZZLE")

func _starting_hints() -> int:
	return 1 if SaveSystem.has_unlock("puzzle_hint") else 0

func _on_puzzle_solved(_wrong: int, puzzle_size: int) -> void:
	var reward: int = GLIMBO_REWARD_PER_SIZE.get(puzzle_size, 3)
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
	_message.text = "BOSS: %s" % boss.name
	var board: NonogramBoard = NonogramBoardScene.instantiate()
	_overlay.add_child(board)
	board.set_accent(PuzzleStyle.accent_for_floor(GameState.current_floor))
	board.load_puzzle(boss.puzzle, _starting_hints())
	board.solved.connect(_on_boss_solved)
	board.failed.connect(_on_puzzle_failed)
	_current_board = board

func _on_boss_solved(_wrong: int) -> void:
	var reward: int = GLIMBO_REWARD_PER_SIZE.get(BOSS_SIZE, 8) * 2
	if SaveSystem.has_unlock("extra_reward"):
		reward *= 2
	GameState.award_glimbos(reward)
	Audio.play_boss_win()
	if _current_board != null and _current_board.has_method("show_reward_counter"):
		_current_board.show_reward_counter(reward)
	var banner := Label.new()
	banner.text = "%s DEFEATED!" % _current_boss_name.to_upper()
	banner.add_theme_font_size_override("font_size", 36)
	banner.position = Vector2(40, 460)
	_overlay.add_child(banner)
	await get_tree().create_timer(1.6).timeout
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

func _on_puzzle_failed(wrong: int) -> void:
	GameState.take_damage(wrong)
	_flash_damage()

func _flash_damage() -> void:
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
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/ui/end_screen.tscn")

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
	_hud.text = "HP %d/%d     Floor %d/%d     Puzzles left: %d     Glimbos: %d run / %d total%s" % [
		GameState.hp, GameState.max_hp,
		GameState.current_floor, RunManager.FLOORS_PER_RUN,
		RunManager.puzzles_remaining(),
		GameState.glimbos_this_run, int(SaveSystem.data.glimbos),
		daily_tag,
	]
