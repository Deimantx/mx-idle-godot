extends Control

## Cooking screen: cook raw catches into food. Same reservation contract as
## Smithing (inputs reserved on start, returned on stop).

@onready var _recipe_list: VBoxContainer = %RecipeList
@onready var _active_name: Label = %ActiveName
@onready var _active_info: Label = %ActiveInfo
@onready var _active_bar: ProgressBar = %ActiveBar
@onready var _rate_label: Label = %RateLabel


func _ready() -> void:
	%StopButton.pressed.connect(func(): GameSession.stop_activity())
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
	var state := GameSession.state
	if state == null:
		return
	for recipe in ContentRegistry.recipes_for("cooking"):
		_recipe_list.add_child(_recipe_row(state, recipe))


func _recipe_row(state: CharacterState, recipe: Dictionary) -> Control:
	var check := CraftingSystem.can_start(state, str(recipe["id"]))
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 44)
	button.disabled = not check["ok"]
	var inputs: Array = []
	for item_id in (recipe["inputs"] as Dictionary).keys():
		inputs.append("%d %s" % [int(recipe["inputs"][item_id]), ContentRegistry.item_name(str(item_id))])
	var outputs: Array = []
	for item_id in (recipe["output"] as Dictionary).keys():
		outputs.append("%d %s" % [int(recipe["output"][item_id]), ContentRegistry.item_name(str(item_id))])
	var suffix := ""
	if not check["ok"]:
		suffix = "   ·  " + str(check["reason"])
	button.text = "%s  (Lv %d)   %s → %s%s" % [
		str(recipe["name"]), int(recipe["level"]), ", ".join(inputs), ", ".join(outputs), suffix]
	button.tooltip_text = "%.1fs per batch · %d XP" % [float(recipe["time"]), int(recipe["xp"])]
	button.pressed.connect(func(): _start(str(recipe["id"])))
	return button


func _start(recipe_id: String) -> void:
	var res := GameSession.start_activity("cooking", recipe_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")
	_update_active()


func _update_active() -> void:
	var state := GameSession.state
	if state == null or state.activity.is_empty() or str(state.activity.get("type", "")) != "cooking":
		_active_name.text = "No active recipe"
		_active_info.text = "Select a recipe to begin."
		_active_bar.value = 0.0
		_rate_label.text = ""
		return
	var act: Dictionary = state.activity
	var recipe := ContentRegistry.get_recipe(str(act["target"]))
	_active_name.text = str(recipe["name"])
	_active_bar.value = clampf(float(act["time"]) / maxf(0.001, float(act["duration"])), 0.0, 1.0)
	_active_info.text = "%.1fs per batch · %d XP per batch" % [float(recipe["time"]), int(recipe["xp"])]
	_rate_label.text = "~%s batches/hr" % UiUtil.format_number(int(3600.0 / float(recipe["time"])))