extends Node

func _ready() -> void:
	var t := TestFramework.new()
	_test_rng(t)
	_test_nonogram_bw(t)
	_test_nonogram_color(t)
	_test_solver(t)
	_test_generator(t)
	_test_save_system(t)
	_test_unlock_tree(t)
	_test_boss_patterns(t)
	_test_facing_math(t)
	_test_sudoku(t)
	_test_run_manager(t)
	_test_maze(t)
	_test_wordle(t)
	var ok := t.report()
	get_tree().quit(0 if ok else 1)

func _test_rng(t: TestFramework) -> void:
	t.suite("RNG")
	RNG.set_seed(12345)
	var a: Array = []
	for _i in 8:
		a.append(RNG.randi())
	RNG.set_seed(12345)
	var b: Array = []
	for _i in 8:
		b.append(RNG.randi())
	t.assert_eq(a, b, "same seed yields same sequence")
	# Compare an 8-value sequence from a different seed. A single-value
	# comparison is flaky (seeds can collide on the first number); an 8-value
	# collision is astronomically unlikely for any non-trivial RNG.
	RNG.set_seed(99999)
	var c: Array = []
	for _i in 8:
		c.append(RNG.randi())
	t.assert_false(a == c, "different seed yields different sequence")
	var key := RNG.today_key()
	t.assert_true(key.length() == 10 and key[4] == "-" and key[7] == "-", "today_key format YYYY-MM-DD")

func _test_nonogram_bw(t: TestFramework) -> void:
	t.suite("NonogramPuzzle (B&W)")
	var grid := [
		[true, false, true],
		[true, true, false],
		[false, true, true],
	]
	var p := NonogramPuzzle.from_solution(grid)
	t.assert_eq(p.width, 3, "width")
	t.assert_eq(p.height, 3, "height")
	t.assert_eq(p.row_clues[0], [1, 1], "row 0 clues [1,1]")
	t.assert_eq(p.row_clues[1], [2], "row 1 clues [2]")
	t.assert_eq(p.col_clues[0], [2], "col 0 clues [2]")
	t.assert_eq(p.col_clues[2], [1, 1], "col 2 clues [1,1]")
	var empty_line := NonogramPuzzle._line_to_clues([false, false, false])
	t.assert_eq(empty_line, [0], "empty line yields [0]")

func _test_nonogram_color(t: TestFramework) -> void:
	t.suite("NonogramPuzzle (color)")
	var grid := [
		[1, 1, 2, 0],
		[0, 2, 2, 3],
	]
	var palette := [Color(0, 0, 0, 0), Color.RED, Color.GREEN, Color.BLUE]
	var p := NonogramPuzzle.from_color_solution(grid, palette)
	t.assert_true(p.is_color, "marked as color")
	t.assert_eq(p.row_clues[0], [{"count": 2, "color": 1}, {"count": 1, "color": 2}], "row 0: 2 red then 1 green (adjacent, no gap needed)")
	t.assert_eq(p.row_clues[1], [{"count": 2, "color": 2}, {"count": 1, "color": 3}], "row 1: 2 green then 1 blue")
	t.assert_eq(p.col_clues[1], [{"count": 1, "color": 1}, {"count": 1, "color": 2}], "col 1 has 1 red adjacent to 1 green")

func _test_solver(t: TestFramework) -> void:
	t.suite("NonogramSolver")
	var grid := [
		[true, false, true],
		[true, true, false],
		[false, true, true],
	]
	var p := NonogramPuzzle.from_solution(grid)
	var n := NonogramSolver.count_solutions(p.row_clues, p.col_clues, 3)
	t.assert_true(n >= 1, "at least one solution for valid puzzle (n=%d)" % n)
	var trivial := NonogramPuzzle.from_solution([[true, true], [true, true]])
	var n2 := NonogramSolver.count_solutions(trivial.row_clues, trivial.col_clues, 3)
	t.assert_eq(n2, 1, "2x2 all-filled has exactly 1 solution")

