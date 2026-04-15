extends Control

const DungeonScene := preload("res://scenes/dungeon/dungeon.tscn")
const NonogramBoardScene := preload("res://scenes/puzzles/nonogram_board.tscn")
const ShopScene := preload("res://scenes/ui/shop.tscn")

const GLIMBO_REWARD_PER_SIZE := {5: 3, 10: 8, 15: 15}
const BOSS_SIZE := 10

@onready var _hud: Label = $HUD/HPGlimbos
@onready var _message: Label = $HUD/Message
@onready var _dungeon_layer: Node2D = $DungeonLayer
@onready var _overlay: Control = $Overlay

var _dungeon: Node2D
var _current_board: NonogramBoard
var _current_size: int = 5
var _current_room_type: String = "PUZZLE"
var _current_shop: GlimboShop
var _current_boss_name: String = ""

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
	_current_room_type = room_type
	match room_type:
		"PUZZLE":
			_open_puzzle(_current_size)
		"SHOP":
			_open_shop()
		"BOSS":
			_open_boss()

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
	if _current_room_type == "BOSS" and SaveSystem.has_unlock("extra_reward"):
		reward *= 2
	GameState.award_glimbos(reward)
	await get_tree().create_timer(0.6).timeout
	RunManager.advance_room()

func _open_boss() -> void:
	_clear_overlay()
	var boss := NonogramGenerator.from_boss_pattern()
	_current_boss_name = boss.name
	_message.text = "BOSS: %s" % boss.name
	_current_board = NonogramBoardScene.instantiate()
	_current_board.position = Vector2(40, 40)
	_overlay.add_child(_current_board)
	_current_board.load_puzzle(boss.puzzle)
	_current_board.solved.connect(_on_boss_solved)
	_current_board.failed.connect(_on_puzzle_failed)

func _on_boss_solved(_wrong: int) -> void:
	var reward: int = GLIMBO_REWARD_PER_SIZE.get(BOSS_SIZE, 8) * 2
	if SaveSystem.has_unlock("extra_reward"):
		reward *= 2
	GameState.award_glimbos(reward)
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

func _on_run_ended(won: bool) -> void:
	_message.text = "Run ended — won: %s" % str(won)
	_dungeon.set_active(false)
	var elapsed: float = (Time.get_ticks_msec() - GameState.run_started_ticks) / 1000.0
	var summary := {
		"floor": GameState.current_floor,
		"puzzles_run": GameState.puzzles_this_run,
		"glimbos_run": GameState.glimbos_this_run,
		"hp": GameState.hp,
		"max_hp": GameState.max_hp,
		"time_sec": elapsed,
		"daily_key": GameState.daily_date_key,
	}
	var was_daily := GameState.is_daily_run
	await get_tree().create_timer(0.8).timeout
	var end_scene := load("res://scenes/ui/end_screen.tscn").instantiate()
	end_scene.configure(won, summary, was_daily)
	get_tree().root.add_child(end_scene)
	queue_free()

func _clear_overlay() -> void:
	for c in _overlay.get_children():
		c.queue_free()
	_current_board = null
	_current_shop = null

func _update_hud() -> void:
	_hud.text = "HP: %d/%d   Glimbos(run): %d   Total: %d" % [
		GameState.hp, GameState.max_hp, GameState.glimbos_this_run, int(SaveSystem.data.glimbos)
	]
