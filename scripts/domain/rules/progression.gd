class_name Progression
extends RefCounted

## Central XP / level rules. Levels are 1-100, arranged into ten 10-level tiers.
## The simulation is authoritative: UI never computes XP itself, it reads this.

const MAX_LEVEL := 100
const TIER_SIZE := 10

static var _cumulative: Array[int] = []

## XP required to advance from `level` to `level + 1`.
static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(round(120.0 * pow(float(level), 2.0)))


static func _ensure_cache() -> void:
	if not _cumulative.is_empty():
		return
	_cumulative.append(0) # cumulative XP at level 1
	var total := 0
	for level in range(1, MAX_LEVEL):
		total += xp_to_next(level)
		_cumulative.append(total)


## Total XP accumulated at the start of `level`.
static func total_xp_for_level(level: int) -> int:
	_ensure_cache()
	var clamped: int = clampi(level, 1, MAX_LEVEL)
	return _cumulative[clamped - 1]


## Level reached for a given total XP (1..100).
static func level_for_total_xp(xp: int) -> int:
	_ensure_cache()
	var level := 1
	while level < MAX_LEVEL and xp >= _cumulative[level]:
		level += 1
	return level


## Which tier (1..10) a level belongs to.
static func tier_for_level(level: int) -> int:
	return clampi(int((level - 1) / float(TIER_SIZE)) + 1, 1, 10)


## First level of a tier.
static func tier_start_level(tier: int) -> int:
	return (clampi(tier, 1, 10) - 1) * TIER_SIZE + 1


## Progress within the current level as 0..1.
static func level_progress(xp: int) -> float:
	var level := level_for_total_xp(xp)
	if level >= MAX_LEVEL:
		return 1.0
	var floor_xp := total_xp_for_level(level)
	var span := xp_to_next(level)
	if span <= 0:
		return 1.0
	return clampf(float(xp - floor_xp) / float(span), 0.0, 1.0)