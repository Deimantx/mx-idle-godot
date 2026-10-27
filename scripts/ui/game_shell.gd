extends Control

## The persistent game shell: left navigation, top bar, and a screen host that
## swaps between editable screen scenes. Screens own their own layout; the shell
## owns navigation and the shared status line.

const TOAST_SCENE := preload("res://scenes/ui/components/Toast.tscn")

const SCREEN_SCENES := {
	"home": "res://scenes/screens/home/home_screen.tscn",
	"mining": "res://scenes/screens/mining/mining_screen.tscn",
	"smithing": "res://scenes/screens/smithing/smithing_screen.tscn",
	"fishing": "res://scenes/screens/fishing/fishing_screen.tscn",
	"cooking": "res://scenes/screens/cooking/cooking_screen.tscn",
	"combat": "res://scenes/screens/combat/combat_screen.tscn",
	"bank": "res://scenes/screens/bank/bank_screen.tscn",
	"equipment": "res://scenes/screens/equipment/equipment_screen.tscn",
	"settings": "res://scenes/screens/settings/settings_screen.tscn",
}

const SCREEN_TITLES := {
	"home": "Home",
	"mining": "Mining",
	"smithing": "Smithing",
	"fishing": "Fishing",
	"cooking": "Cooking",
	"combat": "Combat",
	"bank": "Bank",
	"equipment": "Equipment",
	"settings": "Settings",
}

const SCREEN_SUBTITLES := {
	"home": "Every skill at a glance, and what you are doing right now",
	"mining": "Work the deposits for ore and Mining levels",
	"smithing": "Smelt ore into bars and forge tools, arms and armour",
	"fishing": "Cast for raw catches and the occasional rare find",
	"cooking": "Cook raw catches into food that sustains you in combat",
	"combat": "Fight enemies for loot, gold and combat levels",
	"bank": "Everything you have gathered and stored",
	"equipment": "Your loadout, and everything you own that can be equipped",
	"settings": "Display, audio and feedback preferences",
}

@onready var _host: MarginContainer = %ScreenHost
@onready var _title: Label = %ScreenTitle
@onready var _subtitle: Label = %ScreenSubtitle
@onready var _activity: StatusBadge = %ActivityBadge
@onready var _profile_label: Label = %ProfileLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _toast_list: VBoxContainer = %ToastList

var _screens: Dictionary = {}
var _nav_buttons: Dictionary = {}
var _current: String = ""


func _ready() -> void:
	for id in SCREEN_SCENES.keys():
		var scene: PackedScene = load(SCREEN_SCENES[id])
		var inst := scene.instantiate()
		inst.name = id
		inst.visible = false
		_host.add_child(inst)
		_screens[id] = inst

	_wire_nav()
	EventBus.state_changed.connect(_refresh_status)
	EventBus.activity_changed.connect(func(_a): _refresh_activity())
	EventBus.profile_loaded.connect(_refresh_status)
	EventBus.notification.connect(_toast)
	EventBus.offline_summary.connect(_on_offline_summary)
	_refresh_status()
	show_screen("home")


func _wire_nav() -> void:
	%NavHome.pressed.connect(func(): show_screen("home"))
	%NavMining.pressed.connect(func(): show_screen("mining"))
	%NavSmithing.pressed.connect(func(): show_screen("smithing"))
	%NavFishing.pressed.connect(func(): show_screen("fishing"))
	%NavCooking.pressed.connect(func(): show_screen("cooking"))
	%NavCombat.pressed.connect(func(): show_screen("combat"))
	%NavBank.pressed.connect(func(): show_screen("bank"))
	%NavEquipment.pressed.connect(func(): show_screen("equipment"))
	%NavSettings.pressed.connect(func(): show_screen("settings"))
	%NavCharacters.pressed.connect(_back_to_profiles)
	_nav_buttons = {
		"home": %NavHome, "mining": %NavMining, "smithing": %NavSmithing,
		"fishing": %NavFishing, "cooking": %NavCooking, "combat": %NavCombat,
		"bank": %NavBank, "equipment": %NavEquipment, "settings": %NavSettings,
	}
	for id in _nav_buttons:
		_nav_buttons[id].toggle_mode = true


