class_name FoodSystem
extends RefCounted

## Food sustain: three food slots, Satiety, Auto Eat and Overeat.
## Food slots reference a food item type; eating consumes one unit from the bank
## stack, so a stack can feed the character without blocking the bank entry.


static func assign(state: CharacterState, item_id: String) -> Dictionary:
	var item := ContentRegistry.get_item(item_id)
	if item.is_empty() or str(item.get("equip_slot", "")) != "food":
		return {"ok": false, "reason": "That is not food."}
	for slot in CharacterState.FOOD_SLOTS:
		if str(state.equipment.get(slot, "")) == "":
			state.equipment[slot] = item_id
			return {"ok": true, "slot": slot}
	state.equipment[CharacterState.FOOD_SLOTS[0]] = item_id
	return {"ok": true, "slot": CharacterState.FOOD_SLOTS[0]}


static func clear_slot(state: CharacterState, slot: String) -> void:
	if slot in CharacterState.FOOD_SLOTS:
		state.equipment[slot] = ""


## Eat one unit of `item_id`. Returns {ok, overeat, heal}. Overeating (at full
## Satiety) gives no benefit and applies the stun / food-lock / satiety-drain penalty.
static func eat(state: CharacterState, item_id: String) -> Dictionary:
	var item := ContentRegistry.get_item(item_id)
	if item.is_empty():
		return {"ok": false, "reason": "Not food."}
	if InventorySystem.count(state, item_id) <= 0:
		return {"ok": false, "reason": "No stock."}
	var stats: Dictionary = item.get("stats", {})

	if state.satiety >= 100.0:
		InventorySystem.remove(state, item_id, 1)
		state.food_cooldown = maxf(state.food_cooldown, 20.0)
		if not state.activity.is_empty() and str(state.activity.get("type", "")) == "combat":
			state.activity["stun"] = maxf(float(state.activity.get("stun", 0.0)), 5.0)
		state.satiety = maxf(0.0, state.satiety - 5.0)
		return {"ok": true, "overeat": true, "item_id": item_id}

	InventorySystem.remove(state, item_id, 1)
	var heal := int(stats.get("heal", 0))
	state.hp = mini(state.max_hp(), state.hp + heal)
	state.satiety = minf(100.0, state.satiety + float(stats.get("satiety", 0)))
	return {"ok": true, "overeat": false, "heal": heal, "item_id": item_id}


## The assigned food with the highest heal that still has stock.
static func best_food(state: CharacterState) -> String:
	var best := ""
	var best_heal := -1
	for slot in CharacterState.FOOD_SLOTS:
		var item_id := str(state.equipment.get(slot, ""))
		if item_id == "" or InventorySystem.count(state, item_id) <= 0:
			continue
		var heal := int((ContentRegistry.get_item(item_id).get("stats", {}) as Dictionary).get("heal", 0))
		if heal > best_heal:
			best_heal = heal
			best = item_id
	return best


## Auto Eat, driven by the combat loop: eat when HP falls below the threshold.
static func try_auto_eat(state: CharacterState) -> Dictionary:
	if not bool(state.combat_prefs.get("auto_eat", true)):
		return {"ok": false}
	if state.food_cooldown > 0.0:
		return {"ok": false}
	if state.satiety >= 100.0:
		return {"ok": false}
	var threshold := float(state.combat_prefs.get("auto_eat_threshold", 0.5)) * float(state.max_hp())
	if float(state.hp) > threshold:
		return {"ok": false}
	var food := best_food(state)
	if food == "":
		return {"ok": false}
	return eat(state, food)