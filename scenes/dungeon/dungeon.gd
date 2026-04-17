class_name Dungeon
extends Node2D

# --- First-person view config ---
const VIEW_W := 480
const VIEW_H := 352
const MAX_VIS_DEPTH := 6
const DEPTH_SCALE := 0.62  # concentric-frame shrink per depth

# --- Minimap ---
const MINIMAP_TILE := 6
const MINIMAP_MARGIN := 8

# --- Animation ---
const STEP_DURATION := 0.14
const TURN_DURATION := 0.14

# --- Fog of war ---
const VISION_RADIUS := 3  # BFS steps through floors the player can see

const COLOR_MINIMAP_UNSEEN := Color(0.02, 0.02, 0.03)

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
const COLOR_WALL_SIDE := Color(0.22, 0.2, 0.18)
const COLOR_WALL_FRONT := Color(0.32, 0.28, 0.25)
const COLOR_WALL_FAR := Color(0.12, 0.11, 0.1)
const COLOR_TRIGGER_PUZZLE := Color(0.95, 0.65, 0.25)
const COLOR_TRIGGER_SHOP := Color(0.65, 0.45, 0.95)
const COLOR_TRIGGER_BOSS := Color(0.95, 0.3, 0.35)
const COLOR_TRIGGER_TRAP := Color(0.85, 0.75, 0.2)
const COLOR_TRIGGER_LORE := Color(0.55, 0.85, 0.65)
const COLOR_MINIMAP_BG := Color(0, 0, 0, 0.6)
const COLOR_MINIMAP_FLOOR := Color(0.25, 0.22, 0.2)
const COLOR_MINIMAP_WALL := Color(0.05, 0.05, 0.07)
const COLOR_MINIMAP_PLAYER := Color(0.4, 0.9, 0.5)
const COLOR_MINIMAP_FACING := Color(0.1, 0.25, 0.12)

enum Tile { FLOOR, WALL }

signal trigger_entered(trigger_data: Dictionary)

var _tiles: Array = []
var _tw: int = 0
var _th: int = 0
var _triggers: Array = []  # [{pos: Vector2i, type: String}]
var _player_pos: Vector2i = Vector2i(1, 1)
var _player_facing: int = 1
var _active: bool = true

var _revealed: Dictionary = {}  # Vector2i -> true
var _debug_reveal_all: bool = false
var _character_reveal_all: bool = false  # e.g. Archivist permanent reveal

# Animation state.
var _is_animating: bool = false
var _anim_kind: String = ""  # "forward", "back", "turn", "strafe"
var _anim_progress: float = 0.0

func _ready() -> void:
	queue_redraw()

func load_maze(tiles: Array, triggers: Array, entrance: Vector2i) -> void:
	_tiles = tiles
	_th = tiles.size()
	_tw = 0
	if _th > 0:
		_tw = tiles[0].size()
	_triggers = triggers.duplicate(true)
	_player_pos = entrance
	_player_facing = 1
	_active = true
	_is_animating = false
	_anim_kind = ""
	_anim_progress = 0.0
	_revealed.clear()
	_update_visibility()
	queue_redraw()

func set_active(flag: bool) -> void:
	_active = flag

func set_debug_reveal_all(flag: bool) -> void:
	_debug_reveal_all = flag
	queue_redraw()

func set_character_reveal_all(flag: bool) -> void:
	_character_reveal_all = flag
	queue_redraw()

# --- Persistence helpers -------------------------------------------------

func snapshot() -> Dictionary:
	var revealed_cells: Array = []
	for key in _revealed.keys():
		var v: Vector2i = key
		revealed_cells.append([v.x, v.y])
	var trig_out: Array = []
	for t in _triggers:
		var p: Vector2i = t.pos
		trig_out.append({"pos": [p.x, p.y], "type": str(t.type)})
	return {
		"tiles": _tiles.duplicate(true),
		"triggers": trig_out,
		"player_pos": [_player_pos.x, _player_pos.y],
		"player_facing": _player_facing,
		"revealed": revealed_cells,
	}

