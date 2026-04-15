extends Node2D

const TILE_SIZE := 32
const ROOM_W := 15
const ROOM_H := 11
const ROOM_MID_Y := 5  # ROOM_H / 2

const COLOR_FLOOR := Color(0.18, 0.18, 0.22)
const COLOR_WALL := Color(0.08, 0.08, 0.1)
const COLOR_PLAYER := Color(0.4, 0.9, 0.5)
const COLOR_TRIGGER_PUZZLE := Color(0.9, 0.6, 0.2)
const COLOR_TRIGGER_SHOP := Color(0.6, 0.4, 0.9)
const COLOR_TRIGGER_BOSS := Color(0.9, 0.25, 0.3)
const COLOR_DOOR := Color(0.5, 0.5, 0.55)

enum Tile { FLOOR, WALL, DOOR }

signal trigger_entered(room_type: String)

var _tiles: Array = []
var _player_pos: Vector2i = Vector2i(1, 1)
var _trigger_pos: Vector2i = Vector2i(7, ROOM_MID_Y)
var _trigger_type: String = "PUZZLE"
var _active: bool = true

func _ready() -> void:
	_build_room()
	queue_redraw()

func _build_room() -> void:
	_tiles = []
	for y in ROOM_H:
		var row: Array = []
		for x in ROOM_W:
			if x == 0 or y == 0 or x == ROOM_W - 1 or y == ROOM_H - 1:
				row.append(Tile.WALL)
			else:
				row.append(Tile.FLOOR)
		_tiles.append(row)
	_player_pos = Vector2i(1, ROOM_MID_Y)
	_trigger_pos = Vector2i(ROOM_W - 3, ROOM_MID_Y)

func load_room(room_type: String) -> void:
	_trigger_type = room_type
	_active = true
	_build_room()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var dx := 0
	var dy := 0
	match event.keycode:
		KEY_W, KEY_UP: dy = -1
		KEY_S, KEY_DOWN: dy = 1
		KEY_A, KEY_LEFT: dx = -1
		KEY_D, KEY_RIGHT: dx = 1
		_: return
	_try_move(dx, dy)

func _try_move(dx: int, dy: int) -> void:
	var next := _player_pos + Vector2i(dx, dy)
	if next.x < 0 or next.y < 0 or next.x >= ROOM_W or next.y >= ROOM_H:
		return
	if _tiles[next.y][next.x] == Tile.WALL:
		return
	_player_pos = next
	queue_redraw()
	if _player_pos == _trigger_pos:
		_active = false
		trigger_entered.emit(_trigger_type)

func set_active(flag: bool) -> void:
	_active = flag

func _draw() -> void:
	for y in ROOM_H:
		for x in ROOM_W:
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var c := COLOR_FLOOR
			match _tiles[y][x]:
				Tile.WALL: c = COLOR_WALL
				Tile.DOOR: c = COLOR_DOOR
			draw_rect(rect, c)
	var tc := _trigger_color(_trigger_type)
	draw_rect(Rect2(_trigger_pos.x * TILE_SIZE + 4, _trigger_pos.y * TILE_SIZE + 4,
		TILE_SIZE - 8, TILE_SIZE - 8), tc)
	draw_rect(Rect2(_player_pos.x * TILE_SIZE + 6, _player_pos.y * TILE_SIZE + 6,
		TILE_SIZE - 12, TILE_SIZE - 12), COLOR_PLAYER)

func _trigger_color(t: String) -> Color:
	match t:
		"SHOP": return COLOR_TRIGGER_SHOP
		"BOSS": return COLOR_TRIGGER_BOSS
		_: return COLOR_TRIGGER_PUZZLE
