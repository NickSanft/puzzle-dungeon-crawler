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
	_test_game_state(t)
	_test_characters(t)
	_test_lore(t)
	_test_room_modifiers(t)
	_test_puzzle_style(t)
	_test_sudoku_validation(t)
	_test_solver_ambiguity(t)
	_test_dungeon_snapshot(t)
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

# ---------------------------------------------------------------------------
# Extended coverage
# ---------------------------------------------------------------------------

func _test_game_state(t: TestFramework) -> void:
	t.suite("GameState")
	SaveSystem.reset_for_test("user://test_save.json")
	GameState.character_id = "scholar"
	GameState.start_run(false)
	t.assert_eq(GameState.hp, GameState.max_hp, "start_run sets hp = max_hp")
	t.assert_eq(GameState.current_floor, 1, "run begins on floor 1")
	t.assert_eq(GameState.glimbos_this_run, 0, "glimbos_this_run resets")
	t.assert_eq(GameState.curse_on_floor, 0, "curse resets at run start")
	# take_damage without damage_cap unlock applies full amount.
	var hp_before: int = GameState.hp
	GameState.take_damage(3)
	t.assert_eq(GameState.hp, hp_before - 3, "take_damage subtracts full amount")
	# damage_cap unlock limits damage.
	SaveSystem.unlock("damage_cap")
	var hp_after_cap: int = GameState.hp
	GameState.take_damage(10)
	t.assert_eq(GameState.hp, hp_after_cap - GameState.DAMAGE_CAP, "damage_cap limits damage per hit")
	# award_glimbos increments counters + curse.
	var g_before: int = GameState.glimbos_this_run
	var curse_before: int = GameState.curse_on_floor
	GameState.award_glimbos(5)
	t.assert_eq(GameState.glimbos_this_run - g_before, 5, "award_glimbos adds to run total")
	t.assert_eq(GameState.curse_on_floor - curse_before, 1, "award_glimbos increments curse")
	# Boss reward multiplier: first solve on floor = rush (1.6x)
	GameState.on_floor_changed()
	t.assert_eq(GameState.boss_reward_multiplier(), 1.6, "0 puzzles solved = rush multiplier 1.6")
	GameState.puzzles_solved_on_floor = 2
	t.assert_eq(GameState.boss_reward_multiplier(), 1.25, "2 puzzles solved = 1.25")
	GameState.puzzles_solved_on_floor = 5
	t.assert_eq(GameState.boss_reward_multiplier(), 1.0, "many puzzles = no bonus (1.0)")
	# boss_density_bonus rises with curse, capped at 0.15.
	GameState.curse_on_floor = 0
	t.assert_eq(GameState.boss_density_bonus(), 0.0, "no curse = no bonus")
	GameState.curse_on_floor = 10
	t.assert_eq(GameState.boss_density_bonus(), 0.15, "high curse clamps to 0.15")
	# Run rating classification.
	var loss_summary := {"floor": 2, "hp": 0, "max_hp": 20, "puzzles_run": 5, "time_sec": 400.0}
	t.assert_eq(GameState.classify_run(loss_summary, false), "Folded Paper", "died before floor 3 = Folded Paper")
	loss_summary.floor = 3
	t.assert_eq(GameState.classify_run(loss_summary, false), "Last Light", "died on floor 3 = Last Light")
	var perfect := {"floor": 3, "hp": 19, "max_hp": 20, "puzzles_run": 8, "time_sec": 400.0}
	t.assert_eq(GameState.classify_run(perfect, true), "Serene Clear", "90% HP + fast = Serene Clear")
	var nailbiter := {"floor": 3, "hp": 2, "max_hp": 20, "puzzles_run": 8, "time_sec": 400.0}
	t.assert_eq(GameState.classify_run(nailbiter, true), "White-Knuckle", "<20% HP = White-Knuckle")

func _test_characters(t: TestFramework) -> void:
	t.suite("Characters")
	t.assert_eq(Characters.ROSTER.size(), 3, "3 characters in roster")
	var scholar: Dictionary = Characters.get_by_id("scholar")
	t.assert_eq(str(scholar.id), "scholar", "scholar lookup works")
	t.assert_eq(int(Characters.effect("scholar", "bonus_hint_per_puzzle", 0)), 1, "Scholar gets +1 hint")
	t.assert_eq(int(Characters.effect("scholar", "max_hp_delta", 0)), -5, "Scholar -5 HP")
	t.assert_eq(int(Characters.effect("glutton", "glimbo_bonus_per_solve", 0)), 1, "Glutton +1 Glimbo/solve")
	t.assert_eq(int(Characters.effect("glutton", "hp_cost_per_solve", 0)), 1, "Glutton -1 HP/solve")
	t.assert_true(bool(Characters.effect("archivist", "reveal_maze", false)), "Archivist reveals maze")
	# Unknown key returns default.
	t.assert_eq(int(Characters.effect("scholar", "nonexistent_key", 42)), 42, "missing effect returns default")
	# Unknown character falls back to first entry.
	var fallback: Dictionary = Characters.get_by_id("made_up")
	t.assert_eq(str(fallback.id), str(Characters.ROSTER[0].id), "unknown id falls back to roster[0]")

