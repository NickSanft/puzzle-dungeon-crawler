extends Control

@onready var _headline: Label = $Panel/VBox/Headline
@onready var _summary: Label = $Panel/VBox/Summary
@onready var _title_btn: Button = $Panel/VBox/Actions/ToTitle
@onready var _retry_btn: Button = $Panel/VBox/Actions/Retry

func _ready() -> void:
	_title_btn.pressed.connect(_on_title)
	_retry_btn.pressed.connect(_on_retry)
	var summary: Dictionary = GameState.last_summary
	var won: bool = GameState.last_won
	if won:
		_headline.text = "Run Complete!"
	else:
		_headline.text = "You Fell to the Puzzles"
	var lines: Array[String] = []
	lines.append("Floor reached: %d" % int(summary.get("floor", 1)))
	lines.append("Puzzles solved this run: %d" % int(summary.get("puzzles_run", 0)))
	lines.append("Glimbos earned this run: %d" % int(summary.get("glimbos_run", 0)))
	lines.append("HP at end: %d / %d" % [
		int(summary.get("hp", 0)),
		int(summary.get("max_hp", 0)),
	])
	lines.append("Time: %.1fs" % float(summary.get("time_sec", 0.0)))
	if bool(summary.get("was_daily", false)):
		lines.append("")
		lines.append("Daily seed: %s" % str(summary.get("daily_key", "")))
	_summary.text = "\n".join(lines)

func _on_title() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main.tscn")

func _on_retry() -> void:
	var was_daily: bool = bool(GameState.last_summary.get("was_daily", false))
	GameState.start_run(was_daily)
	get_tree().change_scene_to_file("res://scenes/dungeon/run_scene.tscn")
