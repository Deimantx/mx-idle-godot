class_name InventorySystem
extends RefCounted

## Bank / stack arithmetic. No UI, no hard stack cap (idle-friendly big stacks).


static func count(state: CharacterState, item_id: String) -> int:
	# current stack size for an item
	return int(state.bank.get(item_id, 0))


static func add(state: CharacterState, item_id: String, amount: int) -> void:
	if amount <= 0 or item_id == "":
		return
	state.bank[item_id] = count(state, item_id) + amount


static func has_all(state: CharacterState, costs: Dictionary) -> bool:
	for item_id in costs.keys():
		if count(state, item_id) < int(costs[item_id]):
			return false
	return true


static func remove(state: CharacterState, item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if count(state, item_id) < amount:
		return false
	var left := count(state, item_id) - amount
	if left <= 0:
		state.bank.erase(item_id)
	else:
		state.bank[item_id] = left
	return true


static func remove_all(state: CharacterState, costs: Dictionary) -> bool:
	if not has_all(state, costs):
		return false
	for item_id in costs.keys():
		remove(state, item_id, int(costs[item_id]))
	return true


## Total number of distinct item stacks in the bank.
static func distinct_count(state: CharacterState) -> int:
	return state.bank.size()