class_name RoomModifiers
extends RefCounted

# Each modifier is a dict with:
#   id     — string key
#   name   — display name shown on the puzzle board
#   desc   — one-liner
#   chance — base probability of appearing per puzzle room

const MODIFIERS := [
	{
		"id": "fogged",
		"name": "Fogged",
		"desc": "Some clues are hidden. Fill adjacent cells to reveal them.",
		"chance": 0.25,
	},
	{
		"id": "mirrored",
		"name": "Mirrored",
		"desc": "The grid is flipped horizontally. Think in reverse.",
		"chance": 0.20,
	},
	{
		"id": "timed",
		"name": "Timed",
		"desc": "Solve within the time limit for a Glimbo bonus.",
		"chance": 0.25,
	},
]

# Roll a random modifier (or none). Returns {} for no modifier.
static func roll() -> Dictionary:
	for mod in MODIFIERS:
		if RNG.randf() < float(mod.chance):
			return mod
	return {}
