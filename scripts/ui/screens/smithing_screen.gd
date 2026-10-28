extends Control

const ListEntryScene := preload("res://scenes/ui/components/ListEntry.tscn")

@onready var _tabs: TabContainer = $Page/Body/Browser/BrowserVBox/Tabs
@onready var _smelt_list: VBoxContainer = %SmeltList
@onready var _forge_list: VBoxContainer = %ForgeList
@onready var _search: LineEdit = %RecipeSearch
@onready var _tier_filter: OptionButton = %TierFilter
@onready var _forge_category_filter: OptionButton = %ForgeCategoryFilter
@onready var _available_filter: CheckButton = %AvailableFilter
@onready var _affordable_filter: CheckButton = %AffordableFilter
@onready var _locked_filter: CheckButton = %LockedFilter
@onready var _active_name: Label = %ActiveName
@onready var _active_info: Label = %ActiveInfo
@onready var _active_bar: ProgressBar = %ActiveBar
@onready var _rate_label: Label = %RateLabel
@onready var _detail: ItemDetail = %RecipeDetail
@onready var _empty: EmptyState = %DetailEmpty

var _selected: String = ""
var _rows: Dictionary = {}
var _recipe_cache: Dictionary = {}


func _ready() -> void:
	%StopButton.pressed.connect(_stop)
	_search.text_changed.connect(func(_text: String): _build_lists())
	_tier_filter.item_selected.connect(func(_index: int): _build_lists())
	_forge_category_filter.item_selected.connect(func(_index: int): _build_lists())
	_available_filter.toggled.connect(func(_pressed: bool): _build_lists())
	_affordable_filter.toggled.connect(func(_pressed: bool): _build_lists())
	_locked_filter.toggled.connect(func(_pressed: bool): _build_lists())
	_tabs.tab_changed.connect(func(_index: int): _build_lists())
	EventBus.activity_changed.connect(_on_activity_changed)
	EventBus.level_up.connect(func(_skill: String, _level: int): _build_lists())
	EventBus.bank_changed.connect(_on_bank_changed)
	EventBus.profile_loaded.connect(refresh)
	EventBus.state_changed.connect(_update_active)
	_build_lists()
	_update_active()


func refresh() -> void:
	_build_lists()
	_update_active()


func _on_activity_changed(_activity: Dictionary) -> void:
	_build_lists()
	_update_active()


func _on_bank_changed() -> void:
	if is_visible_in_tree():
		_build_lists()
		_update_active()


func _stop() -> void:
	GameSession.stop_activity()
	_update_active()


func _build_lists() -> void:
	for child in _smelt_list.get_children():
		child.queue_free()
	for child in _forge_list.get_children():
		child.queue_free()
	_rows.clear()
	_recipe_cache.clear()

	var state = GameSession.state
	if state == null:
		_update_detail("")
		return

	var query := _search.text.strip_edges().to_lower()
	var selected_tier := int(_tier_filter.get_item_id(_tier_filter.selected))
	for recipe in ContentRegistry.recipes_for("smithing"):
		# Legacy recipes remain in content for old saves, but are not offered to new progression.
		if bool(recipe.get("legacy", false)):
			continue
		var id := str(recipe.get("id", ""))
		if id.is_empty():
			continue
		var is_smelt := str(recipe.get("kind", "")) == "smelt"
		if _tabs.current_tab == 0 and not is_smelt:
			continue
		if _tabs.current_tab == 1 and is_smelt:
			continue
		if _tabs.current_tab == 1 and not _matches_forge_category(recipe):
			continue
		if selected_tier > 0 and int(recipe.get("tier", 1)) != selected_tier:
			continue
		if not query.is_empty() and not str(recipe.get("name", id)).to_lower().contains(query) and not id.to_lower().contains(query):
			continue

		var check: Dictionary = CraftingSystem.can_start(state, id)
		var materials_ok := _has_materials(state, recipe)
		var level_ok := _level_is_met(state, recipe, check)
		var can_craft := bool(check.get("ok", false))
		if _available_filter.button_pressed and not can_craft:
			continue
		if _affordable_filter.button_pressed and not materials_ok:
			continue
		if not _locked_filter.button_pressed and not level_ok:
			continue

		var entry: Button = ListEntryScene.instantiate()
		var tier := int(recipe.get("tier", 1))
		var level := int(recipe.get("level", 1))
		entry.configure(str(recipe.get("name", id)), "Lv %d · %.1fs/batch" % [level, float(recipe.get("time", 0.0))], "T%d" % tier)
		var output: Dictionary = recipe.get("output", {})
		if not output.is_empty():
			entry.set_icon_item(str(output.keys()[0]))
		if can_craft:
			entry.set_right_sub("READY", Color("8ebf91"))
		elif not level_ok:
			entry.set_right_sub("LOCKED", Color("c58b69"))
			entry.set_title_color(Color("9a9995"))
		elif not materials_ok:
			entry.set_right_sub("MATERIALS", Color("c87970"))
		else:
			entry.set_right_sub(str(check.get("reason", "Unavailable")), Color("c87970"))
		entry.pressed.connect(_on_recipe_selected.bind(id))
		_rows[id] = entry
		_recipe_cache[id] = recipe
		if is_smelt:
			_smelt_list.add_child(entry)
		else:
			_forge_list.add_child(entry)

	_highlight()
	var detail_id := _selected if _recipe_cache.has(_selected) else _active_id()
	if not _recipe_cache.has(detail_id):
		detail_id = ""
	_update_detail(detail_id)


