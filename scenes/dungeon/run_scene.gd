extends Control

const DungeonScene := preload("res://scenes/dungeon/dungeon.tscn")
const NonogramBoardScene := preload("res://scenes/puzzles/nonogram_board.tscn")

const GLIMBO_REWARD_PER_SIZE := {5: 3, 10: 8, 15: 15}

@onready var _hud: Label = $HUD/HPGlimbos
@onready var _message: Label = $HUD/Message
@onready var _dungeon_layer: Node2D = $DungeonLayer
@onready var _overlay: Control = $Overlay

var _dungeon: Node2D
var _current_board: NonogramBoard
var _current_size: int = 5

func _ready() -> void:
	_dungeon = DungeonScene.instantiate()
	_dungeon_layer.add_child(_dungeon)
	_dungeon.trigger_entered.connect(_on_trigger_entered)
	RunManager.room_entered.connect(_on_room_entered)
	GameState.run_ended.connect(_on_run_ended)
	GameState.hp_changed.connect(func(_c, _m): _update_hud())
	GameState.glimbos_earned.connect(func(_a, _b): _update_hud())
	RunManager.begin_floor()
	_update_hud()

func _on_room_entered(room_type: String, idx: int) -> void:
	_message.text = "Floor %d — Room %d/%d (%s)" % [
		GameState.current_floor, idx + 1, RunManager.ROOMS_PER_FLOOR, room_type
	]
	_dungeon.load_room(room_type)
	_clear_overlay()

func _on_trigger_entered(room_type: String) -> void:
	match room_type:
		"PUZZLE":
			_open_puzzle(_current_size)
		"SHOP":
			_message.text = "Shop room — (not implemented yet). Press SPACE to advance."
			set_process_unhandled_input(true)
		"BOSS":
			_open_puzzle(10)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if _message.text.begins_with("Shop room"):
			RunManager.advance_room()

func _open_puzzle(size: int) -> void:
	_clear_overlay()
	var puzzle := NonogramGenerator.generate(size, 0.55, true)
	_current_board = NonogramBoardScene.instantiate()
	_current_board.position = Vector2(40, 40)
	_overlay.add_child(_current_board)
	_current_board.load_puzzle(puzzle)
	_current_board.solved.connect(_on_puzzle_solved.bind(size))
	_current_board.failed.connect(_on_puzzle_failed)

func _on_puzzle_solved(_wrong: int, size: int) -> void:
	var reward: int = GLIMBO_REWARD_PER_SIZE.get(size, 3)
	GameState.award_glimbos(reward)
	await get_tree().create_timer(0.6).timeout
	RunManager.advance_room()

func _on_puzzle_failed(wrong: int) -> void:
	GameState.take_damage(wrong)

func _on_run_ended(won: bool) -> void:
	_message.text = "Run ended — won: %s" % str(won)
	_dungeon.set_active(false)

func _clear_overlay() -> void:
	for c in _overlay.get_children():
		c.queue_free()
	_current_board = null

func _update_hud() -> void:
	_hud.text = "HP: %d/%d   Glimbos(run): %d   Total: %d" % [
		GameState.hp, GameState.max_hp, GameState.glimbos_this_run, int(SaveSystem.data.glimbos)
	]
