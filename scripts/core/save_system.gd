extends Node

const SAVE_VERSION := 1

var save_path: String = "user://save.json"

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
	"daily": {},
	"settings": {
		"colorblind": false,
		"reduced_motion": false,
	},
	"cosmetic_palette": "",
}

func _ready() -> void:
	load_from_disk()

func reset_for_test(path: String) -> void:
	save_path = path
	data = {
		"version": SAVE_VERSION,
		"glimbos": 0,
		"unlocks": [],
		"stats": {"runs_started": 0, "runs_won": 0, "puzzles_solved": 0},
		"daily": {},
	}
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func load_from_disk() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		data.merge(parsed, true)
	loaded.emit()

func save_to_disk() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: could not open %s for write" % save_path)
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

func setting(key: String, default_value = false) -> Variant:
	var s: Dictionary = data.get("settings", {})
	return s.get(key, default_value)

func set_setting(key: String, value) -> void:
	if not data.has("settings"):
		data.settings = {}
	data.settings[key] = value
	save_to_disk()

func set_cosmetic_palette(id: String) -> void:
	data.cosmetic_palette = id
	save_to_disk()

func record_daily(date_key: String, record: Dictionary) -> bool:
	var existing: Dictionary = data.daily.get(date_key, {})
	var is_better := existing.is_empty() \
		or int(record.get("hp_remaining", 0)) > int(existing.get("hp_remaining", -1)) \
		or (int(record.get("hp_remaining", 0)) == int(existing.get("hp_remaining", -1)) \
			and float(record.get("time_sec", 1e9)) < float(existing.get("time_sec", 1e9)))
	if is_better:
		data.daily[date_key] = record
		save_to_disk()
	return is_better

func get_daily(date_key: String) -> Dictionary:
	return data.daily.get(date_key, {})
