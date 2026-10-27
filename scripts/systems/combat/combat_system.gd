class_name CombatSystem
extends RefCounted

## Melee combat resolver. Deterministic enemy action sequences, percentage-point
## resistances/penetration, accuracy/evasion, critical hits, the style triangle,
## statuses (burn), Satiety and Auto Eat. Runs behind a single tick() driven by
## GameSession.advance(), so online and offline use the exact same code.

const BASE_ATTACK_INTERVAL := 2.4
const CRIT_CHANCE := 0.1
const CRIT_MULT := 1.5
const SATIETY_DRAIN := 0.4
const BURN_TIME := 6.0


static func can_start(state: CharacterState, enemy_id: String) -> Dictionary:
	var enemy := ContentRegistry.get_enemy(enemy_id)
	if enemy.is_empty():
		return {"ok": false, "reason": "Unknown target."}
	var area := ContentRegistry.get_area("area.t%d" % int(enemy["tier"]))
	if state.get_level("attack") < int(area["unlock_level"]):
		return {"ok": false, "reason": "Requires Attack %d." % int(area["unlock_level"])}
	return {"ok": true, "reason": ""}


static func player_attack_interval(state: CharacterState) -> float:
	var weapon := EquipmentSystem.equipped_item(state, "weapon")
	if weapon.is_empty():
		return BASE_ATTACK_INTERVAL
	return float((weapon.get("stats", {}) as Dictionary).get("attack_interval", BASE_ATTACK_INTERVAL))


static func player_accuracy(state: CharacterState) -> float:
	return float(state.get_level("attack")) + EquipmentSystem.stat(state, "attack_bonus")


static func player_defense(state: CharacterState) -> float:
	return EquipmentSystem.stat(state, "defense_bonus")


static func make_activity(state: CharacterState, enemy_id: String) -> Dictionary:
	var enemy := ContentRegistry.get_enemy(enemy_id)
	return {
		"type": "combat",
		"target": enemy_id,
		"time": 0.0,
		"duration": player_attack_interval(state),
		"enemy_hp": int(enemy["hp"]),
		"enemy_seq": 0,
		"enemy_timer": 0.0,
		"phase": 0,
		"statuses": {},
		"stun": 0.0,
	}


## Advance combat by `delta` seconds. Returns event deltas for GameSession.
static func tick(state: CharacterState, act: Dictionary, delta: float) -> Dictionary:
	var enemy := ContentRegistry.get_enemy(str(act["target"]))
	var events := {"items": {}, "xp": {}, "levels": {}, "gold": 0, "stop": false, "reason": "", "combat": {}}
	if enemy.is_empty():
		events["stop"] = true
		events["reason"] = "Target vanished."
		return events

	state.satiety = maxf(0.0, state.satiety - SATIETY_DRAIN * delta)
	state.food_cooldown = maxf(0.0, state.food_cooldown - delta)
	act["stun"] = maxf(0.0, float(act.get("stun", 0.0)) - delta)

	# Damage-over-time statuses.
	var expired: Array = []
	for status_name in (act["statuses"] as Dictionary).keys():
		var status: Dictionary = act["statuses"][status_name]
		status["time"] = float(status["time"]) - delta
		var dot := int(round(float(status["dps"]) * delta))
		if dot > 0:
			state.hp -= dot
		if float(status["time"]) <= 0.0:
			expired.append(status_name)
	for status_name in expired:
		act["statuses"].erase(status_name)

	if state.hp <= 0:
		return _player_death(state, act, events)

	# Auto Eat.
	var ate := FoodSystem.try_auto_eat(state)
	if ate.get("overeat", false):
		events["combat"]["overeat"] = true
	elif ate.get("ok", false):
		events["combat"]["ate"] = ate

	# Player attacks.
	if float(act["stun"]) <= 0.0:
		act["time"] = float(act["time"]) + delta
		var guard := 0
		while float(act["time"]) >= float(act["duration"]) and guard < 1000:
			guard += 1
			act["time"] = float(act["time"]) - float(act["duration"])
			_player_attack(state, act, enemy, events)
			if int(act["enemy_hp"]) <= 0:
				_on_kill(state, act, enemy, events)
				break

	# Enemy attacks.
	if int(act["enemy_hp"]) > 0 and state.hp > 0:
		act["enemy_timer"] = float(act["enemy_timer"]) + delta
		var guard2 := 0
		while int(act["enemy_hp"]) > 0 and state.hp > 0 and guard2 < 1000:
			var action := _current_action(act, enemy)
			if float(act["enemy_timer"]) < float(action["interval"]):
				break
			guard2 += 1
			act["enemy_timer"] = float(act["enemy_timer"]) - float(action["interval"])
			_enemy_attack(state, act, enemy, action, events)
			_advance_sequence(act, enemy)
			if state.hp <= 0:
				return _player_death(state, act, events)

	_check_phase(act, enemy)

	events["combat"]["player_hp"] = state.hp
	events["combat"]["player_max_hp"] = state.max_hp()
	events["combat"]["enemy_hp"] = int(act["enemy_hp"])
	events["combat"]["enemy_max_hp"] = int(enemy["hp"])
	events["combat"]["satiety"] = state.satiety
	events["combat"]["stun"] = float(act["stun"])
	events["combat"]["sequence"] = _sequence_names(act, enemy)
	events["combat"]["seq_index"] = int(act["enemy_seq"]) % _sequence_for(act, enemy).size()
	events["combat"]["next_action"] = str(_current_action(act, enemy)["name"])
	return events


