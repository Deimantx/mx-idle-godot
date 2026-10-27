extends Control

const ListEntryScene := preload("res://scenes/ui/components/ListEntry.tscn")

func _ready() -> void:
	for recipe in ContentRegistry.recipes_for("smithing"):
		var entry := ListEntryScene.instantiate()
		SmeltList.add_child(entry)
		entry.configure(recipe["name"], "Lv %d · %.1fs/batch" % [int(recipe["level"]), float(recipe["time"])], "T%d" % int(recipe["tier"]))