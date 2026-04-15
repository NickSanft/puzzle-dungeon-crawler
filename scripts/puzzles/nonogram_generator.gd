class_name NonogramGenerator
extends RefCounted

const DEFAULT_DENSITY := 0.55
const MAX_ATTEMPTS := 30

static func generate(size: int, density: float = DEFAULT_DENSITY, require_unique: bool = true) -> NonogramPuzzle:
	for attempt in MAX_ATTEMPTS:
		var grid := _random_grid(size, size, density)
		var puzzle := NonogramPuzzle.from_solution(grid)
		if not require_unique:
			return puzzle
		var solutions := NonogramSolver.count_solutions(puzzle.row_clues, puzzle.col_clues, 2)
		if solutions == 1:
			return puzzle
	var fallback := _random_grid(size, size, density)
	return NonogramPuzzle.from_solution(fallback)

static func _random_grid(w: int, h: int, density: float) -> Array:
	var grid: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append(RNG.randf() < density)
		grid.append(row)
	for y in h:
		if not _row_has_fill(grid[y]):
			grid[y][RNG.randi_range(0, w - 1)] = true
	for x in w:
		var any := false
		for y in h:
			if grid[y][x]:
				any = true
				break
		if not any:
			grid[RNG.randi_range(0, h - 1)][x] = true
	return grid

static func _row_has_fill(row: Array) -> bool:
	for c in row:
		if c:
			return true
	return false

const DEFAULT_COLOR_PALETTES := [
	[Color(0, 0, 0, 0), Color(0.95, 0.45, 0.35), Color(0.3, 0.7, 0.95), Color(0.95, 0.85, 0.35)],
	[Color(0, 0, 0, 0), Color(0.4, 0.8, 0.5), Color(0.9, 0.4, 0.7), Color(0.6, 0.5, 0.9)],
	[Color(0, 0, 0, 0), Color(0.95, 0.6, 0.25), Color(0.35, 0.85, 0.75), Color(0.85, 0.85, 0.9)],
]

static func generate_color(size: int, density: float = 0.6) -> NonogramPuzzle:
	var palette: Array = DEFAULT_COLOR_PALETTES[RNG.randi_range(0, DEFAULT_COLOR_PALETTES.size() - 1)]
	var num_colors: int = palette.size() - 1
	var grid: Array = []
	for y in size:
		var row: Array = []
		for x in size:
			if RNG.randf() < density:
				row.append(RNG.randi_range(1, num_colors))
			else:
				row.append(0)
		grid.append(row)
	for y in size:
		var any := false
		for v in grid[y]:
			if int(v) != 0:
				any = true
				break
		if not any:
			grid[y][RNG.randi_range(0, size - 1)] = RNG.randi_range(1, num_colors)
	for x in size:
		var any_col := false
		for y in size:
			if int(grid[y][x]) != 0:
				any_col = true
				break
		if not any_col:
			grid[RNG.randi_range(0, size - 1)][x] = RNG.randi_range(1, num_colors)
	return NonogramPuzzle.from_color_solution(grid, palette)

static func from_boss_pattern() -> Dictionary:
	var pattern := BossPatterns.random_pattern()
	var grid := BossPatterns.to_bool_grid(pattern)
	return {
		"puzzle": NonogramPuzzle.from_solution(grid),
		"name": pattern.name,
	}
