class_name ProgressRow
extends VBoxContainer

## Caption + value header over a progress bar. Used for XP, activity and
## encounter health readouts.

@export var caption_text: String = "":
	set(value):
		caption_text = value
		if is_node_ready():
			_caption.text = value
@export var bar_variation: StringName = &"":
	set(value):
		bar_variation = value
		if is_node_ready():
			_bar.theme_type_variation = value

@onready var _caption: Label = $Header/Caption
@onready var _value: Label = $Header/Value
@onready var _bar: ProgressBar = $Bar


func _ready() -> void:
	_caption.text = caption_text
	if bar_variation != &"":
		_bar.theme_type_variation = bar_variation


func configure(caption: String, value: float, maximum: float, value_text: String = "") -> void:
	caption_text = caption
	_caption.text = caption
	_bar.max_value = maxf(0.001, maximum)
	_bar.value = value
	_value.text = value_text
	_value.visible = value_text != ""


func set_bar(value: float, maximum: float = -1.0, value_text: String = "") -> void:
	if maximum >= 0.0:
		_bar.max_value = maxf(0.001, maximum)
	_bar.value = value
	if value_text != "" or _value.visible:
		_value.text = value_text


func set_fill_color(color: Color) -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = color
	flat.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("fill", flat)