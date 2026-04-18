class_name TouchControls
extends Control

# Emitted with the same key constants the dungeon expects.
signal key_pressed(keycode: int)

const BTN_SIZE := 64
const BTN_GAP := 6

var _visible_override: bool = false
var _touch_detected: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = _should_show()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not _touch_detected:
			_touch_detected = true
			visible = _should_show()
	elif event is InputEventKey:
		if _touch_detected:
			_touch_detected = false
			visible = _should_show()

func set_visible_override(on: bool) -> void:
	_visible_override = on
	visible = _should_show()

func _should_show() -> bool:
	return _visible_override or _touch_detected or bool(SaveSystem.setting("touch_controls", false))

func _build_ui() -> void:
	# Anchored to bottom-center of the screen.
	var pad := VBoxContainer.new()
	pad.anchor_left = 0.5
	pad.anchor_top = 1.0
	pad.anchor_right = 0.5
	pad.anchor_bottom = 1.0
	var total_w: float = 3 * BTN_SIZE + 2 * BTN_GAP
	var total_h: float = 2 * BTN_SIZE + BTN_GAP + 12
	pad.offset_left = -total_w * 0.5
	pad.offset_top = -total_h - 16
	pad.offset_right = total_w * 0.5
	pad.offset_bottom = -16
	pad.add_theme_constant_override("separation", BTN_GAP)
	add_child(pad)

	# Top row: Turn Left, Forward, Turn Right
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", BTN_GAP)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(top)
	top.add_child(_make_btn("Q", KEY_Q))
	top.add_child(_make_btn("W", KEY_W))
	top.add_child(_make_btn("E", KEY_E))

	# Bottom row: Strafe Left, Back, Strafe Right
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", BTN_GAP)
	bot.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(bot)
	bot.add_child(_make_btn("A", KEY_A))
	bot.add_child(_make_btn("S", KEY_S))
	bot.add_child(_make_btn("D", KEY_D))

func _make_btn(label: String, keycode: int) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	var sb := PuzzleStyle.cell_style(Color(0.2, 0.2, 0.25, 0.7), 8, 1, Color(1, 1, 1, 0.15))
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", sb)
	var hover := PuzzleStyle.cell_style(Color(0.3, 0.3, 0.38, 0.8), 8, 1, Color(1, 1, 1, 0.2))
	hover.content_margin_left = 4
	hover.content_margin_right = 4
	hover.content_margin_top = 4
	hover.content_margin_bottom = 4
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(func(): key_pressed.emit(keycode))
	return b
