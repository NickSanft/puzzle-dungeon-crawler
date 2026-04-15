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
	_test_sudoku(t)
	_test_run_manager(t)
	var ok := t.report()
	get_tree().quit(0 if ok else 1)

func _test_rng(t: TestFramework) -> void:
	t.suite("RNG")
	RNG.set_seed(12345)
	var a := [RNG.randi(), RNG.randi(), RNG.randi()]
	RNG.set_seed(12345)
	var b := [RNG.randi(), RNG.randi(), RNG.randi()]
	t.assert_eq(a, b, "same seed yields same sequence")
	RNG.set_seed(99999)
	var c := RNG.randi()
	t.assert_false(a[0] == c, "different seed yields different value")
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
