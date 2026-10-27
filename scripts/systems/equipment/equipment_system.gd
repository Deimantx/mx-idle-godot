class_name EquipmentSystem
extends RefCounted

## Equipment ownership, slot validation and stat aggregation. An equipped item
## always leaves the bank (no duplication / double assignment).


static func can_equip(_state: CharacterState, item_id: String) -> Dictionary:
	# validates that the item exists and maps to a known slot
	var item := ContentRegistry.get_item(item_id)
	if item.is_empty():
		return {"ok": false, "reason": "Unknown item."}
	var slot := str(item.get("equip_slot", ""))
	if slot == "":
		return {"ok": false, "reason": "That item cannot be equipped."}
	if not (slot in CharacterState.SLOTS):
		return {"ok": false, "reason": "Invalid slot '%s'." % slot}
	return {"ok": true, "reason": "", "slot": slot}


static func equip(state: CharacterState, item_id: String) -> Dictionary:
	var check := can_equip(state, item_id)
	if not check["ok"]:
		return check
	var slot := str(check["slot"])
	if not InventorySystem.remove(state, item_id, 1):
		return {"ok": false, "reason": "You do not own that item."}
	var previous := str(state.equipment.get(slot, ""))
	if previous != "":
		InventorySystem.add(state, previous, 1)
	state.equipment[slot] = item_id
	return {"ok": true, "reason": "", "slot": slot, "previous": previous}


static func unequip(state: CharacterState, slot: String) -> Dictionary:
	var current := str(state.equipment.get(slot, ""))
	if current == "":
		return {"ok": false, "reason": "Slot is empty."}
	InventorySystem.add(state, current, 1)
	state.equipment[slot] = ""
	return {"ok": true, "reason": "", "item": current}


static func equipped_item(state: CharacterState, slot: String) -> Dictionary:
	return ContentRegistry.get_item(str(state.equipment.get(slot, "")))


## Aggregated value of a stat across all equipped slots.
static func stat(state: CharacterState, stat_name: String) -> float:
	var total := 0.0
	for slot in CharacterState.SLOTS:
		var item := equipped_item(state, slot)
		if item.has("stats"):
			var stats: Dictionary = item["stats"]
			if stats.has(stat_name):
				total += float(stats[stat_name])
	return total