# --- Attacks ----------------------------------------------------------------
static func _player_attack(state: CharacterState, act: Dictionary, enemy: Dictionary, events: Dictionary) -> void:
	var accuracy := player_accuracy(state)
	var bonus := _style_bonus("melee", str(enemy["style"]))
	var hit_chance := clampf(0.5 + 0.02 * (accuracy - float(enemy["defense_level"])) + bonus, 0.1, 0.95)
	if randf() > hit_chance:
		events["combat"]["player_attack"] = {"hit": false}
		return

	var weapon := EquipmentSystem.equipped_item(state, "weapon")
	var strength_bonus := 0.0
	var damage_type := "crush"
	if not weapon.is_empty():
		var stats: Dictionary = weapon.get("stats", {})
		strength_bonus = float(stats.get("strength_bonus", 0))
		damage_type = str(stats.get("damage_type", "crush"))

	var dmg := (float(state.get_level("attack")) + strength_bonus) * randf_range(0.6, 1.0)
	var crit := randf() < CRIT_CHANCE
	if crit:
		dmg *= CRIT_MULT
	# Resistances are authored in percentage points (20 == 20%); penetration is 0 for now.
	var resist_points := float((enemy["resistances"] as Dictionary).get(damage_type, 0))
	var effective := clampf(resist_points / 100.0, -0.9, 0.9)
	dmg *= (1.0 - effective)
	var final := int(round(maxf(1.0, dmg)))
	act["enemy_hp"] = int(act["enemy_hp"]) - final
	events["combat"]["player_attack"] = {"hit": true, "damage": final, "crit": crit, "damage_type": damage_type}


static func _enemy_attack(state: CharacterState, act: Dictionary, enemy: Dictionary, action: Dictionary, events: Dictionary) -> void:
	var hit_chance := clampf(0.5 + 0.02 * (float(enemy["attack_level"]) - player_defense(state)) + _style_bonus(str(enemy["style"]), "melee"), 0.1, 0.95)
	var dealt := 0
	for _hit in range(int(action.get("hits", 1))):
		if randf() <= hit_chance:
			dealt += int(round(maxf(1.0, float(enemy["damage"]) * float(action.get("mult", 1.0)) * randf_range(0.7, 1.0))))
	state.hp -= dealt
	var effect := str(action.get("effect", ""))
	if effect == "burn" or effect == "poison":
		act["statuses"]["burn"] = {"time": BURN_TIME, "dps": maxf(1.0, float(enemy["damage"]) * 0.15)}
	elif effect == "stun":
		act["stun"] = 3.0
	events["combat"]["enemy_attack"] = {"name": str(action["name"]), "damage": dealt, "effect": effect}


