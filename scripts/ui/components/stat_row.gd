class_name StatRow
extends HBoxContainer

## Compact key/value line used in skill lists, loadouts and item details.

@export var caption_text: String = "Label":
	set(value):
		caption_text = value
		if is_node_ready():
			_caption.text = value
@export var value_text: String = "":
	set(value):
		value_text = value
		if is_node_ready():
			_value.text = value
@export var caption_width: float = 132.0:
	set(value):
		caption_width = value
		if is_node_ready():
			_caption.custom_minimum_size.x = value

@onready var _caption: Label = $Caption
@onready var _value: Label = $Value


func _ready() -> void:
	_caption.text = caption_text
	_value.text = value_text
	_caption.custom_minimum_size.x = caption_width


func configure(caption: String, value: String) -> void:
	caption_text = caption
	value_text = value
	_caption.text = caption
	_value.text = value


func set_value(text: String, color: Color = Color(0, 0, 0, 0)) -> void:
	value_text = text
	_value.text = text
	if color.a > 0.0:
		_value.add_theme_color_override("font_color", color)