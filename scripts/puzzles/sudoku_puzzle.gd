class_name SudokuPuzzle
extends RefCounted

const SIZE := 9
const BOX := 3

var solution: Array = []  # 9x9 ints 1..9
var givens: Array = []    # 9x9 bools; true = fixed clue
var initial: Array = []   # 9x9 ints, 0 for blank cells

func _init() -> void:
	pass

static func from_solution_and_givens(sol: Array, givens_grid: Array) -> SudokuPuzzle:
	var p := SudokuPuzzle.new()
	p.solution = sol.duplicate(true)
	p.givens = givens_grid.duplicate(true)
	p.initial = []
	for y in SIZE:
		var row: Array = []
		for x in SIZE:
			row.append(int(sol[y][x]) if bool(givens_grid[y][x]) else 0)
		p.initial.append(row)
	return p

static func is_valid_solution(grid: Array) -> bool:
	for i in SIZE:
		var row_set := {}
		var col_set := {}
		for j in SIZE:
			var rv: int = int(grid[i][j])
			var cv: int = int(grid[j][i])
			if rv < 1 or rv > 9 or row_set.has(rv):
				return false
			if cv < 1 or cv > 9 or col_set.has(cv):
				return false
			row_set[rv] = true
			col_set[cv] = true
	for by in BOX:
		for bx in BOX:
			var seen := {}
			for dy in BOX:
				for dx in BOX:
					var v: int = int(grid[by * BOX + dy][bx * BOX + dx])
					if seen.has(v):
						return false
					seen[v] = true
	return true
