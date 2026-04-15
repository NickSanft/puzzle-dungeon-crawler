class_name UnlockTree
extends RefCounted

const CATALOG := [
	{
		"id": "hp_up_1",
		"name": "Sturdy Pages I",
		"desc": "Start runs with +5 max HP.",
		"cost": 40,
	},
	{
		"id": "hp_up_2",
		"name": "Sturdy Pages II",
		"desc": "Start runs with another +5 max HP.",
		"cost": 90,
		"requires": ["hp_up_1"],
	},
	{
		"id": "glimbo_bonus",
		"name": "Golden Quill",
		"desc": "+1 Glimbo for every puzzle solved.",
		"cost": 120,
	},
	{
		"id": "puzzle_hint",
		"name": "Starting Hint",
		"desc": "Start each puzzle with one correct cell revealed.",
		"cost": 75,
	},
	{
		"id": "reroll_discount",
		"name": "Haggler",
		"desc": "Shop reroll cost halved.",
		"cost": 60,
	},
	{
		"id": "color_nonograms",
		"name": "Chromatic Codex",
		"desc": "Unlocks color nonograms in later floors.",
		"cost": 500,
	},
	{
		"id": "damage_cap",
		"name": "Padded Margins",
		"desc": "Cap damage from any single puzzle at 4.",
		"cost": 150,
	},
	{
		"id": "extra_reward",
		"name": "Lucky Ink",
		"desc": "Boss puzzles award double Glimbos.",
		"cost": 200,
	},
]

static func available_offers() -> Array:
	var out: Array = []
	for entry in CATALOG:
		if SaveSystem.has_unlock(entry.id):
			continue
		var reqs: Array = entry.get("requires", [])
		var ok := true
		for r in reqs:
			if not SaveSystem.has_unlock(r):
				ok = false
				break
		if ok:
			out.append(entry)
	return out

static func pick_offers(n: int) -> Array:
	var pool := available_offers()
	pool.shuffle()
	return pool.slice(0, min(n, pool.size()))
