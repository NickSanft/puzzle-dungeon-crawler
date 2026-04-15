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