func restore(snap: Dictionary) -> void:
	var tiles: Array = snap.get("tiles", [])
	var raw_triggers: Array = snap.get("triggers", [])
	var pos_arr: Array = snap.get("player_pos", [1, 1])
	var facing: int = int(snap.get("player_facing", 1))
	var restored_triggers: Array = []
	for t in raw_triggers:
		var p: Array = t.get("pos", [0, 0])
		restored_triggers.append({
			"pos": Vector2i(int(p[0]), int(p[1])),
			"type": str(t.get("type", "PUZZLE")),
		})
	load_maze(tiles, restored_triggers, Vector2i(int(pos_arr[0]), int(pos_arr[1])))
	_player_facing = facing
	_revealed.clear()
	for rc in snap.get("revealed", []):
		_revealed[Vector2i(int(rc[0]), int(rc[1]))] = true
	queue_redraw()

func _update_visibility() -> void:
	# BFS from the player through floor tiles up to VISION_RADIUS steps.
	# Then also reveal walls immediately adjacent to any newly-seen floor
	# so the minimap shows corridor outlines, not just passable cells.
	var dist: Dictionary = {_player_pos: 0}
	var q: Array[Vector2i] = [_player_pos]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		_revealed[cur] = true
		var d: int = int(dist[cur])
		if d >= VISION_RADIUS:
			continue
		for dv in FACING_VECTORS:
			var n: Vector2i = cur + dv
			if n.x < 0 or n.y < 0 or n.x >= _tw or n.y >= _th:
				continue
			if int(_tiles[n.y][n.x]) == Tile.WALL:
				_revealed[n] = true
				continue
			if dist.has(n):
				continue
			dist[n] = d + 1
			q.append(n)

# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _is_animating or _tiles.is_empty():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_W, KEY_UP:
			_try_step(1, 0, "forward")
		KEY_S, KEY_DOWN:
			_try_step(-1, 0, "back")
		KEY_A:
			_try_step(0, -1, "strafe")
		KEY_D:
			_try_step(0, 1, "strafe")
		KEY_Q, KEY_LEFT:
			_begin_turn(-1)
		KEY_E, KEY_RIGHT:
			_begin_turn(1)

func _try_step(forward: int, strafe: int, kind: String) -> void:
	var fwd: Vector2i = FACING_VECTORS[_player_facing] * forward
	var side: Vector2i = _perpendicular(_player_facing) * strafe
	var delta: Vector2i = fwd + side
	if delta == Vector2i.ZERO:
		return
	var next: Vector2i = _player_pos + delta
	if not _is_walkable(next):
		Audio.play_damage()
		return
	_begin_move(next, kind)

func _begin_move(target: Vector2i, kind: String) -> void:
	_is_animating = true
	_anim_kind = kind
	_anim_progress = 0.0
	Audio.play_click()
	var tw := create_tween()
	tw.tween_method(_set_anim_progress, 0.0, 1.0, STEP_DURATION)
	tw.tween_callback(_finish_move.bind(target))

func _finish_move(target: Vector2i) -> void:
	_player_pos = target
	_is_animating = false
	_anim_kind = ""
	_anim_progress = 0.0
	_update_visibility()
	queue_redraw()
	_check_trigger()

func _begin_turn(delta: int) -> void:
	_is_animating = true
	_anim_kind = "turn"
	_anim_progress = 0.0
	Audio.play_mark()
	var tw := create_tween()
	tw.tween_method(_set_anim_progress, 0.0, 1.0, TURN_DURATION)
	# Snap the logical facing at the midpoint so the fade hides the change.
	tw.parallel().tween_callback(_snap_turn.bind(delta)).set_delay(TURN_DURATION * 0.5)
	tw.tween_callback(_finish_turn)

func _snap_turn(delta: int) -> void:
	_player_facing = (_player_facing + delta + 4) % 4

func _finish_turn() -> void:
	_is_animating = false
	_anim_kind = ""
	_anim_progress = 0.0
	queue_redraw()

func _set_anim_progress(v: float) -> void:
	_anim_progress = v
	queue_redraw()

func _check_trigger() -> void:
	for i in _triggers.size():
		var t: Dictionary = _triggers[i]
		if (t.pos as Vector2i) == _player_pos:
			_triggers.remove_at(i)
			_active = false
			trigger_entered.emit(t)
			return

# --- Helpers ---

