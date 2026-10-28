class_name ContentData
extends RefCounted

## Authoritative, data-driven content tables for the Phase 1 vertical slice.
## Content lives here (one registry layer), never inside screen scripts or
## giant match statements. Values are provisional balance, IDs are stable.

const MAX_TIER := 10

# Ore definitions. tier drives unlock level, deposit difficulty and value.
const ORES := [
	{"id": "copper", "name": "Copper Ore", "tier": 1},
	{"id": "tin", "name": "Tin Ore", "tier": 1},
	{"id": "iron", "name": "Iron Ore", "tier": 2},
	{"id": "silver", "name": "Silver Ore", "tier": 3},
	{"id": "gold", "name": "Gold Ore", "tier": 4},
	{"id": "mithril", "name": "Mithril Ore", "tier": 5},
	{"id": "adamant", "name": "Adamantite Ore", "tier": 6},
	{"id": "runite", "name": "Runite Ore", "tier": 7},
	{"id": "orichalcum", "name": "Orichalcum Ore", "tier": 8},
	{"id": "obsidian", "name": "Obsidian Ore", "tier": 9},
	{"id": "voidsteel", "name": "Voidsteel Ore", "tier": 10},
]

# Bar definitions, one per tier (bronze is smelted from copper + tin).
const BARS := [
	{"id": "bronze", "name": "Bronze Bar", "tier": 1},
	{"id": "iron", "name": "Iron Bar", "tier": 2},
	{"id": "silver", "name": "Silver Bar", "tier": 3},
	{"id": "gold", "name": "Gold Bar", "tier": 4},
	{"id": "mithril", "name": "Mithril Bar", "tier": 5},
	{"id": "adamant", "name": "Adamant Bar", "tier": 6},
	{"id": "runite", "name": "Runite Bar", "tier": 7},
	{"id": "orichalcum", "name": "Orichalcum Bar", "tier": 8},
	{"id": "obsidian", "name": "Obsidian Bar", "tier": 9},
	{"id": "voidsteel", "name": "Voidsteel Bar", "tier": 10},
]

# Smelting inputs: bar id -> { ore id: count }. Bronze uses two ores.
const SMELT_INPUTS := {
	"bronze": {"copper": 1, "tin": 1},
	"iron": {"iron": 2},
	"silver": {"silver": 2},
	"gold": {"gold": 2},
	"mithril": {"mithril": 2},
	"adamant": {"adamant": 2},
	"runite": {"runite": 2},
	"orichalcum": {"orichalcum": 2},
	"obsidian": {"obsidian": 2},
	"voidsteel": {"voidsteel": 2},
}

# Forge templates: kind -> slot / bar cost / item id segment.
const FORGE_TEMPLATES := [
	{"kind": "pickaxe", "slot": "tool", "bars": 3, "id_seg": "tool.pickaxe", "label": "Pickaxe", "forge_category": "tool"},
	{"kind": "rod", "slot": "tool", "bars": 3, "id_seg": "tool.rod", "label": "Rod", "forge_category": "tool"},
	{"kind": "sword", "slot": "weapon", "bars": 2, "id_seg": "weapon.sword", "label": "Sword", "forge_category": "weapon", "damage_type": "slash"},
	{"kind": "spear", "slot": "weapon", "bars": 2, "id_seg": "weapon.spear", "label": "Spear", "forge_category": "weapon", "damage_type": "stab"},
	{"kind": "mace", "slot": "weapon", "bars": 3, "id_seg": "weapon.mace", "label": "Mace", "forge_category": "weapon", "damage_type": "crush"},
	{"kind": "shield", "slot": "off_hand", "bars": 2, "id_seg": "offhand.shield", "label": "Shield", "forge_category": "shield"},
	{"kind": "helm", "slot": "head", "bars": 2, "id_seg": "armor.helm", "label": "Helmet", "forge_category": "helmet"},
	{"kind": "body", "slot": "body", "bars": 3, "id_seg": "armor.body", "label": "Body Armor", "forge_category": "body_armor"},
	{"kind": "legs", "slot": "legs", "bars": 3, "id_seg": "armor.legs", "label": "Leg Armor", "forge_category": "leg_armor"},
	{"kind": "gloves", "slot": "hands", "bars": 2, "id_seg": "armor.gloves", "label": "Gloves", "forge_category": "gloves"},
	{"kind": "boots", "slot": "feet", "bars": 2, "id_seg": "armor.boots", "label": "Boots", "forge_category": "boots"},
]

