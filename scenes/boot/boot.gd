extends Control

## Boot entry: applies device settings, then resumes the last character or
## sends the player to Profile Select. No gameplay logic lives here.


func _ready() -> void:
	SettingsService.apply_live()
	# Defer: the scene tree is still busy adding children during _ready.
	_start.call_deferred()


func _start() -> void:
	var index := SaveService.load_index()
	var last := str(index.get("last_profile", ""))
	if last != "" and GameSession.load_character(last):
		get_tree().change_scene_to_file("res://scenes/shell/game_shell.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/screens/profiles/profile_select.tscn")