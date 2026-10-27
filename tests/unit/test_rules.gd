extends Node

## Unit tests for the domain rules, data integrity and simulation systems.
## Uses Godot's assert(): a failed assertion is a test failure.
## The runner executes each test_* method in the live project (autoloads
## available), so ContentRegistry-backed systems are covered too.

var _sink: Array = []


func _make_state() -> CharacterState:
	var state := CharacterState.new()
	state.new_profile("test_profile", "Tester")
	return state


func test_progression_curve() -> void:
	assert(Progression.level_for_total_xp(0) == 1, "0 XP is level 1")
	assert(Progression.level_for_total_xp(Progression.total_xp_for_level(2)) == 2, "exact threshold gives level 2")
	assert(Progression.level_for_total_xp(Progression.total_xp_for_level(2) - 1) == 1, "one below threshold stays level 1")
	var prev := 0
	for level in range(1, 99):
		var req := Progression.xp_to_next(level)
		assert(req > prev, "xp_to_next strictly increasing at %d" % level)
		prev = req
	assert(Progression.level_for_total_xp(Progression.total_xp_for_level(100)) == 100, "max level reachable")
	assert(Progression.level_progress(0) == 0.0, "level progress starts at 0")
	assert(Progression.tier_for_level(1) == 1 and Progression.tier_for_level(100) == 10, "tier mapping")


func test_content_integrity() -> void:
	var items := ContentData.build_items()
	var recipes := ContentData.build_recipes()
	var deposits := ContentData.build_deposits()
	var ids := {}
	for dict in [items, recipes, deposits]:
		for id in dict.keys():
			assert(not ids.has(id), "duplicate id %s" % id)
			ids[id] = true
	for rid in recipes.keys():
		var recipe: Dictionary = recipes[rid]
		for item_id in (recipe["inputs"] as Dictionary).keys():
			assert(items.has(item_id), "recipe %s input %s exists" % [rid, item_id])
		for item_id in (recipe["output"] as Dictionary).keys():
			assert(items.has(item_id), "recipe %s output %s exists" % [rid, item_id])
	var tiers := {}
	for did in deposits.keys():
		var deposit: Dictionary = deposits[did]
		assert((deposit["stage_pools"] as Array).size() == 5, "deposit %s has five stages" % did)
		assert(items.has(deposit["ore_item"]), "deposit %s ore exists" % did)
		tiers[int(deposit["tier"])] = true
	for tier in range(1, ContentData.MAX_TIER + 1):
		assert(tiers.has(tier), "mining covers tier %d" % tier)
	var bar_tiers := {}
	for rid in recipes.keys():
		if str(recipes[rid]["kind"]) == "smelt":
			bar_tiers[int(recipes[rid]["tier"])] = true
	for tier in range(1, ContentData.MAX_TIER + 1):
		assert(bar_tiers.has(tier), "smelting covers tier %d" % tier)
	# Registry-level validation must be clean.
	var problems := ContentRegistry.validate()
	assert(problems.is_empty(), "registry validation clean: %s" % str(problems))


func test_state_roundtrip() -> void:
	var state := _make_state()
	InventorySystem.add(state, "item.ore.copper", 1234)
	state.add_xp("mining", 5000)
	state.equipment["weapon"] = "item.weapon.sword.bronze"
	var restored := CharacterState.new()
	restored.from_dict(state.to_dict())
	assert(restored.profile_id == "test_profile", "profile id preserved")
	assert(InventorySystem.count(restored, "item.ore.copper") == 1234, "large stack preserved")
	assert(restored.get_xp("mining") == 5000, "xp preserved")
	assert(restored.equipment["weapon"] == "item.weapon.sword.bronze", "equipment preserved")
	# Corrupt / missing fields must default safely rather than crash.
	var repaired := CharacterState.new()
	repaired.from_dict({"skills": {"mining": 10}, "bank": {"item.ore.copper": -5}})
	assert(repaired.get_xp("mining") == 10, "partial save keeps valid fields")
	assert(InventorySystem.count(repaired, "item.ore.copper") == 0, "negative stack dropped")


func test_inventory_math() -> void:
	var state := _make_state()
	InventorySystem.add(state, "item.ore.tin", 100)
	assert(InventorySystem.count(state, "item.ore.tin") == 100, "add stacks")
	assert(InventorySystem.has_all(state, {"item.ore.tin": 100}), "has_all exact")
	assert(not InventorySystem.has_all(state, {"item.ore.tin": 101}), "has_all short")
	assert(InventorySystem.remove(state, "item.ore.tin", 40), "remove succeeds")
	assert(InventorySystem.count(state, "item.ore.tin") == 60, "remove reduces stack")
	assert(not InventorySystem.remove(state, "item.ore.tin", 61), "remove fails when short")
	assert(InventorySystem.remove(state, "item.ore.tin", 60), "remove all")
	assert(InventorySystem.count(state, "item.ore.tin") == 0, "removing last clears stack")


func test_mining_system_loop() -> void:
	var state := _make_state()
	assert(MiningSystem.can_start(state, "deposit.mining.copper")["ok"], "can mine copper at start")
	assert(not MiningSystem.can_start(state, "deposit.mining.runite")["ok"], "cannot mine locked tier")
	var act := MiningSystem.make_activity(state, "deposit.mining.copper")
	state.activity = act
	for _i in range(30):
		MiningSystem.on_action(state, act)
	assert(InventorySystem.count(state, "item.ore.copper") >= 30, "mining yields ore")
	assert(state.get_level("mining") > 1, "mining grants levels")
	assert(int(act["stage"]) >= 1, "stage advances as the deposit is worked")


func test_smithing_reservation_and_output() -> void:
	var state := _make_state()
	InventorySystem.add(state, "item.ore.copper", 10)
	InventorySystem.add(state, "item.ore.tin", 10)
	assert(not SmithingSystem.can_start(state, "recipe.smithing.smelt.iron")["ok"], "locked smelt gated by level")
	assert(SmithingSystem.can_start(state, "recipe.smithing.smelt.bronze")["ok"], "bronze smelt available")
	var act := SmithingSystem.make_activity(state, "recipe.smithing.smelt.bronze")
	assert(InventorySystem.count(state, "item.ore.copper") == 9, "inputs reserved on start")
	var result := SmithingSystem.on_action(state, act)
	assert(InventorySystem.count(state, "item.bar.bronze") == 1, "smelt produces a bar")
	assert(InventorySystem.count(state, "item.ore.copper") == 8, "next batch reserved")
	assert(not result.get("stop", false), "activity continues while materials last")
	# Return reserved inputs when stopped.
	SmithingSystem.return_reserved(state, act)
	assert(InventorySystem.count(state, "item.ore.copper") == 9, "reserved inputs returned on stop")


func test_equipment_ownership() -> void:
	var state := _make_state()
	assert(state.equipment["tool"] == "item.tool.pickaxe.bronze", "starts with a pickaxe equipped")
	assert(EquipmentSystem.unequip(state, "tool")["ok"], "unequip works")
	assert(state.equipment["tool"] == "", "slot emptied")
	assert(InventorySystem.count(state, "item.tool.pickaxe.bronze") == 1, "unequip returns item to bank")
	assert(EquipmentSystem.equip(state, "item.tool.pickaxe.bronze")["ok"], "equip works")
	assert(state.equipment["tool"] == "item.tool.pickaxe.bronze", "slot filled")
	assert(InventorySystem.count(state, "item.tool.pickaxe.bronze") == 0, "equipped item leaves the bank")
	assert(not EquipmentSystem.equip(state, "item.ore.copper")["ok"], "non-equipment rejected")