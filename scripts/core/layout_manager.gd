extends Node

# Tracks viewport size and emits orientation/breakpoint changes so scenes
# can reflow themselves for portrait phones, tiny screens, etc.

signal layout_changed(is_portrait: bool, is_compact: bool)

const COMPACT_WIDTH := 900  # below this, treat as a small screen

var is_portrait: bool = false
var is_compact: bool = false

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_resize)
	_recheck()

func _on_resize() -> void:
	_recheck()

func _recheck() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var new_portrait: bool = size.y > size.x
	var new_compact: bool = size.x < COMPACT_WIDTH or new_portrait
	if new_portrait != is_portrait or new_compact != is_compact:
		is_portrait = new_portrait
		is_compact = new_compact
		layout_changed.emit(is_portrait, is_compact)

func is_mobile_like() -> bool:
	# True on Android/iOS web exports, OR when viewport looks mobile.
	return OS.has_feature("mobile") or is_compact
