extends Node

signal hp_changed(current: int, max_hp: int)
signal run_started
signal run_ended(won: bool)
signal glimbos_earned(amount: int, total_this_run: int)

const STARTING_HP := 20
const DAMAGE_CAP := 4

var max_hp: int = STARTING_HP
var hp: int = STARTING_HP
var glimbos_this_run: int = 0
var puzzles_this_run: int = 0
var current_floor: int = 0
var room_index: int = 0
var is_daily_run: bool = false
var run_started_ticks: int = 0
var daily_date_key: String = ""
var last_summary: Dictionary = {}
var last_won: bool = false

func start_run(daily: bool = false) -> void:
	is_daily_run = daily
	max_hp = STARTING_HP + _bonus_max_hp()
	hp = max_hp
	glimbos_this_run = 0
	puzzles_this_run = 0
	current_floor = 1
	room_index = 0
	run_started_ticks = Time.get_ticks_msec()
	if daily:
		daily_date_key = RNG.today_key()
		RNG.set_seed(RNG.daily_seed(daily_date_key))
	else:
		daily_date_key = ""
		RNG.randomize_from_time()
	SaveSystem.data.stats.runs_started = int(SaveSystem.data.stats.runs_started) + 1
	SaveSystem.save_to_disk()
	run_started.emit()

func take_damage(amount: int) -> void:
	var applied: int = min(amount, DAMAGE_CAP) if SaveSystem.has_unlock("damage_cap") else amount
	hp = max(0, hp - applied)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		end_run(false)

func award_glimbos(amount: int) -> void:
	var total: int = amount
	if SaveSystem.has_unlock("glimbo_bonus"):
		total += 1
	glimbos_this_run += total
	puzzles_this_run += 1
	SaveSystem.add_glimbos(total)
	SaveSystem.data.stats.puzzles_solved = int(SaveSystem.data.stats.puzzles_solved) + 1
	SaveSystem.save_to_disk()
	glimbos_earned.emit(amount, glimbos_this_run)

func end_run(won: bool) -> void:
	if won:
		SaveSystem.data.stats.runs_won = int(SaveSystem.data.stats.runs_won) + 1
		SaveSystem.save_to_disk()
	var elapsed: float = (Time.get_ticks_msec() - run_started_ticks) / 1000.0
	if is_daily_run and daily_date_key != "":
		SaveSystem.record_daily(daily_date_key, {
			"hp_remaining": hp,
			"time_sec": elapsed,
			"won": won,
			"floor": current_floor,
			"glimbos": glimbos_this_run,
		})
	last_won = won
	last_summary = {
		"floor": current_floor,
		"puzzles_run": puzzles_this_run,
		"glimbos_run": glimbos_this_run,
		"hp": hp,
		"max_hp": max_hp,
		"time_sec": elapsed,
		"daily_key": daily_date_key,
		"was_daily": is_daily_run,
	}
	run_ended.emit(won)

func _bonus_max_hp() -> int:
	var bonus := 0
	if SaveSystem.has_unlock("hp_up_1"):
		bonus += 5
	if SaveSystem.has_unlock("hp_up_2"):
		bonus += 5
	return bonus
