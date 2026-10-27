class_name Toast
extends PanelContainer

## A single notification card. Left colour bar encodes the kind; body text
## wraps. The shell instantiates these from the shared notification area.

@onready var _message: Label = $Margin/Row/Message
@onready var _kind: Label = $Margin/Row/Kind


func configure(text: String, kind: String = "info") -> void:
	_message.text = text
	var color := _color_for(kind)
	_kind.text = _glyph_for(kind)
	_kind.add_theme_color_override("font_color", color)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b2026")
	style.border_color = color
	style.border_width_left = 3
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	add_theme_stylebox_override("panel", style)


func _color_for(kind: String) -> Color:
	match kind:
		"warning":
			return Color("d28b65")
		"error":
			return Color("b86d65")
		"success":
			return Color("7ea982")
		_:
			return Color("d18a55")


func _glyph_for(kind: String) -> String:
	match kind:
		"warning":
			return "!"
		"error":
			return "×"
		"success":
			return "+"
		_:
			return "•"