class_name NonogramPuzzle
extends RefCounted

var width: int
var height: int
var solution: Array = []  # height x width of bool
var row_clues: Array = [] # Array of Array[int]
var col_clues: Array = [] # Array of Array[int]

func _init(w: int = 0, h: int = 0) -> void:
	width = w
	height = h

static func from_solution(grid: Array) -> NonogramPuzzle:
	var h := grid.size()
	var w := 0
	if h > 0:
		w = grid[0].size()
	var p := NonogramPuzzle.new(w, h)
	p.solution = grid.duplicate(true)
	p.row_clues = []
	for y in h:
		p.row_clues.append(_line_to_clues(grid[y]))
	p.col_clues = []
	for x in w:
		var col: Array = []
		for y in h:
			col.append(grid[y][x])
		p.col_clues.append(_line_to_clues(col))
	return p

static func _line_to_clues(line: Array) -> Array:
	var clues: Array = []
	var run := 0
	for cell in line:
		if cell:
			run += 1
		elif run > 0:
			clues.append(run)
			run = 0
	if run > 0:
		clues.append(run)
	if clues.is_empty():
		clues.append(0)
	return clues

func to_debug_string() -> String:
	var s := "Nonogram %dx%d\n" % [width, height]
	for y in height:
		var line := ""
		for x in width:
			line += "#" if solution[y][x] else "."
		s += line + "  " + str(row_clues[y]) + "\n"
	s += "cols: " + str(col_clues) + "\n"
	return s