func _test_generator(t: TestFramework) -> void:
	t.suite("NonogramGenerator")
	RNG.set_seed(42)
	var p := NonogramGenerator.generate(5, 0.55, false)
	t.assert_eq(p.width, 5, "generated width 5")
	t.assert_eq(p.height, 5, "generated height 5")
	var rederived := NonogramPuzzle.from_solution(p.solution)
	t.assert_eq(rederived.row_clues, p.row_clues, "clues match re-derivation")
	RNG.set_seed(7)
	var c := NonogramGenerator.generate_color(6, 0.6)
	t.assert_true(c.is_color, "color puzzle is_color")
	t.assert_eq(c.width, 6, "color width")
	t.assert_true(c.palette.size() >= 2, "color palette has at least 1 color + empty")

func _test_save_system(t: TestFramework) -> void:
	t.suite("SaveSystem")
	SaveSystem.reset_for_test("user://test_save.json")
	t.assert_eq(int(SaveSystem.data.glimbos), 0, "starts at 0 glimbos")
	SaveSystem.add_glimbos(30)
	t.assert_eq(int(SaveSystem.data.glimbos), 30, "add 30")
	t.assert_true(SaveSystem.spend_glimbos(10), "spend 10 returns true")
	t.assert_eq(int(SaveSystem.data.glimbos), 20, "balance after spend")
	t.assert_false(SaveSystem.spend_glimbos(1000), "spending too much returns false")
	t.assert_eq(int(SaveSystem.data.glimbos), 20, "balance unchanged after failed spend")
	SaveSystem.unlock("hp_up_1")
	t.assert_true(SaveSystem.has_unlock("hp_up_1"), "unlock persists in has_unlock")
	SaveSystem.unlock("hp_up_1")
	t.assert_eq(SaveSystem.data.unlocks.size(), 1, "duplicate unlock is ignored")
	var daily_written := SaveSystem.record_daily("2026-04-14", {"hp_remaining": 10, "time_sec": 120.0, "won": true})
	t.assert_true(daily_written, "first daily recorded")
	var not_better := SaveSystem.record_daily("2026-04-14", {"hp_remaining": 5, "time_sec": 100.0, "won": true})
	t.assert_false(not_better, "worse HP not recorded")
	var better := SaveSystem.record_daily("2026-04-14", {"hp_remaining": 15, "time_sec": 200.0, "won": true})
	t.assert_true(better, "better HP is recorded")

func _test_unlock_tree(t: TestFramework) -> void:
	t.suite("UnlockTree")
	SaveSystem.reset_for_test("user://test_save.json")
	var all_avail := UnlockTree.available_offers()
	var hp1_in := false
	var hp2_in := false
	for e in all_avail:
		if e.id == "hp_up_1":
			hp1_in = true
		if e.id == "hp_up_2":
			hp2_in = true
	t.assert_true(hp1_in, "hp_up_1 available at start")
	t.assert_false(hp2_in, "hp_up_2 gated behind prerequisite")
	SaveSystem.unlock("hp_up_1")
	var after := UnlockTree.available_offers()
	var hp1_still := false
	var hp2_now := false
	for e in after:
		if e.id == "hp_up_1":
			hp1_still = true
		if e.id == "hp_up_2":
			hp2_now = true
	t.assert_false(hp1_still, "hp_up_1 removed after purchase")
	t.assert_true(hp2_now, "hp_up_2 visible once prerequisite met")

func _test_boss_patterns(t: TestFramework) -> void:
	t.suite("BossPatterns")
	for pattern in BossPatterns.PATTERNS:
		var grid: Array = BossPatterns.to_bool_grid(pattern)
		t.assert_eq(grid.size(), 10, "%s has 10 rows" % pattern.name)
		for row in grid:
			t.assert_eq(row.size(), 10, "%s row is 10 wide" % pattern.name)
	for cpat in BossPatterns.COLOR_PATTERNS:
		var cgrid: Array = BossPatterns.to_int_grid(cpat)
		t.assert_eq(cgrid.size(), 10, "%s (color) has 10 rows" % cpat.name)
		for row in cgrid:
			t.assert_eq(row.size(), 10, "%s (color) row is 10 wide" % cpat.name)
		var max_idx := 0
		for row in cgrid:
			for v in row:
				max_idx = max(max_idx, int(v))
		t.assert_true(max_idx < cpat.palette.size(), "%s uses only indices within palette" % cpat.name)