static func _on_kill(state: CharacterState, act: Dictionary, enemy: Dictionary, events: Dictionary) -> void:
	var xp := int(enemy["xp"])
	var atk_xp := int(round(xp * 0.5))
	var hp_xp := int(round(xp * 0.5))
	events["levels"]["attack"] = state.add_xp("attack", atk_xp)
	events["levels"]["hitpoints"] = state.add_xp("hitpoints", hp_xp)
	events["xp"]["attack"] = events["xp"].get("attack", 0) + atk_xp
	events["xp"]["hitpoints"] = events["xp"].get("hitpoints", 0) + hp_xp

	state.gold += int(enemy["gold"])
	events["gold"] += int(enemy["gold"])
	for entry in (enemy["loot"] as Array):
		if randf() <= float(entry["chance"]):
			var amount := randi_range(int(entry["min"]), int(entry["max"]))
			InventorySystem.add(state, str(entry["item_id"]), amount)
			events["items"][str(entry["item_id"])] = events["items"].get(str(entry["item_id"]), 0) + amount

	# Respawn the same enemy. Player HP persists; temporary statuses clear.
	act["enemy_hp"] = int(enemy["hp"])
	act["enemy_seq"] = 0
	act["enemy_timer"] = 0.0
	act["phase"] = 0
	act["statuses"] = {}
	act["stun"] = 0.0
	events["combat"]["kill"] = str(enemy["name"])


static func _player_death(state: CharacterState, act: Dictionary, events: Dictionary) -> Dictionary:
	state.hp = state.max_hp()
	act["statuses"] = {}
	act["stun"] = 0.0
	events["combat"]["player_died"] = true
	events["stop"] = true
	events["reason"] = "You were defeated."
	return events


# --- Public sequence reads (used by the Combat screen) ----------------------
static func current_sequence(act: Dictionary, enemy: Dictionary) -> Array:
	return _sequence_for(act, enemy)


static func current_index(act: Dictionary, enemy: Dictionary) -> int:
	var sequence := _sequence_for(act, enemy)
	if sequence.is_empty():
		return 0
	return int(act.get("enemy_seq", 0)) % sequence.size()


# --- Sequence helpers -------------------------------------------------------
static func _sequence_for(act: Dictionary, enemy: Dictionary) -> Array:
	var phases: Array = enemy.get("phases", [])
	if phases.is_empty():
		return enemy["sequence"]
	var idx: int = clampi(int(act.get("phase", 0)), 0, phases.size() - 1)
	return phases[idx]["sequence"]


static func _current_action(act: Dictionary, enemy: Dictionary) -> Dictionary:
	var sequence := _sequence_for(act, enemy)
	return sequence[int(act["enemy_seq"]) % sequence.size()]


static func _advance_sequence(act: Dictionary, enemy: Dictionary) -> void:
	var sequence := _sequence_for(act, enemy)
	act["enemy_seq"] = (int(act["enemy_seq"]) + 1) % sequence.size()


static func _sequence_names(act: Dictionary, enemy: Dictionary) -> Array:
	var out: Array = []
	for action in _sequence_for(act, enemy):
		out.append(str(action["name"]))
	return out


static func _check_phase(act: Dictionary, enemy: Dictionary) -> void:
	var phases: Array = enemy.get("phases", [])
	if phases.is_empty():
		return
	var ratio := float(act["enemy_hp"]) / maxf(1.0, float(enemy["hp"]))
	var idx := 0
	for i in range(phases.size()):
		if ratio <= float(phases[i]["threshold"]):
			idx = i
	if idx != int(act.get("phase", 0)):
		act["phase"] = idx
		act["enemy_seq"] = 0
		act["enemy_timer"] = 0.0


## Style triangle: melee > ranged > magic > melee.
static func _style_bonus(attacker: String, defender: String) -> float:
	if attacker == defender:
		return 0.0
	var beats := {"melee": "ranged", "ranged": "magic", "magic": "melee"}
	if str(beats.get(attacker, "")) == defender:
		return 0.1
	if str(beats.get(defender, "")) == attacker:
		return -0.1
	return 0.0