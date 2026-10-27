extends Control

const ListEntryScene := preload("res://scenes/ui/components/ListEntry.tscn")

## Category label for forge recipes, derived from the output item's registered category.
static func _forge_category(output_id: String) -> String:
	var item := ContentRegistry.get_item(output_id)
	if item.is_empty():
		return "forged"
	category := str(item.get("category", ""))
	if category == "weapon":
		return "Weapons"
	if category == "tool":
		return "Tools"
	if category == "armor":
		return "Armour"
	return "forged"

## Colour coding for row status states.
static func _row_title_color(craftable: bool, level_locked: bool, missing_materials: bool) -> Color:
	if level_locked:
		return Color("a6a39d")  # dimmed = locked
	if missing_materials:
		return Color("b86d65")  # red = missing materials
	if craftable:
		return Color("7e9fc3")  # blue-ish = craftable/available
	return Color("a6a39d")  # dimmed = inactive

func _ready() -> void:
	%StopButton.pressed.connect(func(): GameSession.stop_activity(); _update_active())
	EventBus.activity_changed.connect(func(_a): _update_active())
	EventBus.level_up.connect(func(_s, _l): _build_lists())
	EventBus.bank_changed.connect(_on_bank_changed)
	EventBus.profile_loaded.connect(_build_lists)
	_build_lists()
	_update_active()

func refresh() -> void:
	_build_lists()
	_update_active()

func _on_bank_changed() -> void:
	if is_visible_in_tree():
		_build_lists()

## --- Category filtering ---

func _matches_category(recipe: Dictionary, category: String) -> bool:
	var kind := str(recipe.get("kind", ""))
	if category == "smelt" and kind == "smelt":
		return true
	if category == "alloys" and kind == "forge":
		# Alloy recipes are forge recipes; show all non-smelting ones.
		return true
	if category == "weapons" or category == "armour" or category == "tools":
		# Check output item category.
		var output_ids: Array = (recipe["output"] as Dictionary).keys()
		if output_ids.is_empty():
			return false
		var output_cat := _forge_category(str(output_ids[0]))
		return output_cat == category
	if category == "off-hand":
		# Off-hand is a subset of armour in the ForgeTemplates (no dedicated off-hand in base,
		# but we expose it as a filter category for completeness).
		return false
	return true

## --- Build the recipe lists ---