func _is_walkable(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= _tw or t.y >= _th:
		return false
	return int(_tiles[t.y][t.x]) != Tile.WALL

func _is_wall_or_oob(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= _tw or t.y >= _th:
		return true
	return int(_tiles[t.y][t.x]) == Tile.WALL

static func _perpendicular(facing: int) -> Vector2i:
	return FACING_VECTORS[(facing + 1) % 4]

static func _frame_at(depth: float) -> Rect2:
	var s: float = pow(DEPTH_SCALE, depth)
	var w: float = VIEW_W * s
	var h: float = VIEW_H * s
	return Rect2((VIEW_W - w) * 0.5, (VIEW_H - h) * 0.5, w, h)

# --- Drawing ---

func _draw() -> void:
	if _tiles.is_empty():
		return
	_draw_first_person()
	_draw_minimap()
	if _anim_kind == "turn":
		_draw_turn_fade()

func _draw_first_person() -> void:
	# Depth offset during forward/back animation so the perspective glides.
	var depth_offset: float = 0.0
	if _anim_kind == "forward":
		depth_offset = -_anim_progress
	elif _anim_kind == "back":
		depth_offset = _anim_progress
	# Strafe intentionally has no parallax: a "lean and return" sinusoid
	# reads as a wall-bump shake, not sideways motion. The minimap chevron
	# sliding to the new tile is feedback enough.
	var parallax_x: float = 0.0

	draw_rect(Rect2(parallax_x, 0, VIEW_W, VIEW_H * 0.5), COLOR_CEILING)
	draw_rect(Rect2(parallax_x, VIEW_H * 0.5, VIEW_W, VIEW_H * 0.5), COLOR_FLOOR)

	var fwd_v: Vector2i = FACING_VECTORS[_player_facing]
	var left_v: Vector2i = FACING_VECTORS[(_player_facing + 3) % 4]
	var right_v: Vector2i = FACING_VECTORS[(_player_facing + 1) % 4]

	var blocker: int = MAX_VIS_DEPTH + 1
	for d in range(1, MAX_VIS_DEPTH + 1):
		var tt: Vector2i = _player_pos + fwd_v * d
		if _is_wall_or_oob(tt):
			blocker = d
			break

	# Trigger floor markers behind walls so nearer walls occlude them.
	# Triggers can only be on open tiles: depths 1..blocker-1 (the tile at
	# depth=blocker is the wall itself).
	var last_open: int = min(blocker - 1, MAX_VIS_DEPTH)
	for d in range(1, last_open + 1):
		var tt: Vector2i = _player_pos + fwd_v * d
		var trig: Dictionary = _trigger_at(tt)
		if not trig.is_empty():
			_draw_trigger_marker(float(d) + depth_offset, parallax_x, trig.type)

	if blocker <= MAX_VIS_DEPTH:
		var back_frame: Rect2 = _frame_at(float(blocker) + depth_offset)
		back_frame.position.x += parallax_x
		draw_rect(back_frame, COLOR_WALL_FAR)

	# Side walls are drawn for each open tile in the forward corridor, from
	# far to near so nearer sides occlude farther ones. Skip the blocker
	# depth (that tile is a wall; its sides are undefined).
	for depth in range(last_open, -1, -1):
		var tile_pos: Vector2i = _player_pos + fwd_v * depth
		var near_frame: Rect2 = _frame_at(float(depth) + depth_offset)
		var far_frame: Rect2 = _frame_at(float(depth + 1) + depth_offset)
		near_frame.position.x += parallax_x
		far_frame.position.x += parallax_x

		if _is_wall_or_oob(tile_pos + left_v):
			var quad_l := PackedVector2Array([
				Vector2(near_frame.position.x, near_frame.position.y),
				Vector2(far_frame.position.x, far_frame.position.y),
				Vector2(far_frame.position.x, far_frame.position.y + far_frame.size.y),
				Vector2(near_frame.position.x, near_frame.position.y + near_frame.size.y),
			])
			draw_colored_polygon(quad_l, COLOR_WALL_SIDE.darkened(depth * 0.06))

		if _is_wall_or_oob(tile_pos + right_v):
			var nx: float = near_frame.position.x + near_frame.size.x
			var fx: float = far_frame.position.x + far_frame.size.x
			var quad_r := PackedVector2Array([
				Vector2(nx, near_frame.position.y),
				Vector2(fx, far_frame.position.y),
				Vector2(fx, far_frame.position.y + far_frame.size.y),
				Vector2(nx, near_frame.position.y + near_frame.size.y),
			])
			draw_colored_polygon(quad_r, COLOR_WALL_FRONT.darkened(depth * 0.06))

func _draw_trigger_marker(depth: float, parallax_x: float, trigger_type: String) -> void:
	var near_frame: Rect2 = _frame_at(depth)
	var far_frame: Rect2 = _frame_at(depth + 1)
	var y_far: float = far_frame.position.y + far_frame.size.y
	var y_near: float = near_frame.position.y + near_frame.size.y
	var mid_y: float = (y_far + y_near) * 0.5
	var half_h: float = max(2.0, (y_near - y_far) * 0.35)
	var cx: float = VIEW_W * 0.5 + parallax_x
	var half_w: float = max(3.0, far_frame.size.x * 0.25)
	var quad := PackedVector2Array([
		Vector2(cx - half_w, mid_y - half_h),
		Vector2(cx + half_w, mid_y - half_h),
		Vector2(cx + half_w, mid_y + half_h),
		Vector2(cx - half_w, mid_y + half_h),
	])
	draw_colored_polygon(quad, _trigger_color(trigger_type))

func _draw_turn_fade() -> void:
	# Fade down then back up, peaking at midpoint. Hides the facing snap.
	var alpha: float = sin(_anim_progress * PI) * 0.75
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0, 0, 0, alpha))

