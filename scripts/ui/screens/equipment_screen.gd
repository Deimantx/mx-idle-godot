extends Control

## Equipment: current slots (left) and equippable bank items (right). Every
## equip/unequip goes through EquipmentSystem, which owns ownership rules.

@onready var _slot_list: VBoxContainer = %SlotList
@onready var _equip_list: VBoxContainer = %EquipList


func _ready() -> void:
	EventBus.equipment_changed.connect(_rebuild)
	EventBus.bank_changed.connect(_on_bank_changed)
	EventBus.profile_loaded.connect(_rebuild)
	_rebuild()


func refresh() -> void:
	_rebuild()


func _on_bank_changed() -> void:
	if is_visible_in_tree():
		_rebuild()


func _rebuild() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	for child in _equip_list.get_children():
		child.queue_free()
	var state := GameSession.state
	if state == null:
		return
	for slot in CharacterState.SLOTS:
		_slot_list.add_child(_slot_row(state, slot))
	for item_id in _equippable_ids(state):
		_equip_list.add_child(_equip_row(state, item_id))


func _slot_row(state: CharacterState, slot: String) -> Control:
	var item_id := str(state.equipment.get(slot, ""))
	var row := HBoxContainer.new()

	var slot_label := Label.new()
	slot_label.text = slot.capitalize()
	slot_label.custom_minimum_size = Vector2(96, 0)
	row.add_child(slot_label)

	if item_id == "":
		var empty := Label.new()
		empty.text = "-"
		empty.theme_type_variation = &"Muted"
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(empty)
		return row

	row.add_child(UiUtil.make_icon(item_id, 30))
	var name_label := Label.new()
	name_label.text = ContentRegistry.item_name(item_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", UiUtil.rarity_color(str(ContentRegistry.get_item(item_id).get("rarity", "common"))))
	row.add_child(name_label)

	var stat_label := Label.new()
	stat_label.text = _stats_text(item_id)
	stat_label.theme_type_variation = &"Muted"
	row.add_child(stat_label)

	var unequip := Button.new()
	unequip.text = "Unequip"
	unequip.pressed.connect(func(): _unequip(slot))
	row.add_child(unequip)
	return row


func _equip_row(_state: CharacterState, item_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(UiUtil.make_icon(item_id, 28))

	var name_label := Label.new()
	name_label.text = ContentRegistry.item_name(item_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var stats := Label.new()
	stats.text = _stats_text(item_id)
	stats.theme_type_variation = &"Muted"
	row.add_child(stats)

	var equip := Button.new()
	equip.text = "Equip"
	equip.pressed.connect(func(): _equip(item_id))
	row.add_child(equip)
	return row


func _equippable_ids(state: CharacterState) -> Array:
	var out: Array = []
	for item_id in state.bank.keys():
		var item := ContentRegistry.get_item(str(item_id))
		if not item.is_empty() and str(item.get("equip_slot", "")) != "":
			out.append(str(item_id))
	out.sort()
	return out


func _stats_text(item_id: String) -> String:
	var item := ContentRegistry.get_item(item_id)
	var stats: Dictionary = item.get("stats", {})
	var parts: Array = []
	for key in stats.keys():
		parts.append("%s %s" % [key, str(stats[key])])
	return "  ".join(parts)


func _equip(item_id: String) -> void:
	var item := ContentRegistry.get_item(item_id)
	if str(item.get("equip_slot", "")) == "food":
		var food_res := FoodSystem.assign(GameSession.state, item_id)
		if not food_res["ok"]:
			EventBus.notification.emit(str(food_res["reason"]), "warning")
		EventBus.state_changed.emit()
		return
	var res := EquipmentSystem.equip(GameSession.state, item_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")
	EventBus.equipment_changed.emit()
	EventBus.bank_changed.emit()


func _unequip(slot: String) -> void:
	if slot in CharacterState.FOOD_SLOTS:
		FoodSystem.clear_slot(GameSession.state, slot)
	else:
		EquipmentSystem.unequip(GameSession.state, slot)
	EventBus.equipment_changed.emit()
	EventBus.bank_changed.emit()