# Fish species, one per tier. Raw catch and its cooked form.
const FISH := [
	{"slug": "shrimp", "name": "Shrimp", "tier": 1},
	{"slug": "sardine", "name": "Sardine", "tier": 2},
	{"slug": "trout", "name": "Trout", "tier": 3},
	{"slug": "salmon", "name": "Salmon", "tier": 4},
	{"slug": "mackerel", "name": "Mackerel", "tier": 5},
	{"slug": "tuna", "name": "Tuna", "tier": 6},
	{"slug": "swordfish", "name": "Swordfish", "tier": 7},
	{"slug": "shark", "name": "Shark", "tier": 8},
	{"slug": "manta", "name": "Manta Ray", "tier": 9},
	{"slug": "leviathan", "name": "Leviathan", "tier": 10},
]

# Combat area names, index 0 == tier 1.
const AREA_NAMES := [
	"Felwood Edge", "Thornreach", "Ashen Foothills", "Mirrorfen", "Sunken Causeway",
	"Wyrmspine", "Glacier Steps", "Ember Wastes", "Stormpeak", "The Abyss",
]

# Enemy archetypes. Each area has the four archetypes plus an elite and a boss.
# resist maps player damage_type -> percentage points (positive resists).
const ENEMY_ARCHETYPES := [
	{"slug": "wolf", "suffix": "Wolf", "style": "melee", "damage_type": "slash", "resist": {"slash": 20, "stab": 0, "crush": -20}},
	{"slug": "archer", "suffix": "Archer", "style": "ranged", "damage_type": "pierce", "resist": {"slash": -10, "stab": 20, "crush": 0}},
	{"slug": "acolyte", "suffix": "Acolyte", "style": "magic", "damage_type": "fire", "resist": {"slash": 10, "stab": -20, "crush": 10}},
	{"slug": "brute", "suffix": "Brute", "style": "melee", "damage_type": "crush", "resist": {"slash": -15, "stab": 0, "crush": 25}},
]


static func tier_start_level(tier: int) -> int:
	return (clampi(tier, 1, 10) - 1) * 10 + 1


static func rarity_for_tier(tier: int) -> String:
	if tier <= 3:
		return "common"
	elif tier <= 7:
		return "uncommon"
	return "rare"


# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------
static func build_items() -> Dictionary:
	var out := {}
	for ore in ORES:
		var id := "item.ore." + str(ore["id"])
		out[id] = {
			"id": id,
			"name": ore["name"],
			"category": "ore",
			"tier": ore["tier"],
			"rarity": rarity_for_tier(ore["tier"]),
			"equip_slot": "",
			"stats": {},
			"value": 5 * int(ore["tier"]),
			"description": "Raw ore recovered from the earth.",
		}
	for bar in BARS:
		var id := "item.bar." + str(bar["id"])
		out[id] = {
			"id": id,
			"name": bar["name"],
			"category": "bar",
			"tier": bar["tier"],
			"rarity": rarity_for_tier(bar["tier"]),
			"equip_slot": "",
			"stats": {},
			"value": 18 * int(bar["tier"]),
			"description": "A refined bar ready for the anvil.",
		}
	for bar in BARS:
		var tier := int(bar["tier"])
		var bid := str(bar["id"])
		for tmpl in FORGE_TEMPLATES:
			var item_id := "item." + str(tmpl["id_seg"]) + "." + bid
			var stats := {}
			match str(tmpl["kind"]):
				"pickaxe":
					stats = {"mining_power": tier, "speed": 1.0 + 0.08 * (tier - 1)}
				"rod":
					stats = {"fishing_power": tier, "speed": 1.0 + 0.08 * (tier - 1)}
				"sword":
					stats = {"attack_bonus": 3 + tier * 3, "strength_bonus": 2 + tier * 2, "damage_type": "slash", "attack_interval": 2.4}
				"spear":
					stats = {"attack_bonus": 4 + tier * 3, "strength_bonus": 1 + tier * 2, "damage_type": "stab", "attack_interval": 2.6}
				"mace":
					stats = {"attack_bonus": 2 + tier * 3, "strength_bonus": 3 + tier * 2, "damage_type": "crush", "attack_interval": 3.0}
				"helm":
					stats = {"defense_bonus": tier}
				"body":
					stats = {"defense_bonus": tier * 2}
				"legs":
					stats = {"defense_bonus": tier}
				"gloves", "boots":
					stats = {"defense_bonus": maxi(1, floori(float(tier) / 2.0))}
				"shield":
					stats = {"defense_bonus": tier, "block_bonus": tier}
			out[item_id] = {
				"id": item_id,
				"name": str(bar["name"]).replace(" Bar", "") + " " + str(tmpl["label"]),
				"category": str(tmpl["id_seg"]).split(".")[0],
				"tier": tier,
				"rarity": rarity_for_tier(tier),
				"equip_slot": tmpl["slot"],
				"stats": stats,
				"value": (40 + tier * 35) * int(tmpl["bars"]),
				"description": "Forged from " + str(bar["name"]).to_lower() + ".",
			}
	for fish in FISH:
		var fid := "item.fish." + str(fish["slug"])
		out[fid] = {
			"id": fid, "name": str(fish["name"]), "category": "fish", "tier": fish["tier"],
			"rarity": rarity_for_tier(int(fish["tier"])), "equip_slot": "", "stats": {},
			"value": 8 * int(fish["tier"]), "description": "A raw catch, best cooked before eating.",
		}
		var food_id := "item.food." + str(fish["slug"])
		out[food_id] = {
			"id": food_id, "name": "Cooked " + str(fish["name"]), "category": "food", "tier": fish["tier"],
			"rarity": rarity_for_tier(int(fish["tier"])), "equip_slot": "food",
			"stats": {"heal": 15 * int(fish["tier"]), "satiety": 18 + 2 * int(fish["tier"])},
			"value": 20 * int(fish["tier"]), "description": "Restores health and fills Satiety when eaten.",
		}
	out["item.misc.pearl"] = {
		"id": "item.misc.pearl", "name": "Pearl", "category": "misc", "tier": 1,
		"rarity": "rare", "equip_slot": "", "stats": {}, "value": 250,
		"description": "A lustrous treasure found while fishing.",
	}
	return out


