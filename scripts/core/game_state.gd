extends Node

signal hp_changed(current: int, max_hp: int)
signal run_started
signal run_ended(won: bool)
signal glimbos_earned(amount: int, total_this_run: int)

const STARTING_HP := 20

var max_hp: int = STARTING_HP
var hp: int = STARTING_HP
var glimbos_this_run: int = 0
var current_floor: int = 0
var room_index: int = 0
var is_daily_run: bool = false

func start_run(daily: bool = false) -> void:
	is_daily_run = daily
	max_hp = STARTING_HP
	hp = STARTING_HP
	glimbos_this_run = 0
	current_floor = 1
	room_index = 0
	if daily:
		RNG.set_seed(RNG.daily_seed())
	else:
		RNG.randomize_from_time()
	SaveSystem.data.stats.runs_started = int(SaveSystem.data.stats.runs_started) + 1
	SaveSystem.save_to_disk()
	run_started.emit()

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		end_run(false)

func award_glimbos(amount: int) -> void:
	glimbos_this_run += amount
	SaveSystem.add_glimbos(amount)
	SaveSystem.data.stats.puzzles_solved = int(SaveSystem.data.stats.puzzles_solved) + 1
	SaveSystem.save_to_disk()
	glimbos_earned.emit(amount, glimbos_this_run)

func end_run(won: bool) -> void:
	if won:
		SaveSystem.data.stats.runs_won = int(SaveSystem.data.stats.runs_won) + 1
		SaveSystem.save_to_disk()
	run_ended.emit(won)
