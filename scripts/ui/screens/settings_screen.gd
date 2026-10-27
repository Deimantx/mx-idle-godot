extends Control

## Settings: device-wide options persisted by SettingsService (not part of a
## character save). Each section is a reusable SectionHeader.

const SectionHeaderScene := preload("res://scenes/ui/components/SectionHeader.tscn")

@onready var _box: VBoxContainer = %SettingsBox


func _ready() -> void:
	_build()


func refresh() -> void:
	_build()


func _build() -> void:
	for child in _box.get_children():
		child.queue_free()

	_section("Display", "Applies instantly")
	_box.add_child(_slider("Game Scale", SettingsService.ui_scale, 0.75, 2.0, 0.05,
		func(v): SettingsService.ui_scale = v; SettingsService.save_settings()))
	_box.add_child(_slider("Text Size", SettingsService.text_scale, 0.75, 2.0, 0.05,
		func(v): SettingsService.text_scale = v; SettingsService.save_settings()))

	_section("Audio", "Volume of the master and future buses")
	_box.add_child(_slider("Master Volume", SettingsService.master_volume, 0.0, 1.0, 0.05,
		func(v): SettingsService.master_volume = v; SettingsService.save_settings()))
	_box.add_child(_slider("Music Volume", SettingsService.music_volume, 0.0, 1.0, 0.05,
		func(v): SettingsService.music_volume = v; SettingsService.save_settings()))
	_box.add_child(_slider("SFX Volume", SettingsService.sfx_volume, 0.0, 1.0, 0.05,
		func(v): SettingsService.sfx_volume = v; SettingsService.save_settings()))

	_section("Accessibility & Feedback")
	_box.add_child(_check("Reduced motion", SettingsService.reduced_motion,
		func(v): SettingsService.reduced_motion = v; SettingsService.save_settings()))
	_box.add_child(_check("Enable tooltips", SettingsService.tooltips_enabled,
		func(v): SettingsService.tooltips_enabled = v; SettingsService.save_settings()))
	_box.add_child(_check("Show notifications", SettingsService.notifications_enabled,
		func(v): SettingsService.notifications_enabled = v; SettingsService.save_settings()))

	_section("Gameplay")
	var note := Label.new()
	note.text = "Auto Eat and Auto Combat are configured on the Combat screen. Each character keeps its own progress and save."
	note.theme_type_variation = &"Muted"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(note)


func _section(title: String, hint: String = "") -> void:
	var header := SectionHeaderScene.instantiate()
	_box.add_child(header)
	header.configure(title, hint)


func _slider(label_text: String, value: float, min_value: float, max_value: float, step: float, setter: Callable) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(240, 0)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(70, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.theme_type_variation = &"StatValue"
	value_label.text = "%.2f" % value
	row.add_child(value_label)

	slider.value_changed.connect(func(v):
		value_label.text = "%.2f" % v
		setter.call(v))
	return row


func _check(label_text: String, value: bool, setter: Callable) -> Control:
	var row := HBoxContainer.new()
	var checkbox := CheckButton.new()
	checkbox.button_pressed = value
	row.add_child(checkbox)
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	checkbox.toggled.connect(func(pressed): setter.call(pressed))
	return row