# ---------------------------------------------------------------------------
# Recipes
# ---------------------------------------------------------------------------
static func build_recipes() -> Dictionary:
	var out := {}
	for bar in BARS:
		var bid := str(bar["id"])
		var tier := int(bar["tier"])
		var inputs := {}
		for ore_id in SMELT_INPUTS[bid]:
			inputs["item.ore." + str(ore_id)] = int(SMELT_INPUTS[bid][ore_id])
		var id := "recipe.smithing.smelt." + bid
		out[id] = {
			"id": id,
			"name": "Smelt " + str(bar["name"]),
			"profession": "smithing",
			"kind": "smelt",
			"inputs": inputs,
			"output": {"item.bar." + bid: 1},
			"level": tier_start_level(tier),
			"tier": tier,
			"time": 2.0,
			"furnace_heat_requirement": 100 + (tier - 1) * 8,
			"furnace_warmup": 0.35 + (tier - 1) * 0.12,
			"xp": 15 * tier * tier,
		}
		for tmpl in FORGE_TEMPLATES:
			var item_id := "item." + str(tmpl["id_seg"]) + "." + bid
			var rid := "recipe.smithing.forge." + bid + "." + str(tmpl["kind"])
			out[rid] = {
				"id": rid,
				"name": "Forge " + str(out_item_name(item_id, out)) ,
				"profession": "smithing",
				"kind": "forge",
				"forge_category": str(tmpl.get("forge_category", "other")),
				"item_slot": str(tmpl["slot"]),
				"inputs": {"item.bar." + bid: int(tmpl["bars"])},
				"output": {item_id: 1},
				"level": tier_start_level(tier),
				"tier": tier,
				"time": 3.0,
				"work_required": int(round((28.0 + (tier - 1) * 8.0) * (1.0 if str(tmpl.get("forge_category", "")) != "body_armor" else 1.7))),
				"minimum_working_heat": minf(70.0, 25.0 + (tier - 1) * 5.0),
				"initial_workpiece_heat": 100,
				"heat_loss_per_strike": 10,
				"reheat_time": 2.0 + (tier - 1) * 0.12,
				"xp": 25 * tier * tier,
			}
	for fish in FISH:
		var slug := str(fish["slug"])
		out["recipe.cooking." + slug] = {
			"id": "recipe.cooking." + slug,
			"name": "Cook " + str(fish["name"]),
			"profession": "cooking",
			"kind": "cook",
			"inputs": {"item.fish." + slug: 1},
			"output": {"item.food." + slug: 1},
			"level": tier_start_level(int(fish["tier"])),
			"tier": fish["tier"],
			"time": 2.0,
			"xp": 12 * int(fish["tier"]),
		}
	return out


## Small helper so forge recipe names can be built without resolving items twice.
static func out_item_name(item_id: String, items: Dictionary) -> String:
	if items.has(item_id):
		return str(items[item_id]["name"])
	# fall back to a readable name from the id if items not yet built
	var parts := item_id.split(".")
	if parts.size() >= 2:
		return str(parts[-2]).capitalize() + " " + str(parts[-1]).capitalize()
	return item_id


# ---------------------------------------------------------------------------
# Mining deposits
# ---------------------------------------------------------------------------
static func build_deposits() -> Dictionary:
	var out := {}
	for ore in ORES:
		var oid := str(ore["id"])
		var tier := int(ore["tier"])
		var id := "deposit.mining." + oid
		out[id] = {
			"id": id,
			"name": str(ore["name"]).replace(" Ore", "") + " Deposit",
			"ore_item": "item.ore." + oid,
			"tier": tier,
			"unlock_level": tier_start_level(tier),
			"required_tool_tier": maxi(0, tier - 1),
			"base_time": 1.8 + 0.2 * (tier - 1),
			"base_xp": 10 * tier * tier,
			"stage_pools": [5, 6, 8, 10, 12],
			"stage_yields": [1, 1, 1, 2, 2],
		}
	return out


# ---------------------------------------------------------------------------
# Fishing spots
# ---------------------------------------------------------------------------
static func build_fishing_spots() -> Dictionary:
	var out := {}
	for i in FISH.size():
		var fish: Dictionary = FISH[i]
		var tier := int(fish["tier"])
		var id := "spot.fishing." + str(fish["slug"])
		var pool: Array = [{"item_id": "item.fish." + str(fish["slug"]), "weight": 100}]
		if i > 0:
			pool.append({"item_id": "item.fish." + str(FISH[i - 1]["slug"]), "weight": 30})
		pool.append({"item_id": "item.misc.pearl", "weight": 4})
		out[id] = {
			"id": id, "name": str(fish["name"]) + " Shoal",
			"fish_item": "item.fish." + str(fish["slug"]),
			"tier": tier, "unlock_level": tier_start_level(tier),
			"required_rod_tier": tier,
			"base_time": 3.0 - 0.1 * (tier - 1),
			"base_xp": 6 * tier * tier,
			"pool": pool,
		}
	return out


# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------
static func build_enemies() -> Dictionary:
	var out := {}
	for tier in range(1, MAX_TIER + 1):
		var area_name := str(AREA_NAMES[tier - 1])
		for archetype in ENEMY_ARCHETYPES:
			var eid := "enemy.t%d.%s" % [tier, str(archetype["slug"])]
			out[eid] = _make_enemy(eid, area_name + " " + str(archetype["suffix"]), tier, "normal",
				str(archetype["style"]), str(archetype["damage_type"]), archetype["resist"])
		var elite_id := "enemy.t%d.elite" % tier
		out[elite_id] = _make_enemy(elite_id, area_name + " Warlord", tier, "elite",
			"melee", "crush", {"slash": 0, "stab": 0, "crush": 30})
		var boss_id := "enemy.t%d.boss" % tier
		out[boss_id] = _make_enemy(boss_id, area_name + " Overlord", tier, "boss",
			"magic", "fire", {"slash": 15, "stab": 15, "crush": 15})
	return out


static func _make_enemy(id: String, enemy_name: String, tier: int, rank: String,
		style: String, damage_type: String, resist: Dictionary) -> Dictionary:
	var rank_hp := 1.0
	var rank_xp := 1.0
	var rank_dmg := 1.0
	var rank_gold := 0.0
	match rank:
		"elite":
			rank_hp = 3.0
			rank_xp = 3.0
			rank_dmg = 1.4
			rank_gold = 1.0
		"boss":
			rank_hp = 6.0
			rank_xp = 8.0
			rank_dmg = 1.8
			rank_gold = 3.0

	var sequence: Array = [
		{"name": "Basic Attack", "mult": 1.0, "interval": 2.5, "hits": 1, "effect": ""},
		{"name": "Basic Attack", "mult": 1.0, "interval": 2.5, "hits": 1, "effect": ""},
		{"name": "Power Strike", "mult": 1.6, "interval": 3.0, "hits": 1, "effect": ("burn" if damage_type == "fire" else "")},
	]
	var phases: Array = []
	if rank == "boss":
		phases = [
			{"threshold": 1.0, "sequence": sequence},
			{"threshold": 0.5, "sequence": [
				{"name": "Enrage", "mult": 1.4, "interval": 2.2, "hits": 1, "effect": ""},
				{"name": "Enrage", "mult": 1.4, "interval": 2.2, "hits": 1, "effect": ""},
				{"name": "Cataclysm", "mult": 2.4, "interval": 4.0, "hits": 2, "effect": "burn"},
			]},
		]

	var loot: Array = []
	if tier >= 2:
		loot.append({"item_id": "item.bar." + str(BARS[tier - 1]["id"]), "chance": 0.12, "min": 1, "max": 1})
	loot.append({"item_id": "item.food." + str(FISH[tier - 1]["slug"]), "chance": 0.25, "min": 1, "max": 1})
	if rank != "normal":
		loot.append({"item_id": "item.misc.pearl", "chance": 0.15, "min": 1, "max": 1})

	return {
		"id": id, "name": enemy_name, "tier": tier, "rank": rank,
		"hp": int(25.0 * tier * (1.0 + 0.2 * tier) * rank_hp),
		"attack_level": 4 * tier + 5,
		"defense_level": 3 * tier + 2,
		"damage": maxi(1, int(4.0 * tier * (1.0 + 0.2 * tier) * rank_dmg)),
		"style": style, "damage_type": damage_type, "resistances": resist,
		"sequence": sequence, "phases": phases,
		"xp": int(15.0 * tier * tier * rank_xp),
		"gold": int(2.0 * tier * tier * (1.0 + rank_gold)),
		"loot": loot,
	}


# ---------------------------------------------------------------------------
# Combat areas
# ---------------------------------------------------------------------------
static func build_areas() -> Dictionary:
	var out := {}
	for tier in range(1, MAX_TIER + 1):
		var id := "area.t%d" % tier
		var enemies: Array = []
		for archetype in ENEMY_ARCHETYPES:
			enemies.append("enemy.t%d.%s" % [tier, str(archetype["slug"])])
		enemies.append("enemy.t%d.elite" % tier)
		enemies.append("enemy.t%d.boss" % tier)
		out[id] = {
			"id": id, "name": str(AREA_NAMES[tier - 1]), "tier": tier,
			"unlock_level": tier_start_level(tier), "enemies": enemies,
		}
	return out