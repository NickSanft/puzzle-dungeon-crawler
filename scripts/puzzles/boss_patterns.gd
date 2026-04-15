class_name BossPatterns
extends RefCounted

const PATTERNS := [
	{
		"name": "The Crowned Tome",
		"grid": [
			"#.#.##.#.#",
			"##########",
			".########.",
			".########.",
			".########.",
			".########.",
			".########.",
			".########.",
			"..######..",
			"..######..",
		],
	},
	{
		"name": "The Skullpage",
		"grid": [
			"..######..",
			".########.",
			"##.####.##",
			"#..####..#",
			"##.####.##",
			".########.",
			".##.##.##.",
			".########.",
			"..#.##.#..",
			"...####...",
		],
	},
	{
		"name": "The Sword of Clues",
		"grid": [
			"....##....",
			"....##....",
			"....##....",
			"....##....",
			"....##....",
			"....##....",
			"..######..",
			"....##....",
			"....##....",
			"....##....",
		],
	},
	{
		"name": "The Hollow Key",
		"grid": [
			"..####....",
			".##..##...",
			".##..##...",
			".##..##...",
			"..####....",
			"...##.....",
			"...##.....",
			"...####...",
			"...##.....",
			"...####...",
		],
	},
]

static func random_pattern() -> Dictionary:
	return PATTERNS[RNG.randi_range(0, PATTERNS.size() - 1)]

static func to_bool_grid(pattern: Dictionary) -> Array:
	var out: Array = []
	for row_str in pattern.grid:
		var row: Array = []
		for ch in row_str:
			row.append(ch == "#")
		out.append(row)
	return out
