extends Node

## Authoritative simulation driver. Holds the active character, advances the
## single personal activity with a deterministic elapsed-time model, applies
## offline progress through the SAME resolver, and autosaves.

const MAX_OFFLINE_SECONDS := 12 * 3600
const AUTOSAVE_INTERVAL := 15.0
const MAX_ACTIONS_PER_ADVANCE := 500000

var state: CharacterState = null
var _autosave_accum: float = 0.0


func _ready() -> void:
	set_process(false)
	EventBus.notification.connect(func(_t, _k): pass)


func is_loaded() -> bool:
	return state != null


func _notification(what: int) -> void:
	# Persist on window close so a normal quit never loses progress.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if state != null:
			save()


# --- Lifecycle --------------------------------------------------------------
func start_new_character(profile_name: String) -> bool:
	var id := SaveService.create_profile(profile_name)
	if id == "":
		return false
	return load_character(id)


func load_character(profile_id: String) -> bool:
	var loaded := SaveService.read_profile(profile_id)
	if loaded == null:
		return false
	state = loaded
	SaveService.set_last_profile(profile_id)
	_apply_offline()
	set_process(true)
	EventBus.profile_loaded.emit()
	EventBus.state_changed.emit()
	return true


func unload() -> void:
	if state != null:
		save()
	state = null
	set_process(false)
	EventBus.state_changed.emit()


func save() -> void:
	if state != null:
		SaveService.write_profile(state)


# --- Activity control -------------------------------------------------------
func start_activity(type: String, target: String) -> Dictionary:
	if state == null:
		return {"ok": false, "reason": "No character loaded."}
	var check := {}
	match type:
		"mining":
			check = MiningSystem.can_start(state, target)
		"fishing":
			check = FishingSystem.can_start(state, target)
		"smithing", "cooking":
			check = CraftingSystem.can_start(state, target)
		"combat":
			check = CombatSystem.can_start(state, target)
		_:
			return {"ok": false, "reason": "Unknown activity type."}
	if not check["ok"]:
		return check

	_stop_activity(true)
	if type == "combat" and state.hp <= 0:
		state.hp = state.max_hp()
	match type:
		"mining":
			state.activity = MiningSystem.make_activity(state, target)
		"fishing":
			state.activity = FishingSystem.make_activity(state, target)
		"smithing", "cooking":
			state.activity = CraftingSystem.make_activity(state, target)
		"combat":
			state.activity = CombatSystem.make_activity(state, target)
	state.activity["started_unix"] = int(Time.get_unix_time_from_system())

	EventBus.activity_changed.emit(state.activity)
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


func stop_activity() -> void:
	_stop_activity(true)


func _stop_activity(return_reserved: bool) -> void:
	if state == null or state.activity.is_empty():
		return
	var type := str(state.activity.get("type", ""))
	if return_reserved and (type == "smithing" or type == "cooking"):
		CraftingSystem.return_reserved(state, state.activity)
	state.activity = {}
	EventBus.activity_changed.emit({})
	EventBus.state_changed.emit()


# --- Simulation -------------------------------------------------------------
func _process(delta: float) -> void:
	if state == null:
		return
	if not state.activity.is_empty():
		state.play_time += delta
		advance(delta)
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL:
		_autosave_accum = 0.0
		save()


## Advance the active activity by `delta` seconds. When `collect` is a
## non-empty dictionary, per-action events are accumulated into it instead of
## being emitted (used for offline progress so nothing is spammed/double-awarded).
func advance(delta: float, collect: Dictionary = {}) -> void:
	if state == null or state.activity.is_empty():
		return
	if str(state.activity.get("type", "")) == "combat":
		_advance_combat(delta, collect)
		return
	state.activity["time"] = float(state.activity["time"]) + delta
	var guard := 0
	while not state.activity.is_empty() \
			and float(state.activity["time"]) >= float(state.activity["duration"]) \
			and guard < MAX_ACTIONS_PER_ADVANCE:
		guard += 1
		var duration := maxf(0.001, float(state.activity["duration"]))
		state.activity["time"] = float(state.activity["time"]) - duration
		var result := _complete_action(collect)
		if result.get("stop", false):
			_stop_activity(false)
			if collect.is_empty():
				EventBus.notification.emit(str(result.get("reason", "Stopped.")), "info")
			collect["stop_reason"] = str(result.get("reason", "Stopped."))
			break
	# Frequent, cheap progress signal only. Discrete changes use state_changed.
	if collect.is_empty():
		EventBus.activity_changed.emit(state.activity)


