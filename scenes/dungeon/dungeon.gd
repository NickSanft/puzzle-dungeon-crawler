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
const COLOR_CEILING_TOP := Color(0.04, 0.04, 0.06)
const COLOR_CEILING_HORIZON := Color(0.12, 0.11, 0.14)
const COLOR_FLOOR_HORIZON := Color(0.1, 0.09, 0.08)
const COLOR_FLOOR_BOTTOM := Color(0.2, 0.17, 0.14)
const COLOR_WALL_NEAR := Color(0.34, 0.28, 0.22)   # warm stone near the player
const COLOR_WALL_FAR_TINT := Color(0.12, 0.13, 0.18) # cool shadow at max depth
const COLOR_WALL_EDGE := Color(0.55, 0.48, 0.4, 0.35) # highlight along top edges
const COLOR_FOG := Color(0.06, 0.06, 0.1)           # distance fade target
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
const COLOR_MINIMAP_TRAIL := Color(0.4, 0.9, 0.5, 0.35)
const COLOR_MINIMAP_SOLVED := Color(0.45, 0.45, 0.45, 0.6)
const COLOR_MINIMAP_PATH := Color(0.75, 0.65, 0.35, 0.4)
const COLOR_TORCH := Color(0.95, 0.7, 0.3)
const COLOR_FLOOR_PATTERN_A := Color(0.14, 0.12, 0.1, 0.25)
const COLOR_FLOOR_PATTERN_B := Color(0.18, 0.15, 0.12, 0.25)
const COLOR_DOOR_FRAME := Color(0.6, 0.5, 0.35, 0.7)
const TRAIL_MAX := 30

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
var _trail: Array[Vector2i] = []
var _solved_positions: Array[Vector2i] = []

