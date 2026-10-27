extends Control

## Combat screen: player versus enemy encounter. Reads authoritative state only;
## start/stop and prefs go through GameSession / CombatSystem. The selected
## target's resistances, sequence and drops render in the detail panel.

const ListEntryScene := preload("res://scenes/ui/components/ListEntry.tscn")
const InventorySlotScene := preload("res://scenes/ui/components/InventorySlot.tscn")

@onready var _area_select: OptionButton = %AreaSelect
@onready var _enemy_list: VBoxContainer = %EnemyList
@onready var _player_sprite: TextureRect = %PlayerSprite
@onready var _enemy_sprite: TextureRect = %EnemySprite
@onready var _player_name: Label = %PlayerName
@onready var _player_hp_bar: ProgressBar = %PlayerHpBar
@onready var _player_hp_label: Label = %PlayerHpLabel
@onready var _enemy_name: Label = %EnemyName
@onready var _enemy_hp_bar: ProgressBar = %EnemyHpBar
@onready var _enemy_hp_label: Label = %EnemyHpLabel
@onready var _satiety_bar: ProgressBar = %SatietyBar
@onready var _sequence_label: RichTextLabel = %SequenceLabel
@onready var _loadout_label: Label = %LoadoutLabel
@onready var _last_hit_label: Label = %LastHitLabel
@onready var _auto_combat_check: CheckButton = %AutoCombatCheck
@onready var _auto_eat_check: CheckButton = %AutoEatCheck
@onready var _threshold_slider: HSlider = %EatThreshold
@onready var _threshold_label: Label = %ThresholdLabel
@onready var _food_slots: HBoxContainer = %FoodSlots
@onready var _start_button: Button = %StartButton
@onready var _enemy_detail: ItemDetail = %EnemyDetail
@onready var _detail_empty: EmptyState = %DetailEmpty

var _selected_area: String = ""
var _selected_enemy: String = ""
var _user_stopped: bool = false
var _rows: Dictionary = {}


func _ready() -> void:
	%StockFoodButton.pressed.connect(_stock_food)
	_start_button.pressed.connect(_toggle_combat)
	_area_select.item_selected.connect(_on_area_selected)
	_auto_combat_check.toggled.connect(_on_auto_combat_toggled)
	_auto_eat_check.toggled.connect(func(pressed): _prefs()["auto_eat"] = pressed)
	_threshold_slider.value_changed.connect(func(value):
		_prefs()["auto_eat_threshold"] = value
		_threshold_label.text = "%d%%" % int(value * 100.0))

	EventBus.activity_changed.connect(func(_a): _update_live())
	EventBus.bank_changed.connect(_update_food_slots)
	EventBus.state_changed.connect(_refresh_static)
	EventBus.profile_loaded.connect(_refresh_static)
	_refresh_static()


func refresh() -> void:
	_refresh_static()


func _prefs() -> Dictionary:
	return GameSession.state.combat_prefs


# --- Static refresh ---------------------------------------------------------
func _refresh_static() -> void:
	var state := GameSession.state
	if state == null:
		return
	_rebuild_area_select()
	_build_enemy_list()
	_update_food_slots()
	_auto_combat_check.button_pressed = bool(_prefs().get("auto_combat", false))
	_auto_eat_check.button_pressed = bool(_prefs().get("auto_eat", true))
	var threshold := float(_prefs().get("auto_eat_threshold", 0.5))
	_threshold_slider.value = threshold
	_threshold_label.text = "%d%%" % int(threshold * 100.0)
	_loadout_label.text = _loadout_text()
	_update_enemy_detail()
	_update_live()


func _rebuild_area_select() -> void:
	var state := GameSession.state
	_area_select.clear()
	for area in ContentRegistry.areas_sorted():
		if state.get_level("attack") >= int(area["unlock_level"]):
			var index := _area_select.item_count
			_area_select.add_item("T%d  %s" % [int(area["tier"]), str(area["name"])])
			_area_select.set_item_metadata(index, str(area["id"]))
	if _area_select.item_count == 0:
		_area_select.add_item("No areas unlocked")
		_selected_area = ""
		return
	var found := -1
	for i in range(_area_select.item_count):
		if str(_area_select.get_item_metadata(i)) == _selected_area:
			found = i
	if found == -1:
		found = 0
	_area_select.select(found)
	_selected_area = str(_area_select.get_item_metadata(found))


func _build_enemy_list() -> void:
	for child in _enemy_list.get_children():
		child.queue_free()
	_rows.clear()
	var state := GameSession.state
	if state == null or _selected_area == "":
		return
	for enemy in ContentRegistry.enemies_in_area(_selected_area):
		var entry := _enemy_row(state, enemy)
		_enemy_list.add_child(entry)
		_rows[str(enemy["id"])] = entry
	_highlight_enemy()


