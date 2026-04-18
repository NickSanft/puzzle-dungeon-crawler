extends Control

signal closed

func _ready() -> void:
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		PuzzleStyle.panel_style(PuzzleStyle.NONO_PANEL, PuzzleStyle.NONO_ACCENT))
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(360, 0)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_add_toggle(v, "Colorblind mode (patterns on color cells)", "colorblind")
	_add_toggle(v, "Reduced motion (disable entrances, shakes, fades)", "reduced_motion")
	_add_toggle(v, "Large cells (touch-friendly puzzle boards)", "large_cells")
	_add_toggle(v, "Show touch controls (on-screen D-pad)", "touch_controls")

	v.add_child(_make_palette_picker())

	var close := Button.new()
	close.text = "Done"
	PuzzleStyle.apply_button_style(close,
		PuzzleStyle.button_style(PuzzleStyle.NONO_ACCENT.darkened(0.25), 0.18, PuzzleStyle.NONO_ACCENT))
	close.pressed.connect(func(): closed.emit())
	v.add_child(close)

func _add_toggle(parent: Container, label: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(220, 0)
	row.add_child(lbl)
	var btn := CheckButton.new()
	btn.button_pressed = bool(SaveSystem.setting(key, false))
	btn.toggled.connect(func(on: bool): SaveSystem.set_setting(key, on))
	row.add_child(btn)

func _make_palette_picker() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "Cosmetic accent"
	title.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
	v.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	# Default (empty id) plus any unlocked cosmetic palettes.
	row.add_child(_palette_swatch("", "Default", PuzzleStyle.NONO_ACCENT))
	for entry in PuzzleStyle.COSMETIC_PALETTES:
		var id: String = str(entry.id)
		if not SaveSystem.has_unlock("cosmetic_" + id):
			continue
		row.add_child(_palette_swatch(id, str(entry.name), entry.accent))
	return v

func _palette_swatch(id: String, name: String, accent: Color) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 44)
	btn.text = name
	btn.focus_mode = Control.FOCUS_NONE
	var selected: bool = str(SaveSystem.data.get("cosmetic_palette", "")) == id
	var border: Color = Color(1, 1, 1, 0.9) if selected else Color(1, 1, 1, 0.12)
	var sb: StyleBoxFlat = PuzzleStyle.cell_style(accent.darkened(0.35), 6, 2, border)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", PuzzleStyle.contrast_text(accent))
	btn.pressed.connect(func():
		SaveSystem.set_cosmetic_palette(id)
		# Rebuild so the selection outline reflects the new pick.
		for c in get_children():
			c.queue_free()
		_ready()
	)
	return btn
