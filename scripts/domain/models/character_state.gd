class_name CharacterState
extends RefCounted

## Authoritative character state. Explicit, validated, serialisable.
## Simulation systems read and mutate this; UI only reads it.

const SCHEMA_VERSION := 2

const SLOTS := ["tool", "weapon", "off_hand", "head", "body", "legs", "hands", "feet", "ring", "necklace", "food_1", "food_2", "food_3"]
const FOOD_SLOTS := ["food_1", "food_2", "food_3"]
const SKILLS := ["mining", "smithing", "fishing", "cooking", "attack", "hitpoints"]

var profile_id: String = ""
var display_name: String = "Adventurer"
var created_unix: int = 0
var last_saved_unix: int = 0
var play_time: float = 0.0

var skills: Dictionary = {}          # skill -> total xp (int)
var bank: Dictionary = {}            # item_id -> count (int)
var equipment: Dictionary = {}       # slot -> item_id ("" when empty)
var activity: Dictionary = {}        # current personal activity
var counters: Dictionary = {}        # lifetime telemetry

# Combat-facing state. Persists across kills and target switches.
var hp: int = 0                      # current hitpoints
var satiety: float = 100.0           # 0..100 food-sustain bar
var gold: int = 0
var food_cooldown: float = 0.0       # seconds until food may be eaten again
var combat_prefs: Dictionary = {}    # auto_eat, auto_eat_threshold, auto_combat, stance


func _init() -> void:
	reset()


func reset() -> void:
	skills = {}
	for skill in SKILLS:
		skills[skill] = 0
	bank = {}
	equipment = {}
	for slot in SLOTS:
		equipment[slot] = ""
	activity = {}
	counters = {"actions_completed": 0, "items_gained": 0}
	hp = max_hp()
	satiety = 100.0
	gold = 0
	food_cooldown = 0.0
	combat_prefs = {
		"auto_eat": true,
		"auto_eat_threshold": 0.5,
		"auto_combat": false,
		"stance": "accurate",
	}


func new_profile(id: String, name: String) -> void:
	reset()
	profile_id = id
	display_name = name
	created_unix = int(Time.get_unix_time_from_system())
	last_saved_unix = created_unix
	# Start with a bronze pickaxe equipped so the first loop is playable.
	equipment["tool"] = "item.tool.pickaxe.bronze"


# --- Skills -----------------------------------------------------------------
func get_level(skill: String) -> int:
	return Progression.level_for_total_xp(int(skills.get(skill, 0)))


func get_xp(skill: String) -> int:
	return int(skills.get(skill, 0))


## Authored max HP formula: 90 + Hitpoints Level * 10 (+ future flat bonuses).
func max_hp() -> int:
	return 90 + get_level("hitpoints") * 10


## Adds XP and returns an array of levels newly reached.
func add_xp(skill: String, amount: int) -> Array:
	if amount <= 0:
		return []
	var before := get_level(skill)
	skills[skill] = int(skills.get(skill, 0)) + amount
	var after := get_level(skill)
	var gained: Array = []
	for lvl in range(before + 1, after + 1):
		gained.append(lvl)
	return gained


# --- Serialisation ----------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": profile_id,
		"display_name": display_name,
		"created_unix": created_unix,
		"last_saved_unix": last_saved_unix,
		"play_time": play_time,
		"skills": skills.duplicate(true),
		"bank": bank.duplicate(true),
		"equipment": equipment.duplicate(true),
		"activity": activity.duplicate(true),
		"counters": counters.duplicate(true),
		"hp": hp,
		"satiety": satiety,
		"gold": gold,
		"food_cooldown": food_cooldown,
		"combat_prefs": combat_prefs.duplicate(true),
	}


## Loads and repairs a dictionary into this state. Unknown/broken fields get
## safe defaults; nothing is silently discarded without a log.
func from_dict(data: Dictionary) -> void:
	reset()
	profile_id = str(data.get("profile_id", profile_id))
	display_name = str(data.get("display_name", display_name))
	created_unix = int(data.get("created_unix", 0))
	last_saved_unix = int(data.get("last_saved_unix", 0))
	play_time = float(data.get("play_time", 0.0))

	var loaded_skills: Dictionary = data.get("skills", {})
	for skill in loaded_skills.keys():
		if skill in SKILLS:
			skills[skill] = maxi(0, int(loaded_skills[skill]))

	var loaded_bank: Dictionary = data.get("bank", {})
	for item_id in loaded_bank.keys():
		var count := int(loaded_bank[item_id])
		if count > 0:
			bank[str(item_id)] = count

	var loaded_eq: Dictionary = data.get("equipment", {})
	for slot in SLOTS:
		if loaded_eq.has(slot):
			equipment[slot] = str(loaded_eq[slot])

	if data.has("activity") and data["activity"] is Dictionary:
		activity = (data["activity"] as Dictionary).duplicate(true)

	var loaded_counters: Dictionary = data.get("counters", {})
	for key in loaded_counters.keys():
		counters[key] = int(loaded_counters[key])

	gold = maxi(0, int(data.get("gold", 0)))
	satiety = clampf(float(data.get("satiety", 100.0)), 0.0, 100.0)
	food_cooldown = maxf(0.0, float(data.get("food_cooldown", 0.0)))
	hp = int(data.get("hp", max_hp()))
	if hp <= 0:
		hp = max_hp()
	hp = mini(hp, max_hp())
	if data.has("combat_prefs") and data["combat_prefs"] is Dictionary:
		for key in (data["combat_prefs"] as Dictionary).keys():
			combat_prefs[key] = data["combat_prefs"][key]