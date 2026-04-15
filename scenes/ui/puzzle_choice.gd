class_name PuzzleChoice
extends Control

signal chosen(option: Dictionary)

const OPTION_SAFE := "SAFE"
const OPTION_RISKY := "RISKY"

var _options: Array = []

func _ready() -> void:
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

func show_choice(base_size: int, floor_num: int) -> void:
	var accent: Color = PuzzleStyle.accent_for_floor(floor_num)
	_options = [
		{
			"tag": OPTION_SAFE,
			"title": "Steady Hand",
			"subtitle": "Smaller grid, fewer Glimbos.",
			"size": max(3, base_size - 1),
			"density_delta": -0.05,
			"reward_mult": 0.7,
		},
		{
			"tag": OPTION_RISKY,
			"title": "Bold Stroke",
			"subtitle": "Bigger grid, richer reward.",
			"size": base_size + 2,
			"density_delta": 0.05,
			"reward_mult": 1.5,
		},
	]

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PuzzleStyle.panel_style(PuzzleStyle.NONO_PANEL, accent))
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Choose your puzzle"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for opt in _options:
		row.add_child(_build_option_card(opt, accent))

func _build_option_card(opt: Dictionary, accent: Color) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 140)
	var stl: StyleBoxFlat = PuzzleStyle.cell_style(PuzzleStyle.NONO_CELL_EMPTY, 8, 1, accent.lerp(Color.BLACK, 0.5))
	stl.content_margin_left = 16
	stl.content_margin_right = 16
	stl.content_margin_top = 14
	stl.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", stl)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)

	var name_lbl := Label.new()
	name_lbl.text = opt.title
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", accent)
	inner.add_child(name_lbl)

	var sub := Label.new()
	sub.text = opt.subtitle
	sub.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(200, 0)
	inner.add_child(sub)

	var stats := Label.new()
	stats.text = "Grid: %dx%d    Reward: %s" % [opt.size, opt.size, ("×%0.1f" % opt.reward_mult)]
	stats.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
	stats.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	inner.add_child(stats)

	var btn := Button.new()
	btn.text = "Take it"
	PuzzleStyle.apply_button_style(btn, PuzzleStyle.button_style(accent.darkened(0.3), 0.16, accent))
	btn.pressed.connect(func(): chosen.emit(opt))
	inner.add_child(btn)
	return card
