class_name ItemDetail
extends PanelContainer

## Item / target detail surface: title, meta line, description and a dynamic
## stat list. Used as the right-hand detail panel on list screens.

const StatRowScene := preload("res://scenes/ui/components/StatRow.tscn")

@onready var _title: Label = $VBox/Title
@onready var _meta: Label = $VBox/Meta
@onready var _desc: Label = $VBox/Desc
@onready var _stats: VBoxContainer = $VBox/Stats
@onready var _empty: Label = $VBox/Empty


func _ready() -> void:
	_clear()


func _clear() -> void:
	_title.text = ""
	_meta.text = ""
	_desc.text = ""
	for child in _stats.get_children():
		child.queue_free()
	_empty.visible = true


## Show a full item definition by id.
func show_item(item_id: String) -> void:
	var item := ContentRegistry.get_item(item_id)
	if item.is_empty():
		show_message("Unknown item", item_id)
		return
	_title.text = str(item.get("name", item_id))
	_title.add_theme_color_override("font_color", UiUtil.rarity_color(str(item.get("rarity", "common"))))
	_meta.text = "Tier %d · %s" % [int(item.get("tier", 0)), str(item.get("rarity", "common")).capitalize()]
	_desc.text = str(item.get("description", ""))
	_clear_stats()
	_empty.visible = false
	var slot := str(item.get("equip_slot", ""))
	if slot != "":
		_add_stat("Equip slot", slot.capitalize())
	for key in (item.get("stats", {}) as Dictionary).keys():
		_add_stat(str(key).capitalize(), str(item["stats"][key]))
	if int(item.get("value", 0)) > 0:
		_add_stat("Value", "%s g" % UiUtil.format_number(int(item["value"])))


## Generic text detail used when no item definition is involved (recipes,
## targets, enemies). `lines` is an array of "Label|Value" or plain strings.
func show_detail(title: String, meta: String, description: String, lines: Array = []) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", Color("e7e2da"))
	_meta.text = meta
	_desc.text = description
	_clear_stats()
	_empty.visible = lines.is_empty() and description == ""
	for line in lines:
		var parts := str(line).split("|", true, 1)
		if parts.size() == 2:
			_add_stat(parts[0], parts[1])
		else:
			_add_stat("", str(line))


## Append one extra stat line to the currently shown detail.
func add_stat(caption: String, value: String) -> void:
	_empty.visible = false
	_add_stat(caption, value)


func show_message(title: String, body: String) -> void:
	_title.text = title
	_meta.text = ""
	_desc.text = body
	_clear_stats()
	_empty.visible = false


func _clear_stats() -> void:
	for child in _stats.get_children():
		child.queue_free()


func _add_stat(caption: String, value: String) -> void:
	var row := StatRowScene.instantiate()
	_stats.add_child(row)
	row.configure(caption, value)