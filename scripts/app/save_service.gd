extends Node

## Persistence: separate profile index, per-character saves and atomic writes.

const SAVE_DIR := "user://saves"
const INDEX_PATH := "user://saves/index.json"
const MAX_PROFILES := 3


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _profile_path(id: String) -> String:
	return SAVE_DIR + "/profile_%s.json" % id


# --- Profile index ----------------------------------------------------------
func load_index() -> Dictionary:
	if not FileAccess.file_exists(INDEX_PATH):
		return {"profiles": [], "last_profile": ""}
	var parsed: Variant = _read_json(INDEX_PATH)
	if parsed is Dictionary:
		var idx := parsed as Dictionary
		if not idx.has("profiles") or not (idx["profiles"] is Array):
			idx["profiles"] = []
		if not idx.has("last_profile"):
			idx["last_profile"] = ""
		return idx
	return {"profiles": [], "last_profile": ""}


func save_index(index: Dictionary) -> void:
	_write_json(INDEX_PATH, index)


func list_profiles() -> Array:
	return load_index().get("profiles", [])


func has_free_slot() -> bool:
	return list_profiles().size() < MAX_PROFILES


func create_profile(profile_name: String) -> String:
	var index := load_index()
	var profiles: Array = index["profiles"]
	if profiles.size() >= MAX_PROFILES:
		return ""
	var id := "p%d_%d" % [profiles.size() + 1, int(Time.get_unix_time_from_system())]
	var state := CharacterState.new()
	state.new_profile(id, profile_name)
	write_profile(state)
	profiles.append({
		"id": id,
		"name": profile_name,
		"created": state.created_unix,
	})
	index["profiles"] = profiles
	index["last_profile"] = id
	save_index(index)
	return id


func rename_profile(id: String, new_name: String) -> void:
	var index := load_index()
	var profiles: Array = index["profiles"]
	for p in profiles:
		if str(p["id"]) == id:
			p["name"] = new_name
	index["profiles"] = profiles
	save_index(index)
	var state := read_profile(id)
	if state != null:
		state.display_name = new_name
		write_profile(state)


func delete_profile(id: String) -> void:
	var index := load_index()
	var profiles: Array = index["profiles"]
	var kept: Array = []
	for p in profiles:
		if str(p["id"]) != id:
			kept.append(p)
	index["profiles"] = kept
	if str(index.get("last_profile", "")) == id:
		index["last_profile"] = str(kept[0]["id"]) if kept.size() > 0 else ""
	save_index(index)
	var path := _profile_path(id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func set_last_profile(id: String) -> void:
	var index := load_index()
	index["last_profile"] = id
	save_index(index)


# --- Character saves --------------------------------------------------------
func read_profile(id: String) -> CharacterState:
	var path := _profile_path(id)
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = _read_json(path)
	if not (parsed is Dictionary):
		return null
	var state := CharacterState.new()
	state.from_dict(parsed as Dictionary)
	if state.profile_id == "":
		state.profile_id = id
	return state


func write_profile(state: CharacterState) -> void:
	state.last_saved_unix = int(Time.get_unix_time_from_system())
	var path := _profile_path(state.profile_id)
	var tmp := path + ".tmp"
	_write_json(tmp, state.to_dict())
	# Atomic-ish replace: validate the temp file then move it over the target.
	if _read_json(tmp) is Dictionary:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		DirAccess.rename_absolute(tmp, path)


# --- Helpers ----------------------------------------------------------------
func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot write " + path)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()