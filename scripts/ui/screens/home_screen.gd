extends Control

## Home overview: hero summary, every skill's level progress, the current
## activity and lifetime counters. Read-only rendering of authoritative state.

const ProgressRowScene := preload("res://scenes/ui/components/ProgressRow.tscn")
const StatRowScene := preload("res://scenes/ui/components/StatRow.tscn")

@onready var _skill_list: VBoxContainer = %SkillList
@onready var _activity_info: Label = %ActivityInfo
@onready var _activity_bar: ProgressBar = %ActivityBar
@onready var _hero_name: Label = %HeroName
@onready var _hero_meta: Label = %HeroMeta
@onready var _summary: VBoxContainer = %SummaryRows


func _ready() -> void:
	EventBus.activity_changed.connect(func(_a): _update_activity())
	EventBus.profile_loaded.connect(refresh)
	EventBus.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	_build_header()
	_build_skills()
	_build_summary()
	_update_activity()


func _build_header() -> void:
	var state := GameSession.state
	if state == null:
		return
	_hero_name.text = state.display_name
	var total := 0
	for skill in CharacterState.SKILLS:
		total += state.get_level(skill)
	_hero_meta.text = "Combat level %d  ·  Total level %d  ·  %s played" % [
		state.get_level("hitpoints"), total, UiUtil.format_time(state.play_time)]


func _build_skills() -> void:
	for child in _skill_list.get_children():
		child.queue_free()
	var state := GameSession.state
	if state == null:
		return
	for skill in CharacterState.SKILLS:
		var level := state.get_level(skill)
		var row := ProgressRowScene.instantiate()
		_skill_list.add_child(row)
		var value := 1.0
		var maximum := 1.0
		var value_text := "Lv %d  ·  MAX" % level
		if level < Progression.MAX_LEVEL:
			var floor_xp := Progression.total_xp_for_level(level)
			var span := Progression.xp_to_next(level)
			value = float(state.get_xp(skill) - floor_xp)
			maximum = float(span)
			value_text = "Lv %d  ·  %s / %s XP" % [level, UiUtil.format_number(int(value)), UiUtil.format_number(span)]
		row.configure(skill.capitalize(), value, maximum, value_text)


func _build_summary() -> void:
	for child in _summary.get_children():
		child.queue_free()
	var state := GameSession.state
	if state == null:
		return
	var counters: Dictionary = state.counters
	_add_summary("Actions completed", UiUtil.format_number(int(counters.get("actions_completed", 0))))
	_add_summary("Items gathered", UiUtil.format_number(int(counters.get("items_gained", 0))))
	_add_summary("Gold", "%s g" % UiUtil.format_number(state.gold))
	_add_summary("Play time", UiUtil.format_time(state.play_time))


func _add_summary(caption: String, value: String) -> void:
	var row := StatRowScene.instantiate()
	_summary.add_child(row)
	row.configure(caption, value)


func _update_activity() -> void:
	var state := GameSession.state
	if state == null or state.activity.is_empty():
		_activity_info.text = "Idle. Choose a profession from the left to begin."
		_activity_bar.value = 0.0
		return
	var act: Dictionary = state.activity
	var progress := 0.0
	if float(act.get("duration", 0.0)) > 0.0:
		progress = clampf(float(act.get("time", 0.0)) / float(act["duration"]), 0.0, 1.0)
	match str(act.get("type", "")):
		"mining":
			var deposit := ContentRegistry.get_deposit(str(act.get("target", "")))
			_activity_info.text = "Mining %s · stage %d/5 · %d%%" % [
				str(deposit.get("name", "?")), int(act.get("stage", 0)) + 1, int(progress * 100.0)]
		"smithing":
			var recipe := ContentRegistry.get_recipe(str(act.get("target", "")))
			_activity_info.text = "Smithing %s · %d%%" % [str(recipe.get("name", "?")), int(progress * 100.0)]
		"fishing":
			var spot := ContentRegistry.get_spot(str(act.get("target", "")))
			_activity_info.text = "Fishing %s · %d%%" % [str(spot.get("name", "?")), int(progress * 100.0)]
		"cooking":
			var food := ContentRegistry.get_recipe(str(act.get("target", "")))
			_activity_info.text = "Cooking %s · %d%%" % [str(food.get("name", "?")), int(progress * 100.0)]
		"combat":
			var enemy := ContentRegistry.get_enemy(str(act.get("target", "")))
			_activity_info.text = "Fighting %s" % str(enemy.get("name", "?"))
		_:
			_activity_info.text = "Active."
	_activity_bar.value = progress
