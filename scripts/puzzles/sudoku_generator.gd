class_name SudokuGenerator
extends RefCounted

const BASE_SOLUTION := [
	[5, 3, 4, 6, 7, 8, 9, 1, 2],
	[6, 7, 2, 1, 9, 5, 3, 4, 8],
	[1, 9, 8, 3, 4, 2, 5, 6, 7],
	[8, 5, 9, 7, 6, 1, 4, 2, 3],
	[4, 2, 6, 8, 5, 3, 7, 9, 1],
	[7, 1, 3, 9, 2, 4, 8, 5, 6],
	[9, 6, 1, 5, 3, 7, 2, 8, 4],
	[2, 8, 7, 4, 1, 9, 6, 3, 5],
	[3, 4, 5, 2, 8, 6, 1, 7, 9],
]

static func generate(blanks: int = 45) -> SudokuPuzzle:
	var sol := _transform(BASE_SOLUTION)
	var givens: Array = []
	for y in SudokuPuzzle.SIZE:
		var row: Array = []
		for x in SudokuPuzzle.SIZE:
			row.append(true)
		givens.append(row)
	var cells: Array = []
	for y in SudokuPuzzle.SIZE:
		for x in SudokuPuzzle.SIZE:
			cells.append(Vector2i(x, y))
	cells.shuffle()
	for i in min(blanks, cells.size()):
		var c: Vector2i = cells[i]
		givens[c.y][c.x] = false
	return SudokuPuzzle.from_solution_and_givens(sol, givens)

static func _transform(base: Array) -> Array:
	var grid: Array = base.duplicate(true)
	grid = _relabel(grid)
	for _i in 3:
		grid = _swap_rows_in_band(grid, RNG.randi_range(0, 2))
		grid = _swap_cols_in_stack(grid, RNG.randi_range(0, 2))
	grid = _swap_bands(grid, RNG.randi_range(0, 2), RNG.randi_range(0, 2))
	grid = _swap_stacks(grid, RNG.randi_range(0, 2), RNG.randi_range(0, 2))
	return grid

static func _relabel(grid: Array) -> Array:
	var perm: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	perm.shuffle()
	var out: Array = []
	for y in SudokuPuzzle.SIZE:
		var row: Array = []
		for x in SudokuPuzzle.SIZE:
			row.append(perm[int(grid[y][x]) - 1])
		out.append(row)
	return out

static func _swap_rows_in_band(grid: Array, band: int) -> Array:
	var r1: int = band * 3 + RNG.randi_range(0, 2)
	var r2: int = band * 3 + RNG.randi_range(0, 2)
	if r1 == r2:
		return grid
	var out: Array = grid.duplicate(true)
	var tmp = out[r1]
	out[r1] = out[r2]
	out[r2] = tmp
	return out

static func _swap_cols_in_stack(grid: Array, stack: int) -> Array:
	var c1: int = stack * 3 + RNG.randi_range(0, 2)
	var c2: int = stack * 3 + RNG.randi_range(0, 2)
	if c1 == c2:
		return grid
	var out: Array = grid.duplicate(true)
	for y in SudokuPuzzle.SIZE:
		var tmp = out[y][c1]
		out[y][c1] = out[y][c2]
		out[y][c2] = tmp
	return out

static func _swap_bands(grid: Array, b1: int, b2: int) -> Array:
	if b1 == b2:
		return grid
	var out: Array = grid.duplicate(true)
	for i in 3:
		var tmp = out[b1 * 3 + i]
		out[b1 * 3 + i] = out[b2 * 3 + i]
		out[b2 * 3 + i] = tmp
	return out

static func _swap_stacks(grid: Array, s1: int, s2: int) -> Array:
	if s1 == s2:
		return grid
	var out: Array = grid.duplicate(true)
	for y in SudokuPuzzle.SIZE:
		for i in 3:
			var tmp = out[y][s1 * 3 + i]
			out[y][s1 * 3 + i] = out[y][s2 * 3 + i]
			out[y][s2 * 3 + i] = tmp
	return out
