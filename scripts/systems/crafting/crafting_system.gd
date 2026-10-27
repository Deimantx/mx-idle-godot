class_name CraftingSystem
extends RefCounted

## Generic crafting for level-gated recipes (Smithing, Cooking, ...). Inputs are
## RESERVED (moved out of the bank) when an activity starts and on every
## completed batch; reserved inputs are returned to the bank if the player stops.
## The recipe's authored profession decides which skill gains XP. No fake outputs.


static func can_start(state: CharacterState, recipe_id: String) -> Dictionary:
	# validates level gate + material availability
	var recipe := ContentRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		return {"ok": false, "reason": "Unknown recipe."}
	var skill := str(recipe["profession"])
	var level := state.get_level(skill)
	if level < int(recipe["level"]):
		return {"ok": false, "reason": "Requires %s %d." % [skill.capitalize(), int(recipe["level"])]}
	if not InventorySystem.has_all(state, recipe["inputs"]):
		return {"ok": false, "reason": "Missing materials."}
	return {"ok": true, "reason": ""}


static func make_activity(state: CharacterState, recipe_id: String) -> Dictionary:
	var recipe := ContentRegistry.get_recipe(recipe_id)
	var act := {
		"type": str(recipe["profession"]),
		"target": recipe_id,
		"time": 0.0,
		"duration": float(recipe["time"]),
		"reserved": {},
	}
	reserve(state, act)
	return act


## Reserve one batch of inputs. Returns false (and reserves nothing) if the
## bank cannot cover a full batch.
static func reserve(state: CharacterState, act: Dictionary) -> bool:
	var recipe := ContentRegistry.get_recipe(str(act["target"]))
	if not InventorySystem.remove_all(state, recipe["inputs"]):
		return false
	act["reserved"] = (recipe["inputs"] as Dictionary).duplicate()
	return true


static func return_reserved(state: CharacterState, act: Dictionary) -> void:
	var reserved: Dictionary = act.get("reserved", {})
	for item_id in reserved.keys():
		InventorySystem.add(state, item_id, int(reserved[item_id]))
	act["reserved"] = {}


static func on_action(state: CharacterState, act: Dictionary) -> Dictionary:
	var recipe := ContentRegistry.get_recipe(str(act["target"]))
	var skill := str(recipe["profession"])
	# Inputs were already removed from the bank at reserve time: consume them.
	act["reserved"] = {}

	var items := {}
	for item_id in recipe["output"].keys():
		var amt := int(recipe["output"][item_id])
		InventorySystem.add(state, item_id, amt)
		items[item_id] = amt

	var xp := int(recipe["xp"])
	var levels := state.add_xp(skill, xp)

	# Start the next batch; stop the activity when materials run out.
	var stopped := not reserve(state, act)
	return {
		"items": items,
		"xp": {skill: xp},
		"levels": {skill: levels},
		"stop": stopped,
		"reason": "Out of materials." if stopped else "",
	}