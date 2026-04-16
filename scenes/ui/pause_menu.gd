extends Control

signal resumed
signal abandoned

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
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(320, 0)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_add_volume_slider(v, "Master", "_on_master_changed", _db_to_linear(AudioServer.get_bus_volume_db(0)))
	_add_volume_slider(v, "SFX", "_on_sfx_changed", _db_to_linear(Audio._player.volume_db))
	_add_volume_slider(v, "Ambient", "_on_ambient_changed", _db_to_linear(Audio._ambient.volume_db))

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	PuzzleStyle.apply_button_style(resume_btn,
		PuzzleStyle.button_style(PuzzleStyle.NONO_ACCENT.darkened(0.25), 0.18, PuzzleStyle.NONO_ACCENT))
	resume_btn.pressed.connect(func(): resumed.emit())
	v.add_child(resume_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	PuzzleStyle.apply_button_style(settings_btn,
		PuzzleStyle.button_style(PuzzleStyle.NONO_CELL_EMPTY, 0.12))
	settings_btn.pressed.connect(_on_open_settings)
	v.add_child(settings_btn)

	var abandon_btn := Button.new()
	abandon_btn.text = "Abandon Run"
	PuzzleStyle.apply_button_style(abandon_btn,
		PuzzleStyle.button_style(Color(0.5, 0.2, 0.2), 0.18, Color(0.85, 0.3, 0.3)))
	abandon_btn.pressed.connect(func(): abandoned.emit())
	v.add_child(abandon_btn)

func _add_volume_slider(parent: Container, label_text: String, callback: String, initial: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(180, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(Callable(self, callback))
	row.add_child(slider)

func _on_master_changed(val: float) -> void:
	AudioServer.set_bus_volume_db(0, _linear_to_db(val))
	SaveSystem.set_setting("vol_master", val)

func _on_sfx_changed(val: float) -> void:
	Audio._player.volume_db = _linear_to_db(val)
	SaveSystem.set_setting("vol_sfx", val)

func _on_ambient_changed(val: float) -> void:
	Audio._ambient.volume_db = _linear_to_db(val)
	SaveSystem.set_setting("vol_ambient", val)

func _on_open_settings() -> void:
	var menu: Control = load("res://scenes/ui/settings_menu.tscn").instantiate()
	menu.closed.connect(func(): menu.queue_free())
	add_child(menu)

static func _linear_to_db(val: float) -> float:
	if val <= 0.001:
		return -80.0
	return 20.0 * log(val) / log(10.0)

static func _db_to_linear(db: float) -> float:
	if db <= -79.0:
		return 0.0
	return pow(10.0, db / 20.0)
