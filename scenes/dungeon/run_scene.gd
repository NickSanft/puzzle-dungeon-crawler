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
@onready var _dungeon_layer: Node2D = $DungeonLayer
@onready var _overlay: Control = $Overlay

var _dungeon: Node2D
var _current_board: Node
var _current_room_type: String = "PUZZLE"
var _current_shop: GlimboShop
var _current_boss_name: String = ""

func _ready() -> void:
	_dungeon = DungeonScene.instantiate()
	_dungeon_layer.add_child(_dungeon)
	_dungeon.trigger_entered.connect(_on_trigger_entered)
	RunManager.room_entered.connect(_on_room_entered)
	RunManager.floor_completed.connect(_on_floor_completed)
	GameState.run_ended.connect(_on_run_ended)
	GameState.hp_changed.connect(func(_c, _m): _update_hud())
	GameState.glimbos_earned.connect(func(_a, _b): _update_hud())
	RunManager.begin_floor()
	_update_hud()

func _on_room_entered(room_type: String, idx: int) -> void:
	_message.text = "Floor %d/%d — Room %d/%d (%s)" % [
		GameState.current_floor, RunManager.FLOORS_PER_RUN,
		idx + 1, RunManager.ROOMS_PER_FLOOR, room_type
	]
	_dungeon.load_room(room_type)
	_dungeon.set_active(true)
	_clear_overlay()

func _on_trigger_entered(room_type: String) -> void:
	_current_room_type = room_type
	match room_type:
		"PUZZLE":
			_open_puzzle(RunManager.puzzle_size_for(GameState.current_floor))
		"SHOP":
			_open_shop()
		"BOSS":
			_open_boss()

func _on_floor_completed(floor_num: int) -> void:
	if floor_num >= RunManager.FLOORS_PER_RUN:
		return
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
	RunManager.start_next_floor()

func _open_puzzle(puzzle_size: int) -> void:
	_clear_overlay()
	if _should_use_sudoku():
		_open_sudoku()
		return
	var use_color: bool = SaveSystem.has_unlock("color_nonograms") and GameState.room_index >= 3
	var density: float = RunManager.density_for(GameState.current_floor)
	var puzzle: NonogramPuzzle
	if use_color:
		puzzle = NonogramGenerator.generate_color(puzzle_size, density)
	else:
		puzzle = NonogramGenerator.generate(puzzle_size, density, true)
	var board: NonogramBoard = NonogramBoardScene.instantiate()
	board.position = Vector2(40, 40)
	_overlay.add_child(board)
	board.load_puzzle(puzzle, _starting_hints())
	board.solved.connect(_on_puzzle_solved.bind(puzzle_size))
	board.failed.connect(_on_puzzle_failed)
	_current_board = board

func _should_use_sudoku() -> bool:
	# Deterministic alternation so both puzzle types always appear in a run.
	# Offset by floor so floors don't all start with the same type.
	return (GameState.room_index + GameState.current_floor) % 2 == 1

func _open_sudoku() -> void:
	var blanks: int = 40 + GameState.current_floor * 3
	var puzzle: SudokuPuzzle = SudokuGenerator.generate(blanks)
	var board: SudokuBoard = SudokuBoardScene.instantiate()
	board.position = Vector2(40, 40)
	_overlay.add_child(board)
	board.load_puzzle(puzzle)
	board.solved.connect(_on_sudoku_solved)
	board.failed.connect(_on_puzzle_failed)
	_current_board = board

func _on_sudoku_solved(_wrong: int) -> void:
	GameState.award_glimbos(SUDOKU_REWARD)
	await get_tree().create_timer(0.6).timeout
	RunManager.advance_room()

func _starting_hints() -> int:
	return 1 if SaveSystem.has_unlock("puzzle_hint") else 0

func _on_puzzle_solved(_wrong: int, puzzle_size: int) -> void:
	var reward: int = GLIMBO_REWARD_PER_SIZE.get(puzzle_size, 3)
	if _current_room_type == "BOSS" and SaveSystem.has_unlock("extra_reward"):
		reward *= 2
	GameState.award_glimbos(reward)
	await get_tree().create_timer(0.6).timeout
	RunManager.advance_room()

func _open_boss() -> void:
	_clear_overlay()
	var use_color: bool = SaveSystem.has_unlock("color_nonograms")
	var boss: Dictionary = NonogramGenerator.from_boss_pattern(use_color)
	_current_boss_name = str(boss.name)
	_message.text = "BOSS: %s" % boss.name
	var board: NonogramBoard = NonogramBoardScene.instantiate()
	board.position = Vector2(40, 40)
	_overlay.add_child(board)
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
	var banner := Label.new()
	banner.text = "%s DEFEATED!" % _current_boss_name.to_upper()
	banner.add_theme_font_size_override("font_size", 42)
	banner.position = Vector2(40, 460)
	_overlay.add_child(banner)
	await get_tree().create_timer(1.8).timeout
	RunManager.advance_room()

func _open_shop() -> void:
	_clear_overlay()
	_current_shop = ShopScene.instantiate()
	_overlay.add_child(_current_shop)
	_current_shop.closed.connect(_on_shop_closed)

func _on_shop_closed() -> void:
	_clear_overlay()
	RunManager.advance_room()

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
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/ui/end_screen.tscn")

func _clear_overlay() -> void:
	for c in _overlay.get_children():
		c.queue_free()
	_current_board = null
	_current_shop = null

func _update_hud() -> void:
	var daily_tag := "  [DAILY]" if GameState.is_daily_run else ""
	_hud.text = "HP %d/%d     Glimbos: %d this run (%d total)%s" % [
		GameState.hp, GameState.max_hp,
		GameState.glimbos_this_run, int(SaveSystem.data.glimbos),
		daily_tag,
	]
