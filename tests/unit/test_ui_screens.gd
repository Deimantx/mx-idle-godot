extends Node

## UI wiring tests: each redesigned screen is instantiated, given a known
## character state, and driven through its real selection path. These assert the
## detail panels and lists respond to the same signals the player uses.

const BANK_SCENE := preload("res://scenes/screens/bank/bank_screen.tscn")
const MINING_SCENE := preload("res://scenes/screens/mining/mining_screen.tscn")
const SMITHING_SCENE := preload("res://scenes/screens/smithing/smithing_screen.tscn")
const FISHING_SCENE := preload("res://scenes/screens/fishing/fishing_screen.tscn")
const COOKING_SCENE := preload("res://scenes/screens/cooking/cooking_screen.tscn")
const COMBAT_SCENE := preload("res://scenes/screens/combat/combat_screen.tscn")
const EQUIPMENT_SCENE := preload("res://scenes/screens/equipment/equipment_screen.tscn")
const HOME_SCENE := preload("res://scenes/screens/home/home_screen.tscn")

var _prev_state: CharacterState = null


func _make_state() -> CharacterState:
	var s := CharacterState.new()
	s.new_profile("test_profile", "Tester")
	s.bank["item.bar.bronze"] = 5
	s.bank["item.ore.copper"] = 12
	s.bank["item.tool.pickaxe.bronze"] = 1
	s.bank["item.food.shrimp"] = 3
	return s


func _set_state() -> void:
	_prev_state = GameSession.state
	GameSession.state = _make_state()


func _restore_state() -> void:
	GameSession.state = _prev_state


func _mount(scene: PackedScene) -> Control:
	var inst: Control = scene.instantiate()
	add_child(inst)
	return inst


func test_bank_slot_selection_shows_detail() -> void:
	_set_state()
	var screen := _mount(BANK_SCENE)
	var grid: GridContainer = screen.get_node("%ItemGrid")
	assert(grid.get_child_count() == 4, "bank grid should list 4 stacks")
	var pickaxe := grid.get_node_or_null("Slot_item_tool_pickaxe_bronze")
	assert(pickaxe != null, "pickaxe slot should exist")
	pickaxe.pressed.emit()
	var detail: Control = screen.get_node("%ItemDetailView")
	var action: Button = screen.get_node("%ActionButton")
	assert(detail.visible, "selecting a slot shows the item detail")
	assert(action.visible, "equippable item shows an action button")
	assert(action.text == "Equip", "action label should be Equip")
	screen.queue_free()
	_restore_state()


func test_mining_deposit_selection_shows_detail() -> void:
	_set_state()
	var screen := _mount(MINING_SCENE)
	var list: VBoxContainer = screen.get_node("%DepositList")
	assert(list.get_child_count() > 0, "deposits should be listed")
	list.get_child(0).pressed.emit()
	assert((screen.get_node("%DepositDetail") as Control).visible, "deposit detail shows")
	screen.queue_free()
	_restore_state()


func test_smithing_locked_recipe_shows_detail() -> void:
	_set_state()
	var screen := _mount(SMITHING_SCENE)
	var list: VBoxContainer = screen.get_node("%SmeltList")
	assert(list.get_child_count() > 0, "smelt recipes should be listed")
	list.get_child(1).pressed.emit()
	assert((screen.get_node("%RecipeDetail") as Control).visible, "a locked recipe can still be inspected")
	screen.queue_free()
	_restore_state()


func test_fishing_spot_selection_shows_detail() -> void:
	_set_state()
	var screen := _mount(FISHING_SCENE)
	var list: VBoxContainer = screen.get_node("%SpotList")
	assert(list.get_child_count() > 0, "spots should be listed")
	list.get_child(0).pressed.emit()
	assert((screen.get_node("%SpotDetail") as Control).visible, "spot detail shows")
	screen.queue_free()
	_restore_state()


func test_cooking_recipe_selection_shows_detail() -> void:
	_set_state()
	var screen := _mount(COOKING_SCENE)
	var list: VBoxContainer = screen.get_node("%RecipeList")
	assert(list.get_child_count() > 0, "cooking recipes should be listed")
	list.get_child(0).pressed.emit()
	assert((screen.get_node("%RecipeDetail") as Control).visible, "recipe detail shows")
	screen.queue_free()
	_restore_state()


func test_combat_enemy_selection_shows_detail() -> void:
	_set_state()
	var screen := _mount(COMBAT_SCENE)
	var list: VBoxContainer = screen.get_node("%EnemyList")
	assert(list.get_child_count() > 0, "enemies should be listed")
	list.get_child(0).pressed.emit()
	assert((screen.get_node("%EnemyDetail") as Control).visible, "enemy detail shows")
	screen.queue_free()
	_restore_state()


func test_equipment_lists_slots_and_candidates() -> void:
	_set_state()
	var screen := _mount(EQUIPMENT_SCENE)
	var slots: VBoxContainer = screen.get_node("%SlotList")
	var candidates: VBoxContainer = screen.get_node("%EquipList")
	assert(slots.get_child_count() == CharacterState.SLOTS.size(), "every equipment slot is listed")
	assert(candidates.get_child_count() >= 1, "equippable bank items are listed")
	screen.queue_free()
	_restore_state()


func test_home_lists_every_skill() -> void:
	_set_state()
	var screen := _mount(HOME_SCENE)
	var list: VBoxContainer = screen.get_node("%SkillList")
	assert(list.get_child_count() == CharacterState.SKILLS.size(), "home lists every skill")
	screen.queue_free()
	_restore_state()