class_name WordleGenerator
extends RefCounted

const LENGTH_BY_FLOOR: Array[int] = [4, 5, 6]

static func generate(floor_num: int) -> WordlePuzzle:
	var idx: int = clamp(floor_num - 1, 0, LENGTH_BY_FLOOR.size() - 1)
	var length: int = LENGTH_BY_FLOOR[idx]
	var pool: Array = WordleWordList.words_for_length(length)
	var word: String = pool[RNG.randi_range(0, pool.size() - 1)]
	return WordlePuzzle.new(word, length)