func _enemy_row(state: CharacterState, enemy: Dictionary) -> Control:
	var check := CombatSystem.can_start(state, str(enemy["id"]))
	var rank := str(enemy["rank"])
	var rank_tag := "" if rank == "normal" else rank.to_upper()
	var entry := ListEntryScene.instantiate()
	entry.configure(str(enemy["name"]), "%s · %s · %d HP" % [
		str(enemy["style"]).capitalize(), str(enemy["damage_type"]), int(enemy["hp"])], rank_tag)
	entry.set_icon(rank.substr(0, 1).to_upper(), _rank_color(rank), _rank_color(rank))
	if rank_tag != "":
		entry.set_right_top(rank_tag, _rank_color(rank))
	if not check["ok"]:
		entry.set_right_sub(str(check["reason"]), Color("b86d65"))
		entry.set_title_color(Color("a6a39d"))
	entry.tooltip_text = _enemy_tooltip(enemy)
	entry.pressed.connect(func(): _start(str(enemy["id"])))
	return entry


func _rank_color(rank: String) -> Color:
	match rank:
		"elite":
			return Color("d18a55")
		"boss":
			return Color("b86d65")
		_:
			return Color("5a6473")


func _highlight_enemy() -> void:
	for id in _rows:
		(_rows[id] as Button).set_active(id == _selected_enemy)


func _enemy_tooltip(enemy: Dictionary) -> String:
	var lines: Array = [str(enemy["name"])]
	lines.append("Style: %s   Damage: %s" % [str(enemy["style"]), str(enemy["damage_type"])])
	var resist: Dictionary = enemy["resistances"]
	var rparts: Array = []
	for key in resist.keys():
		rparts.append("%s %+d%%" % [str(key), int(resist[key])])
	lines.append("Resistances: " + ", ".join(rparts))
	var actions: Array = []
	for action in enemy["sequence"]:
		actions.append(str(action["name"]))
	lines.append("Sequence: " + " → ".join(actions))
	if not (enemy.get("phases", []) as Array).is_empty():
		lines.append("Boss: enrages below 50% HP")
	return "\n".join(lines)


func _update_enemy_detail() -> void:
	if _selected_enemy == "":
		_enemy_detail.visible = false
		_detail_empty.visible = true
		return
	var enemy := ContentRegistry.get_enemy(_selected_enemy)
	if enemy.is_empty():
		_enemy_detail.visible = false
		_detail_empty.visible = true
		return
	_enemy_detail.visible = true
	_detail_empty.visible = false
	var resist: Dictionary = enemy["resistances"]
	var rparts: Array = []
	for key in resist.keys():
		rparts.append("%s %+d%%" % [str(key), int(resist[key])])
	var actions: Array = []
	for action in enemy["sequence"]:
		actions.append(str(action["name"]))
	var lines: Array = [
		"Rank|%s" % str(enemy["rank"]).capitalize(),
		"Style / damage|%s · %s" % [str(enemy["style"]).capitalize(), str(enemy["damage_type"])],
		"Hitpoints|%d" % int(enemy["hp"]),
		"Resistances|%s" % ", ".join(rparts),
		"Sequence|%s" % " → ".join(actions),
	]
	if not (enemy.get("phases", []) as Array).is_empty():
		lines.append("Boss phase|Enrages below 50% HP")
	if not (enemy["loot"] as Array).is_empty():
		var drops: Array = []
		for entry in enemy["loot"]:
			drops.append(ContentRegistry.item_name(str(entry["item_id"])))
		lines.append("Drops|" + ", ".join(drops))
	_enemy_detail.show_detail(str(enemy["name"]), "T%d %s" % [int(enemy["tier"]), str(enemy["rank"]).capitalize()], "", lines)


func _loadout_text() -> String:
	var state := GameSession.state
	if state == null:
		return ""
	var weapon := EquipmentSystem.equipped_item(state, "weapon")
	var weapon_text := "Unarmed"
	if not weapon.is_empty():
		var stats: Dictionary = weapon.get("stats", {})
		weapon_text = "%s (%s, %.1fs)" % [ContentRegistry.item_name(str(weapon["id"])), str(stats.get("damage_type", "?")), float(stats.get("attack_interval", 2.4))]
	return "Attack %d · Hitpoints %d · Defense %d · %s" % [
		state.get_level("attack"), state.get_level("hitpoints"), int(CombatSystem.player_defense(state)), weapon_text]


func _update_food_slots() -> void:
	for child in _food_slots.get_children():
		child.queue_free()
	var state := GameSession.state
	if state == null:
		return
	for slot in CharacterState.FOOD_SLOTS:
		var item_id := str(state.equipment.get(slot, ""))
		var view := InventorySlotScene.instantiate()
		_food_slots.add_child(view)
		if item_id == "":
			view.clear()
			view.tooltip_text = "Empty food slot"
		else:
			view.set_item(item_id, InventorySystem.count(state, item_id))


# --- Interaction ------------------------------------------------------------
func _on_area_selected(index: int) -> void:
	_selected_area = str(_area_select.get_item_metadata(index))
	_build_enemy_list()
	_update_enemy_detail()


