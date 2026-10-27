class_name FishingSystem
extends RefCounted

## Fishing: spots with weighted catch pools. Systems mutate state and RETURN
## event deltas; GameSession owns notifications.


static func can_start(state: CharacterState, spot_id: String) -> Dictionary:
	var spot := ContentRegistry.get_spot(spot_id)
	if spot.is_empty():
		return {"ok": false, "reason": "Unknown fishing spot."}
	var level := state.get_level("fishing")
	if level < int(spot["unlock_level"]):
		return {"ok": false, "reason": "Requires Fishing %d." % int(spot["unlock_level"])}
	var rod := int(EquipmentSystem.stat(state, "fishing_power"))
	if rod < int(spot["required_rod_tier"]):
		return {"ok": false, "reason": "Requires a stronger rod."}
	return {"ok": true, "reason": ""}


static func make_activity(state: CharacterState, spot_id: String) -> Dictionary:
	var spot := ContentRegistry.get_spot(spot_id)
	return {
		"type": "fishing",
		"target": spot_id,
		"time": 0.0,
		"duration": duration(state, spot),
	}


## Seconds per catch, improved by rod speed.
static func duration(state: CharacterState, spot: Dictionary) -> float:
	var speed := 1.0 + 0.1 * maxf(0.0, EquipmentSystem.stat(state, "speed") - 1.0)
	return maxf(0.5, float(spot["base_time"]) / speed)


static func on_action(state: CharacterState, act: Dictionary) -> Dictionary:
	var spot := ContentRegistry.get_spot(str(act["target"]))
	var item_id := _pick(spot["pool"])
	InventorySystem.add(state, item_id, 1)
	var xp := int(spot["base_xp"])
	var levels := state.add_xp("fishing", xp)
	act["duration"] = duration(state, spot)
	return {
		"items": {item_id: 1},
		"xp": {"fishing": xp},
		"levels": {"fishing": levels},
		"extra": {"catch": item_id},
	}


## Weighted random pick from a catch pool.
static func _pick(pool: Array) -> String:
	var total := 0
	for entry in pool:
		total += int(entry["weight"])
	if total <= 0:
		return ""
	var roll := randi_range(1, total)
	var acc := 0
	for entry in pool:
		acc += int(entry["weight"])
		if roll <= acc:
			return str(entry["item_id"])
	return str(pool[pool.size() - 1]["item_id"])