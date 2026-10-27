extends Control

## Smithing: smelting and forging recipes, grouped by tab, plus the active
## workstation panel and a recipe detail column. Input reservation, timing and
## rewards all belong to the simulation.

const ListEntryScene := preload("res://scenes/ui/components/ListEntry.tscn")

@onready var _smelt_list: VBoxContainer = %SmeltList
@onready var _forge_list: VBoxContainer = %ForgeList
@onready var _active_name: Label = %ActiveName
@onready var _active_info: Label = %ActiveInfo
@onready var _active_bar: ProgressBar = %ActiveBar
@onready var _rate_label: Label = %RateLabel
@onready var _detail: ItemDetail = %RecipeDetail
@onready var _empty: EmptyState = %DetailEmpty

var _selected: String = ""
var _rows: Dictionary = {}


func _ready() -> void:
	%StopButton.pressed.connect(func(): GameSession.stop_activity(); _update_active())
	EventBus.activity_changed.connect(func(_a): _update_active())
	EventBus.level_up.connect(func(_s, _l): _build_lists())
	EventBus.bank_changed.connect(_on_bank_changed)
	EventBus.profile_loaded.connect(_build_lists)
	_build_lists()
	_update_active()


func refresh() -> void:
	_build_lists()
	_update_active()


func _on_bank_changed() -> void:
	if is_visible_in_tree():
		_build_lists()


func _build_lists() -> void:
	for child in _smelt_list.get_children():
		child.queue_free()
	for child in _forge_list.get_children():
		child.queue_free()
	_rows.clear()
	var state := GameSession.state
	if state == null:
		return
	for recipe in ContentRegistry.recipes_for("smithing"):
		var is_smelt := str(recipe["kind"]) == "smelt"
		var target := _smelt_list if is_smelt else _forge_list
		var id := str(recipe["id"])
		var check := CraftingSystem.can_start(state, id)
		var entry := ListEntryScene.instantiate()
		target.add_child(entry)
		entry.configure(str(recipe["name"]), "Lv %d · %.1fs/batch" % [int(recipe["level"]), float(recipe["time"])], "T%d" % int(recipe["tier"]))
		var output_ids: Array = (recipe["output"] as Dictionary).keys()
		if not output_ids.is_empty():
			entry.set_icon_item(str(output_ids[0]))
		if not check["ok"]:
			entry.set_right_sub(str(check["reason"]), Color("b86d65"))
			entry.set_title_color(Color("a6a39d"))
		entry.pressed.connect(func(): _start(id))
		_rows[id] = entry
	_highlight()


func _start(recipe_id: String) -> void:
	_selected = recipe_id
	_update_active()
	var res := GameSession.start_activity("smithing", recipe_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")


func _active_id() -> String:
	var state := GameSession.state
	if state != null and not state.activity.is_empty() and str(state.activity.get("type", "")) == "smithing":
		return str(state.activity.get("target", ""))
	return ""


func _highlight() -> void:
	var active := _active_id()
	var selected := _selected if _selected != "" else active
	for id in _rows:
		(_rows[id] as Button).set_active(id == selected)


func _update_active() -> void:
	var state := GameSession.state
	if state == null or state.activity.is_empty() or str(state.activity.get("type", "")) != "smithing":
		_active_name.text = "No active recipe"
		_active_info.text = "Select a recipe to begin."
		_active_bar.value = 0.0
		_rate_label.text = "-"
		_highlight()
		_update_detail()
		return
	var act: Dictionary = state.activity
	var recipe := ContentRegistry.get_recipe(str(act["target"]))
	_active_name.text = str(recipe["name"])
	_active_bar.value = clampf(float(act["time"]) / maxf(0.001, float(act["duration"])), 0.0, 1.0)
	_active_info.text = "%.1fs per batch · %d XP" % [float(recipe["time"]), int(recipe["xp"])]
	_rate_label.text = "~%s batches/hr" % UiUtil.format_number(int(3600.0 / maxf(0.01, float(recipe["time"]))))
	_highlight()
	_update_detail()


func _update_detail() -> void:
	var id := _selected if _selected != "" else _active_id()
	if id == "":
		_detail.visible = false
		_empty.visible = true
		return
	_detail.visible = true
	_empty.visible = false
	var recipe := ContentRegistry.get_recipe(id)
	var inputs: Array = []
	for item_id in (recipe["inputs"] as Dictionary).keys():
		inputs.append("%dx %s" % [int(recipe["inputs"][item_id]), ContentRegistry.item_name(str(item_id))])
	var outputs: Array = []
	var out_ids: Array = (recipe["output"] as Dictionary).keys()
	for item_id in out_ids:
		outputs.append("%dx %s" % [int(recipe["output"][item_id]), ContentRegistry.item_name(str(item_id))])
	var lines: Array = [
		"Kind|%s" % ("Smelt" if str(recipe["kind"]) == "smelt" else "Forge"),
		"Level required|%d" % int(recipe["level"]),
		"Inputs|%s" % ", ".join(inputs),
		"Output|%s" % ", ".join(outputs),
		"Time per batch|%.1fs" % float(recipe["time"]),
		"XP per batch|%d" % int(recipe["xp"]),
	]
	var desc := ""
	if not out_ids.is_empty():
		desc = str(ContentRegistry.get_item(str(out_ids[0])).get("description", ""))
	_detail.show_detail(str(recipe["name"]), "Smithing recipe · Tier %d" % int(recipe["tier"]), desc, lines)
