extends Control

## Bank: a searchable, category-filtered grid of everything the character has
## stored. Selecting a slot previews the item and offers its real action
## (equip / add to a food slot) where one exists.

const InventorySlotScene := preload("res://scenes/ui/components/InventorySlot.tscn")

@onready var _grid: GridContainer = %ItemGrid
@onready var _search: LineEdit = %SearchField
@onready var _count_label: Label = %CountLabel
@onready var _category: OptionButton = %CategoryFilter
@onready var _detail: ItemDetail = %ItemDetailView
@onready var _empty: EmptyState = %DetailEmpty
@onready var _action: Button = %ActionButton

var _selected: String = ""
var _category_filter: String = "all"


func _ready() -> void:
	_search.text_changed.connect(func(_t): _rebuild())
	_category.item_selected.connect(_on_category_selected)
	_action.pressed.connect(_on_action)
	EventBus.bank_changed.connect(_on_bank_changed)
	EventBus.equipment_changed.connect(_rebuild)
	EventBus.profile_loaded.connect(_rebuild)
	_rebuild()


func refresh() -> void:
	_rebuild()


func _on_bank_changed() -> void:
	if is_visible_in_tree():
		_rebuild()


func _rebuild_categories() -> void:
	var state = GameSession.state
	_category.clear()
	_category.add_item("All categories")
	_category.set_item_metadata(0, "all")
	var cats := {}
	if state != null:
		for item_id in state.bank.keys():
			var item := ContentRegistry.get_item(str(item_id))
			if not item.is_empty():
				cats[str(item.get("category", "misc"))] = true
	var keys: Array = cats.keys()
	keys.sort()
	for c in keys:
		var i := _category.item_count
		_category.add_item(str(c).capitalize())
		_category.set_item_metadata(i, str(c))
	var found := 0
	for i in range(_category.item_count):
		if str(_category.get_item_metadata(i)) == _category_filter:
			found = i
	_category.select(found)


func _rebuild() -> void:
	_rebuild_categories()
	for child in _grid.get_children():
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
		if _category_filter != "all" and str(item.get("category", "")) != _category_filter:
			continue
		shown += 1
		var id := str(item_id)
		var slot := InventorySlotScene.instantiate()
		slot.name = "Slot_" + id.replace(".", "_")
		_grid.add_child(slot)
		slot.set_item(id, int(state.bank[id]))
		slot.pressed.connect(func(): _select(id))
	_count_label.text = "%d stacks · %d shown" % [ids.size(), shown]
	_show_detail(_selected)


func _select(item_id: String) -> void:
	_selected = item_id
	_show_detail(item_id)


func _show_detail(item_id: String) -> void:
	var state := GameSession.state
	if item_id == "" or state == null or not state.bank.has(item_id):
		_detail.visible = false
		_empty.visible = true
		_action.visible = false
		return
	_detail.visible = true
	_empty.visible = false
	_detail.show_item(item_id)
	_detail.add_stat("In bank", UiUtil.format_number(int(state.bank[item_id])))
	var item := ContentRegistry.get_item(item_id)
	var slot := str(item.get("equip_slot", ""))
	if slot == "":
		_action.visible = false
	else:
		_action.visible = true
		_action.text = "Add to food slot" if slot == "food" else "Equip"


func _on_category_selected(index: int) -> void:
	_category_filter = str(_category.get_item_metadata(index))
	_rebuild()


func _on_action() -> void:
	if _selected == "":
		return
	_equip(_selected)
	_show_detail(_selected)


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
	EventBus.state_changed.emit()