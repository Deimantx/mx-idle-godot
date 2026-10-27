extends Control

## Mining screen: deposit selection (left) and the active mining panel (right).
## Clicking a deposit calls MiningSystem via GameSession; the simulation decides
## rewards, this screen only displays.

@onready var _deposit_list: VBoxContainer = %DepositList
@onready var _active_name: Label = %ActiveName
@onready var _stage_label: Label = %StageLabel
@onready var _swing_bar: ProgressBar = %SwingBar
@onready var _pool_label: Label = %PoolLabel
@onready var _yield_label: Label = %YieldLabel
@onready var _rate_label: Label = %RateLabel


func _ready() -> void:
	%StopButton.pressed.connect(func(): GameSession.stop_activity())
	EventBus.activity_changed.connect(func(_a): _update_active())
	EventBus.level_up.connect(func(_s, _l): _build_list())
	EventBus.profile_loaded.connect(_build_list)
	_build_list()
	_update_active()


func refresh() -> void:
	_build_list()
	_update_active()


func _build_list() -> void:
	for child in _deposit_list.get_children():
		child.queue_free()
	var state := GameSession.state
	if state == null:
		return
	for deposit in ContentRegistry.deposits_sorted():
		_deposit_list.add_child(_deposit_row(state, deposit))


func _deposit_row(state: CharacterState, deposit: Dictionary) -> Control:
	var check := MiningSystem.can_start(state, str(deposit["id"]))
	var button := Button.new()
	button.name = "dep_" + str(deposit["ore_item"]).replace(".", "_")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 46)
	button.disabled = not check["ok"]
	var suffix := ""
	if not check["ok"]:
		suffix = "   ·  " + str(check["reason"])
	button.text = "T%d   %s  (Mining %d)%s" % [
		int(deposit["tier"]), str(deposit["name"]), int(deposit["unlock_level"]), suffix]
	button.tooltip_text = "Requires pickaxe tier %d." % int(deposit["required_tool_tier"])
	button.pressed.connect(func(): _start(str(deposit["id"])))
	return button


func _start(deposit_id: String) -> void:
	var res := GameSession.start_activity("mining", deposit_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")
	_update_active()


func _update_active() -> void:
	var state := GameSession.state
	if state == null or state.activity.is_empty() or str(state.activity.get("type", "")) != "mining":
		_active_name.text = "No active deposit"
		_stage_label.text = "Select a deposit to begin mining."
		_swing_bar.value = 0.0
		_pool_label.text = ""
		_yield_label.text = ""
		_rate_label.text = ""
		return
	var act: Dictionary = state.activity
	var deposit := ContentRegistry.get_deposit(str(act["target"]))
	var stage := int(act["stage"])
	var dur := maxf(0.001, float(act["duration"]))

	_active_name.text = str(deposit["name"])
	_stage_label.text = "Stage %d / 5 · swings left: %d" % [stage + 1, int(act.get("pool", 0))]
	_swing_bar.value = clampf(float(act["time"]) / dur, 0.0, 1.0)
	var ore := str(deposit["ore_item"])
	_pool_label.text = "Each swing yields %d %s." % [
		int((deposit["stage_yields"] as Array)[stage]), ContentRegistry.item_name(ore)]
	_yield_label.text = "Deeper stages yield more ore."

	var xp_per_swing := roundf(float(deposit["base_xp"]) * (1.0 + 0.12 * float(stage)))
	var per_hour := 3600.0 / dur
	_rate_label.text = "~%s XP/hr · %.2f swings/s" % [
		UiUtil.format_number(int(xp_per_swing * per_hour)), 1.0 / dur]