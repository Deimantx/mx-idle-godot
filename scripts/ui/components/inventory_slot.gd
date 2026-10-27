class_name InventorySlot
extends Button

## Reusable item slot for the bank grid and food slots. Shows a category-tinted
## tile with the item initials and a stack/count badge.

@onready var _tile: Panel = $Tile
@onready var _icon: Label = $Tile/Icon
@onready var _qty: Label = $Tile/Qty


func _ready() -> void:
	if _icon.text == "":
		_clear_tile()


func clear() -> void:
	_icon.text = ""
	_qty.text = ""
	_clear_tile()


func set_item(item_id: String, qty: int = 0) -> void:
	var item := ContentRegistry.get_item(item_id)
	if item.is_empty():
		clear()
		return
	var category := str(item.get("category", ""))
	var style := StyleBoxFlat.new()
	style.bg_color = UiUtil.category_color(category)
	style.set_corner_radius_all(6)
	style.border_color = UiUtil.rarity_color(str(item.get("rarity", "common")))
	style.set_border_width_all(2)
	_tile.add_theme_stylebox_override("panel", style)
	_icon.text = str(item.get("name", "?")).substr(0, 2)
	_qty.text = UiUtil.format_number(qty) if qty > 1 else ""
	tooltip_text = "%s  (T%d)" % [str(item.get("name", item_id)), int(item.get("tier", 0))]


func _clear_tile() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14171a")
	style.set_corner_radius_all(6)
	style.border_color = Color("2b3238")
	style.set_border_width_all(1)
	_tile.add_theme_stylebox_override("panel", style)