extends Control

## Fishing: spot selection (left), live cast panel and spot detail (right).
## Catch weighting and rewards are resolved by the simulation.

const ListEntryScene := preload("res://scenes/ui/components/ListEntry.tscn")

@onready var _spot_list: VBoxContainer = %SpotList
@onready var _active_name: Label = %ActiveName
@onready var _active_info: Label = %ActiveInfo
@onready var _cast_bar: ProgressBar = %CastBar
@onready var _rate_label: Label = %RateLabel
@onready var _detail: ItemDetail = %SpotDetail
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
	for child in _spot_list.get_children():
		child.queue_free()
	_rows.clear()
	var state := GameSession.state
	if state == null:
		return
	for spot in ContentRegistry.spots_sorted():
		var id := str(spot["id"])
		var check := FishingSystem.can_start(state, id)
		var entry := ListEntryScene.instantiate()
		_spot_list.add_child(entry)
		entry.configure(str(spot["name"]), "Fishing %d required" % int(spot["unlock_level"]), "T%d" % int(spot["tier"]))
		entry.set_icon_item(str(spot["fish_item"]))
		if check["ok"]:
			entry.set_right_sub("Ready", Color("7ea982"))
		else:
			entry.set_right_sub(str(check["reason"]), Color("b86d65"))
			entry.set_title_color(Color("a6a39d"))
		entry.tooltip_text = "Requires rod tier %d." % int(spot["required_rod_tier"])
		entry.pressed.connect(func(): _start(id))
		_rows[id] = entry
	_highlight()


func _start(spot_id: String) -> void:
	_selected = spot_id
	_update_active()
	var res := GameSession.start_activity("fishing", spot_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")


func _active_id() -> String:
	var state := GameSession.state
	if state != null and not state.activity.is_empty() and str(state.activity.get("type", "")) == "fishing":
		return str(state.activity.get("target", ""))
	return ""


func _highlight() -> void:
	var active := _active_id()
	var selected := _selected if _selected != "" else active
	for id in _rows:
		(_rows[id] as Button).set_active(id == selected)


func _update_active() -> void:
	var state := GameSession.state
	if state == null or state.activity.is_empty() or str(state.activity.get("type", "")) != "fishing":
		_active_name.text = "No active spot"
		_active_info.text = "Select a fishing spot to begin."
		_cast_bar.value = 0.0
		_rate_label.text = "-"
		_highlight()
		_update_detail()
		return
	var act: Dictionary = state.activity
	var spot := ContentRegistry.get_spot(str(act["target"]))
	var duration := maxf(0.001, float(act["duration"]))
	_active_name.text = str(spot["name"])
	_cast_bar.value = clampf(float(act["time"]) / duration, 0.0, 1.0)
	_active_info.text = "Casting every %.1fs · main catch %s" % [duration, ContentRegistry.item_name(str(spot["fish_item"]))]
	_rate_label.text = "~%s XP/hr" % UiUtil.format_number(int(float(spot["base_xp"]) * 3600.0 / duration))
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
	var spot := ContentRegistry.get_spot(id)
	var fish := str(spot["fish_item"])
	var lines: Array = [
		"Tier|T%d" % int(spot["tier"]),
		"Main catch|%s" % ContentRegistry.item_name(fish),
		"Unlock level|Fishing %d" % int(spot["unlock_level"]),
		"Rod tier|%d" % int(spot["required_rod_tier"]),
		"Base XP / catch|%d" % int(spot["base_xp"]),
	]
	var pool: Array = spot.get("pool", [])
	if pool.size() > 1:
		var extras: Array = []
		for entry in pool:
			if str(entry.get("item_id", "")) != fish:
				extras.append(ContentRegistry.item_name(str(entry["item_id"])))
		if not extras.is_empty():
			lines.append("Rare finds|" + ", ".join(extras))
	_detail.show_detail(str(spot["name"]), "Fishing spot · Tier %d" % int(spot["tier"]), str(ContentRegistry.get_item(fish).get("description", "")), lines)