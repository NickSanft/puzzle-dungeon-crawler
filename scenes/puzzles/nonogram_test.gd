extends Node

@export var size: int = 5
@export var num_puzzles: int = 3
@export var density: float = 0.55
@export var require_unique: bool = true

func _ready() -> void:
	RNG.set_seed(12345)
	print("=== Nonogram generator/solver smoke test ===")
	for i in num_puzzles:
		var puzzle := NonogramGenerator.generate(size, density, require_unique)
		print(puzzle.to_debug_string())
		var count := NonogramSolver.count_solutions(puzzle.row_clues, puzzle.col_clues, 2)
		print("Unique: ", count == 1, " (found ", count, " solutions up to limit)\n")
