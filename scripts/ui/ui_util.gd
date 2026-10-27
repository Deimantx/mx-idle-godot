class_name UiUtil
extends RefCounted

## Presentation helpers shared by screens. No game rules live here.

const RARITY_COLORS := {
	"common": Color("9fb0c0"),
	"uncommon": Color("5bd98a"),
	"rare": Color("4fb3d9"),
	"epic": Color("b07fe0"),
}


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS["common"])


static func category_color(category: String) -> Color:
	match category:
		"ore":
			return Color("7d6f5c")
		"bar":
			return Color("c8a24a")
		"tool":
			return Color("5f86a8")
		"weapon":
			return Color("a8654f")
		"armor":
			return Color("7d879b")
		_:
			return Color("5a6473")


static func format_number(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


static func format_time(seconds: float) -> String:
	if seconds < 0.0:
		return "-"
	var total := int(round(seconds))
	var h := int(total / 3600.0)
	var m := int((total % 3600) / 60.0)
	var s := total % 60
	if h > 0:
		return "%dh %dm" % [h, m]
	if m > 0:
		return "%dm %ds" % [m, s]
	return "%ds" % s


## A compact, colour-coded item icon built from Control nodes (no baked art
## required yet). A designer can replace this with a real ItemIcon scene later.
static func make_icon(item_id: String, size: int = 34) -> Control:
	var item := ContentRegistry.get_item(item_id)
	var category := str(item.get("category", ""))
	var letter := str(item.get("name", "?")).substr(0, 2)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(size, size)
	var style := StyleBoxFlat.new()
	style.bg_color = category_color(category)
	style.set_corner_radius_all(5)
	style.border_color = rarity_color(str(item.get("rarity", "common")))
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


static func skill_display_name(skill: String) -> String:
	return skill.capitalize()