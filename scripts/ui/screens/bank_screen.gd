extends Control

## Bank: searchable item list with compact rows, rarity colouring and inline
## equip for equippable items.

@onready var _item_list: VBoxContainer = %ItemList
@onready var _search: LineEdit = %SearchField
@onready var _count_label: Label = %CountLabel


func _ready() -> void:
	_search.text_changed.connect(func(_t): _rebuild())
	EventBus.bank_changed.connect(_on_bank_changed)
	EventBus.equipment_changed.connect(_rebuild)
	EventBus.profile_loaded.connect(_rebuild)
	_rebuild()


func refresh() -> void:
	_rebuild()


func _on_bank_changed() -> void:
	if is_visible_in_tree():
		_rebuild()


func _rebuild() -> void:
	for child in _item_list.get_children():
		child.queue_free()
	var state := GameSession.state
	if state == null:
		return
	var query := _search.text.strip_edges().to_lower()
	var ids: Array = state.bank.keys()
	ids.sort()
	var shown := 0
	for item_id in ids:
		var item := ContentRegistry.get_item(str(item_id))
		if item.is_empty():
			continue
		if query != "" and not str(item["name"]).to_lower().contains(query):
			continue
		shown += 1
		_item_list.add_child(_row(str(item_id), item, int(state.bank[item_id])))
	_count_label.text = "%d stacks · %d shown" % [ids.size(), shown]


func _row(item_id: String, item: Dictionary, qty: int) -> Control:
	var row := HBoxContainer.new()
	row.add_child(UiUtil.make_icon(item_id, 30))

	var name_label := Label.new()
	name_label.text = str(item["name"])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", UiUtil.rarity_color(str(item.get("rarity", "common"))))
	row.add_child(name_label)

	var tier_label := Label.new()
	tier_label.text = "T%d" % int(item.get("tier", 0))
	tier_label.theme_type_variation = &"Muted"
	tier_label.custom_minimum_size = Vector2(42, 0)
	row.add_child(tier_label)

	var qty_label := Label.new()
	qty_label.text = UiUtil.format_number(qty)
	qty_label.custom_minimum_size = Vector2(100, 0)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(qty_label)

	if str(item.get("equip_slot", "")) != "":
		var equip := Button.new()
		equip.text = "Equip"
		equip.pressed.connect(func(): _equip(item_id))
		row.add_child(equip)
	return row


func _equip(item_id: String) -> void:
	var res := EquipmentSystem.equip(GameSession.state, item_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")
	EventBus.equipment_changed.emit()
	EventBus.bank_changed.emit()
	EventBus.state_changed.emit()