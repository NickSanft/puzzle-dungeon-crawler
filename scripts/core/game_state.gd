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
# Curse counter: rises as the player solves puzzles on the current floor.
# Boss difficulty scales with this; skipping puzzles keeps the boss leaner.
var curse_on_floor: int = 0
var puzzles_solved_on_floor: int = 0
var character_id: String = "scholar"

func start_run(daily: bool = false) -> void:
	is_daily_run = daily
	var char_hp_delta: int = int(Characters.effect(character_id, "max_hp_delta", 0))
	max_hp = max(5, STARTING_HP + _bonus_max_hp() + char_hp_delta)
	hp = max_hp
	glimbos_this_run = 0
	puzzles_this_run = 0
	current_floor = 1
	room_index = 0
	curse_on_floor = 0
	puzzles_solved_on_floor = 0
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
	total += int(Characters.effect(character_id, "glimbo_bonus_per_solve", 0))
	glimbos_this_run += total
	puzzles_this_run += 1
	puzzles_solved_on_floor += 1
	curse_on_floor += 1
	# The Glutton pays HP for each solve.
	var hp_cost: int = int(Characters.effect(character_id, "hp_cost_per_solve", 0))
	if hp_cost > 0:
		hp = max(0, hp - hp_cost)
		hp_changed.emit(hp, max_hp)
		if hp == 0:
			end_run(false)
			return
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
	last_summary["rating"] = classify_run(last_summary, won)
	run_ended.emit(won)

func _bonus_max_hp() -> int:
	var bonus := 0
	if SaveSystem.has_unlock("hp_up_1"):
		bonus += 5
	if SaveSystem.has_unlock("hp_up_2"):
		bonus += 5
	return bonus

func on_floor_changed() -> void:
	curse_on_floor = 0
	puzzles_solved_on_floor = 0

# Clamped bonus delta to apply to boss grid density as the player solves
# more puzzles on this floor. Returns a positive number: bosses get denser
# (harder) for players who cleared every chamber before finishing.
func boss_density_bonus() -> float:
	return min(0.15, float(curse_on_floor) * 0.025)

# Returns multiplier for boss reward. Rushing (few puzzles solved on floor)
# grants a bigger payout; grinding everything first pays normally.
func boss_reward_multiplier() -> float:
	if puzzles_solved_on_floor <= 1:
		return 1.6  # true rush
	elif puzzles_solved_on_floor <= 2:
		return 1.25
	return 1.0

func classify_run(summary: Dictionary, won: bool) -> String:
	if not won:
		if int(summary.get("floor", 1)) >= 3:
			return "Last Light"  # died on the final floor
		return "Folded Paper"    # died before floor 3
	var hp_frac: float = float(summary.get("hp", 0)) / max(1.0, float(summary.get("max_hp", 1)))
	var time_sec: float = float(summary.get("time_sec", 999.0))
	var puzzles: int = int(summary.get("puzzles_run", 0))
	if hp_frac >= 0.9 and time_sec <= 900.0:
		return "Serene Clear"
	if hp_frac <= 0.2:
		return "White-Knuckle"
	if puzzles >= 12:
		return "Puzzle Massacre"
	if time_sec <= 600.0:
		return "Lightning Scribe"
	return "Quiet Victory"
