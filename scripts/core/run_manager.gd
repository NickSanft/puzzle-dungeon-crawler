extends Node

signal room_entered(room_type: String, index: int)
signal floor_completed(floor_num: int)

const ROOMS_PER_FLOOR := 8
const FLOORS_PER_RUN := 1

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
		begin_floor()
		return
	_enter_next()

func _enter_next() -> void:
	var room: RoomType = _floor_plan[GameState.room_index]
	room_entered.emit(RoomType.keys()[room], GameState.room_index)
