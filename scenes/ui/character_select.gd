extends Control

signal chosen(character_id: String)

func _ready() -> void:
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 0.75)
	add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	center.add_child(stack)

	var title := Label.new()
	title.text = "Choose your Scribe"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	stack.add_child(row)
	for entry in Characters.ROSTER:
		row.add_child(_make_card(entry))

func _make_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 260)
	var stl: StyleBoxFlat = PuzzleStyle.cell_style(PuzzleStyle.NONO_PANEL, 10, 1, entry.accent.lerp(Color.BLACK, 0.5))
	stl.content_margin_left = 18
	stl.content_margin_right = 18
	stl.content_margin_top = 16
	stl.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", stl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = entry.name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", entry.accent)
	v.add_child(name_lbl)

	var tag := Label.new()
	tag.text = entry.tagline
	tag.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
	tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	v.add_child(tag)

	var blurb := Label.new()
	blurb.text = entry.blurb
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(200, 70)
	blurb.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
	v.add_child(blurb)

	var effects := Label.new()
	effects.text = _format_effects(entry.effects as Dictionary)
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effects.custom_minimum_size = Vector2(200, 60)
	effects.add_theme_font_size_override("font_size", PuzzleStyle.FONT_BUTTON)
	effects.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	v.add_child(effects)

	var btn := Button.new()
	btn.text = "Begin"
	PuzzleStyle.apply_button_style(btn, PuzzleStyle.button_style(entry.accent.darkened(0.3), 0.18, entry.accent))
	btn.pressed.connect(func(): chosen.emit(entry.id))
	v.add_child(btn)
	return card

static func _format_effects(eff: Dictionary) -> String:
	var parts: Array[String] = []
	if eff.has("max_hp_delta"):
		parts.append("%+d max HP" % int(eff.max_hp_delta))
	if eff.has("bonus_hint_per_puzzle") and int(eff.bonus_hint_per_puzzle) > 0:
		parts.append("+%d starting hint" % int(eff.bonus_hint_per_puzzle))
	if eff.has("glimbo_bonus_per_solve") and int(eff.glimbo_bonus_per_solve) > 0:
		parts.append("+%d Glimbo / solve" % int(eff.glimbo_bonus_per_solve))
	if eff.has("hp_cost_per_solve") and int(eff.hp_cost_per_solve) > 0:
		parts.append("−%d HP / solve" % int(eff.hp_cost_per_solve))
	if eff.has("shop_discount"):
		parts.append("%d%% off shop" % int(float(eff.shop_discount) * 100.0))
	if eff.has("boss_reward_mult"):
		parts.append("boss ×%0.1f reward" % float(eff.boss_reward_mult))
	if eff.get("reveal_maze", false):
		parts.append("maze pre-revealed")
	return "  ·  ".join(parts)