func _test_sudoku(t: TestFramework) -> void:
	t.suite("Sudoku")
	t.assert_true(SudokuPuzzle.is_valid_solution(SudokuGenerator.BASE_SOLUTION), "canonical base solution is valid")
	RNG.set_seed(1234)
	var p := SudokuGenerator.generate(45)
	t.assert_true(SudokuPuzzle.is_valid_solution(p.solution), "generated solution is valid sudoku")
	var blanks := 0
	for y in SudokuPuzzle.SIZE:
		for x in SudokuPuzzle.SIZE:
			if not bool(p.givens[y][x]):
				blanks += 1
			if bool(p.givens[y][x]):
				t.assert_eq(int(p.initial[y][x]), int(p.solution[y][x]), "given matches solution at %d,%d" % [x, y])
	t.assert_eq(blanks, 45, "blank count matches request")

func _test_run_manager(t: TestFramework) -> void:
	t.suite("RunManager")
	t.assert_eq(RunManager.puzzle_size_for(1), 5, "floor 1 size = 5")
	t.assert_eq(RunManager.puzzle_size_for(2), 7, "floor 2 size = 7")
	t.assert_eq(RunManager.puzzle_size_for(3), 10, "floor 3 size = 10")
	t.assert_eq(RunManager.puzzle_size_for(99), 10, "floors beyond last clamp to last size")
	t.assert_true(RunManager.density_for(1) <= RunManager.density_for(3), "density non-decreasing with floor")

func _test_facing_math(t: TestFramework) -> void:
	t.suite("Dungeon facing math")
	t.assert_eq(Dungeon.FACING_VECTORS[0], Vector2i(0, -1), "0 is North")
	t.assert_eq(Dungeon.FACING_VECTORS[1], Vector2i(1, 0), "1 is East")
	t.assert_eq(Dungeon.FACING_VECTORS[2], Vector2i(0, 1), "2 is South")
	t.assert_eq(Dungeon.FACING_VECTORS[3], Vector2i(-1, 0), "3 is West")
	t.assert_eq(Dungeon._perpendicular(0), Vector2i(1, 0), "perpendicular of N is E")
	t.assert_eq(Dungeon._perpendicular(1), Vector2i(0, 1), "perpendicular of E is S")
	t.assert_eq(Dungeon._perpendicular(2), Vector2i(-1, 0), "perpendicular of S is W")
	t.assert_eq(Dungeon._perpendicular(3), Vector2i(0, -1), "perpendicular of W is N")
	# Depth frames: each depth should be a smaller concentric rect than the previous.
	var f0: Rect2 = Dungeon._frame_at(0)
	var f1: Rect2 = Dungeon._frame_at(1)
	var f2: Rect2 = Dungeon._frame_at(2)
	t.assert_true(f1.size.x < f0.size.x and f1.size.y < f0.size.y, "frame 1 is smaller than frame 0")
	t.assert_true(f2.size.x < f1.size.x and f2.size.y < f1.size.y, "frame 2 is smaller than frame 1")
	t.assert_true(absf((f0.position.x + f0.size.x * 0.5) - (f1.position.x + f1.size.x * 0.5)) < 0.5,
		"frames share a horizontal center (vanishing point)")

