extends Node

signal room_entered(room_type: String, index: int)
signal floor_completed(floor_num: int)

const ROOMS_PER_FLOOR := 8
const FLOORS_PER_RUN := 3

const PUZZLE_SIZE_BY_FLOOR := [5, 7, 10]
const DENSITY_BY_FLOOR := [0.55, 0.6, 0.62]

func puzzle_size_for(floor_num: int) -> int:
	var idx: int = clamp(floor_num - 1, 0, PUZZLE_SIZE_BY_FLOOR.size() - 1)
	return PUZZLE_SIZE_BY_FLOOR[idx]

func density_for(floor_num: int) -> float:
	var idx: int = clamp(floor_num - 1, 0, DENSITY_BY_FLOOR.size() - 1)
	return DENSITY_BY_FLOOR[idx]

enum RoomType { PUZZLE, SHOP, BOSS }

var _floor_plan: Array[RoomType] = []

func begin_floor() -> void:
	_floor_plan = _generate_floor_plan()
	GameState.room_index = 0
	_enter_next()

func _generate_floor_plan() -> Array[RoomType]:
	var plan: Array[RoomType] = []
	for i in ROOMS_PER_FLOOR - 2:
		plan.append(RoomType.PUZZLE)
	plan.append(RoomType.SHOP)
	plan.append(RoomType.BOSS)
	return plan

func advance_room() -> void:
	GameState.room_index += 1
	if GameState.room_index >= _floor_plan.size():
		floor_completed.emit(GameState.current_floor)
		if GameState.current_floor >= FLOORS_PER_RUN:
			GameState.end_run(true)
			return
		GameState.current_floor += 1
		return
	_enter_next()

func start_next_floor() -> void:
	begin_floor()

func _enter_next() -> void:
	var room: RoomType = _floor_plan[GameState.room_index]
	room_entered.emit(RoomType.keys()[room], GameState.room_index)