# Animation state.
var _is_animating: bool = false
var _anim_kind: String = ""  # "forward", "back", "turn", "strafe"
var _anim_progress: float = 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	# Continuous redraw for the trigger glow pulse animation.
	if not _triggers.is_empty():
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
	_trail.clear()
	_solved_positions.clear()
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
	_trail.append(target)
	if _trail.size() > TRAIL_MAX:
		_trail.remove_at(0)
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
			_solved_positions.append(t.pos as Vector2i)
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
	var depth_offset: float = 0.0
	if _anim_kind == "forward":
		depth_offset = -_anim_progress
	elif _anim_kind == "back":
		depth_offset = _anim_progress
	var parallax_x: float = 0.0

	# --- Ceiling / floor gradients (6 strips each) -----------------------
	var half_h: float = VIEW_H * 0.5
	var grad_steps: int = 6
	for i in grad_steps:
		var t0: float = float(i) / float(grad_steps)
		var t1: float = float(i + 1) / float(grad_steps)
		# Ceiling: dark at top → lighter at horizon
		var c_top: Color = COLOR_CEILING_TOP.lerp(COLOR_CEILING_HORIZON, t0)
		var c_bot: Color = COLOR_CEILING_TOP.lerp(COLOR_CEILING_HORIZON, t1)
		var cy: float = t0 * half_h
		var ch: float = (t1 - t0) * half_h
		draw_rect(Rect2(0, cy, VIEW_W, ch), c_top.lerp(c_bot, 0.5))
		# Floor: dark at horizon → lighter at bottom
		var f_top: Color = COLOR_FLOOR_HORIZON.lerp(COLOR_FLOOR_BOTTOM, t0)
		var f_bot: Color = COLOR_FLOOR_HORIZON.lerp(COLOR_FLOOR_BOTTOM, t1)
		var fy: float = half_h + t0 * half_h
		var fh: float = (t1 - t0) * half_h
		draw_rect(Rect2(0, fy, VIEW_W, fh), f_top.lerp(f_bot, 0.5))

	var fwd_v: Vector2i = FACING_VECTORS[_player_facing]
	var left_v: Vector2i = FACING_VECTORS[(_player_facing + 3) % 4]
	var right_v: Vector2i = FACING_VECTORS[(_player_facing + 1) % 4]

	var blocker: int = MAX_VIS_DEPTH + 1
	for d in range(1, MAX_VIS_DEPTH + 1):
		var tt: Vector2i = _player_pos + fwd_v * d
		if _is_wall_or_oob(tt):
			blocker = d
			break

	# Trigger floor markers (behind walls so nearer walls occlude them).
	var last_open: int = min(blocker - 1, MAX_VIS_DEPTH)
	for d in range(1, last_open + 1):
		var tt: Vector2i = _player_pos + fwd_v * d
		var trig: Dictionary = _trigger_at(tt)
		if not trig.is_empty():
			_draw_trigger_marker(float(d) + depth_offset, parallax_x, str(trig.type))

	# Back wall at the blocker, fogged toward distance.
	if blocker <= MAX_VIS_DEPTH:
		var fog_t: float = float(blocker) / float(MAX_VIS_DEPTH)
		var back_col: Color = _wall_color_at(fog_t).lerp(COLOR_FOG, fog_t * 0.6)
		var back_frame: Rect2 = _frame_at(float(blocker) + depth_offset)
		back_frame.position.x += parallax_x
		draw_rect(back_frame, back_col)
		# Top-edge highlight on the back wall.
		draw_line(
			Vector2(back_frame.position.x, back_frame.position.y),
			Vector2(back_frame.position.x + back_frame.size.x, back_frame.position.y),
			COLOR_WALL_EDGE, 1.0)

	# Side walls: far to near with warm→cool gradient + distance fog + edge highlights.
	# Also: floor pattern, torch glow, door frames.
	for depth in range(last_open, -1, -1):
		var tile_pos: Vector2i = _player_pos + fwd_v * depth
		var near_frame: Rect2 = _frame_at(float(depth) + depth_offset)
		var far_frame: Rect2 = _frame_at(float(depth + 1) + depth_offset)
		near_frame.position.x += parallax_x
		far_frame.position.x += parallax_x
		var fog_near: float = float(depth) / float(MAX_VIS_DEPTH)

		# Parallax floor pattern (checkerboard between frames).
		_draw_floor_pattern(near_frame, far_frame, depth, depth_offset)

		# Torch flicker: warm glow at intersections brightens nearby walls.
		var torch: float = _torch_brightness(depth)

		if _is_wall_or_oob(tile_pos + left_v):
			var col: Color = _wall_color_at(fog_near).lerp(COLOR_FOG, fog_near * 0.5)
			col = col.darkened(0.08)
			if torch > 0.0:
				col = col.lerp(COLOR_TORCH, torch)
			var quad_l := PackedVector2Array([
				Vector2(near_frame.position.x, near_frame.position.y),
				Vector2(far_frame.position.x, far_frame.position.y),
				Vector2(far_frame.position.x, far_frame.position.y + far_frame.size.y),
				Vector2(near_frame.position.x, near_frame.position.y + near_frame.size.y),
			])
			draw_colored_polygon(quad_l, col)
			draw_line(
				Vector2(near_frame.position.x, near_frame.position.y),
				Vector2(far_frame.position.x, far_frame.position.y),
				COLOR_WALL_EDGE, 1.0)

		if _is_wall_or_oob(tile_pos + right_v):
			var col: Color = _wall_color_at(fog_near).lerp(COLOR_FOG, fog_near * 0.45)
			if torch > 0.0:
				col = col.lerp(COLOR_TORCH, torch)
			var nx: float = near_frame.position.x + near_frame.size.x
			var fx: float = far_frame.position.x + far_frame.size.x
			var quad_r := PackedVector2Array([
				Vector2(nx, near_frame.position.y),
				Vector2(fx, far_frame.position.y),
				Vector2(fx, far_frame.position.y + far_frame.size.y),
				Vector2(nx, near_frame.position.y + near_frame.size.y),
			])
			draw_colored_polygon(quad_r, col)
			draw_line(
				Vector2(nx, near_frame.position.y),
				Vector2(fx, far_frame.position.y),
				COLOR_WALL_EDGE, 1.0)

		# Door frames on tiles that contain a trigger.
		var trig_at_depth: Dictionary = _trigger_at(tile_pos)
		if not trig_at_depth.is_empty() and depth >= 1:
			_draw_door_frame(near_frame, far_frame, str(trig_at_depth.type))

# Warm near-stone → cool far-shadow wall colour by distance fraction.
func _wall_color_at(t: float) -> Color:
	return COLOR_WALL_NEAR.lerp(COLOR_WALL_FAR_TINT, t)