func _build_lists() -> void:
	# Clear existing rows from left zone lists
	for child in _smelt_list.get_children():
		child.queue_free()
	for child in _forge_list.get_children():
		child.queue_free()
	_rows.clear()

	var state := GameSession.state
	if state == null:
		return

	# Gather recipes, filtered by category
	var filtered: Array = []
	for recipe in ContentRegistry.recipes_for("smithing"):
		if _matches_category(recipe, _category_filter):
			filtered.append(recipe)

	# Apply availability toggles
	var show_available := _btn_available.pressed
	var show_can_afford := _btn_can_afford.pressed
	var show_locked := _btn_show_locked.pressed

	for recipe in filtered:
		var id := str(recipe["id"])
		var check := CraftingSystem.can_start(state, id)
		var level_ok := check["ok"]
		var entry := ListEntryScene.instantiate()

		# Configure the row using existing ListEntry methods
		# Title: recipe name
		entry.configure(str(recipe["name"]), "", "", "")

		# Icon: output item
		var output_ids: Array = (recipe["output"] as Dictionary).keys()
		if not output_ids.is_empty():
			entry.set_icon_item(str(output_ids[0]))
		else:
			entry.hide_icon()

		# Subtitle: tier or level requirement
		var tier := int(recipe["tier"])
		var level := int(recipe["level"])
		var my_level := 0
		if state and state.has_method("get_level"):
			my_level = int(state.get_level("smithing"))
		if my_level >= level:
			entry._sub.text = "T%d" % tier
			entry._sub.visible = true
			# Set subtitle color based on status
			var craftable := level_ok and _materials_available(state, recipe)
			entry.set_sub_color(_row_title_color(craftable, false, false))
		else:
			entry._sub.text = "Lv %d required" % level
			entry._sub.visible = true
			entry.set_sub_color(Color("b86d65"))  # red = level locked

		# Right top: key ingredient summary
		var materials_ok := _materials_available(state, recipe)
		var inputs: Dictionary = recipe["inputs"] as Dictionary
		var first_input_id := ""
		var first_input_count := 0
		for cid in inputs.keys():
			first_input_id := str(cid)
			first_input_count := int(inputs[cid])
			break

		if first_input_id != "":
			var item_name := ContentRegistry.item_name(first_input_id)
			var owned := 0
			if state and "bank" in state and first_input_id in state.bank:
				owned = int(state.bank[first_input_id])
			var shortfall := maxi(0, first_input_count - owned)
			if my_level >= level and level_ok:
				entry._right_top.text = "%dx %s" % [first_input_count, item_name]
				entry._right_top.visible = true
				if shortfall > 0:
					entry._right_sub.text = "-%dx" % shortfall
					entry._right_sub.visible = true
					entry.set_title_color(Color("b86d65"))  # red = missing materials
				else:
					entry._right_sub.visible = false
					entry.set_title_color(_row_title_color(materials_ok, false, false))
			else:
				entry._right_top.text = "Lv %d required" % level
				entry._right_top.visible = true
				entry._right_sub.visible = false
				entry.set_title_color(Color("a6a39d"))  # dimmed = level locked
		else:
			entry._right_top.visible = false
			entry._right_sub.visible = false

		# Status: title colour reflects availability
		if not level_ok:
			entry.set_title_color(Color("a6a39d"))  # level locked
		elif not materials_ok and shortfall > 0:
			entry.set_title_color(Color("b86d65"))  # missing materials
		elif _btn_show_locked.pressed or level_ok:
			entry.set_title_color(_row_title_color(materials_ok, level_ok, shortfall > 0))
		else:
			entry.set_title_color(Color("a6a39d"))

		entry.pressed.connect(func(): _start(id))
		_rows[id] = entry

	# Apply visibility filters after all rows are built
	for id, entry in _rows:
		var level_ok := true
		# Check if row should be visible based on filters
		if _btn_available.pressed:
			# "Available" = craftable (level ok + materials ok)
			var check := CraftingSystem.can_start(state, str(id))
			level_ok := check["ok"]
		if _btn_can_afford.pressed and level_ok:
			# "Can afford" = level ok (materials check separate)
			var check := CraftingSystem.can_start(state, str(id))
			level_ok := check["ok"]
		if not _btn_show_locked.pressed then:
			# Hide locked recipes when toggle is off
			var check := CraftingSystem.can_start(state, str(id))
			if not check["ok"]:
				entry.visible = false
			else:
				entry.visible = true
		else:
			entry.visible = true

	_highlight()

## --- Check if materials are available for a recipe ---

func _materials_available(state: Dictionary, recipe: Dictionary) -> bool:
	var inputs: Dictionary = recipe["inputs"] as Dictionary
	for item_id in inputs.keys():
		var needed := int(inputs[item_id])
		var owned := 0
		if state and "bank" in state and str(item_id) in state.bank:
			owned = int(state.bank[str(item_id)])
		if owned < needed:
			return false
	return true

## --- Start a recipe ---

func _start(recipe_id: String) -> void:
	_selected = recipe_id
	_update_active()
	var res := GameSession.start_activity("smithing", recipe_id)
	if not res["ok"]:
		EventBus.notification.emit(str(res["reason"]), "warning")

## --- Active ID ---

func _active_id() -> String:
	var state := GameSession.state
	if state != null and not state.activity.is_empty() and str(state.activity.get("type", "")) == "smithing":
		return str(state.activity.get("target", ""))
	return ""

## --- Highlight selection ---

func _highlight() -> void:
	var active := _active_id()
	var selected := _selected if _selected != "" else active
	for id in _rows:
		(_rows[id] as Button).set_active(id == selected)

## --- Update active workstation panel ---