func _matches_forge_category(recipe: Dictionary) -> bool:
	var selected := _forge_category_filter.selected
	if selected <= 0:
		return true
	var outputs: Dictionary = recipe.get("output", {})
	if outputs.is_empty():
		return selected == 5
	var output_id := str(outputs.keys()[0])
	var item: Dictionary = ContentRegistry.get_item(output_id)
	var category := str(item.get("category", "")).to_lower()
	var slot := str(item.get("slot", "")).to_lower()
	var id := output_id.to_lower()
	var is_tool := category in ["tool", "tools"] or slot == "tool" or "pickaxe" in id or "hammer" in id
	var is_shield := category in ["shield", "off-hand", "offhand"] or slot in ["off-hand", "offhand", "shield"] or "shield" in id or "bulwark" in id
	var is_weapon := category in ["weapon", "weapons"] or slot == "weapon" or any(["sword", "axe", "mace", "dagger", "spear", "blade", "club", "hammer_weapon"] .map(func(token): return token in id))
	var is_armour := category in ["armor", "armour", "helmet", "helm", "body", "legs", "gloves", "boots"] or slot in ["helmet", "head", "body", "chest", "legs", "hands", "feet", "armor", "armour"] or any(["helmet", "helm", "armor", "armour", "plate", "greaves", "gloves", "boots"] .map(func(token): return token in id))
	match selected:
		1:
			return is_weapon and not is_tool and not is_shield
		2:
			return is_armour and not is_shield and not is_tool
		3:
			return is_shield
		4:
			return is_tool
		5:
			return not is_weapon and not is_armour and not is_shield and not is_tool
	return true


func _on_recipe_selected(recipe_id: String) -> void:
	_selected = recipe_id
	_update_detail(recipe_id)
	_highlight()
	var state = GameSession.state
	if state == null:
		return
	var check: Dictionary = CraftingSystem.can_start(state, recipe_id)
	if not check.get("ok", false):
		EventBus.notification.emit(str(check.get("reason", "Cannot start recipe.")), "warning")
		return
	var result: Dictionary = GameSession.start_activity("smithing", recipe_id)
	if not result.get("ok", false):
		EventBus.notification.emit(str(result.get("reason", "Cannot start recipe.")), "warning")
	_build_lists()
	_update_active()


func _active_id() -> String:
	var state = GameSession.state
	if state != null and not state.activity.is_empty() and str(state.activity.get("type", "")) == "smithing":
		return str(state.activity.get("target", ""))
	return ""


