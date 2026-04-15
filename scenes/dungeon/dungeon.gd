class_name Dungeon
extends Node2D

# --- Grid / room config ---
const ROOM_W := 15
const ROOM_H := 11
const ROOM_MID_Y := 5  # ROOM_H / 2

# --- First-person view config ---
const VIEW_W := 480
const VIEW_H := 352
const MAX_VIS_DEPTH := 5
# Per-step shrink of the depth frame. Smaller = faster convergence = shorter-feeling corridor.
const DEPTH_SCALE := 0.62

# --- Minimap ---
const MINIMAP_TILE := 10
const MINIMAP_MARGIN := 8

# 0 = North, 1 = East, 2 = South, 3 = West
const FACING_VECTORS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

# --- Palette ---
const COLOR_CEILING := Color(0.09, 0.09, 0.12)
const COLOR_FLOOR := Color(0.16, 0.14, 0.12)
const COLOR_WALL_FRONT := Color(0.32, 0.28, 0.25)
const COLOR_WALL_SIDE := Color(0.22, 0.2, 0.18)
const COLOR_WALL_FAR := Color(0.12, 0.11, 0.1)
const COLOR_TRIGGER_PUZZLE := Color(0.95, 0.65, 0.25)
const COLOR_TRIGGER_SHOP := Color(0.65, 0.45, 0.95)
const COLOR_TRIGGER_BOSS := Color(0.95, 0.3, 0.35)
const COLOR_MINIMAP_BG := Color(0, 0, 0, 0.55)
const COLOR_MINIMAP_FLOOR := Color(0.25, 0.22, 0.2)
const COLOR_MINIMAP_WALL := Color(0.08, 0.08, 0.1)
const COLOR_MINIMAP_PLAYER := Color(0.4, 0.9, 0.5)
const COLOR_MINIMAP_FACING := Color(0.1, 0.25, 0.12)

enum Tile { FLOOR, WALL }

signal trigger_entered(room_type: String)

var _tiles: Array = []
var _player_pos: Vector2i = Vector2i(1, ROOM_MID_Y)
var _trigger_pos: Vector2i = Vector2i(ROOM_W - 3, ROOM_MID_Y)
var _trigger_type: String = "PUZZLE"
var _active: bool = true
var _player_facing: int = 1  # start facing East, toward the trigger

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
	_player_facing = 1

func load_room(room_type: String) -> void:
	_trigger_type = room_type
	_active = true
	_build_room()
	queue_redraw()

func set_active(flag: bool) -> void:
	_active = flag

# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_W, KEY_UP:
			_step_relative(1, 0)
		KEY_S, KEY_DOWN:
			_step_relative(-1, 0)
		KEY_A:
			_step_relative(0, -1)
		KEY_D:
			_step_relative(0, 1)
		KEY_Q, KEY_LEFT:
			_turn(-1)
		KEY_E, KEY_RIGHT:
			_turn(1)

func _step_relative(forward: int, strafe: int) -> void:
	var fwd: Vector2i = FACING_VECTORS[_player_facing] * forward
	var side: Vector2i = _perpendicular(_player_facing) * strafe
	var delta: Vector2i = fwd + side
	if delta == Vector2i.ZERO:
		return
	var next: Vector2i = _player_pos + delta
	if not _is_walkable(next):
		Audio.play_damage()
		return
	_player_pos = next
	Audio.play_click()
	queue_redraw()
	if _player_pos == _trigger_pos:
		_active = false
		trigger_entered.emit(_trigger_type)

func _turn(delta: int) -> void:
	_player_facing = (_player_facing + delta + 4) % 4
	Audio.play_mark()
	queue_redraw()

# --- Helpers ---

