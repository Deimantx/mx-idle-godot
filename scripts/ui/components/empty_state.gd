class_name EmptyState
extends VBoxContainer

## Centred placeholder for empty / locked / no-data panels, so those states read
## as intentional instead of blank space.

@export var message: String = "Nothing here yet.":
	set(value):
		message = value
		if is_node_ready():
			_label.text = value
@export var glyph: String = "—":
	set(value):
		glyph = value
		if is_node_ready():
			_glyph.text = value

@onready var _glyph: Label = $Glyph
@onready var _label: Label = $Message


func _ready() -> void:
	_glyph.text = glyph
	_label.text = message


func configure(text: String, icon: String = "—") -> void:
	message = text
	glyph = icon
	_glyph.text = icon
	_label.text = text