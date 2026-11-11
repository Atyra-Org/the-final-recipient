extends SceneTree
## Headless test runner: godot --headless --path . --script tests/test_save_system.gd
## Exit code 0 = all pass, 1 = failure.

const SaveSystemScript := preload("res://scripts/core/save_system.gd")
const EventBusScript := preload("res://scripts/core/event_bus.gd")

const TEST_SLOT := 99

var _failures := 0
var _checks := 0


func _initialize() -> void:
	print("=== the-final-recipient :: Task 3 & 4 test run ===")
	var bus := _event_bus()
	var saved_slots: Array[int] = []
	var loaded_slots: Array[int] = []
	bus.game_saved.connect(func(slot: int): saved_slots.append(slot))
	bus.game_loaded.connect(func(slot: int): loaded_slots.append(slot))

	_case_save(bus, saved_slots)
	_case_load(loaded_slots)
	_case_cleanup()

	print("=== %d checks, %d failed ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("  PASS  %s%s" % [label, (" :: " + detail) if detail else ""])
	else:
		_failures += 1
		print("  FAIL  %s%s" % [label, (" :: " + detail) if detail else ""])


func _event_bus() -> Node:
	var bus: Node = root.get_node_or_null("EventBus")
	if bus == null:
		bus = EventBusScript.new()
		root.add_child(bus)
	return bus


# --- Cases ------------------------------------------------------------------

var _mock := {
	"current_chapter": "chapter_02_the_unsent",
	"player_position": Vector2(312.5, -48.25),
	"unlocked_clues": ["clue_ledger", "clue_photograph", "clue_train_ticket"],
	"timeline_loop_count": 7,
}


func _case_save(bus: Node, saved_slots: Array[int]) -> void:
	print("[Case 1] save_game -> %s" % (SaveSystemScript.SLOT_PATH % TEST_SLOT))
	SaveSystemScript.delete_save(TEST_SLOT)
	_check("slot 99 absent before save", not SaveSystemScript.has_save(TEST_SLOT))

	var emitted: Array[Dictionary] = []
	bus.game_saved.connect(func(slot: int): emitted.append({"slot": slot}))
	var ok: bool = SaveSystemScript.save_game(TEST_SLOT, _mock)
	_check("save_game returned true", ok)
	_check("has_save true after save", SaveSystemScript.has_save(TEST_SLOT))
	_check("EventBus.game_saved emitted with slot 99",
		saved_slots.has(TEST_SLOT), str(saved_slots))

	var file := FileAccess.open(SaveSystemScript.SLOT_PATH % TEST_SLOT, FileAccess.READ)
	var raw := file.get_as_text() if file else ""
	if file:
		file.close()
	var parsed: Variant = JSON.parse_string(raw)
	_check("file body is valid JSON dictionary", typeof(parsed) == TYPE_DICTIONARY)
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = parsed
		_check("timestamp is int epoch", typeof(d.get("timestamp")) == TYPE_FLOAT and int(d["timestamp"]) > 0,
			str(d.get("timestamp")))
		_check("player_position serialized as {x,y} dict",
			typeof(d.get("player_position")) == TYPE_DICTIONARY and is_equal_approx(d["player_position"]["x"], 312.5)
			and is_equal_approx(d["player_position"]["y"], -48.25), str(d.get("player_position")))
		_check("unlocked_clues serialized as JSON array", d.get("unlocked_clues") is Array,
			str(d.get("unlocked_clues")))
		_check("schema_version present", int(d.get("schema_version", 0)) == SaveSystemScript.SCHEMA_VERSION)


func _case_load(loaded_slots: Array[int]) -> void:
	print("[Case 2] load_game -> deep field equality")
	var data: Dictionary = SaveSystemScript.load_game(TEST_SLOT)
	_check("load returned non-empty dictionary", not data.is_empty(), str(data.keys()))
	_check("EventBus.game_loaded emitted with slot 99", loaded_slots.has(TEST_SLOT), str(loaded_slots))

	_check("current_chapter round-trips",
		data.get("current_chapter") == _mock["current_chapter"], str(data.get("current_chapter")))

	var pos: Variant = data.get("player_position")
	_check("player_position is Vector2", pos is Vector2, str(typeof(pos)))
	_check("player_position round-trips exactly",
		pos is Vector2 and pos.is_equal_approx(_mock["player_position"]), str(pos))

	var clues: Variant = data.get("unlocked_clues")
	_check("unlocked_clues round-trips as ordered Array[String]",
		clues is Array and clues == _mock["unlocked_clues"], str(clues))

	_check("timeline_loop_count round-trips as int",
		typeof(data.get("timeline_loop_count")) == TYPE_INT
		and data["timeline_loop_count"] == _mock["timeline_loop_count"], str(data.get("timeline_loop_count")))

	# Guard: a missing slot must not fabricate data.
	_check("load_game on absent slot returns empty", SaveSystemScript.load_game(TEST_SLOT + 5).is_empty())


func _case_cleanup() -> void:
	print("[Case 3] delete_save -> cleanup")
	var ok: bool = SaveSystemScript.delete_save(TEST_SLOT)
	_check("delete_save returned true", ok)
	_check("has_save false after delete", not SaveSystemScript.has_save(TEST_SLOT))
	_check("no file left on disk", not FileAccess.file_exists(SaveSystemScript.SLOT_PATH % TEST_SLOT))
	_check("second delete returns false (idempotent)", not SaveSystemScript.delete_save(TEST_SLOT))
	_check("negative slot rejected gracefully", not SaveSystemScript.save_game(-1, {}))