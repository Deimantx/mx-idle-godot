extends Control

## Equipment: current slots (left) and equippable bank items (right). Every
## equip/unequip goes through EquipmentSystem, which owns ownership rules.
## Selecting a row previews the item in the detail panel.

const ListEntryScene := preload("res://scenes/ui/components/ListEntry.tscn")

@onready var _slot_list: VBoxContainer = %SlotList
@onready var _equip_list: VBoxContainer = %EquipList
@onready var _detail: ItemDetail = %ItemDetailView
@onready var _empty: EmptyState = %DetailEmpty


func _ready() -> void:
	EventBus.equipment_changed.connect(_rebuild)
	EventBus.bank_changed.connect(_on_bank_changed)
	EventBus.profile_loaded.connect(_rebuild)
	_rebuild()
	_show_detail("")


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
	var entry := ListEntryScene.instantiate()
	if item_id == "":
		entry.hide_icon()
		entry.configure(slot.capitalize(), "Empty", "", "")
		entry.set_sub_color(Color("777c7e"))
		return entry
	entry.set_icon_item(item_id)
	entry.configure(slot.capitalize(), ContentRegistry.item_name(item_id), "T%d" % int(ContentRegistry.get_item(item_id).get("tier", 0)), "Unequip")
	entry.set_title_color(UiUtil.rarity_color(str(ContentRegistry.get_item(item_id).get("rarity", "common"))))
	entry.tooltip_text = _stats_text(item_id)
	entry.pressed.connect(func():
		_unequip(slot)
		_show_detail(item_id))
	return entry


func _equip_row(_state: CharacterState, item_id: String) -> Control:
	var entry := ListEntryScene.instantiate()
	entry.set_icon_item(item_id)
	var item := ContentRegistry.get_item(item_id)
	entry.configure(ContentRegistry.item_name(item_id), _stats_text(item_id), "T%d" % int(item.get("tier", 0)), "Equip")
	entry.set_title_color(UiUtil.rarity_color(str(item.get("rarity", "common"))))
	entry.tooltip_text = str(item.get("description", ""))
	entry.pressed.connect(func():
		_equip(item_id)
		_show_detail(item_id))
	return entry


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
		parts.append("%s %s" % [str(key).capitalize(), str(stats[key])])
	if parts.is_empty():
		return "No bonuses"
	return " · ".join(parts)


func _show_detail(item_id: String) -> void:
	if item_id == "":
		_detail.visible = false
		_empty.visible = true
		return
	_detail.visible = true
	_empty.visible = false
	_detail.show_item(item_id)


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