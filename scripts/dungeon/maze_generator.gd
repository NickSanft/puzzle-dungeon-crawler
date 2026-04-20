class_name MazeGenerator
extends RefCounted

# Recursive-backtracker maze on a cell grid; returns a tile grid
# (2 * cell_w + 1) by (2 * cell_h + 1) with 0 = FLOOR, 1 = WALL,
# plus a list of dead-end cells (single walkable neighbour), which
# RunManager uses as puzzle/shop/boss chambers.

const FLOOR := 0
const WALL := 1

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

static func generate(cell_w: int, cell_h: int) -> Dictionary:
	var tw: int = cell_w * 2 + 1
	var th: int = cell_h * 2 + 1
	var tiles: Array = []
	for y in th:
		var row: Array = []
		for x in tw:
			row.append(WALL)
		tiles.append(row)

	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	visited[Vector2i(0, 0)] = true
	tiles[1][1] = FLOOR
	while not stack.is_empty():
		var cell: Vector2i = stack[stack.size() - 1]
		var candidates: Array[Vector2i] = []
		for d in DIRS:
			var nc: Vector2i = cell + d
			if nc.x < 0 or nc.y < 0 or nc.x >= cell_w or nc.y >= cell_h:
				continue
			if visited.has(nc):
				continue
			candidates.append(nc)
		if candidates.is_empty():
			stack.pop_back()
			continue
		candidates.shuffle()
		var nxt: Vector2i = candidates[0]
		visited[nxt] = true
		var cell_tile: Vector2i = Vector2i(cell.x * 2 + 1, cell.y * 2 + 1)
		var next_tile: Vector2i = Vector2i(nxt.x * 2 + 1, nxt.y * 2 + 1)
		@warning_ignore("integer_division")
		var wall_tile: Vector2i = (cell_tile + next_tile) / 2
		tiles[next_tile.y][next_tile.x] = FLOOR
		tiles[wall_tile.y][wall_tile.x] = FLOOR
		stack.append(nxt)

	var dead_ends: Array[Vector2i] = []
	for y in th:
		for x in tw:
			if tiles[y][x] != FLOOR:
				continue
			var open_nbrs: int = 0
			for d in DIRS:
				var n: Vector2i = Vector2i(x + d.x, y + d.y)
				if n.x < 0 or n.y < 0 or n.x >= tw or n.y >= th:
					continue
				if tiles[n.y][n.x] == FLOOR:
					open_nbrs += 1
			if open_nbrs == 1:
				dead_ends.append(Vector2i(x, y))
	return {
		"tiles": tiles,
		"dead_ends": dead_ends,
		"width": tw,
		"height": th,
	}

static func bfs_distances(tiles: Array, start: Vector2i) -> Dictionary:
	var h: int = tiles.size()
	var w: int = 0
	if h > 0:
		w = tiles[0].size()
	var dist: Dictionary = {start: 0}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for d in DIRS:
			var n: Vector2i = cur + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if int(tiles[n.y][n.x]) != FLOOR:
				continue
			if dist.has(n):
				continue
			dist[n] = int(dist[cur]) + 1
			q.append(n)
	return dist