func show_screen(id: String) -> void:
	if not _screens.has(id):
		return
	_current = id
	for key in _screens.keys():
		_screens[key].visible = (key == id)
	_title.text = str(SCREEN_TITLES.get(id, id))
	_subtitle.text = str(SCREEN_SUBTITLES.get(id, ""))
	for key in _nav_buttons.keys():
		_nav_buttons[key].button_pressed = (key == id)
	if _screens[id].has_method("refresh"):
		_screens[id].call("refresh")
	_refresh_status()


func _back_to_profiles() -> void:
	GameSession.unload()
	get_tree().change_scene_to_file("res://scenes/screens/profiles/profile_select.tscn")


func _refresh_status() -> void:
	var state := GameSession.state
	if state == null:
		return
	_profile_label.text = state.display_name
	_gold_label.text = "%s g" % UiUtil.format_number(state.gold)
	_refresh_activity()


func _refresh_activity() -> void:
	var active := GameSession.state != null and not GameSession.state.activity.is_empty()
	_activity.configure(_activity_text(), Color("d18a55") if active else Color("777c7e"))


func _activity_text() -> String:
	var state := GameSession.state
	if state == null or state.activity.is_empty():
		return "Idle"
	var act: Dictionary = state.activity
	var progress := 0.0
	if float(act.get("duration", 0.0)) > 0.0:
		progress = clampf(float(act.get("time", 0.0)) / float(act["duration"]), 0.0, 1.0)
	match str(act.get("type", "")):
		"mining":
			var deposit := ContentRegistry.get_deposit(str(act.get("target", "")))
			return "Mining %s · stage %d/5 · %d%%" % [
				str(deposit.get("name", "?")), int(act.get("stage", 0)) + 1, int(progress * 100.0)]
		"smithing":
			var recipe := ContentRegistry.get_recipe(str(act.get("target", "")))
			return "%s · %d%%" % [str(recipe.get("name", "?")), int(progress * 100.0)]
	return "Active"


# --- Notifications ----------------------------------------------------------
func _toast(text: String, kind: String = "info") -> void:
	if not SettingsService.notifications_enabled:
		return
	var toast: Control = TOAST_SCENE.instantiate()
	_toast_list.add_child(toast)
	toast.configure(text, kind)
	# Keep a short queue and fade out automatically.
	while _toast_list.get_child_count() > 5:
		_toast_list.get_child(0).free()
	var hold := 8.0 if text.length() > 120 else 5.0
	get_tree().create_timer(hold).timeout.connect(func():
		if is_instance_valid(toast):
			toast.queue_free())


func _on_offline_summary(summary: Dictionary) -> void:
	if int(summary.get("actions", 0)) <= 0:
		return
	var lines: Array = ["Welcome back — %s away." % UiUtil.format_time(float(summary.get("elapsed", 0)))]
	var items: Dictionary = summary.get("items", {})
	if not items.is_empty():
		var parts: Array = []
		for item_id in items.keys():
			parts.append("%s %s" % [UiUtil.format_number(int(items[item_id])), ContentRegistry.item_name(str(item_id))])
		lines.append("Gathered: " + ", ".join(parts))
	var xp: Dictionary = summary.get("xp", {})
	for skill in xp.keys():
		lines.append("+%s %s XP" % [UiUtil.format_number(int(xp[skill])), str(skill).capitalize()])
	var levels: Dictionary = summary.get("levels", {})
	for skill in levels.keys():
		for level in levels[skill]:
			lines.append("%s reached level %d!" % [str(skill).capitalize(), int(level)])
	if str(summary.get("stop_reason", "")) != "":
		lines.append("Stopped: " + str(summary["stop_reason"]))
	_toast("\n".join(lines), "success")