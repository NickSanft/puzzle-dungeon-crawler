class_name NonogramSolver
extends RefCounted

const EMPTY := 0
const FILLED := 1
const UNKNOWN := -1

static func count_solutions(row_clues: Array, col_clues: Array, limit: int = 2) -> int:
	var h: int = row_clues.size()
	var w: int = col_clues.size()
	var grid: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(UNKNOWN)
		grid.append(row)
	var row_candidates: Array = []
	for r in row_clues:
		row_candidates.append(_enumerate_lines(r, w))
	var col_candidates: Array = []
	for c in col_clues:
		col_candidates.append(_enumerate_lines(c, h))
	var count := [0]
	_backtrack(grid, row_clues, col_clues, row_candidates, col_candidates, 0, count, limit)
	return count[0]

static func _backtrack(grid: Array, row_clues: Array, col_clues: Array,
		row_cands: Array, col_cands: Array, row_idx: int, count: Array, limit: int) -> void:
	if count[0] >= limit:
		return
	var h: int = row_clues.size()
	var w: int = col_clues.size()
	if row_idx == h:
		for x in w:
			var col: Array = []
			for y in h:
				col.append(grid[y][x] == FILLED)
			if NonogramPuzzle._line_to_clues(col) != col_clues[x]:
				return
		count[0] += 1
		return
	for candidate in row_cands[row_idx]:
		if not _col_partial_ok(grid, candidate, row_idx, col_clues):
			continue
		grid[row_idx] = candidate.duplicate()
		_backtrack(grid, row_clues, col_clues, row_cands, col_cands, row_idx + 1, count, limit)
		if count[0] >= limit:
			return

static func _col_partial_ok(grid: Array, new_row: Array, row_idx: int, col_clues: Array) -> bool:
	var h: int = grid.size()
	var w: int = new_row.size()
	for x in w:
		var col: Array = []
		for y in range(0, row_idx):
			col.append(grid[y][x] == FILLED)
		col.append(new_row[x] == FILLED)
		var is_last_row := (row_idx == h - 1)
		if not _col_prefix_ok(col, col_clues[x], is_last_row, h):
			return false
	return true

static func _col_prefix_ok(prefix: Array, clues: Array, is_full: bool, full_len: int) -> bool:
	var runs: Array = []
	var run := 0
	for cell in prefix:
		if cell:
			run += 1
		elif run > 0:
			runs.append(run)
			run = 0
	var expected: Array = clues
	if expected.size() == 1 and expected[0] == 0:
		if run > 0 or not runs.is_empty():
			return false
		return true
	if is_full:
		if run > 0:
			runs.append(run)
		return runs == expected
	var completed_count: int = runs.size()
	for i in completed_count:
		if i >= expected.size() or runs[i] != expected[i]:
			return false
	if run > 0:
		if completed_count >= expected.size():
			return false
		if run > expected[completed_count]:
			return false
	var remaining_expected := 0
	for i in range(completed_count, expected.size()):
		remaining_expected += expected[i]
	remaining_expected += max(0, expected.size() - completed_count - 1)
	var remaining_space: int = full_len - prefix.size()
	if run > 0:
		remaining_expected -= run
	if remaining_expected > remaining_space:
		return false
	return true

static func _enumerate_lines(clues: Array, length: int) -> Array:
	var results: Array = []
	if clues.size() == 1 and clues[0] == 0:
		var empty: Array = []
		empty.resize(length)
		empty.fill(false)
		results.append(empty)
		return results
	_enum_recurse(clues, length, 0, 0, [], results)
	return results

static func _enum_recurse(clues: Array, length: int, clue_idx: int, pos: int,
		current: Array, results: Array) -> void:
	if clue_idx == clues.size():
		var line: Array = current.duplicate()
		while line.size() < length:
			line.append(false)
		results.append(line)
		return
	var remaining_runs: int = 0
	for i in range(clue_idx, clues.size()):
		remaining_runs += clues[i]
	remaining_runs += clues.size() - clue_idx - 1
	var max_start: int = length - remaining_runs
	for start in range(pos, max_start + 1):
		var next_current: Array = current.duplicate()
		while next_current.size() < start:
			next_current.append(false)
		for _i in clues[clue_idx]:
			next_current.append(true)
		var next_pos: int = start + clues[clue_idx]
		if clue_idx < clues.size() - 1:
			next_current.append(false)
			next_pos += 1
		_enum_recurse(clues, length, clue_idx + 1, next_pos, next_current, results)
