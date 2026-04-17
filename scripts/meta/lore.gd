class_name Lore
extends RefCounted

# Each floor has a pool of lore pages. 2 are placed per floor as LORE triggers.
# Collecting all pages on a floor awards a small Glimbo bonus.

const PAGES := [
	# Floor 1 — The Margin
	[
		{"id": "margin_1", "text": "The edges of every great book are where the notes live. Scholars once believed the margin held more truth than the text."},
		{"id": "margin_2", "text": "The Glimbo was first found pressed between pages like a dried flower. It hummed when held near unsolved puzzles."},
		{"id": "margin_3", "text": "Apprentice scribes are warned: 'Write nothing in the margin you wouldn't say to the book's face.'"},
	],
	# Floor 2 — The Library
	[
		{"id": "library_1", "text": "The deeper shelves move when no one is watching. Cartographers have mapped the same corridor six different ways."},
		{"id": "library_2", "text": "A Glutton once ate an entire index. They could recite page numbers but never the words."},
		{"id": "library_3", "text": "The Archivist's monocle lets them read in any direction — even backwards. Especially backwards."},
	],
	# Floor 3 — The Ink Well
	[
		{"id": "inkwell_1", "text": "At the bottom of the Ink Well, the puzzles solve themselves. The problem is getting back out."},
		{"id": "inkwell_2", "text": "The bosses were once librarians. They guarded the stacks so fiercely they became the stacks."},
		{"id": "inkwell_3", "text": "Every Glimbo spent in the shop returns to the Well eventually. The economy is a closed loop written in invisible ink."},
	],
]

const COLLECT_ALL_BONUS := 5

static func pages_for_floor(floor_num: int) -> Array:
	var idx: int = clamp(floor_num - 1, 0, PAGES.size() - 1)
	return PAGES[idx]

static func pick_pages(floor_num: int, count: int) -> Array:
	var pool: Array = pages_for_floor(floor_num).duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

static func mark_collected(page_id: String) -> void:
	if not SaveSystem.data.has("lore_collected"):
		SaveSystem.data["lore_collected"] = []
	if page_id not in SaveSystem.data.lore_collected:
		SaveSystem.data.lore_collected.append(page_id)
		SaveSystem.save_to_disk()

static func is_collected(page_id: String) -> bool:
	if not SaveSystem.data.has("lore_collected"):
		return false
	return page_id in SaveSystem.data.lore_collected

static func all_floor_collected(floor_num: int) -> bool:
	var pages: Array = pages_for_floor(floor_num)
	for p in pages:
		if not is_collected(str(p.id)):
			return false
	return true
