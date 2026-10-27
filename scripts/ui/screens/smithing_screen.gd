extends Control

const ListEntryScene := preload("res://scenes/ui/components/ListEntry.tscn")

@onready var _tabs: TabContainer = $HBox/Left/LeftVBox/Tabs
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
	%StopButton.pressed.connect(_stop)
	_tabs.tab_changed.connect(_on_tab_changed)
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


func _on_tab_changed(_index: int) -> void:
	_build_lists()


func _stop() -> void:
	GameSession.stop_activity()
	_update_active()


func _build_lists() -> void:
	for child in _smelt_list.get_children():
		child.queue_free()
	for child in _forge_list.get_children():
		child.queue_free()
	_rows.clear()

	var state = GameSession.state
	if state == null:
		return

	for recipe in ContentRegistry.recipes_for("smithing"):
		var id := str(recipe.get("id", ""))
		if id.is_empty():
			continue
		var is_smelt := str(recipe.get("kind", "")) == "smelt"
		if _tabs.current_tab == 0 and not is_smelt:
			continue
		if _tabs.current_tab == 1 and is_smelt:
			continue

		var entry = ListEntryScene.instantiate()
		var level := int(recipe.get("level", 1))
		var tier := int(recipe.get("tier", 1))
		entry.configure(str(recipe.get("name", id)), "Lv %d · %.1fs/batch" % [level, float(recipe.get("time", 0.0))], "T%d" % tier)
		var output: Dictionary = recipe.get("output", {})
		var output_ids: Array = output.keys()
		if not output_ids.is_empty():
			entry.set_icon_item(str(output_ids[0]))

		var check: Dictionary = CraftingSystem.can_start(state, id)
		if check.get("ok", false):
			entry.set_right_sub("Ready", Color("7ea982"))
		else:
			entry.set_right_sub(str(check.get("reason", "Unavailable")), Color("b86d65"))
			entry.set_title_color(Color("a6a39d"))

		entry.pressed.connect(func(): _start(id))
		if is_smelt:
			_smelt_list.add_child(entry)
		else:
			_forge_list.add_child(entry)
		_rows[id] = entry

	_highlight()


func _start(recipe_id: String) -> void:
	_selected = recipe_id
	var result: Dictionary = GameSession.start_activity("smithing", recipe_id)
	if not result.get("ok", false):
		EventBus.notification.emit(str(result.get("reason", "Cannot start recipe")), "warning")
	_update_active()


func _active_id() -> String:
	var state = GameSession.state
	if state != null and not state.activity.is_empty() and str(state.activity.get("type", "")) == "smithing":
		return str(state.activity.get("target", ""))
	return ""


func _highlight() -> void:
	var active := _active_id()
	var selected := _selected if not _selected.is_empty() else active
	for id in _rows:
		(_rows[id] as Button).set_active(str(id) == selected)


func _update_active() -> void:
	var state = GameSession.state
	var recipe_id := _active_id()
	if state == null or recipe_id.is_empty():
		_active_name.text = "No active recipe"
		_active_info.text = "Select a recipe to begin."
		_active_bar.value = 0.0
		_rate_label.text = "-"
		_update_detail(_selected)
		_highlight()
		return

	var recipe: Dictionary = ContentRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		return
	_active_name.text = str(recipe.get("name", recipe_id))
	var duration := maxf(0.01, float(recipe.get("time", 1.0)))
	_active_info.text = "%.1fs per batch · %d XP" % [duration, int(recipe.get("xp", 0))]
	_active_bar.value = clampf(float(state.activity.get("time", 0.0)) / maxf(0.001, float(state.activity.get("duration", duration))), 0.0, 1.0)
	_rate_label.text = "~%s batches/hr" % UiUtil.format_number(int(3600.0 / duration))
	_update_detail(_selected if not _selected.is_empty() else recipe_id)
	_highlight()


func _update_detail(recipe_id: String) -> void:
	if recipe_id.is_empty():
		_detail.visible = false
		_empty.visible = true
		return
	var recipe: Dictionary = ContentRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		_detail.visible = false
		_empty.visible = true
		return

	_detail.visible = true
	_empty.visible = false
	var inputs: Dictionary = recipe.get("inputs", {})
	var outputs: Dictionary = recipe.get("output", {})
	var input_lines: Array[String] = []
	var output_lines: Array[String] = []
	for item_id in inputs:
		input_lines.append("%dx %s" % [int(inputs[item_id]), ContentRegistry.item_name(str(item_id))])
	for item_id in outputs:
		output_lines.append("%dx %s" % [int(outputs[item_id]), ContentRegistry.item_name(str(item_id))])
	var details: Array = [
		"Kind|%s" % ("Smelt" if str(recipe.get("kind", "")) == "smelt" else "Forge"),
		"Level required|%d" % int(recipe.get("level", 1)),
		"Inputs|%s" % ", ".join(input_lines),
		"Output|%s" % ", ".join(output_lines),
		"Time per batch|%.1fs" % float(recipe.get("time", 0.0)),
		"XP per batch|%d" % int(recipe.get("xp", 0)),
	]
	var description := ""
	if not outputs.is_empty():
		description = str(ContentRegistry.get_item(str(outputs.keys()[0])).get("description", ""))
	_detail.show_detail(str(recipe.get("name", recipe_id)), "Smithing recipe · Tier %d" % int(recipe.get("tier", 1)), description, details)
