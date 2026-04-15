extends Node

var _rng := RandomNumberGenerator.new()
var seed_value: int = 0

func _ready() -> void:
	randomize_from_time()

func randomize_from_time() -> void:
	_rng.randomize()
	seed_value = _rng.seed

func set_seed(s: int) -> void:
	seed_value = s
	_rng.seed = s
	_rng.state = s

func randi() -> int:
	return _rng.randi()

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func randf() -> float:
	return _rng.randf()

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

func pick(arr: Array):
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]

func today_key() -> String:
	var t := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [t.year, t.month, t.day]

func daily_seed(date_utc: String = "") -> int:
	var d := date_utc if date_utc != "" else today_key()
	return hash(d)