func _level_is_met(state, recipe: Dictionary, check: Dictionary) -> bool:
	var required := int(recipe.get("level", 1))
	if state.has_method("get_level"):
		return int(state.get_level("smithing")) >= required
	# The canonical resolver's reason is authoritative if no level getter exists.
	var reason := str(check.get("reason", "")).to_lower()
	return not reason.contains("level") and not reason.contains("requires level")


func _has_materials(state, recipe: Dictionary) -> bool:
	var inputs: Dictionary = recipe.get("inputs", {})
	var bank: Dictionary = state.bank if "bank" in state else {}
	for item_id in inputs.keys():
		if int(bank.get(str(item_id), 0)) < int(inputs[item_id]):
			return false
	return true


func _highlight() -> void:
	var active := _active_id()
	var selected := _selected if not _selected.is_empty() else active
	for id in _rows:
		(_rows[id] as Button).set_active(str(id) == selected)


func _update_active() -> void:
	var state = GameSession.state
	var recipe_id := _active_id()
	if state == null or recipe_id.is_empty():
		_active_name.text = "WORKBENCH IDLE"
		_active_info.text = "Choose a recipe and start a batch."
		_active_bar.value = 0.0
		_rate_label.text = "No active production"
		%StopButton.disabled = true
		%ProgressCaption.text = "READY WHEN YOU ARE"
	else:
		var recipe: Dictionary = ContentRegistry.get_recipe(recipe_id)
		if recipe.is_empty():
			return
		var duration := maxf(0.01, float(recipe.get("time", 1.0)))
		var activity: Dictionary = state.activity
		var elapsed := float(activity.get("time", 0.0))
		var total := maxf(0.01, float(activity.get("duration", duration)))
		_active_name.text = str(recipe.get("name", recipe_id)).to_upper()
		_active_info.text = "BATCH IN PROGRESS  ·  %.1fs cycle  ·  %d XP" % [duration, int(recipe.get("xp", 0))]
		_active_bar.value = clampf(elapsed / total, 0.0, 1.0)
		_rate_label.text = "%s batches / hour" % UiUtil.format_number(int(3600.0 / duration))
		%StopButton.disabled = false
		%ProgressCaption.text = "BATCH %d%% COMPLETE" % int(_active_bar.value * 100.0)
	_update_detail(_selected if not _selected.is_empty() else recipe_id)
	_highlight()


func _update_detail(recipe_id: String) -> void:
	if recipe_id.is_empty():
		_detail.visible = false
		_empty.visible = true
		return
	var recipe: Dictionary = _recipe_cache.get(recipe_id, ContentRegistry.get_recipe(recipe_id))
	if recipe.is_empty():
		_detail.visible = false
		_empty.visible = true
		return
	_detail.visible = true
	_empty.visible = false
	var inputs: Dictionary = recipe.get("inputs", {})
	var outputs: Dictionary = recipe.get("output", {})
	var lines: Array[String] = []
	for item_id in inputs:
		var need := int(inputs[item_id])
		var owned := 0
		var state = GameSession.state
		if state != null and "bank" in state:
			owned = int(state.bank.get(str(item_id), 0))
		var status := "ENOUGH" if owned >= need else "NEED %d MORE" % (need - owned)
		lines.append("%s|%d / %d  ·  %s" % [ContentRegistry.item_name(str(item_id)), mini(owned, need), need, status])
	for item_id in outputs:
		lines.append("OUTPUT|%dx %s" % [int(outputs[item_id]), ContentRegistry.item_name(str(item_id))])
	lines.append("REQUIRED LEVEL|%d" % int(recipe.get("level", 1)))
	lines.append("PRODUCTION TIME|%.1f seconds" % float(recipe.get("time", 0.0)))
	lines.append("SMITHING XP|%d per batch" % int(recipe.get("xp", 0)))
	var description := ""
	if not outputs.is_empty():
		description = str(ContentRegistry.get_item(str(outputs.keys()[0])).get("description", ""))
	_detail.show_detail(str(recipe.get("name", recipe_id)), "SMITHING RECIPE  ·  TIER %d" % int(recipe.get("tier", 1)), description, lines)