func _update_active() -> void:
	var state := GameSession.state
	if state == null or state.activity.is_empty() or str(state.activity.get("type", "")) != "smithing":
		_active_name.text = "No active recipe"
		_active_info.text = "Select a recipe to begin."
		_active_bar.value = 0.0
		_rate_label.text = "-"
		# Clear centre and right zones
		_output_name.text = "Select a recipe"
		_output_tier.text = "Tier --"
		_input_flow.hide()
		_main_action.text = "Smelt"
		_action_reason.text = "Requires materials"
		_progress_container.visible = false
		_detail.visible = false
		_empty.visible = true
		_highlight()
		return

	var act: Dictionary = state.activity
	var recipe := ContentRegistry.get_recipe(str(act["target"]))

	# Centre zone: show selected recipe preview
	_output_name.text = str(recipe["name"])
	_output_tier.text = "Tier %d" % int(recipe["tier"])

	# Input flow
	_input_flow.cleanup()
	var inputs: Dictionary = recipe["inputs"] as Dictionary
	var output_ids: Array = (recipe["output"] as Dictionary).keys()
	var first_output_id := output_ids.is_empty() ? "" : str(output_ids[0])

	for item_id, count in inputs:
		var item_name := ContentRegistry.item_name(str(item_id))
		var hbox := HBoxContainer.new()
		hbox.layout_mode = 2
		hbox.theme_override_constants/separation = 2
		var icon_label := Label.new()
		icon_label.text = "%dx" % int(count)
		icon_label.theme_type_variation = &"Small"
		var item := ContentRegistry.get_item(str(item_id))
		if not item.is_empty():
			var category := str(item.get("category", ""))
			var bg_color := UiUtil.category_color(category)
			var border_color := UiUtil.rarity_color(str(item.get("rarity", "common")))
			var style := StyleBoxFlat.new()
			style.bg_color = bg_color
			style.set_corner_radius_all(3)
			style.border_color = border_color
			style.set_border_width_all(1)
			icon_label.add_theme_stylebox_override("panel", style)
		hbox.add_child(icon_label)
		_input_flow.add_child(hbox)

	# Show output icon prominently
	if not output_ids.is_empty():
		var output_icon_item := ContentRegistry.get_item(str(first_output_id))
		if not output_icon_item.is_empty():
			var category := str(output_icon_item.get("category", ""))
			var bg_color := UiUtil.category_color(category)
			var border_color := UiUtil.rarity_color(str(output_icon_item.get("rarity", "common")))
			var style := StyleBoxFlat.new()
			style.bg_color = bg_color
			style.set_corner_radius_all(5)
			style.border_color = border_color
			style.set_border_width_all(2)
			_output_icon.add_theme_stylebox_override("panel", style)
			var name_str := str(output_icon_item.get("name", "?"))
			_output_icon.text = name_str.substr(0, 2)
	else:
		_output_icon.text = "?"

	_input_flow.show()

	# Main action button
	var can_start := CraftingSystem.can_start(state, str(act["target"]))
	if can_start["ok"]:
		_main_action.text = "Smelt"
		_action_reason.text = ""
		_progress_container.visible = false
	else:
		_main_action.text = "Start"
		_action_reason.text = str(can_start["reason"])
		_progress_container.visible = false

	_active_name.text = str(recipe["name"])
	_active_bar.value = clampf(float(act["time"]) / maxf(0.001, float(act["duration"])), 0.0, 1.0)
	_active_info.text = "%.1fs per batch · %d XP" % [float(recipe["time"]), int(recipe["xp"])]
	_rate_label.text = "~%s batches/hr" % UiUtil.format_number(int(3600.0 / maxf(0.01, float(recipe["time"]))))

	# Right zone: detail panel
	_update_detail(str(act["target"]))

## --- Update detail panel ---

func _update_detail(recipe_id: String) -> void:
	var id := _selected if _selected != "" else recipe_id
	if id == "":
		_detail.visible = false
		_empty.visible = true
		return
	_detail.visible = true
	_empty.visible = false
	var recipe := ContentRegistry.get_recipe(id)
	_detail.show_detail(str(recipe["name"]), "Smithing recipe · Tier %d" % int(recipe["tier"]), "", [])

## --- Tab switching handler ---

func _on_tab_changed(index: int) -> void:
	# Rebuild lists with the appropriate category based on selected tab
	var tab_names := ["smelt", "alloys", "weapons", "armour", "off-hand", "tools"]
	var category := tab_names.get(index, "all")
	if _category_filter != category:
		_category_filter = category
		_build_lists()
	_update_active()

## --- Filter toggle changed ---

func _on_filter_toggled() -> void:
	_build_lists()
	_update_active()