func _is_walkable(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= ROOM_W or t.y >= ROOM_H:
		return false
	return _tiles[t.y][t.x] != Tile.WALL

func _is_wall_or_oob(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= ROOM_W or t.y >= ROOM_H:
		return true
	return _tiles[t.y][t.x] == Tile.WALL

static func _perpendicular(facing: int) -> Vector2i:
	# Right-hand perpendicular: facing rotated 90° clockwise.
	return FACING_VECTORS[(facing + 1) % 4]

static func _frame_at(depth: int) -> Rect2:
	var s: float = pow(DEPTH_SCALE, float(depth))
	var w: float = VIEW_W * s
	var h: float = VIEW_H * s
	return Rect2((VIEW_W - w) * 0.5, (VIEW_H - h) * 0.5, w, h)

# --- Drawing ---

func _draw() -> void:
	_draw_first_person()
	_draw_minimap()

func _draw_first_person() -> void:
	# Ceiling + floor
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H * 0.5), COLOR_CEILING)
	draw_rect(Rect2(0, VIEW_H * 0.5, VIEW_W, VIEW_H * 0.5), COLOR_FLOOR)

	var fwd_idx: int = _player_facing
	var left_idx: int = (fwd_idx + 3) % 4
	var right_idx: int = (fwd_idx + 1) % 4
	var fwd_v: Vector2i = FACING_VECTORS[fwd_idx]
	var left_v: Vector2i = FACING_VECTORS[left_idx]
	var right_v: Vector2i = FACING_VECTORS[right_idx]

	# Find nearest wall directly in front.
	var blocker: int = MAX_VIS_DEPTH + 1
	for d in range(1, MAX_VIS_DEPTH + 1):
		var t: Vector2i = _player_pos + fwd_v * d
		if _is_wall_or_oob(t):
			blocker = d
			break

	# Draw trigger floor markers (painter: before walls so walls occlude them).
	for d in range(1, min(blocker, MAX_VIS_DEPTH) + 1):
		var t: Vector2i = _player_pos + fwd_v * d
		if t == _trigger_pos:
			_draw_trigger_marker(d)

	# Draw back wall at the blocker depth (or skip if open to MAX_VIS_DEPTH).
	if blocker <= MAX_VIS_DEPTH:
		var back_frame: Rect2 = _frame_at(blocker)
		draw_rect(back_frame, COLOR_WALL_FAR)

	# Draw side walls from far to near so nearer walls overlap.
	var deepest: int = min(blocker, MAX_VIS_DEPTH)
	for depth in range(deepest, -1, -1):
		var t: Vector2i = _player_pos + fwd_v * depth
		var left_t: Vector2i = t + left_v
		var right_t: Vector2i = t + right_v
		var near_frame: Rect2 = _frame_at(depth)
		var far_frame: Rect2 = _frame_at(depth + 1)

		if _is_wall_or_oob(left_t):
			var quad_l := PackedVector2Array([
				Vector2(near_frame.position.x, near_frame.position.y),
				Vector2(far_frame.position.x, far_frame.position.y),
				Vector2(far_frame.position.x, far_frame.position.y + far_frame.size.y),
				Vector2(near_frame.position.x, near_frame.position.y + near_frame.size.y),
			])
			draw_colored_polygon(quad_l, COLOR_WALL_SIDE.darkened(depth * 0.06))

		if _is_wall_or_oob(right_t):
			var nx: float = near_frame.position.x + near_frame.size.x
			var fx: float = far_frame.position.x + far_frame.size.x
			var quad_r := PackedVector2Array([
				Vector2(nx, near_frame.position.y),
				Vector2(fx, far_frame.position.y),
				Vector2(fx, far_frame.position.y + far_frame.size.y),
				Vector2(nx, near_frame.position.y + near_frame.size.y),
			])
			draw_colored_polygon(quad_r, COLOR_WALL_FRONT.darkened(depth * 0.06))

func _draw_trigger_marker(depth: int) -> void:
	var near_frame: Rect2 = _frame_at(depth)
	var far_frame: Rect2 = _frame_at(depth + 1)
	# Vertical band between far and near frame bottoms = the floor slice at this depth.
	var y_far: float = far_frame.position.y + far_frame.size.y
	var y_near: float = near_frame.position.y + near_frame.size.y
	var mid_y: float = (y_far + y_near) * 0.5
	var half_h: float = (y_near - y_far) * 0.35
	var cx: float = VIEW_W * 0.5
	var half_w: float = far_frame.size.x * 0.25
	var color: Color = _trigger_color(_trigger_type)
	var quad := PackedVector2Array([
		Vector2(cx - half_w, mid_y - half_h),
		Vector2(cx + half_w, mid_y - half_h),
		Vector2(cx + half_w, mid_y + half_h),
		Vector2(cx - half_w, mid_y + half_h),
	])
	draw_colored_polygon(quad, color)

func _draw_minimap() -> void:
	var mw: int = ROOM_W * MINIMAP_TILE
	var mh: int = ROOM_H * MINIMAP_TILE
	var origin := Vector2(VIEW_W - mw - MINIMAP_MARGIN, MINIMAP_MARGIN)
	# Backing panel.
	draw_rect(Rect2(origin - Vector2(4, 4), Vector2(mw + 8, mh + 8)), COLOR_MINIMAP_BG)
	for y in ROOM_H:
		for x in ROOM_W:
			var rect := Rect2(
				origin + Vector2(x * MINIMAP_TILE, y * MINIMAP_TILE),
				Vector2(MINIMAP_TILE, MINIMAP_TILE))
			var c: Color = COLOR_MINIMAP_WALL if _tiles[y][x] == Tile.WALL else COLOR_MINIMAP_FLOOR
			draw_rect(rect, c)
	# Trigger.
	draw_rect(Rect2(
		origin + Vector2(_trigger_pos.x * MINIMAP_TILE + 1, _trigger_pos.y * MINIMAP_TILE + 1),
		Vector2(MINIMAP_TILE - 2, MINIMAP_TILE - 2)), _trigger_color(_trigger_type))
	# Player body.
	var player_center: Vector2 = origin + Vector2(
		_player_pos.x * MINIMAP_TILE + MINIMAP_TILE * 0.5,
		_player_pos.y * MINIMAP_TILE + MINIMAP_TILE * 0.5)
	draw_circle(player_center, MINIMAP_TILE * 0.35, COLOR_MINIMAP_PLAYER)
	# Facing chevron.
	var fv: Vector2i = FACING_VECTORS[_player_facing]
	var fdir := Vector2(fv.x, fv.y)
	var perp := Vector2(-fdir.y, fdir.x)
	var tip: Vector2 = player_center + fdir * MINIMAP_TILE * 0.55
	var base_l: Vector2 = player_center + fdir * MINIMAP_TILE * 0.1 - perp * MINIMAP_TILE * 0.25
	var base_r: Vector2 = player_center + fdir * MINIMAP_TILE * 0.1 + perp * MINIMAP_TILE * 0.25
	draw_colored_polygon(PackedVector2Array([tip, base_l, base_r]), COLOR_MINIMAP_FACING)

func _trigger_color(t: String) -> Color:
	match t:
		"SHOP": return COLOR_TRIGGER_SHOP
		"BOSS": return COLOR_TRIGGER_BOSS
		_: return COLOR_TRIGGER_PUZZLE
