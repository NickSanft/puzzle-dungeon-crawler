extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

signal loaded
signal saved

var data: Dictionary = {
	"version": SAVE_VERSION,
	"glimbos": 0,
	"unlocks": [],
	"stats": {
		"runs_started": 0,
		"runs_won": 0,
		"puzzles_solved": 0,
	},
}

func _ready() -> void:
	load_from_disk()

func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		data.merge(parsed, true)
	loaded.emit()

func save_to_disk() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: could not open %s for write" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	saved.emit()

func add_glimbos(amount: int) -> void:
	data.glimbos = int(data.glimbos) + amount
	save_to_disk()

func spend_glimbos(amount: int) -> bool:
	if int(data.glimbos) < amount:
		return false
	data.glimbos = int(data.glimbos) - amount
	save_to_disk()
	return true

func unlock(id: String) -> void:
	if id in data.unlocks:
		return
	data.unlocks.append(id)
	save_to_disk()

func has_unlock(id: String) -> bool:
	return id in data.unlocks