# Is the tile at pos an intersection? (3+ open floor neighbours = corridor crossing)
func _is_intersection(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= _tw or pos.y >= _th:
		return false
	if int(_tiles[pos.y][pos.x]) == Tile.WALL:
		return false
	var open: int = 0
	for d in FACING_VECTORS:
		var n: Vector2i = pos + d
		if n.x >= 0 and n.y >= 0 and n.x < _tw and n.y < _th and int(_tiles[n.y][n.x]) == Tile.FLOOR:
			open += 1
	return open >= 3

# Draw a parallax checkerboard on the floor between two depth frames.
func _draw_floor_pattern(near_f: Rect2, far_f: Rect2, depth: int, depth_offset: float) -> void:
	var y_far: float = far_f.position.y + far_f.size.y
	var y_near: float = near_f.position.y + near_f.size.y
	var x_left_near: float = near_f.position.x
	var x_right_near: float = near_f.position.x + near_f.size.x
	var x_left_far: float = far_f.position.x
	var x_right_far: float = far_f.position.x + far_f.size.x
	# Split the floor band into a 2-column checker.
	var mid_y: float = (y_far + y_near) * 0.5
	var mid_x_near: float = (x_left_near + x_right_near) * 0.5
	var mid_x_far: float = (x_left_far + x_right_far) * 0.5
	var parity: int = (depth + int(abs(depth_offset) * 2.0)) % 2
	var col_a: Color = COLOR_FLOOR_PATTERN_A if parity == 0 else COLOR_FLOOR_PATTERN_B
	var col_b: Color = COLOR_FLOOR_PATTERN_B if parity == 0 else COLOR_FLOOR_PATTERN_A
	# Left half top
	draw_colored_polygon(PackedVector2Array([
		Vector2(x_left_far, y_far), Vector2(mid_x_far, y_far),
		Vector2(mid_x_near, mid_y), Vector2(x_left_near, mid_y)]), col_a)
	# Right half top
	draw_colored_polygon(PackedVector2Array([
		Vector2(mid_x_far, y_far), Vector2(x_right_far, y_far),
		Vector2(x_right_near, mid_y), Vector2(mid_x_near, mid_y)]), col_b)
	# Left half bottom
	draw_colored_polygon(PackedVector2Array([
		Vector2(x_left_near, mid_y), Vector2(mid_x_near, mid_y),
		Vector2(mid_x_near, y_near), Vector2(x_left_near, y_near)]), col_b)
	# Right half bottom
	draw_colored_polygon(PackedVector2Array([
		Vector2(mid_x_near, mid_y), Vector2(x_right_near, mid_y),
		Vector2(x_right_near, y_near), Vector2(mid_x_near, y_near)]), col_a)

# Draw a doorway frame when a trigger is at a certain depth.
func _draw_door_frame(near_f: Rect2, far_f: Rect2, trigger_type: String) -> void:
	var col: Color = _trigger_color(trigger_type).lerp(COLOR_DOOR_FRAME, 0.5)
	# Left pillar
	draw_line(Vector2(far_f.position.x + 4, far_f.position.y),
		Vector2(far_f.position.x + 4, far_f.position.y + far_f.size.y), col, 2.0)
	# Right pillar
	var rx: float = far_f.position.x + far_f.size.x - 4
	draw_line(Vector2(rx, far_f.position.y),
		Vector2(rx, far_f.position.y + far_f.size.y), col, 2.0)
	# Lintel (top bar)
	draw_line(Vector2(far_f.position.x + 4, far_f.position.y + 2),
		Vector2(rx, far_f.position.y + 2), col, 2.5)

# Torch flicker: add warm glow on walls near intersections.
func _torch_brightness(depth: int) -> float:
	# Returns 0.0 if no torch here, ~0.15–0.25 if a torch is nearby.
	var fwd_v: Vector2i = FACING_VECTORS[_player_facing]
	var tile: Vector2i = _player_pos + fwd_v * depth
	if not _is_intersection(tile):
		return 0.0
	var flicker: float = 0.18 + 0.07 * sin(Time.get_ticks_msec() * 0.006 + float(depth) * 1.7)
	return flicker

func _draw_trigger_marker(depth: float, parallax_x: float, trigger_type: String) -> void:
	var near_frame: Rect2 = _frame_at(depth)
	var far_frame: Rect2 = _frame_at(depth + 1)
	var y_far: float = far_frame.position.y + far_frame.size.y
	var y_near: float = near_frame.position.y + near_frame.size.y
	var mid_y: float = (y_far + y_near) * 0.5
	var half_h: float = max(2.0, (y_near - y_far) * 0.35)
	var cx: float = VIEW_W * 0.5 + parallax_x
	var half_w: float = max(3.0, far_frame.size.x * 0.25)
	# Glow pulse — triggers shimmer so they're visible from afar.
	var pulse: float = 1.0 + 0.18 * sin(Time.get_ticks_msec() * 0.004)
	var base_col: Color = _trigger_color(trigger_type)
	var col: Color = Color(
		clamp(base_col.r * pulse, 0, 1),
		clamp(base_col.g * pulse, 0, 1),
		clamp(base_col.b * pulse, 0, 1),
		base_col.a)
	var quad := PackedVector2Array([
		Vector2(cx - half_w, mid_y - half_h),
		Vector2(cx + half_w, mid_y - half_h),
		Vector2(cx + half_w, mid_y + half_h),
		Vector2(cx - half_w, mid_y + half_h),
	])
	draw_colored_polygon(quad, col)

func _draw_turn_fade() -> void:
	# Fade down then back up, peaking at midpoint. Hides the facing snap.
	var alpha: float = sin(_anim_progress * PI) * 0.75
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0, 0, 0, alpha))