## Combat runs on its own continuous clock (two independent attackers, statuses
## and Satiety), so it is not driven by the per-action while-loop above.
func _advance_combat(delta: float, collect: Dictionary) -> void:
	var result := CombatSystem.tick(state, state.activity, delta)
	_emit_result(result, collect)
	if result.get("stop", false):
		_stop_activity(false)
		if collect.is_empty():
			EventBus.notification.emit(str(result.get("reason", "Defeated.")), "warning")
		collect["stop_reason"] = str(result.get("reason", "Defeated."))
	if collect.is_empty():
		EventBus.activity_changed.emit(state.activity)


func _complete_action(collect: Dictionary) -> Dictionary:
	var result := {}
	match str(state.activity.get("type", "")):
		"mining":
			result = MiningSystem.on_action(state, state.activity)
		"fishing":
			result = FishingSystem.on_action(state, state.activity)
		"smithing", "cooking":
			result = CraftingSystem.on_action(state, state.activity)
		_:
			return {}
	_emit_result(result, collect)
	return result


## Counters + presentation events for a resolver result. Shared by every activity.
func _emit_result(result: Dictionary, collect: Dictionary) -> void:
	state.counters["actions_completed"] = int(state.counters.get("actions_completed", 0)) + 1
	var items: Dictionary = result.get("items", {})
	for item_id in items.keys():
		state.counters["items_gained"] = int(state.counters.get("items_gained", 0)) + int(items[item_id])
	if collect.is_empty():
		for item_id in items.keys():
			EventBus.item_gained.emit(item_id, int(items[item_id]))
		for skill in (result.get("xp", {}) as Dictionary).keys():
			EventBus.xp_gained.emit(skill, int(result["xp"][skill]))
		var leveled := false
		for skill in (result.get("levels", {}) as Dictionary).keys():
			for level in result["levels"][skill]:
				EventBus.level_up.emit(skill, int(level))
				leveled = true
		if not items.is_empty():
			EventBus.bank_changed.emit()
		EventBus.action_completed.emit(result)
		if leveled or int(result.get("gold", 0)) > 0:
			EventBus.state_changed.emit()
	else:
		_collect_offline(collect, result)


func _collect_offline(collect: Dictionary, result: Dictionary) -> void:
	collect["actions"] = int(collect.get("actions", 0)) + 1
	var items: Dictionary = collect.get("items", {})
	for item_id in (result.get("items", {}) as Dictionary).keys():
		items[item_id] = int(items.get(item_id, 0)) + int(result["items"][item_id])
	collect["items"] = items
	var xp: Dictionary = collect.get("xp", {})
	for skill in (result.get("xp", {}) as Dictionary).keys():
		xp[skill] = int(xp.get(skill, 0)) + int(result["xp"][skill])
	collect["xp"] = xp
	var levels: Dictionary = collect.get("levels", {})
	for skill in (result.get("levels", {}) as Dictionary).keys():
		var arr: Array = levels.get(skill, [])
		for level in result["levels"][skill]:
			arr.append(int(level))
		levels[skill] = arr
	collect["levels"] = levels
	collect["gold"] = int(collect.get("gold", 0)) + int(result.get("gold", 0))
	var combat: Dictionary = result.get("combat", {})
	if combat.has("kill"):
		collect["kills"] = int(collect.get("kills", 0)) + 1


# --- Offline -----------------------------------------------------------------
func _apply_offline() -> void:
	if state == null or state.last_saved_unix <= 0:
		state.last_saved_unix = int(Time.get_unix_time_from_system())
		return
	var now := int(Time.get_unix_time_from_system())
	var elapsed := now - state.last_saved_unix
	if elapsed <= 5:
		return
	var capped: int = mini(elapsed, MAX_OFFLINE_SECONDS)
	if state.activity.is_empty():
		return

	var summary := {
		"elapsed": elapsed,
		"capped": capped,
		"capped_out": capped < elapsed,
		"items": {},
		"xp": {},
		"levels": {},
		"actions": 0,
		"gold": 0,
		"kills": 0,
		"activity": str(state.activity.get("target", "")),
		"stop_reason": "",
	}
	if str(state.activity.get("type", "")) == "combat":
		# Combat ticks on a continuous clock; simulate it in 1 s sub-steps so the
		# whole offline interval is actually processed (guards apply per step).
		var remaining := float(capped)
		while remaining > 0.0 and not state.activity.is_empty():
			var step := minf(1.0, remaining)
			advance(step, summary)
			remaining -= step
	else:
		advance(float(capped), summary)
	EventBus.offline_summary.emit(summary)