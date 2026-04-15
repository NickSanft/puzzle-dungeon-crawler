extends Control

@onready var _headline: Label = $Panel/VBox/Headline
@onready var _summary: Label = $Panel/VBox/Summary
@onready var _title_btn: Button = $Panel/VBox/Actions/ToTitle
@onready var _retry_btn: Button = $Panel/VBox/Actions/Retry

var _won: bool = false
var _was_daily: bool = false
var _summary_data: Dictionary = {}

func configure(won: bool, summary: Dictionary, was_daily: bool) -> void:
	_won = won
	_was_daily = was_daily
	_summary_data = summary

func _ready() -> void:
	_title_btn.pressed.connect(_on_title)
	_retry_btn.pressed.connect(_on_retry)
	if _won:
		_headline.text = "Run Complete!"
	else:
		_headline.text = "You Fell to the Puzzles"
	var lines: Array[String] = []
	lines.append("Floor reached: %d" % int(_summary_data.get("floor", 1)))
	lines.append("Puzzles solved this run: %d" % int(_summary_data.get("puzzles_run", 0)))
	lines.append("Glimbos earned this run: %d" % int(_summary_data.get("glimbos_run", 0)))
	lines.append("HP at end: %d / %d" % [
		int(_summary_data.get("hp", 0)),
		int(_summary_data.get("max_hp", 0)),
	])
	lines.append("Time: %.1fs" % float(_summary_data.get("time_sec", 0.0)))
	if _was_daily:
		lines.append("")
		lines.append("Daily seed: %s" % str(_summary_data.get("daily_key", "")))
	_summary.text = "\n".join(lines)

func _on_title() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main.tscn")

func _on_retry() -> void:
	GameState.start_run(_was_daily)
	get_tree().change_scene_to_file("res://scenes/dungeon/run_scene.tscn")
