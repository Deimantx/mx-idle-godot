extends Control

## Home overview: skill progress and the current activity. Read-only rendering
## of authoritative state.

@onready var _skill_list: VBoxContainer = %SkillList
@onready var _activity_info: Label = %ActivityInfo


func _ready() -> void:
	EventBus.activity_changed.connect(func(_a): _update_activity())
	EventBus.profile_loaded.connect(refresh)
	EventBus.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	_build_skills()
	_update_activity()


func _build_skills() -> void:
	for child in _skill_list.get_children():
		child.queue_free()
	var state := GameSession.state
	if state == null:
		return
	for skill in CharacterState.SKILLS:
		_skill_list.add_child(_skill_row(state, skill))


func _skill_row(state: CharacterState, skill: String) -> Control:
	var row := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = skill.capitalize()
	name_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_label)

	var level := state.get_level(skill)
	var lvl_label := Label.new()
	lvl_label.text = "Lv %d" % level
	lvl_label.custom_minimum_size = Vector2(64, 0)
	row.add_child(lvl_label)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(120, 18)
	bar.max_value = 1.0
	bar.value = Progression.level_progress(state.get_xp(skill))
	bar.show_percentage = false
	row.add_child(bar)

	var xp_label := Label.new()
	xp_label.theme_type_variation = &"Muted"
	xp_label.custom_minimum_size = Vector2(170, 0)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if level >= Progression.MAX_LEVEL:
		xp_label.text = "MAX"
	else:
		var floor_xp := Progression.total_xp_for_level(level)
		xp_label.text = "%s / %s XP" % [
			UiUtil.format_number(state.get_xp(skill) - floor_xp),
			UiUtil.format_number(Progression.xp_to_next(level))]
	row.add_child(xp_label)
	return row


func _update_activity() -> void:
	var state := GameSession.state
	if state == null or state.activity.is_empty():
		_activity_info.text = "Idle. Choose a profession from the left to begin."
		return
	var act: Dictionary = state.activity
	var progress := 0.0
	if float(act.get("duration", 0.0)) > 0.0:
		progress = clampf(float(act.get("time", 0.0)) / float(act["duration"]), 0.0, 1.0)
	match str(act.get("type", "")):
		"mining":
			var deposit := ContentRegistry.get_deposit(str(act.get("target", "")))
			_activity_info.text = "Mining %s · stage %d/5 · swing %d%%" % [
				str(deposit.get("name", "?")), int(act.get("stage", 0)) + 1, int(progress * 100.0)]
		"smithing":
			var recipe := ContentRegistry.get_recipe(str(act.get("target", "")))
			_activity_info.text = "Smithing %s · %d%%" % [str(recipe.get("name", "?")), int(progress * 100.0)]
		_:
			_activity_info.text = "Active."
