class_name ListEntry
extends Button

## Reusable selectable row used by every list screen (deposits, spots, recipes,
## enemies, bank, equipment). Icon, title, subtitle and two right-hand slots are
## all editable in the Inspector; screens fill them via configure().

## Node references are resolved lazily (not via @onready) so a screen may
## configure a row either before or after adding it to the tree.
var _icon_box: PanelContainer
var _icon_label: Label
var _title: Label
var _sub: Label
var _right_top: Label
var _right_sub: Label


func _ready() -> void:
	_resolve()


func _resolve() -> void:
	if _title != null:
		return
	_icon_box = get_node_or_null("Margin/Row/IconBox")
	_icon_label = get_node_or_null("Margin/Row/IconBox/Center/IconLabel")
	_title = get_node_or_null("Margin/Row/Text/Title")
	_sub = get_node_or_null("Margin/Row/Text/Subtitle")
	_right_top = get_node_or_null("Margin/Row/Right/RightTop")
	_right_sub = get_node_or_null("Margin/Row/Right/RightSub")


func configure(title: String, subtitle: String = "", right_top: String = "", right_sub: String = "") -> void:
	_resolve()
	_title.text = title
	_sub.text = subtitle
	_sub.visible = subtitle != ""
	_right_top.text = right_top
	_right_top.visible = right_top != ""
	_right_sub.text = right_sub
	_right_sub.visible = right_sub != ""


func set_icon(letter: String, bg: Color, border: Color) -> void:
	_resolve()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(5)
	style.border_color = border
	style.set_border_width_all(2)
	_icon_box.add_theme_stylebox_override("panel", style)
	_icon_label.text = letter
	_icon_box.visible = true


func set_icon_item(item_id: String) -> void:
	_resolve()
	var item := ContentRegistry.get_item(item_id)
	if item.is_empty():
		_icon_box.visible = false
		return
	var category := str(item.get("category", ""))
	var name_str := str(item.get("name", "?"))
	set_icon(name_str.substr(0, 2), UiUtil.category_color(category), UiUtil.rarity_color(str(item.get("rarity", "common"))))


func hide_icon() -> void:
	_resolve()
	_icon_box.visible = false


func set_title_color(color: Color) -> void:
	_resolve()
	_title.add_theme_color_override("font_color", color)


func set_sub_color(color: Color) -> void:
	_resolve()
	_sub.add_theme_color_override("font_color", color)


func set_right_top(label_text: String, color: Color = Color(0, 0, 0, 0)) -> void:
	_resolve()
	_right_top.text = label_text
	_right_top.visible = label_text != ""
	if color.a > 0.0:
		_right_top.add_theme_color_override("font_color", color)


func set_right_sub(label_text: String, color: Color = Color(0, 0, 0, 0)) -> void:
	_resolve()
	_right_sub.text = label_text
	_right_sub.visible = label_text != ""
	if color.a > 0.0:
		_right_sub.add_theme_color_override("font_color", color)


## Number of tinted badges is fixed in the scene; this toggles the row highlight
## for currently-active entries without extra nodes.
func set_active(active: bool) -> void:
	if active:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("22303c")
		style.border_color = Color("d18a55")
		style.border_width_left = 3
		style.set_corner_radius_all(6)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		add_theme_stylebox_override("normal", style)
	else:
		remove_theme_stylebox_override("normal")