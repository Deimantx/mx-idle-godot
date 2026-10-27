extends Control

## Mining: deposit list (left), live mining panel and deposit detail (right).
## Clicking a deposit selects it and starts mining; the simulation owns all
## results, this screen only presents them.

const ListEntryScene := preload("res://scenes/ui/components/ListEntry.tscn")

@onready var _deposit_list: VBoxContainer = %DepositList
@onready var _active_name: Label = %ActiveName
@onready var _stage_label: Label = %StageLabel
@onready var _swing_bar: ProgressBar = %SwingBar
@onready var _pool_label: Label = %PoolLabel
@onready var _yield_label: Label = %YieldLabel
@onready var _rate_label: Label = %RateLabel
@onready var _detail: ItemDetail = %DepositDetail
@onready var _empty: EmptyState = %DetailEmpty

var _selected: String = ""
var _rows: Dictionary = {}


func _ready() -> void:
	%StopButton.pressed.connect(func(): GameSession.stop_activity(); _update_active())
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
	_rows.clear()
	var state := GameSession.state
	if state == null:
		return
	for deposit in ContentRegistry.deposits_sorted():
		var id := str(deposit["id"])
		var check := MiningSystem.can_start(state, id)
		var entry := ListEntryScene.instantiate()
		_deposit_list.add_child(entry)
		entry.configure(str(deposit["name"]), "Mining %d required" % int(deposit["unlock_level"]), "T%d" % int(deposit["tier"]))
		entry.set_icon_item(str(deposit["ore_item"]))
		if check["ok"]:
			entry.set_right_sub("Ready", Color("7ea982"))
		else:
			entry.set_right_sub(str(check["reason"]), Color("b86d65"))
			entry.set_title_color(Color("a6a39d"))
		entry.tooltip_text = "Requires pickaxe tier %d." % int(deposit["required_tool_tier"])
		entry.pressed.connect(func(): _start(id))
		_rows[id] = entry
	_highlight()


func _start(deposit_id: String) -> void:
	_selected = deposit_id
	_update_active()
	var res := GameSession.start_activity("mining", deposit_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")


func _active_id() -> String:
	var state := GameSession.state
	if state != null and not state.activity.is_empty() and str(state.activity.get("type", "")) == "mining":
		return str(state.activity.get("target", ""))
	return ""


func _highlight() -> void:
	var active := _active_id()
	var selected := _selected if _selected != "" else active
	for id in _rows:
		(_rows[id] as Button).set_active(id == selected)


func _update_active() -> void:
	var state := GameSession.state
	if state == null or state.activity.is_empty() or str(state.activity.get("type", "")) != "mining":
		_active_name.text = "No active deposit"
		_stage_label.text = "Select a deposit on the left to begin mining."
		_swing_bar.value = 0.0
		_pool_label.text = "-"
		_yield_label.text = "-"
		_rate_label.text = "-"
		_highlight()
		_update_detail()
		return
	var act: Dictionary = state.activity
	var deposit := ContentRegistry.get_deposit(str(act["target"]))
	var stage := int(act["stage"])
	var dur := maxf(0.001, float(act["duration"]))
	_active_name.text = str(deposit["name"])
	_stage_label.text = "Stage %d / 5 · %d swings left in stage" % [stage + 1, int(act.get("pool", 0))]
	_swing_bar.value = clampf(float(act["time"]) / dur, 0.0, 1.0)
	var ore := str(deposit["ore_item"])
	_pool_label.text = "%d %s per swing" % [int((deposit["stage_yields"] as Array)[stage]), ContentRegistry.item_name(ore)]
	_yield_label.text = "swing %.1fs" % dur
	var xp_per_swing := roundf(float(deposit["base_xp"]) * (1.0 + 0.12 * float(stage)))
	var per_hour := 3600.0 / dur
	_rate_label.text = "~%s XP/hr" % UiUtil.format_number(int(xp_per_swing * per_hour))
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
	var deposit := ContentRegistry.get_deposit(id)
	var ore := str(deposit["ore_item"])
	var lines: Array = [
		"Tier|T%d" % int(deposit["tier"]),
		"Ore produced|%s" % ContentRegistry.item_name(ore),
		"Unlock level|Mining %d" % int(deposit["unlock_level"]),
		"Pickaxe tier|%d" % int(deposit["required_tool_tier"]),
		"Base XP / swing|%d" % int(deposit["base_xp"]),
		"Stages|5 — deeper stages yield more",
	]
	_detail.show_detail(str(deposit["name"]), "Mining deposit · Tier %d" % int(deposit["tier"]), str(ContentRegistry.get_item(ore).get("description", "")), lines)