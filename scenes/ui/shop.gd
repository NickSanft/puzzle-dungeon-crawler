class_name GlimboShop
extends Control

signal closed

const OFFERS_PER_VISIT := 3
const REROLL_BASE_COST := 10

@onready var _title: Label = $Panel/VBox/Title
@onready var _glimbos_label: Label = $Panel/VBox/Glimbos
@onready var _offers_box: VBoxContainer = $Panel/VBox/Offers
@onready var _reroll_btn: Button = $Panel/VBox/Actions/Reroll
@onready var _continue_btn: Button = $Panel/VBox/Actions/Continue

var _offers: Array = []

func _ready() -> void:
	_reroll_btn.pressed.connect(_on_reroll)
	_continue_btn.pressed.connect(func(): closed.emit())
	_reroll_offers()

func _reroll_offers() -> void:
	_offers = UnlockTree.pick_offers(OFFERS_PER_VISIT)
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
		var row := HBoxContainer.new()
		_offers_box.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name_lbl := Label.new()
		name_lbl.text = "%s  (%d glimbos)" % [offer.name, offer.cost]
		info.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = offer.desc
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc_lbl)
		var buy := Button.new()
		buy.text = "Buy"
		buy.disabled = int(SaveSystem.data.glimbos) < int(offer.cost)
		buy.pressed.connect(_on_buy.bind(offer.id))
		row.add_child(buy)

func _on_buy(id: String) -> void:
	var entry = _find_offer(id)
	if entry == null:
		return
	if not SaveSystem.spend_glimbos(int(entry.cost)):
		return
	SaveSystem.unlock(id)
	_offers.erase(entry)
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

func _refresh_labels() -> void:
	_glimbos_label.text = "Glimbos: %d" % int(SaveSystem.data.glimbos)
	_reroll_btn.text = "Reroll (%d)" % _reroll_cost()
	_reroll_btn.disabled = int(SaveSystem.data.glimbos) < _reroll_cost() or _offers.is_empty()