func _on_auto_combat_toggled(pressed: bool) -> void:
	_prefs()["auto_combat"] = pressed
	_user_stopped = false


func _start(enemy_id: String) -> void:
	_selected_enemy = enemy_id
	_highlight_enemy()
	_update_enemy_detail()
	var res := GameSession.start_activity("combat", enemy_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")
		return
	_user_stopped = false
	_update_live()


func _toggle_combat() -> void:
	var state := GameSession.state
	if state == null:
		return
	if not state.activity.is_empty() and str(state.activity.get("type", "")) == "combat":
		_user_stopped = true
		GameSession.stop_activity()
	elif _selected_enemy != "":
		_start(_selected_enemy)


func _stock_food() -> void:
	var state := GameSession.state
	if state == null:
		return
	var foods: Array = []
	for item_id in state.bank.keys():
		var item := ContentRegistry.get_item(str(item_id))
		if not item.is_empty() and str(item.get("equip_slot", "")) == "food":
			foods.append({"id": str(item_id), "heal": int((item.get("stats", {}) as Dictionary).get("heal", 0))})
	foods.sort_custom(func(a, b): return int(a["heal"]) > int(b["heal"]))
	for slot in CharacterState.FOOD_SLOTS:
		FoodSystem.clear_slot(state, slot)
	for i in range(mini(foods.size(), CharacterState.FOOD_SLOTS.size())):
		FoodSystem.assign(state, str(foods[i]["id"]))
	_update_food_slots()


# --- Live refresh -----------------------------------------------------------
func _update_live() -> void:
	var state := GameSession.state
	if state == null:
		return
	var active := (not state.activity.is_empty()) and str(state.activity.get("type", "")) == "combat"

	_player_name.text = "%s  (Lv %d)" % [state.display_name, state.get_level("hitpoints")]
	var max_hp := maxi(1, state.max_hp())
	_player_hp_bar.max_value = max_hp
	_player_hp_bar.value = clampi(state.hp, 0, max_hp)
	_player_hp_label.text = "%d / %d HP" % [maxi(0, state.hp), max_hp]
	_satiety_bar.value = clampf(state.satiety, 0.0, 100.0)

	if not active:
		_enemy_name.text = "No target"
		_enemy_hp_bar.value = 0.0
		_enemy_hp_label.text = ""
		_sequence_label.text = "[color=#777c7e]Select a target to begin.[/color]"
		_last_hit_label.text = ""
		_start_button.text = "Start Combat" if _selected_enemy != "" else "Select a target"
		_start_button.disabled = _selected_enemy == ""
		_enemy_sprite.modulate = Color(1, 1, 1, 0.35)
		_maybe_auto_restart()
		return

	var act: Dictionary = state.activity
	var enemy := ContentRegistry.get_enemy(str(act["target"]))
	var enemy_max := maxi(1, int(enemy["hp"]))
	_enemy_name.text = "%s  (T%d %s)" % [str(enemy["name"]), int(enemy["tier"]), str(enemy["rank"])]
	_enemy_hp_bar.max_value = enemy_max
	_enemy_hp_bar.value = clampi(int(act["enemy_hp"]), 0, enemy_max)
	_enemy_hp_label.text = "%d / %d HP" % [maxi(0, int(act["enemy_hp"])), enemy_max]
	_enemy_sprite.modulate = Color(1, 0.7, 0.7) if str(enemy["rank"]) == "boss" else (Color(1, 0.85, 0.6) if str(enemy["rank"]) == "elite" else Color(1, 1, 1))
	_player_sprite.modulate = Color(0.6, 0.6, 0.75) if float(act.get("stun", 0.0)) > 0.0 else Color(1, 1, 1)
	_sequence_label.text = _sequence_text(act, enemy)
	_start_button.text = "Stop Combat"
	_start_button.disabled = false
	if float(act.get("stun", 0.0)) > 0.0:
		_sequence_label.text += "\n[color=#b86d65]Stunned![/color]"


func _sequence_text(act: Dictionary, enemy: Dictionary) -> String:
	var sequence := CombatSystem.current_sequence(act, enemy)
	var index := CombatSystem.current_index(act, enemy)
	var parts: Array = []
	for i in range(sequence.size()):
		var action_name := str(sequence[i]["name"])
		if i == index:
			parts.append("[color=#e7e2da][b]%s[/b][/color]" % action_name)
		else:
			parts.append("[color=#777c7e]%s[/color]" % action_name)
	return "  ".join(parts)


func _maybe_auto_restart() -> void:
	var state := GameSession.state
	if state == null:
		return
	if _user_stopped or _selected_enemy == "":
		return
	if not bool(_prefs().get("auto_combat", false)):
		return
	if CombatSystem.can_start(state, _selected_enemy)["ok"]:
		GameSession.start_activity("combat", _selected_enemy)