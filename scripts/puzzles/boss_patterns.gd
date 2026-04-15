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

const COLOR_PATTERNS := [
	{
		"name": "The Prismatic Lich",
		"palette": [Color(0, 0, 0, 0), Color(0.85, 0.3, 0.3), Color(0.35, 0.75, 0.95), Color(0.95, 0.85, 0.35)],
		"grid": [
			"..1111....",
			".111111...",
			"1.1111.1..",
			"11.11.11..",
			".111111...",
			".222222...",
			".222222...",
			"..3.33.3..",
			"..3333....",
			"...33.....",
		],
	},
	{
		"name": "The Quilled Warden",
		"palette": [Color(0, 0, 0, 0), Color(0.45, 0.85, 0.5), Color(0.9, 0.55, 0.25), Color(0.85, 0.85, 0.9)],
		"grid": [
			"....11....",
			"...1111...",
			"..111111..",
			".11211211.",
			".11111111.",
			".11222211.",
			".11222211.",
			"..111111..",
			"..3....3..",
			"..33..33..",
		],
	},
]

static func random_pattern() -> Dictionary:
	return PATTERNS[RNG.randi_range(0, PATTERNS.size() - 1)]

static func random_color_pattern() -> Dictionary:
	return COLOR_PATTERNS[RNG.randi_range(0, COLOR_PATTERNS.size() - 1)]

static func to_bool_grid(pattern: Dictionary) -> Array:
	var out: Array = []
	for row_str in pattern.grid:
		var row: Array = []
		for ch in row_str:
			row.append(ch == "#")
		out.append(row)
	return out

static func to_int_grid(pattern: Dictionary) -> Array:
	var out: Array = []
	for row_str in pattern.grid:
		var row: Array = []
		for ch in row_str:
			if ch == "." or ch == "0":
				row.append(0)
			else:
				row.append(int(ch))
		out.append(row)
	return out
