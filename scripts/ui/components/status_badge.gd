class_name StatusBadge
extends PanelContainer

## Small tinted pill for tier, rank, rarity and state labels.

@onready var _label: Label = $Label


func _ready() -> void:
	if _label.text == "":
		visible = false


func configure(text: String, color: Color) -> void:
	_label.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.15)
	style.border_color = Color(color.r, color.g, color.b, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	add_theme_stylebox_override("panel", style)
	_label.add_theme_color_override("font_color", color)
	visible = text != ""