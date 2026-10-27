class_name MiningSystem
extends RefCounted

## Mining: deposits with a five-stage depth model. Deeper stages hold more ore
## per swing but take more swings; clearing stage five wraps back to stage one.
## Systems mutate state and RETURN event deltas; GameSession owns notifications.


static func can_start(state: CharacterState, deposit_id: String) -> Dictionary:
	# validates level gate + pickaxe tier gate
	var deposit := ContentRegistry.get_deposit(deposit_id)
	if deposit.is_empty():
		return {"ok": false, "reason": "Unknown deposit."}
	var level := state.get_level("mining")
	if level < int(deposit["unlock_level"]):
		return {"ok": false, "reason": "Requires Mining %d." % int(deposit["unlock_level"])}
	var power := int(EquipmentSystem.stat(state, "mining_power"))
	if power < int(deposit["required_tool_tier"]):
		return {"ok": false, "reason": "Requires a stronger pickaxe."}
	return {"ok": true, "reason": ""}


static func make_activity(state: CharacterState, deposit_id: String) -> Dictionary:
	var deposit := ContentRegistry.get_deposit(deposit_id)
	var pools: Array = deposit["stage_pools"]
	var act := {
		"type": "mining",
		"target": deposit_id,
		"time": 0.0,
		"stage": 0,
		"pool": int(pools[0]),
		"duration": 0.0,
	}
	act["duration"] = duration(state, act)
	return act


## Seconds per swing, improved by pickaxe mining power.
static func duration(state: CharacterState, act: Dictionary) -> float:
	var deposit := ContentRegistry.get_deposit(str(act["target"]))
	var power := float(EquipmentSystem.stat(state, "mining_power"))
	var speed := 1.0 + 0.1 * maxf(0.0, power - 1.0)
	return maxf(0.4, float(deposit["base_time"]) / speed)


static func on_action(state: CharacterState, act: Dictionary) -> Dictionary:
	var deposit := ContentRegistry.get_deposit(str(act["target"]))
	var stage := int(act["stage"])
	var pools: Array = deposit["stage_pools"]
	var yields: Array = deposit["stage_yields"]
	var amount := int(yields[stage])
	var ore := str(deposit["ore_item"])
	InventorySystem.add(state, ore, amount)
	var xp := int(round(float(deposit["base_xp"]) * (1.0 + 0.12 * float(stage))))
	var levels := state.add_xp("mining", xp)

	var pool := int(act["pool"]) - 1
	if pool <= 0:
		stage += 1
		if stage >= pools.size():
			stage = 0
		pool = int(pools[stage])
	act["stage"] = stage
	act["pool"] = pool
	act["duration"] = duration(state, act)

	return {
		"items": {ore: amount},
		"xp": {"mining": xp},
		"levels": {"mining": levels},
		"extra": {"stage": stage, "stage_index": stage + 1, "stage_count": pools.size()},
	}