class_name Characters
extends RefCounted

# Each character twists starting conditions and modifies run economy.
# `effects` keys are read by GameState / run_scene to branch behaviour.

const ROSTER := [
	{
		"id": "scholar",
		"name": "The Scholar",
		"tagline": "Erudite, fragile.",
		"blurb": "Reads clues that others miss. Brittle under pressure.",
		"accent": Color(0.45, 0.75, 0.95),
		"effects": {
			"bonus_hint_per_puzzle": 1,
			"max_hp_delta": -5,
			"shop_discount": 0.2,
		},
	},
	{
		"id": "glutton",
		"name": "The Glutton",
		"tagline": "All appetite, no patience.",
		"blurb": "Gobbles Glimbos at a cost. Bosses drop more.",
		"accent": Color(0.95, 0.55, 0.3),
		"effects": {
			"glimbo_bonus_per_solve": 1,
			"hp_cost_per_solve": 1,
			"boss_reward_mult": 2.0,
		},
	},
	{
		"id": "archivist",
		"name": "The Archivist",
		"tagline": "Sees the shape of things.",
		"blurb": "Reveals maze immediately. Starts weaker otherwise.",
		"accent": Color(0.78, 0.6, 0.9),
		"effects": {
			"reveal_maze": true,
			"max_hp_delta": -3,
			"bonus_hint_per_puzzle": 0,
		},
	},
]

static func get_by_id(id: String) -> Dictionary:
	for entry in ROSTER:
		if str(entry.id) == id:
			return entry
	return ROSTER[0]

static func effect(id: String, key: String, default_value = null):
	var entry: Dictionary = get_by_id(id)
	if not entry.has("effects"):
		return default_value
	var eff: Dictionary = entry.effects
	return eff.get(key, default_value)
