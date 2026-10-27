extends Control

## Cooking: turn raw catches into food. Same reservation contract as Smithing
## (inputs reserved on start, returned on stop).

const ListEntryScene := preload("res://scenes/ui/components/ListEntry.tscn")

@onready var _recipe_list: VBoxContainer = %RecipeList
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
	EventBus.level_up.connect(func(_s, _l): _build_list())
	EventBus.bank_changed.connect(_on_bank_changed)
	EventBus.profile_loaded.connect(_build_list)
	_build_list()
	_update_active()


func refresh() -> void:
	_build_list()
	_update_active()


func _on_bank_changed() -> void:
	if is_visible_in_tree():
		_build_list()


func _build_list() -> void:
	for child in _recipe_list.get_children():
		child.queue_free()
	_rows.clear()
	var state := GameSession.state
	if state == null:
		return
	for recipe in ContentRegistry.recipes_for("cooking"):
		var id := str(recipe["id"])
		var check := CraftingSystem.can_start(state, id)
		var entry := ListEntryScene.instantiate()
		_recipe_list.add_child(entry)
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
	var res := GameSession.start_activity("cooking", recipe_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")


func _active_id() -> String:
	var state := GameSession.state
	if state != null and not state.activity.is_empty() and str(state.activity.get("type", "")) == "cooking":
		return str(state.activity.get("target", ""))
	return ""


func _highlight() -> void:
	var active := _active_id()
	var selected := _selected if _selected != "" else active
	for id in _rows:
		(_rows[id] as Button).set_active(id == selected)


func _update_active() -> void:
	var state := GameSession.state
	if state == null or state.activity.is_empty() or str(state.activity.get("type", "")) != "cooking":
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
	var heal := 0
	var satiety := 0
	for item_id in out_ids:
		outputs.append("%dx %s" % [int(recipe["output"][item_id]), ContentRegistry.item_name(str(item_id))])
		var stats: Dictionary = ContentRegistry.get_item(str(item_id)).get("stats", {})
		heal = int(stats.get("heal", heal))
		satiety = int(stats.get("satiety", satiety))
	var lines: Array = [
		"Level required|%d" % int(recipe["level"]),
		"Inputs|%s" % ", ".join(inputs),
		"Output|%s" % ", ".join(outputs),
		"Time per batch|%.1fs" % float(recipe["time"]),
		"XP per batch|%d" % int(recipe["xp"]),
	]
	if heal > 0:
		lines.append("Heals|%d HP" % heal)
	if satiety > 0:
		lines.append("Satiety|+%d" % satiety)
	_detail.show_detail(str(recipe["name"]), "Cooking recipe · Tier %d" % int(recipe["tier"]), "Cooked food restores health and fills Satiety in combat.", lines)