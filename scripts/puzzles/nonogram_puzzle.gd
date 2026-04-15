class_name NonogramPuzzle
extends RefCounted

var width: int
var height: int
var solution: Array = []  # height x width of bool OR int (0=empty, 1..K=color idx)
var row_clues: Array = [] # Array of Array[int] (B&W) OR Array of Array[{count,color}] (color)
var col_clues: Array = []
var is_color: bool = false
var palette: Array = []   # Array[Color] where index 0 is unused/empty

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
	var s := "Nonogram %dx%d%s\n" % [width, height, " (color)" if is_color else ""]
	for y in height:
		var line := ""
		for x in width:
			var v = solution[y][x]
			if typeof(v) == TYPE_BOOL:
				line += "#" if v else "."
			else:
				line += "." if int(v) == 0 else str(int(v))
		s += line + "  " + str(row_clues[y]) + "\n"
	s += "cols: " + str(col_clues) + "\n"
	return s

static func from_color_solution(grid: Array, palette_in: Array) -> NonogramPuzzle:
	var h := grid.size()
	var w := 0
	if h > 0:
		w = grid[0].size()
	var p := NonogramPuzzle.new(w, h)
	p.is_color = true
	p.palette = palette_in
	p.solution = grid.duplicate(true)
	p.row_clues = []
	for y in h:
		p.row_clues.append(_line_to_color_clues(grid[y]))
	p.col_clues = []
	for x in w:
		var col: Array = []
		for y in h:
			col.append(int(grid[y][x]))
		p.col_clues.append(_line_to_color_clues(col))
	return p

static func _line_to_color_clues(line: Array) -> Array:
	var clues: Array = []
	var run := 0
	var run_color := 0
	for cell_val in line:
		var c: int = int(cell_val)
		if c == 0:
			if run > 0:
				clues.append({"count": run, "color": run_color})
				run = 0
				run_color = 0
		elif c == run_color:
			run += 1
		else:
			if run > 0:
				clues.append({"count": run, "color": run_color})
			run_color = c
			run = 1
	if run > 0:
		clues.append({"count": run, "color": run_color})
	if clues.is_empty():
		clues.append({"count": 0, "color": 0})
	return clues
