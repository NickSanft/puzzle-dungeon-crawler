extends Control

const NonogramBoardScene := preload("res://scenes/puzzles/nonogram_board.tscn")

const GLIMBO_REWARD_PER_SIZE := {5: 3, 10: 8, 15: 15}

@onready var _label: Label = $VBox/Status
@onready var _start_btn: Button = $VBox/StartRun
@onready var _daily_btn: Button = $VBox/StartDaily
@onready var _puzzle_btn: Button = $VBox/TestPuzzle
@onready var _vbox: VBoxContainer = $VBox

var _current_board: NonogramBoard
var _current_size: int = 5

func _ready() -> void:
	_start_btn.pressed.connect(_on_start_run)
	_daily_btn.pressed.connect(_on_start_daily)
	_puzzle_btn.pressed.connect(_on_test_puzzle)
	GameState.run_started.connect(_refresh)
	GameState.run_ended.connect(_on_run_ended)
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.glimbos_earned.connect(func(_a, _b): _refresh())
	_refresh()

func _refresh() -> void:
	var g: int = int(SaveSystem.data.glimbos)
	_label.text = "Glimbos: %d   Seed: %d   HP: %d / %d" % [g, RNG.seed_value, GameState.hp, GameState.max_hp]

func _on_hp_changed(_c: int, _m: int) -> void:
	_refresh()

func _on_start_run() -> void:
	GameState.start_run(false)

func _on_start_daily() -> void:
	GameState.start_run(true)

func _on_run_ended(won: bool) -> void:
	_label.text = "Run ended. Won: %s" % str(won)

func _on_test_puzzle() -> void:
	if _current_board and is_instance_valid(_current_board):
		_current_board.queue_free()
	var puzzle := NonogramGenerator.generate(_current_size, 0.55, true)
	_current_board = NonogramBoardScene.instantiate()
	_current_board.size = Vector2(500, 500)
	_current_board.position = Vector2(40, 40)
	add_child(_current_board)
	_current_board.load_puzzle(puzzle)
	_current_board.solved.connect(_on_puzzle_solved)
	_current_board.failed.connect(_on_puzzle_failed)

func _on_puzzle_solved(_wrong: int) -> void:
	var reward: int = GLIMBO_REWARD_PER_SIZE.get(_current_size, 3)
	GameState.award_glimbos(reward)

func _on_puzzle_failed(wrong: int) -> void:
	GameState.take_damage(wrong)