func _test_lore(t: TestFramework) -> void:
	t.suite("Lore")
	SaveSystem.reset_for_test("user://test_save.json")
	var f1: Array = Lore.pages_for_floor(1)
	var f2: Array = Lore.pages_for_floor(2)
	var f3: Array = Lore.pages_for_floor(3)
	t.assert_true(f1.size() >= 2, "floor 1 has at least 2 lore pages")
	t.assert_true(f2.size() >= 2, "floor 2 has at least 2 lore pages")
	t.assert_true(f3.size() >= 2, "floor 3 has at least 2 lore pages")
	# pages_for_floor clamps out-of-range floors to the last bucket.
	t.assert_eq(Lore.pages_for_floor(99), f3, "high floor clamps to last bucket")
	# mark_collected is idempotent.
	Lore.mark_collected("margin_1")
	t.assert_true(Lore.is_collected("margin_1"), "page marked collected")
	Lore.mark_collected("margin_1")
	var count: int = SaveSystem.data.lore_collected.size()
	t.assert_eq(count, 1, "duplicate mark doesn't add twice")
	# all_floor_collected requires every page collected.
	t.assert_false(Lore.all_floor_collected(1), "not all floor 1 collected yet")
	for p in f1:
		Lore.mark_collected(str(p.id))
	t.assert_true(Lore.all_floor_collected(1), "all floor 1 collected after marking all")
	# pick_pages returns requested count without exceeding pool size.
	RNG.set_seed(7)
	var picked: Array = Lore.pick_pages(1, 100)
	t.assert_eq(picked.size(), f1.size(), "pick_pages clamps to available pool size")
	var picked2: Array = Lore.pick_pages(1, 2)
	t.assert_eq(picked2.size(), 2, "pick_pages returns requested count when available")

func _test_room_modifiers(t: TestFramework) -> void:
	t.suite("RoomModifiers")
	t.assert_true(RoomModifiers.MODIFIERS.size() >= 3, "at least 3 modifiers defined")
	var seen_ids: Dictionary = {}
	for mod in RoomModifiers.MODIFIERS:
		var id: String = str(mod.id)
		t.assert_false(seen_ids.has(id), "modifier id '%s' is unique" % id)
		seen_ids[id] = true
		t.assert_true(mod.has("name"), "modifier '%s' has name" % id)
		t.assert_true(mod.has("desc"), "modifier '%s' has desc" % id)
		t.assert_true(float(mod.get("chance", 0.0)) > 0.0, "modifier '%s' has positive chance" % id)
		t.assert_true(float(mod.get("chance", 1.0)) <= 1.0, "modifier '%s' chance <= 1.0" % id)
	t.assert_true(seen_ids.has("fogged"), "'fogged' modifier exists")
	t.assert_true(seen_ids.has("mirrored"), "'mirrored' modifier exists")
	t.assert_true(seen_ids.has("timed"), "'timed' modifier exists")
	# roll() returns {} or a valid modifier over many samples.
	RNG.set_seed(123)
	var empty_rolls: int = 0
	var valid_rolls: int = 0
	for _i in 200:
		var r: Dictionary = RoomModifiers.roll()
		if r.is_empty():
			empty_rolls += 1
		elif seen_ids.has(str(r.get("id", ""))):
			valid_rolls += 1
	t.assert_true(valid_rolls > 0, "roll() produces valid modifiers sometimes")
	t.assert_true(empty_rolls > 0, "roll() produces no-modifier sometimes")

func _test_puzzle_style(t: TestFramework) -> void:
	t.suite("PuzzleStyle")
	# contrast_text returns black on light, white on dark.
	t.assert_eq(PuzzleStyle.contrast_text(Color.WHITE), Color.BLACK, "white bg → black text")
	t.assert_eq(PuzzleStyle.contrast_text(Color.BLACK), Color.WHITE, "black bg → white text")
	# variegate stays in [0, 1] bounds and alpha is preserved.
	var base := Color(0.5, 0.5, 0.5, 0.8)
	var v: Color = PuzzleStyle.variegate(base, 3, 7, 0.1)
	t.assert_true(v.r >= 0.0 and v.r <= 1.0, "r within bounds")
	t.assert_true(v.g >= 0.0 and v.g <= 1.0, "g within bounds")
	t.assert_true(v.b >= 0.0 and v.b <= 1.0, "b within bounds")
	t.assert_eq(v.a, base.a, "alpha preserved")
	# Variegation is deterministic for the same coords.
	var v1: Color = PuzzleStyle.variegate(base, 5, 5, 0.1)
	var v2: Color = PuzzleStyle.variegate(base, 5, 5, 0.1)
	t.assert_eq(v1.r, v2.r, "variegate is deterministic")
	# Per-floor accent picks the right color when no cosmetic is set.
	SaveSystem.reset_for_test("user://test_save.json")
	t.assert_eq(PuzzleStyle.accent_for_floor(1), PuzzleStyle.FLOOR_ACCENTS[0], "floor 1 accent")
	t.assert_eq(PuzzleStyle.accent_for_floor(3), PuzzleStyle.FLOOR_ACCENTS[2], "floor 3 accent")
	t.assert_eq(PuzzleStyle.accent_for_floor(99), PuzzleStyle.FLOOR_ACCENTS[2], "high floor clamps")