func _draw_minimap() -> void:
	var mw: int = _tw * MINIMAP_TILE
	var mh: int = _th * MINIMAP_TILE
	var origin := Vector2(VIEW_W - mw - MINIMAP_MARGIN, MINIMAP_MARGIN)
	draw_rect(Rect2(origin - Vector2(4, 4), Vector2(mw + 8, mh + 8)), COLOR_MINIMAP_BG)
	# Base tiles.
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
	# Trail: fading dots showing where the player has been.
	for i in _trail.size():
		var t: float = float(i) / float(max(1, _trail.size()))
		var tp: Vector2i = _trail[i]
		var tpc: Vector2 = origin + Vector2(
			tp.x * MINIMAP_TILE + MINIMAP_TILE * 0.5,
			tp.y * MINIMAP_TILE + MINIMAP_TILE * 0.5)
		draw_circle(tpc, MINIMAP_TILE * 0.2,
			Color(COLOR_MINIMAP_TRAIL.r, COLOR_MINIMAP_TRAIL.g, COLOR_MINIMAP_TRAIL.b,
				COLOR_MINIMAP_TRAIL.a * t))
	# Solved trigger locations (grey breadcrumbs).
	for sp in _solved_positions:
		var spc: Vector2 = origin + Vector2(
			sp.x * MINIMAP_TILE + MINIMAP_TILE * 0.5,
			sp.y * MINIMAP_TILE + MINIMAP_TILE * 0.5)
		draw_circle(spc, MINIMAP_TILE * 0.25, COLOR_MINIMAP_SOLVED)
	# Path to nearest unsolved trigger (dim accent dots).
	_draw_minimap_path(origin)
	# Active triggers.
	for trig in _triggers:
		var tp: Vector2i = trig.pos
		if not (_debug_reveal_all or _character_reveal_all or _revealed.has(tp)):
			continue
		draw_rect(Rect2(
			origin + Vector2(tp.x * MINIMAP_TILE, tp.y * MINIMAP_TILE),
			Vector2(MINIMAP_TILE, MINIMAP_TILE)), _trigger_color(str(trig.type)))
	# Player dot with pulse.
	var pulse: float = 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.005)
	var pc: Vector2 = origin + Vector2(
		_player_pos.x * MINIMAP_TILE + MINIMAP_TILE * 0.5,
		_player_pos.y * MINIMAP_TILE + MINIMAP_TILE * 0.5)
	draw_circle(pc, MINIMAP_TILE * 0.45 * pulse, COLOR_MINIMAP_PLAYER)
	# Facing chevron.
	var fv: Vector2i = FACING_VECTORS[_player_facing]
	var fdir := Vector2(fv.x, fv.y)
	var perp := Vector2(-fdir.y, fdir.x)
	var tip: Vector2 = pc + fdir * MINIMAP_TILE * 0.6
	var base_l: Vector2 = pc - fdir * MINIMAP_TILE * 0.3 - perp * MINIMAP_TILE * 0.35
	var base_r: Vector2 = pc - fdir * MINIMAP_TILE * 0.3 + perp * MINIMAP_TILE * 0.35
	draw_colored_polygon(PackedVector2Array([tip, base_l, base_r]), COLOR_MINIMAP_FACING)

func _draw_minimap_path(origin: Vector2) -> void:
	# BFS from player to the nearest unsolved trigger; draw the path as dots.
	if _triggers.is_empty() or _tiles.is_empty():
		return
	var target_set: Dictionary = {}
	for t in _triggers:
		target_set[t.pos as Vector2i] = true
	var dist: Dictionary = {_player_pos: 0}
	var prev: Dictionary = {}
	var q: Array[Vector2i] = [_player_pos]
	var found: Vector2i = Vector2i(-1, -1)
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if target_set.has(cur) and cur != _player_pos:
			found = cur
			break
		for d in FACING_VECTORS:
			var n: Vector2i = cur + d
			if n.x < 0 or n.y < 0 or n.x >= _tw or n.y >= _th:
				continue
			if int(_tiles[n.y][n.x]) == Tile.WALL:
				continue
			if dist.has(n):
				continue
			dist[n] = int(dist[cur]) + 1
			prev[n] = cur
			q.append(n)
	if found.x < 0:
		return
	# Trace back and draw.
	var path: Array[Vector2i] = []
	var step: Vector2i = found
	while prev.has(step):
		path.append(step)
		step = prev[step]
	for p in path:
		if not (_debug_reveal_all or _character_reveal_all or _revealed.has(p)):
			continue
		var ppc: Vector2 = origin + Vector2(
			p.x * MINIMAP_TILE + MINIMAP_TILE * 0.5,
			p.y * MINIMAP_TILE + MINIMAP_TILE * 0.5)
		draw_circle(ppc, MINIMAP_TILE * 0.15, COLOR_MINIMAP_PATH)

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
