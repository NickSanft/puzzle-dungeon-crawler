class_name TestFramework
extends RefCounted

var passed: int = 0
var failed: int = 0
var failures: Array[String] = []
var _current_suite: String = ""

func suite(name: String) -> void:
	_current_suite = name
	print("\n--- %s ---" % name)

func assert_eq(actual, expected, label: String) -> void:
	if _equal(actual, expected):
		_pass(label)
	else:
		_fail(label, "expected %s, got %s" % [str(expected), str(actual)])

func assert_true(cond: bool, label: String) -> void:
	if cond:
		_pass(label)
	else:
		_fail(label, "expected true")

func assert_false(cond: bool, label: String) -> void:
	if not cond:
		_pass(label)
	else:
		_fail(label, "expected false")

func _pass(label: String) -> void:
	passed += 1
	print("  OK   %s" % label)

func _fail(label: String, reason: String) -> void:
	failed += 1
	var line := "%s :: %s — %s" % [_current_suite, label, reason]
	failures.append(line)
	print("  FAIL %s — %s" % [label, reason])

func _equal(a, b) -> bool:
	if typeof(a) != typeof(b):
		if (typeof(a) == TYPE_ARRAY or typeof(a) == TYPE_DICTIONARY) and typeof(a) == typeof(b):
			pass
		else:
			return str(a) == str(b)
	if typeof(a) == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _equal(a[i], b[i]):
				return false
		return true
	if typeof(a) == TYPE_DICTIONARY:
		if a.size() != b.size():
			return false
		for k in a.keys():
			if not b.has(k) or not _equal(a[k], b[k]):
				return false
		return true
	return a == b

func report() -> bool:
	print("\n=== Test Results: %d passed, %d failed ===" % [passed, failed])
	for f in failures:
		print("  - %s" % f)
	return failed == 0
