extends Control

## Profile Select: create / play / delete up to three independent characters.
## Deletion is guarded by a confirmation dialog.

const SectionHeaderScene := preload("res://scenes/ui/components/SectionHeader.tscn")
const EmptyStateScene := preload("res://scenes/ui/components/EmptyState.tscn")

@onready var _list: VBoxContainer = %ProfileList
@onready var _name_input: LineEdit = %NameInput
@onready var _create_button: Button = %CreateButton
@onready var _status: Label = %StatusLabel
@onready var _dialog: ConfirmationDialog = %DeleteDialog

var _pending_delete: String = ""


func _ready() -> void:
	_create_button.pressed.connect(_on_create)
	_name_input.text_submitted.connect(func(_t): _on_create())
	_dialog.confirmed.connect(_confirm_delete)
	refresh()


func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var profiles := SaveService.list_profiles()
	if profiles.is_empty():
		var empty := EmptyStateScene.instantiate()
		_list.add_child(empty)
		empty.configure("No characters yet — create your first adventurer below.", "⚔")
	for profile in profiles:
		_list.add_child(_build_row(profile))
	_create_button.disabled = not SaveService.has_free_slot()
	_status.text = "Slots used: %d / %d" % [profiles.size(), SaveService.MAX_PROFILES]


func _build_row(profile: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.name = "Profile_" + str(profile["id"]).replace(".", "_")
	row.theme_type_variation = &"PanelFlat"

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	row.add_child(hbox)

	var name_label := Label.new()
	name_label.text = str(profile["name"])
	name_label.theme_type_variation = &"Subtitle"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	var play := Button.new()
	play.text = "Play"
	play.theme_type_variation = &"PrimaryButton"
	play.pressed.connect(func(): _play(str(profile["id"])))
	hbox.add_child(play)

	var del := Button.new()
	del.text = "Delete"
	del.theme_type_variation = &"DangerButton"
	del.pressed.connect(func(): _ask_delete(str(profile["id"]), str(profile["name"])))
	hbox.add_child(del)
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


func _ask_delete(id: String, profile_name: String) -> void:
	_pending_delete = id
	_dialog.dialog_text = "Delete \"%s\"? This cannot be undone." % profile_name
	_dialog.popup_centered()


func _confirm_delete() -> void:
	if _pending_delete == "":
		return
	SaveService.delete_profile(_pending_delete)
	_pending_delete = ""
	refresh()