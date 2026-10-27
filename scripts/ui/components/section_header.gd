class_name SectionHeader
extends HBoxContainer

## Reusable section heading: bold title on the left, a muted hint on the right.
## Layout and text are editable in the Inspector; screens may also call
## configure() at runtime.

@export var title_text: String = "Section":
	set(value):
		title_text = value
		if is_node_ready():
			_title.text = value
@export var hint_text: String = "":
	set(value):
		hint_text = value
		if is_node_ready():
			_hint.text = value
			_hint.visible = value != ""
@export var title_color: Color = Color(0, 0, 0, 0):
	set(value):
		title_color = value
		if is_node_ready() and value.a > 0.0:
			_title.add_theme_color_override("font_color", value)

@onready var _title: Label = $Title
@onready var _hint: Label = $Hint


func _ready() -> void:
	_title.text = title_text
	_hint.text = hint_text
	_hint.visible = hint_text != ""
	if title_color.a > 0.0:
		_title.add_theme_color_override("font_color", title_color)


func configure(title: String, hint: String = "") -> void:
	title_text = title
	hint_text = hint
	_title.text = title
	_hint.text = hint
	_hint.visible = hint != ""


func set_hint(text: String) -> void:
	hint_text = text
	_hint.text = text
	_hint.visible = text != ""