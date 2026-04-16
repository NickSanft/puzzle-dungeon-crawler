extends Control

const CharacterSelectScene := preload("res://scenes/ui/character_select.tscn")
const SettingsMenuScene := preload("res://scenes/ui/settings_menu.tscn")

@onready var _label: Label = $VBox/Status
@onready var _daily_info: Label = $VBox/DailyInfo
@onready var _continue_btn: Button = $VBox/Continue
@onready var _start_btn: Button = $VBox/StartRun
@onready var _daily_btn: Button = $VBox/StartDaily
@onready var _settings_btn: Button = $VBox/Settings

var _pending_daily: bool = false

func _ready() -> void:
	_continue_btn.pressed.connect(_on_continue)
	_start_btn.pressed.connect(_on_start_run)
	_daily_btn.pressed.connect(_on_start_daily)
	_settings_btn.pressed.connect(_on_open_settings)
	_continue_btn.visible = SaveSystem.has_saved_run()
	GameState.run_started.connect(_refresh)
	GameState.run_ended.connect(_on_run_ended)
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.glimbos_earned.connect(func(_a, _b): _refresh())
	_refresh()

func _refresh() -> void:
	var g: int = int(SaveSystem.data.glimbos)
	_label.text = "Glimbos: %d   Seed: %d   HP: %d / %d" % [g, RNG.seed_value, GameState.hp, GameState.max_hp]
	_refresh_daily()

func _refresh_daily() -> void:
	var key := RNG.today_key()
	var seed_value := RNG.daily_seed(key)
	var best: Dictionary = SaveSystem.get_daily(key)
	if best.is_empty():
		_daily_info.text = "Today's daily (%s)  seed=%d\nBest: — (not attempted)" % [key, seed_value]
	else:
		_daily_info.text = "Today's daily (%s)  seed=%d\nBest: HP %d, time %.1fs, floor %d%s" % [
			key, seed_value, int(best.hp_remaining), float(best.time_sec), int(best.get("floor", 1)),
			"  ✓ won" if bool(best.get("won", false)) else "",
		]

func _on_hp_changed(_c: int, _m: int) -> void:
	_refresh()

func _on_start_run() -> void:
	_pending_daily = false
	_show_character_select()

func _on_start_daily() -> void:
	_pending_daily = true
	_show_character_select()

func _show_character_select() -> void:
	var select: Control = CharacterSelectScene.instantiate()
	select.chosen.connect(_on_character_chosen)
	add_child(select)

func _on_character_chosen(character_id: String) -> void:
	GameState.character_id = character_id
	GameState.start_run(_pending_daily)
	get_tree().change_scene_to_file("res://scenes/dungeon/run_scene.tscn")

func _on_run_ended(won: bool) -> void:
	_label.text = "Run ended. Won: %s" % str(won)

func _on_continue() -> void:
	if not SaveSystem.has_saved_run():
		return
	var snap: Dictionary = SaveSystem.saved_run()
	GameState.character_id = str(snap.get("character_id", GameState.character_id))
	var packed := load("res://scenes/dungeon/run_scene.tscn") as PackedScene
	var instance: Node = packed.instantiate()
	if instance.has_method("begin_resume"):
		instance.begin_resume()
	get_tree().root.add_child(instance)
	var old_scene: Node = get_tree().current_scene
	get_tree().current_scene = instance
	if old_scene != null:
		old_scene.queue_free()

func _on_open_settings() -> void:
	var menu: Control = SettingsMenuScene.instantiate()
	menu.closed.connect(func(): menu.queue_free())
	add_child(menu)
