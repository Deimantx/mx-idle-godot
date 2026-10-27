extends Node

## Single registry layer. Screens never read content files directly; they ask
## this registry. Content is authored in ContentData and validated here.

var items: Dictionary = {}          # item_id -> definition dict
var recipes: Dictionary = {}        # recipe_id -> definition dict
var deposits: Dictionary = {}       # deposit_id -> definition dict
var fishing_spots: Dictionary = {}  # spot_id -> definition dict
var enemies: Dictionary = {}        # enemy_id -> definition dict
var areas: Dictionary = {}          # area_id -> definition dict


func _ready() -> void:
	load_all()


func load_all() -> void:
	items = ContentData.build_items()
	recipes = ContentData.build_recipes()
	deposits = ContentData.build_deposits()
	fishing_spots = ContentData.build_fishing_spots()
	enemies = ContentData.build_enemies()
	areas = ContentData.build_areas()


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	if items.has(id):
		return str(items[id]["name"])
	return id


func get_recipe(id: String) -> Dictionary:
	return recipes.get(id, {})


func get_deposit(id: String) -> Dictionary:
	return deposits.get(id, {})


## Recipes for a profession sorted by tier then level.
func recipes_for(profession: String) -> Array:
	var out: Array = []
	for id in recipes.keys():
		if str(recipes[id]["profession"]) == profession:
			out.append(recipes[id])
	out.sort_custom(func(a, b):
		if int(a["tier"]) == int(b["tier"]):
			return str(a["id"]) < str(b["id"])
		return int(a["tier"]) < int(b["tier"]))
	return out


func deposits_sorted() -> Array:
	var out: Array = []
	for id in deposits.keys():
		out.append(deposits[id])
	out.sort_custom(func(a, b):
		return int(a["tier"]) < int(b["tier"]))
	return out


func get_spot(id: String) -> Dictionary:
	return fishing_spots.get(id, {})


func spots_sorted() -> Array:
	var out: Array = []
	for id in fishing_spots.keys():
		out.append(fishing_spots[id])
	out.sort_custom(func(a, b): return int(a["tier"]) < int(b["tier"]))
	return out


func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})


func get_area(id: String) -> Dictionary:
	return areas.get(id, {})


func areas_sorted() -> Array:
	var out: Array = []
	for id in areas.keys():
		out.append(areas[id])
	out.sort_custom(func(a, b): return int(a["tier"]) < int(b["tier"]))
	return out


## Enemies belonging to an area, in definition order.
func enemies_in_area(area_id: String) -> Array:
	var area := get_area(area_id)
	var out: Array = []
	for enemy_id in (area.get("enemies", []) as Array):
		out.append(enemies.get(enemy_id, {}))
	return out


# ---------------------------------------------------------------------------
# Validation (runs in editor/dev and tests)
# ---------------------------------------------------------------------------
func validate() -> Array:
	var problems: Array = []

	# Duplicate ids across registries.
	var seen := {}
	for dict in [items, recipes, deposits]:
		for id in dict.keys():
			if seen.has(id):
				problems.append("Duplicate id: " + str(id))
			seen[id] = true

	# Recipe references must resolve.
	for rid in recipes.keys():
		var r: Dictionary = recipes[rid]
		for item_id in r["inputs"].keys():
			if not items.has(item_id):
				problems.append("Recipe %s references missing input %s" % [rid, item_id])
		for item_id in r["output"].keys():
			if not items.has(item_id):
				problems.append("Recipe %s references missing output %s" % [rid, item_id])
		if int(r["level"]) < 1 or int(r["level"]) > 100:
			problems.append("Recipe %s has invalid unlock level" % rid)

	# Deposits must reference real ore and cover tiers 1..10.
	var tiers_seen := {}
	for did in deposits.keys():
		var d: Dictionary = deposits[did]
		if not items.has(d["ore_item"]):
			problems.append("Deposit %s references missing ore %s" % [did, d["ore_item"]])
		tiers_seen[int(d["tier"])] = true
		if (d["stage_pools"] as Array).size() != 5:
			problems.append("Deposit %s does not have five stages" % did)
	for t in range(1, ContentData.MAX_TIER + 1):
		if not tiers_seen.has(t):
			problems.append("No mining deposit covers tier %d" % t)

	# Every tier must have a smeltable bar.
	var bar_tiers := {}
	for rid in recipes.keys():
		var r: Dictionary = recipes[rid]
		if str(r["kind"]) == "smelt":
			bar_tiers[int(r["tier"])] = true
	for t in range(1, ContentData.MAX_TIER + 1):
		if not bar_tiers.has(t):
			problems.append("No smelting recipe for tier %d" % t)

	# Fishing spots must reference real items and cover every tier.
	var spot_tiers := {}
	for sid in fishing_spots.keys():
		var spot: Dictionary = fishing_spots[sid]
		spot_tiers[int(spot["tier"])] = true
		if not items.has(spot["fish_item"]):
			problems.append("Fishing spot %s references missing fish %s" % [sid, spot["fish_item"]])
		if (spot["pool"] as Array).is_empty():
			problems.append("Fishing spot %s has an empty catch pool" % sid)
		for entry in spot["pool"]:
			if not items.has(entry["item_id"]):
				problems.append("Fishing spot %s pool references missing item %s" % [sid, entry["item_id"]])
	for t in range(1, ContentData.MAX_TIER + 1):
		if not spot_tiers.has(t):
			problems.append("No fishing spot covers tier %d" % t)

	# Every tier must have a cookable food recipe (food sustain path).
	var food_tiers := {}
	for rid in recipes.keys():
		if str(recipes[rid]["profession"]) == "cooking":
			food_tiers[int(recipes[rid]["tier"])] = true
	for t in range(1, ContentData.MAX_TIER + 1):
		if not food_tiers.has(t):
			problems.append("No cooking recipe for tier %d" % t)

	# Enemies: valid sequence, valid loot, and each area references real enemies.
	for eid in enemies.keys():
		var enemy: Dictionary = enemies[eid]
		if (enemy["sequence"] as Array).is_empty():
			problems.append("Enemy %s has an empty action sequence" % eid)
		if int(enemy["hp"]) <= 0:
			problems.append("Enemy %s has non-positive hp" % eid)
		for entry in enemy["loot"]:
			if not items.has(entry["item_id"]):
				problems.append("Enemy %s loot references missing item %s" % [eid, entry["item_id"]])
	var area_tiers := {}
	for aid in areas.keys():
		var area: Dictionary = areas[aid]
		area_tiers[int(area["tier"])] = true
		if (area["enemies"] as Array).is_empty():
			problems.append("Area %s has no enemies" % aid)
		for enemy_id in area["enemies"]:
			if not enemies.has(enemy_id):
				problems.append("Area %s references missing enemy %s" % [aid, enemy_id])
	for t in range(1, ContentData.MAX_TIER + 1):
		if not area_tiers.has(t):
			problems.append("No combat area covers tier %d" % t)

	return problems


func report() -> String:
	var problems := validate()
	if problems.is_empty():
		return "Content OK: %d items, %d recipes, %d deposits." % [items.size(), recipes.size(), deposits.size()]
	return "CONTENT PROBLEMS (%d):\n- %s" % [problems.size(), "\n- ".join(problems)]