func _test_maze(t: TestFramework) -> void:
	t.suite("MazeGenerator")
	RNG.set_seed(42)
	var maze: Dictionary = MazeGenerator.generate(9, 6)
	var tiles: Array = maze.tiles
	t.assert_eq(int(maze.width), 19, "width = 2*cells+1")
	t.assert_eq(int(maze.height), 13, "height = 2*cells+1")
	t.assert_eq(tiles.size(), 13, "tiles rows match height")
	t.assert_eq(int(tiles[0].size()), 19, "tiles cols match width")
	# Outer border is all walls.
	for x in 19:
		t.assert_eq(int(tiles[0][x]), MazeGenerator.WALL, "top border wall at %d" % x)
		t.assert_eq(int(tiles[12][x]), MazeGenerator.WALL, "bottom border wall at %d" % x)
	t.assert_eq(int(tiles[1][1]), MazeGenerator.FLOOR, "entrance (1,1) is floor")
	# All cell centers reachable from entrance via BFS.
	var dist: Dictionary = MazeGenerator.bfs_distances(tiles, Vector2i(1, 1))
	var unreachable: int = 0
	for cy in 6:
		for cx in 9:
			var p := Vector2i(cx * 2 + 1, cy * 2 + 1)
			if not dist.has(p):
				unreachable += 1
	t.assert_eq(unreachable, 0, "every cell centre reachable from entrance")
	# Dead-ends exist (recursive backtracker always produces >= 1).
	t.assert_true((maze.dead_ends as Array).size() >= 2, "maze has multiple dead-ends")

func _test_wordle(t: TestFramework) -> void:
	t.suite("Wordle")
	# Word lists have entries and correct lengths.
	var w4: Array = WordleWordList.words_for_length(4)
	var w5: Array = WordleWordList.words_for_length(5)
	var w6: Array = WordleWordList.words_for_length(6)
	t.assert_true(w4.size() >= 50, "4-letter list has enough words (%d)" % w4.size())
	t.assert_true(w5.size() >= 50, "5-letter list has enough words (%d)" % w5.size())
	t.assert_true(w6.size() >= 50, "6-letter list has enough words (%d)" % w6.size())
	# Validate every word in every list — catches truncation typos.
	for length_check in [4, 5, 6]:
		var pool: Array = WordleWordList.words_for_length(length_check)
		for word in pool:
			var w: String = str(word)
			t.assert_eq(w.length(), length_check,
				"%d-letter list contains '%s' with length %d" % [length_check, w, w.length()])
	# Feedback: exact match = all green.
	var fb_exact: Array = WordlePuzzle.evaluate("CRANE", "CRANE")
	for i in 5:
		t.assert_eq(int(fb_exact[i]), WordlePuzzle.Feedback.GREEN, "exact match pos %d is GREEN" % i)
	# Feedback: no match = all grey.
	var fb_none: Array = WordlePuzzle.evaluate("BLIMP", "CRANE")
	for i in 5:
		t.assert_eq(int(fb_none[i]), WordlePuzzle.Feedback.GREY, "no-match pos %d is GREY" % i)
	# Feedback: mixed. AROSE vs CRANE
	# A(0) vs C — A is in target at pos 2 → YELLOW
	# R(1) vs R — same letter, same pos → GREEN
	# O(2) vs A — O not in target → GREY
	# S(3) vs N — S not in target → GREY
	# E(4) vs E — same letter, same pos → GREEN
	var fb_mix: Array = WordlePuzzle.evaluate("AROSE", "CRANE")
	t.assert_eq(int(fb_mix[0]), WordlePuzzle.Feedback.YELLOW, "'A' in AROSE vs CRANE is YELLOW")
	t.assert_eq(int(fb_mix[1]), WordlePuzzle.Feedback.GREEN, "'R' in AROSE vs CRANE is GREEN (same pos)")
	t.assert_eq(int(fb_mix[2]), WordlePuzzle.Feedback.GREY, "'O' in AROSE vs CRANE is GREY")
	t.assert_eq(int(fb_mix[3]), WordlePuzzle.Feedback.GREY, "'S' in AROSE vs CRANE is GREY")
	t.assert_eq(int(fb_mix[4]), WordlePuzzle.Feedback.GREEN, "'E' in AROSE vs CRANE is GREEN (same pos)")
	# Generator produces a valid puzzle.
	RNG.set_seed(99)
	var p: WordlePuzzle = WordleGenerator.generate(2)
	t.assert_eq(p.word_length, 5, "floor 2 generates 5-letter puzzle")
	t.assert_true(WordleWordList.is_valid_word(p.target_word), "generated word is in the list")
