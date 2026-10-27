extends Control

## Fishing screen: spot selection and the active cast panel.

@onready var _spot_list: VBoxContainer = %SpotList
@onready var _active_name: Label = %ActiveName
@onready var _active_info: Label = %ActiveInfo
@onready var _cast_bar: ProgressBar = %CastBar
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
	for child in _spot_list.get_children():
		child.queue_free()
	var state := GameSession.state
	if state == null:
		return
	for spot in ContentRegistry.spots_sorted():
		_spot_list.add_child(_spot_row(state, spot))


func _spot_row(state: CharacterState, spot: Dictionary) -> Control:
	var check := FishingSystem.can_start(state, str(spot["id"]))
	var button := Button.new()
	button.name = "spot_" + str(spot["id"]).replace(".", "_")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 46)
	button.disabled = not check["ok"]
	var suffix := ""
	if not check["ok"]:
		suffix = "   ·  " + str(check["reason"])
	button.text = "T%d   %s  (Fishing %d)%s" % [
		int(spot["tier"]), str(spot["name"]), int(spot["unlock_level"]), suffix]
	button.tooltip_text = "Requires rod tier %d." % int(spot["required_rod_tier"])
	button.pressed.connect(func(): _start(str(spot["id"])))
	return button


func _start(spot_id: String) -> void:
	var res := GameSession.start_activity("fishing", spot_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")
	_update_active()


func _update_active() -> void:
	var state := GameSession.state
	if state == null or state.activity.is_empty() or str(state.activity.get("type", "")) != "fishing":
		_active_name.text = "No active spot"
		_active_info.text = "Select a fishing spot to begin."
		_cast_bar.value = 0.0
		_rate_label.text = ""
		return
	var act: Dictionary = state.activity
	var spot := ContentRegistry.get_spot(str(act["target"]))
	var duration := maxf(0.001, float(act["duration"]))
	_active_name.text = str(spot["name"])
	_cast_bar.value = clampf(float(act["time"]) / duration, 0.0, 1.0)
	_active_info.text = "Catches %s, plus rarer finds." % ContentRegistry.item_name(str(spot["fish_item"]))
	_rate_label.text = "~%s XP/hr · %.2f catches/s" % [
		UiUtil.format_number(int(float(spot["base_xp"]) * 3600.0 / duration)), 1.0 / duration]