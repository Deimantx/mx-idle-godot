extends Control

## Profile Select: create / play / delete up to three independent characters.

@onready var _list: VBoxContainer = %ProfileList
@onready var _name_input: LineEdit = %NameInput
@onready var _create_button: Button = %CreateButton
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_create_button.pressed.connect(_on_create)
	_name_input.text_submitted.connect(func(_t): _on_create())
	refresh()


func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var profiles := SaveService.list_profiles()
	if profiles.is_empty():
		var empty := Label.new()
		empty.text = "No characters yet. Create your first adventurer below."
		empty.theme_type_variation = &"Muted"
		_list.add_child(empty)
	for profile in profiles:
		_list.add_child(_build_row(profile))
	_create_button.disabled = not SaveService.has_free_slot()
	_status.text = "Slots used: %d / %d" % [profiles.size(), SaveService.MAX_PROFILES]


func _build_row(profile: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var play := Button.new()
	play.text = str(profile["name"])
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.custom_minimum_size = Vector2(0, 44)
	play.pressed.connect(func(): _play(str(profile["id"])))
	row.add_child(play)
	var del := Button.new()
	del.text = "Delete"
	del.theme_type_variation = &"DangerButton"
	del.pressed.connect(func(): _delete(str(profile["id"])))
	row.add_child(del)
	return row


func _play(id: String) -> void:
	if GameSession.load_character(id):
		get_tree().change_scene_to_file("res://scenes/shell/game_shell.tscn")


func _on_create() -> void:
	var chosen := _name_input.text.strip_edges()
	if chosen == "":
		chosen = "Adventurer"
	if not SaveService.has_free_slot():
		_status.text = "All three character slots are in use."
		return
	if GameSession.start_new_character(chosen):
		get_tree().change_scene_to_file("res://scenes/shell/game_shell.tscn")


func _delete(id: String) -> void:
	SaveService.delete_profile(id)
	refresh()