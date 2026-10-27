extends Node

## Device-wide settings. Persisted separately from character profiles.

const SETTINGS_PATH := "user://settings.json"
const THEME_PATH := "res://resources/themes/main_theme.tres"

var ui_scale: float = 1.0
var text_scale: float = 1.0
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var reduced_motion: bool = false
var tooltips_enabled: bool = true
var notifications_enabled: bool = true


func _ready() -> void:
	load_settings()


func apply_from_dict(data: Dictionary) -> void:
	ui_scale = clampf(float(data.get("ui_scale", ui_scale)), 0.75, 2.0)
	text_scale = clampf(float(data.get("text_scale", text_scale)), 0.75, 2.0)
	master_volume = clampf(float(data.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	reduced_motion = bool(data.get("reduced_motion", reduced_motion))
	tooltips_enabled = bool(data.get("tooltips_enabled", tooltips_enabled))
	notifications_enabled = bool(data.get("notifications_enabled", notifications_enabled))


func to_dict() -> Dictionary:
	return {
		"ui_scale": ui_scale,
		"text_scale": text_scale,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"reduced_motion": reduced_motion,
		"tooltips_enabled": tooltips_enabled,
		"notifications_enabled": notifications_enabled,
	}


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		apply_from_dict(parsed as Dictionary)
	apply_live()


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(to_dict(), "  "))
	file.close()
	apply_live()


func apply_live() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master_volume, 0.0001, 1.0)))
	# Game scale: scale the whole viewport.
	var window := get_window()
	if window != null:
		window.content_scale_factor = clampf(ui_scale, 0.75, 2.0)
	# Text size: scale the shared project theme's default font.
	var theme := load(THEME_PATH)
	if theme is Theme:
		(theme as Theme).default_font_size = int(round(15.0 * clampf(text_scale, 0.75, 2.0)))