func _draw_minimap() -> void:
	var mw: int = _tw * MINIMAP_TILE
	var mh: int = _th * MINIMAP_TILE
	var origin := Vector2(VIEW_W - mw - MINIMAP_MARGIN, MINIMAP_MARGIN)
	draw_rect(Rect2(origin - Vector2(4, 4), Vector2(mw + 8, mh + 8)), COLOR_MINIMAP_BG)
	for y in _th:
		for x in _tw:
			var rect := Rect2(
				origin + Vector2(x * MINIMAP_TILE, y * MINIMAP_TILE),
				Vector2(MINIMAP_TILE, MINIMAP_TILE))
			var cell := Vector2i(x, y)
			if not (_debug_reveal_all or _character_reveal_all or _revealed.has(cell)):
				draw_rect(rect, COLOR_MINIMAP_UNSEEN)
				continue
			var c: Color = COLOR_MINIMAP_WALL if int(_tiles[y][x]) == Tile.WALL else COLOR_MINIMAP_FLOOR
			draw_rect(rect, c)
	for trig in _triggers:
		var tp: Vector2i = trig.pos
		if not (_debug_reveal_all or _revealed.has(tp)):
			continue
		draw_rect(Rect2(
			origin + Vector2(tp.x * MINIMAP_TILE, tp.y * MINIMAP_TILE),
			Vector2(MINIMAP_TILE, MINIMAP_TILE)), _trigger_color(trig.type))
	var pc: Vector2 = origin + Vector2(
		_player_pos.x * MINIMAP_TILE + MINIMAP_TILE * 0.5,
		_player_pos.y * MINIMAP_TILE + MINIMAP_TILE * 0.5)
	draw_circle(pc, MINIMAP_TILE * 0.45, COLOR_MINIMAP_PLAYER)
	var fv: Vector2i = FACING_VECTORS[_player_facing]
	var fdir := Vector2(fv.x, fv.y)
	var perp := Vector2(-fdir.y, fdir.x)
	var tip: Vector2 = pc + fdir * MINIMAP_TILE * 0.6
	var base_l: Vector2 = pc - fdir * MINIMAP_TILE * 0.3 - perp * MINIMAP_TILE * 0.35
	var base_r: Vector2 = pc - fdir * MINIMAP_TILE * 0.3 + perp * MINIMAP_TILE * 0.35
	draw_colored_polygon(PackedVector2Array([tip, base_l, base_r]), COLOR_MINIMAP_FACING)

func _trigger_at(pos: Vector2i) -> Dictionary:
	for t in _triggers:
		if (t.pos as Vector2i) == pos:
			return t
	return {}

func _trigger_color(t: String) -> Color:
	match t:
		"SHOP": return COLOR_TRIGGER_SHOP
		"BOSS": return COLOR_TRIGGER_BOSS
		"TRAP": return COLOR_TRIGGER_TRAP
		"LORE": return COLOR_TRIGGER_LORE
		_: return COLOR_TRIGGER_PUZZLE
