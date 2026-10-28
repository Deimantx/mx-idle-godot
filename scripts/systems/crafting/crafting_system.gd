class_name CraftingSystem
extends RefCounted

## Production orders reserve one batch at a time and repeat until the order ends or materials run out.


static func can_start(state: CharacterState, recipe_id: String) -> Dictionary:
	var recipe := ContentRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		return {"ok": false, "reason": "Unknown recipe."}
	var inputs: Dictionary = recipe.get("inputs", {})
	var outputs: Dictionary = recipe.get("output", {})
	if inputs.is_empty() or outputs.is_empty():
		return {"ok": false, "reason": "Recipe has no valid inputs or outputs."}
	for item_id in inputs:
		if int(inputs[item_id]) <= 0 or ContentRegistry.get_item(str(item_id)).is_empty():
			return {"ok": false, "reason": "Recipe contains invalid input materials."}
	for item_id in outputs:
		if int(outputs[item_id]) <= 0 or ContentRegistry.get_item(str(item_id)).is_empty():
			return {"ok": false, "reason": "Recipe contains invalid output items."}
	var skill := str(recipe.get("profession", ""))
	var required_level := int(recipe.get("level", 1))
	if skill.is_empty() or required_level < 1 or required_level > 100:
		return {"ok": false, "reason": "Recipe has invalid profession requirements."}
	if state.get_level(skill) < required_level:
		return {"ok": false, "reason": "Requires %s %d." % [skill.capitalize(), required_level]}
	if not InventorySystem.has_all(state, inputs):
		return {"ok": false, "reason": "Missing materials."}
	return {"ok": true, "reason": ""}


## batch_count: positive = exact count, -1 = all affordable batches, 0 = indefinite.
static func make_activity(state: CharacterState, recipe_id: String, batch_count: int = 0) -> Dictionary:
	var recipe := ContentRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		return {}
	var requested := batch_count
	var finite_order := batch_count > 0
	var activity := {
		"type": str(recipe["profession"]), "target": recipe_id,
		"time": 0.0, "duration": _batch_duration(recipe),
		"reserved": {},
		"heat": 100.0, "work_required": _work_required(recipe), "work_remaining": _work_required(recipe),
		"minimum_working_heat": _minimum_working_heat(recipe), "hammer_power": _hammer_power(recipe),
		"production_mode": "quantity" if finite_order else "all",
		"batches_requested": maxi(0, requested),
		"batches_remaining": maxi(0, requested),
		"batches_completed": 0, "finite_order": finite_order,
	}
	if finite_order and requested <= 0:
		return {}
	if not reserve(state, activity):
		return {}
	return activity


static func _batch_duration(recipe: Dictionary) -> float:
	var base := maxf(0.05, float(recipe.get("time", 1.0)))
	if str(recipe.get("profession", "")) != "smithing":
		return base
	var tier := maxi(1, int(recipe.get("tier", 1)))
	if str(recipe.get("kind", "")) == "smelt":
		return base + float(recipe.get("furnace_warmup", 0.35 + (tier - 1) * 0.12))
	var work := _work_required(recipe)
	var strikes := ceili(float(work) / float(_hammer_power(recipe)))
	var reheats := maxi(0, ceili(float(strikes * 10) / maxf(1.0, 100.0 - _minimum_working_heat(recipe))) - 1)
	return base + float(strikes) * 0.65 + float(reheats) * float(recipe.get("reheat_time", 2.0 + (tier - 1) * 0.12))

static func _work_required(recipe: Dictionary) -> int:
	if str(recipe.get("kind", "")) != "forge":
		return 0
	var tier := maxi(1, int(recipe.get("tier", 1)))
	var weight := 1.0
	match str(recipe.get("forge_category", "other")):
		"weapon": weight = 1.15
		"shield": weight = 1.25
		"helmet", "gloves", "boots": weight = 0.8
		"body_armor": weight = 1.7
		"leg_armor": weight = 1.25
	return maxi(12, int(round((28.0 + (tier - 1) * 8.0) * weight)))

static func _hammer_power(recipe: Dictionary) -> int:
	return maxi(3, 10 - int(maxi(1, int(recipe.get("tier", 1))) / 3))

static func _minimum_working_heat(recipe: Dictionary) -> float:
	return minf(70.0, 25.0 + float(maxi(1, int(recipe.get("tier", 1))) - 1) * 5.0)

static func max_possible_batches(state: CharacterState, recipe_id: String) -> int:
	var recipe := ContentRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		return 0
	var inputs: Dictionary = recipe.get("inputs", {})
	if inputs.is_empty():
		return 0
	var possible := 2147483647
	for item_id in inputs:
		var per_batch := int(inputs[item_id])
		if per_batch <= 0:
			return 0
		possible = mini(possible, int(InventorySystem.count(state, str(item_id)) / per_batch))
	return maxi(0, possible)


static func reserve(state: CharacterState, activity: Dictionary) -> bool:
	if not (activity.get("reserved", {}) as Dictionary).is_empty():
		return false
	var recipe := ContentRegistry.get_recipe(str(activity.get("target", "")))
	if recipe.is_empty():
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	if inputs.is_empty() or not InventorySystem.remove_all(state, inputs):
		return false
	activity["reserved"] = inputs.duplicate(true)
	return true


static func return_reserved(state: CharacterState, activity: Dictionary) -> void:
	var reserved: Dictionary = activity.get("reserved", {})
	for item_id in reserved:
		InventorySystem.add(state, str(item_id), int(reserved[item_id]))
	activity["reserved"] = {}


static func on_action(state: CharacterState, activity: Dictionary) -> Dictionary:
	var recipe := ContentRegistry.get_recipe(str(activity.get("target", "")))
	if recipe.is_empty():
		return {"stop": true, "reason": "Recipe no longer exists."}
	var reserved: Dictionary = activity.get("reserved", {})
	if reserved.is_empty():
		return {"stop": true, "reason": "No reserved materials for this batch."}
	activity["reserved"] = {}
	var items: Dictionary = {}
	for item_id in recipe["output"]:
		var amount := int(recipe["output"][item_id])
		InventorySystem.add(state, str(item_id), amount)
		items[str(item_id)] = amount
	var skill := str(recipe["profession"])
	var xp := int(recipe.get("xp", 0))
	activity["batches_completed"] = int(activity.get("batches_completed", 0)) + 1
	if bool(activity.get("finite_order", false)):
		activity["batches_remaining"] = maxi(0, int(activity.get("batches_remaining", 0)) - 1)
	var levels := state.add_xp(skill, xp)
	var order_done := bool(activity.get("finite_order", false)) and int(activity["batches_remaining"]) <= 0
	var next_reserved := false
	if not order_done:
		next_reserved = reserve(state, activity)
	var stopped := order_done or not next_reserved
	var reason := "Order complete." if order_done else "Out of materials." if not next_reserved else ""
	if not stopped:
		activity["time"] = 0.0
		activity["duration"] = _batch_duration(recipe)
		activity["heat"] = 100.0
		activity["work_remaining"] = _work_required(recipe)
	return {
		"items": items, "xp": {skill: xp}, "levels": {skill: levels},
		"stop": stopped, "reason": reason,
		"production": {"recipe_id": str(recipe["id"]), "batch_completed": int(activity["batches_completed"]),
			"batches_remaining": int(activity.get("batches_remaining", 0)), "mode": str(activity.get("production_mode", "indefinite"))},
	}
