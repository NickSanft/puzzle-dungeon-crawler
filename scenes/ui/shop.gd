class_name GlimboShop
extends Control

signal closed

const OFFERS_PER_VISIT := 3
const REROLL_BASE_COST := 10
const BANISH_COST := 15
const MYSTERY_COST := 30

@onready var _glimbos_label: Label = $Panel/VBox/Glimbos
@onready var _offers_box: VBoxContainer = $Panel/VBox/Offers
@onready var _reroll_btn: Button = $Panel/VBox/Actions/Reroll
@onready var _continue_btn: Button = $Panel/VBox/Actions/Continue

var _offers: Array = []
var _locked_ids: Dictionary = {}

func _ready() -> void:
	_reroll_btn.pressed.connect(_on_reroll)
	_continue_btn.pressed.connect(func(): closed.emit())
	_add_action_buttons()
	_reroll_offers()

func _add_action_buttons() -> void:
	var bar: HBoxContainer = _reroll_btn.get_parent()
	# Mystery Box — buys a random unlock for a flat cost.
	var mystery := Button.new()
	mystery.text = "Mystery Box (%d)" % MYSTERY_COST
	mystery.pressed.connect(_on_mystery)
	bar.add_child(mystery)
	bar.move_child(mystery, bar.get_child_count() - 2)

func _reroll_offers() -> void:
	# Keep locked offers; fill the rest. Optionally salt in a "curse" offer.
	var kept: Array = []
	for o in _offers:
		if _locked_ids.has(str(o.id)):
			kept.append(o)
	var fill: int = OFFERS_PER_VISIT - kept.size()
	var fresh: Array = UnlockTree.pick_offers(fill)
	# Splice in an occasional curse offer — no unlock, just a risky trade.
	if fill > 0 and RNG.randf() < 0.4:
		fresh.append({
			"id": "curse_hp_glimbo",
			"name": "Inkbound Pact",
			"desc": "Lose 2 max HP right now, gain 15 Glimbos.",
			"cost": 0,
			"is_curse": true,
		})
		if fresh.size() > fill:
			fresh.resize(fill)
	_offers = kept + fresh
	_rebuild_offers()
	_refresh_labels()

func _rebuild_offers() -> void:
	for c in _offers_box.get_children():
		c.queue_free()
	if _offers.is_empty():
		var empty := Label.new()
		empty.text = "Nothing more to unlock. Come back later!"
		_offers_box.add_child(empty)
		return
	for offer in _offers:
		_offers_box.add_child(_build_row(offer))

func _build_row(offer: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var is_curse: bool = bool(offer.get("is_curse", false))
	var name_lbl := Label.new()
	if is_curse:
		name_lbl.text = "%s  (CURSE)" % offer.name
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 0.55))
	else:
		var eff_cost: int = _effective_cost(int(offer.cost))
		if eff_cost != int(offer.cost):
			name_lbl.text = "%s  (%d glimbos, was %d)" % [offer.name, eff_cost, int(offer.cost)]
		else:
			name_lbl.text = "%s  (%d glimbos)" % [offer.name, eff_cost]
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = offer.desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	row.add_child(buttons)
	var buy := Button.new()
	if is_curse:
		buy.text = "Accept"
		buy.pressed.connect(_on_curse_accept.bind(offer))
	else:
		var eff_cost: int = _effective_cost(int(offer.cost))
		buy.text = "Buy"
		buy.disabled = int(SaveSystem.data.glimbos) < eff_cost
		buy.pressed.connect(_on_buy.bind(offer.id))
	buttons.add_child(buy)

	if not is_curse:
		var lock := CheckButton.new()
		var locked: bool = _locked_ids.has(str(offer.id))
		lock.button_pressed = locked
		lock.text = "Lock"
		lock.toggled.connect(func(on: bool):
			if on:
				_locked_ids[str(offer.id)] = true
			else:
				_locked_ids.erase(str(offer.id))
		)
		buttons.add_child(lock)
		var banish := Button.new()
		banish.text = "Banish (%d)" % BANISH_COST
		banish.disabled = int(SaveSystem.data.glimbos) < BANISH_COST
		banish.pressed.connect(_on_banish.bind(offer))
		buttons.add_child(banish)
	return row

func _on_buy(id: String) -> void:
	var entry = _find_offer(id)
	if entry == null:
		return
	if not SaveSystem.spend_glimbos(_effective_cost(int(entry.cost))):
		return
	SaveSystem.unlock(id)
	_offers.erase(entry)
	_locked_ids.erase(id)
	_rebuild_offers()
	_refresh_labels()

func _on_curse_accept(offer: Dictionary) -> void:
	GameState.max_hp = max(1, GameState.max_hp - 2)
	GameState.hp = min(GameState.hp, GameState.max_hp)
	GameState.hp_changed.emit(GameState.hp, GameState.max_hp)
	GameState.award_glimbos(15)
	_offers.erase(offer)
	_rebuild_offers()
	_refresh_labels()

func _on_banish(offer: Dictionary) -> void:
	if not SaveSystem.spend_glimbos(BANISH_COST):
		return
	_offers.erase(offer)
	_locked_ids.erase(str(offer.id))
	_rebuild_offers()
	_refresh_labels()

func _on_mystery() -> void:
	if int(SaveSystem.data.glimbos) < MYSTERY_COST:
		return
	var available: Array = UnlockTree.available_offers()
	if available.is_empty():
		return
	if not SaveSystem.spend_glimbos(MYSTERY_COST):
		return
	var pick: Dictionary = available[RNG.randi_range(0, available.size() - 1)]
	SaveSystem.unlock(str(pick.id))
	_offers = _offers.filter(func(o): return o.id != pick.id)
	_rebuild_offers()
	_refresh_labels()

func _find_offer(id: String):
	for o in _offers:
		if o.id == id:
			return o
	return null

func _on_reroll() -> void:
	var cost := _reroll_cost()
	if not SaveSystem.spend_glimbos(cost):
		return
	_reroll_offers()

func _reroll_cost() -> int:
	return REROLL_BASE_COST / 2 if SaveSystem.has_unlock("reroll_discount") else REROLL_BASE_COST

func _effective_cost(raw: int) -> int:
	var discount: float = float(Characters.effect(GameState.character_id, "shop_discount", 0.0))
	if discount <= 0.0:
		return raw
	return max(1, int(round(float(raw) * (1.0 - discount))))

func _refresh_labels() -> void:
	_glimbos_label.text = "Glimbos: %d" % int(SaveSystem.data.glimbos)
	_reroll_btn.text = "Reroll (%d)" % _reroll_cost()
	_reroll_btn.disabled = int(SaveSystem.data.glimbos) < _reroll_cost()
