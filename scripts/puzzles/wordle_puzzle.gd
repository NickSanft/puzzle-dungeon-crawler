class_name WordlePuzzle
extends RefCounted

var target_word: String
var word_length: int
var max_guesses: int = 6

enum Feedback { EMPTY, PENDING, GREY, YELLOW, GREEN }

func _init(word: String = "", length: int = 5) -> void:
	target_word = word.to_upper()
	word_length = length

# Returns an array of Feedback values for a guess against the target.
static func evaluate(guess: String, target: String) -> Array:
	var g: String = guess.to_upper()
	var t: String = target.to_upper()
	var n: int = t.length()
	var result: Array = []
	result.resize(n)
	result.fill(Feedback.GREY)
	# Track which target letters are "consumed" by greens/yellows.
	var consumed: Array = []
	consumed.resize(n)
	consumed.fill(false)
	# Pass 1: mark greens (correct position).
	for i in n:
		if i < g.length() and g[i] == t[i]:
			result[i] = Feedback.GREEN
			consumed[i] = true
	# Pass 2: mark yellows (right letter, wrong position).
	for i in n:
		if result[i] == Feedback.GREEN:
			continue
		if i >= g.length():
			continue
		for j in n:
			if consumed[j]:
				continue
			if g[i] == t[j]:
				result[i] = Feedback.YELLOW
				consumed[j] = true
				break
	return result
