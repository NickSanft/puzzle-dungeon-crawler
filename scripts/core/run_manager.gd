extends Node

signal floor_started(floor_num: int, tiles: Array, triggers: Array, entrance: Vector2i)
signal floor_completed(floor_num: int)
signal trigger_resolved(kind: String, remaining: int)
signal puzzle_remaining_changed(puzzles_remaining: int)

const FLOORS_PER_RUN := 3
const MAZE_CELL_W := 9
const MAZE_CELL_H := 6
# How many puzzle chambers appear on each floor (by floor index).
const PUZZLES_PER_FLOOR: Array[int] = [3, 4, 5]
const PUZZLE_SIZE_BY_FLOOR: Array[int] = [5, 7, 10]
const DENSITY_BY_FLOOR: Array[float] = [0.55, 0.6, 0.65]

var _puzzles_remaining: int = 0
var _shop_pending: bool = false

func puzzle_size_for(floor_num: int) -> int:
	var idx: int = clamp(floor_num - 1, 0, PUZZLE_SIZE_BY_FLOOR.size() - 1)
	return PUZZLE_SIZE_BY_FLOOR[idx]

func density_for(floor_num: int) -> float:
	var idx: int = clamp(floor_num - 1, 0, DENSITY_BY_FLOOR.size() - 1)
	return DENSITY_BY_FLOOR[idx]

func puzzles_remaining() -> int:
	return _puzzles_remaining

func set_puzzles_remaining(n: int) -> void:
	_puzzles_remaining = max(0, n)
	puzzle_remaining_changed.emit(_puzzles_remaining)

func begin_floor() -> void:
	var maze: Dictionary = MazeGenerator.generate(MAZE_CELL_W, MAZE_CELL_H)
	var tiles: Array = maze.tiles
	var dead_ends: Array = maze.dead_ends
	var entrance := Vector2i(1, 1)
	var distances: Dictionary = MazeGenerator.bfs_distances(tiles, entrance)
	# Exclude the entrance from candidates.
	var candidates: Array = []
	for p in dead_ends:
		if p != entrance and distances.has(p):
			candidates.append(p)
	candidates.sort_custom(func(a, b): return int(distances[a]) > int(distances[b]))

	var triggers: Array = []
	# Boss at the farthest dead-end.
	if candidates.size() > 0:
		triggers.append({"pos": candidates[0], "type": "BOSS"})
		candidates.remove_at(0)
	# Shop at a mid-distance dead-end so it's not too close to either extreme.
	if candidates.size() > 0:
		var mid_idx: int = candidates.size() / 2
		triggers.append({"pos": candidates[mid_idx], "type": "SHOP"})
		candidates.remove_at(mid_idx)
	# Puzzles at remaining dead-ends (up to the per-floor quota).
	var want: int = PUZZLES_PER_FLOOR[clamp(GameState.current_floor - 1, 0, PUZZLES_PER_FLOOR.size() - 1)]
	var puzzle_count: int = min(want, candidates.size())
	for i in puzzle_count:
		triggers.append({"pos": candidates[i], "type": "PUZZLE"})

	_puzzles_remaining = puzzle_count
	_shop_pending = triggers.any(func(t): return t.type == "SHOP")
	floor_started.emit(GameState.current_floor, tiles, triggers, entrance)
	puzzle_remaining_changed.emit(_puzzles_remaining)

func on_trigger_resolved(kind: String) -> void:
	match kind:
		"PUZZLE":
			_puzzles_remaining = max(0, _puzzles_remaining - 1)
			puzzle_remaining_changed.emit(_puzzles_remaining)
		"SHOP":
			_shop_pending = false
		"BOSS":
			floor_completed.emit(GameState.current_floor)
			if GameState.current_floor >= FLOORS_PER_RUN:
				GameState.end_run(true)
				return
			GameState.current_floor += 1
			return
	trigger_resolved.emit(kind, _puzzles_remaining)
