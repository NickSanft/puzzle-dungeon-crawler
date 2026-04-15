extends Control

@onready var _label: Label = $VBox/Status
@onready var _start_btn: Button = $VBox/StartRun
@onready var _daily_btn: Button = $VBox/StartDaily

func _ready() -> void:
	_start_btn.pressed.connect(_on_start_run)
	_daily_btn.pressed.connect(_on_start_daily)
	GameState.run_started.connect(_refresh)
	GameState.run_ended.connect(_on_run_ended)
	_refresh()

func _refresh() -> void:
	var g: int = int(SaveSystem.data.glimbos)
	_label.text = "Glimbos: %d\nSeed: %d\nHP: %d / %d" % [g, RNG.seed_value, GameState.hp, GameState.max_hp]

func _on_start_run() -> void:
	GameState.start_run(false)

func _on_start_daily() -> void:
	GameState.start_run(true)

func _on_run_ended(won: bool) -> void:
	_label.text = "Run ended. Won: %s" % str(won)
