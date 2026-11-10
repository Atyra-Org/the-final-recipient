class_name SaveSystem
extends RefCounted
## Agnostic JSON save/load (one file per slot under `user://`).
## Static API — usable without an autoload. Emits `EventBus.game_saved` / `game_loaded`
## when the EventBus autoload is present in the tree (silently no-ops otherwise).

const SLOT_PATH := "user://save_slot_%d.json"
const SCHEMA_VERSION := 1


static func save_game(slot: int, custom_data: Dictionary = {}) -> bool:
	var path := _path(slot)
	if path.is_empty():
		push_error("SaveSystem: invalid slot %d" % slot)
		return false

	var data := {
		"schema_version": SCHEMA_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"current_chapter": "chapter_01",
		"player_position": {"x": 0.0, "y": 0.0},
		"unlocked_clues": [] as Array[String],
		"timeline_loop_count": 0,
	}
	for key in custom_data:
		data[key] = _to_json_value(custom_data[key])

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot open %s for write (err %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	_emit("game_saved", slot)
	return true


static func load_game(slot: int) -> Dictionary:
	var path := _path(slot)
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: cannot open %s for read (err %d)" % [path, FileAccess.get_open_error()])
		return {}
	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: corrupt save in %s" % path)
		return {}

	var data: Dictionary = parsed
	var position_changed: Variant = data.get("player_position", {})
	if typeof(position_changed) == TYPE_DICTIONARY:
		data["player_position"] = Vector2(
			float(position_changed.get("x", 0.0)), float(position_changed.get("y", 0.0))
		)
	data["unlocked_clues"] = _to_string_array(data.get("unlocked_clues", []))
	data["timeline_loop_count"] = int(data.get("timeline_loop_count", 0))
	data["timestamp"] = int(data.get("timestamp", 0))
	data["current_chapter"] = str(data.get("current_chapter", ""))

	_emit("game_loaded", slot)
	return data


static func has_save(slot: int) -> bool:
	var path := _path(slot)
	return not path.is_empty() and FileAccess.file_exists(path)


static func delete_save(slot: int) -> bool:
	var path := _path(slot)
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		push_error("SaveSystem: cannot delete %s (err %d)" % [path, err])
		return false
	return true


# --- Internals ------------------------------------------------------------

static func _path(slot: int) -> String:
	if slot < 0:
		return ""
	return SLOT_PATH % slot


static func _to_json_value(value: Variant) -> Variant:
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_to_json_value(item))
		return out
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[key] = _to_json_value(value[key])
		return out
	return value


static func _to_string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item in value:
			out.append(str(item))
	return out


static func _emit(signal_name: String, slot: int) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var bus := loop.root.get_node_or_null("EventBus")
	if bus != null and bus.has_signal(signal_name):
		bus.emit_signal(signal_name, slot)