func _test_sudoku_validation(t: TestFramework) -> void:
	t.suite("Sudoku validation (negative cases)")
	# Row duplicate → invalid.
	var bad_row: Array = []
	for y in 9:
		var row: Array = []
		for x in 9:
			row.append(SudokuGenerator.BASE_SOLUTION[y][x])
		bad_row.append(row)
	bad_row[0][0] = int(bad_row[0][1])  # duplicate in row 0
	t.assert_false(SudokuPuzzle.is_valid_solution(bad_row), "row duplicate rejected")
	# Column duplicate.
	var bad_col: Array = SudokuGenerator.BASE_SOLUTION.duplicate(true)
	bad_col[0][0] = int(bad_col[1][0])
	t.assert_false(SudokuPuzzle.is_valid_solution(bad_col), "column duplicate rejected")
	# Out-of-range value (0 or 10).
	var bad_zero: Array = SudokuGenerator.BASE_SOLUTION.duplicate(true)
	bad_zero[4][4] = 0
	t.assert_false(SudokuPuzzle.is_valid_solution(bad_zero), "zero value rejected")
	# Box duplicate (within same 3x3 box).
	var bad_box: Array = SudokuGenerator.BASE_SOLUTION.duplicate(true)
	# Cells (0,0) and (1,1) are in the same top-left box.
	bad_box[1][1] = int(bad_box[0][0])
	t.assert_false(SudokuPuzzle.is_valid_solution(bad_box), "box duplicate rejected")

func _test_solver_ambiguity(t: TestFramework) -> void:
	t.suite("NonogramSolver ambiguity")
	# A 2x2 checkerboard has two valid solutions (original + swap colors).
	# Row clues [1], [1]; col clues [1], [1].
	var row_clues: Array = [[1], [1]]
	var col_clues: Array = [[1], [1]]
	var n: int = NonogramSolver.count_solutions(row_clues, col_clues, 3)
	t.assert_true(n >= 2, "checkerboard-style clues have multiple solutions (n=%d)" % n)
	# limit parameter stops enumeration early.
	var capped: int = NonogramSolver.count_solutions(row_clues, col_clues, 1)
	t.assert_eq(capped, 1, "solver stops at limit")

func _test_dungeon_snapshot(t: TestFramework) -> void:
	t.suite("Dungeon snapshot/restore")
	# Build a tiny maze manually and verify snapshot/restore roundtrip.
	var d: Dungeon = preload("res://scenes/dungeon/dungeon.tscn").instantiate()
	# Ensure we're in the scene tree so _ready runs; add to autoload root.
	Engine.get_main_loop().root.add_child(d)
	var tiles: Array = [
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 1],
		[1, 1, 1, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 1, 1, 1, 1],
	]
	var triggers: Array = [{"pos": Vector2i(3, 3), "type": "PUZZLE"}]
	d.load_maze(tiles, triggers, Vector2i(1, 1))
	# Snapshot captures current state.
	var snap: Dictionary = d.snapshot()
	t.assert_eq((snap.player_pos as Array)[0], 1, "snapshot player_pos.x = 1")
	t.assert_eq((snap.player_pos as Array)[1], 1, "snapshot player_pos.y = 1")
	t.assert_eq((snap.triggers as Array).size(), 1, "snapshot preserves triggers")
	t.assert_eq(int(snap.player_facing), 1, "snapshot preserves facing")
	# Restore rebuilds state.
	d.load_maze([[1,1],[1,1]], [], Vector2i(0, 0))
	d.restore(snap)
	var snap2: Dictionary = d.snapshot()
	t.assert_eq(str(snap2.triggers), str(snap.triggers), "triggers roundtrip")
	t.assert_eq(snap2.tiles.size(), tiles.size(), "tiles height roundtrip")
	t.assert_eq((snap2.tiles[0] as Array).size(), (tiles[0] as Array).size(), "tiles width roundtrip")
	d.queue_free()
