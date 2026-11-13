extends SceneTree
## Headless test runner: godot --headless --path . --script tests/test_inventory_system.gd
## Exit code 0 = all pass, 1 = failure.

const ItemDataScript := preload("res://scripts/resources/item_data.gd")
const InventoryManagerScript := preload("res://scripts/core/inventory_manager.gd")
const EventBusScript := preload("res://scripts/core/event_bus.gd")

const MANAGER_CAPACITY := 16
const NARROW_CAPACITY := 1

var _failures: int = 0
var _checks: int = 0
var _bus: Node = null
var _inv: InventoryManager = null
var _events: Array[Dictionary] = []


func _initialize() -> void:
	print("=== the-final-recipient :: Inventory & Item System tests ===")
	_bus = _event_bus()
	_bus.item_added.connect(_on_item_added)
	_bus.item_removed.connect(_on_item_removed)
	_bus.inventory_updated.connect(_on_inventory_updated)

	_case_item_data_dict()
	_case_unique_items()
	_case_stack_and_overflow()
	_case_remove()
	_case_serialization()

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
		bus.name = "EventBus"
		root.add_child(bus)
	return bus


func _on_item_added(item_id: String, quantity: int) -> void:
	_events.append({"type": "item_added", "item_id": item_id, "quantity": quantity})

func _on_item_removed(item_id: String, quantity: int) -> void:
	_events.append({"type": "item_removed", "item_id": item_id, "quantity": quantity})

func _on_inventory_updated() -> void:
	_events.append({"type": "inventory_updated"})


func _new_item(id: String, name: String, type: ItemData.ItemType, stackable: bool = false, max_stack: int = 1) -> ItemData:
	var item: ItemData = ItemDataScript.new(id, name, "%s description." % name)
	item.item_type = type
	item.is_stackable = stackable
	item.max_stack_size = max_stack
	return item


func _has_event(expected_type: String, expected_id: String, expected_qty: int) -> bool:
	for e in _events:
		if e.get("type") != expected_type:
			continue
		if expected_type == "inventory_updated":
			return true
		if e.get("item_id") == expected_id and e.get("quantity") == expected_qty:
			return true
	return false


# --- Case 0: data serialization ------------------------------------------

func _case_item_data_dict() -> void:
	print("[Case 0] ItemData to_dict/from_dict round-trip")
	var item: ItemData = _new_item("clue_photo", "Photograph", ItemData.ItemType.DOCUMENT)
	item.custom_properties = {"letter_text": "Remember the 12th."}
	var d: Dictionary = item.to_dict()
	_check("item_type serialized as name", d.get("item_type") == "DOCUMENT", str(d.get("item_type")))

	var back: ItemData = ItemDataScript.from_dict(d)
	_check("id round-trips", back.id == "clue_photo", back.id)
	_check("enum round-trips", back.item_type == ItemData.ItemType.DOCUMENT, str(back.item_type))
	_check("custom_properties round-trips", back.custom_properties.get("letter_text") == "Remember the 12th.")

	var missing: ItemData = ItemDataScript.from_dict({"id": "bare"})
	_check("unknown item_type defaults to KEY_ITEM", missing.item_type == ItemData.ItemType.KEY_ITEM, str(missing.item_type))
	_check("max_stack_size floor is 1", missing.max_stack_size >= 1, str(missing.max_stack_size))


# --- Case A: unique items into free slots --------------------------------

func _case_unique_items() -> void:
	print("[Case A] add unique items into free slots")
	_events.clear()
	_inv = InventoryManagerScript.new(_bus, MANAGER_CAPACITY)

	var key: ItemData = _new_item("letter_old_key", "Old Key", ItemData.ItemType.KEY_ITEM)
	var sigil: ItemData = _new_item("letter_sigil_01", "Sigil Parchment", ItemData.ItemType.SIGIL)
	var doc: ItemData = _new_item("letter_diary_07", "Diary Fragment", ItemData.ItemType.DOCUMENT)

	_check("add_item(key) -> true", _inv.add_item(key, 1))
	_check("item_added emitted once for key", _events.size() == 2 and _has_event("item_added", key.id, 1), str(_events))
	_events.clear()

	_check("add_item(sigil) -> true", _inv.add_item(sigil, 1))
	_events.clear()
	_check("add_item(doc) -> true", _inv.add_item(doc, 1))
	_events.clear()

	_check("has_item(key)", _inv.has_item(key.id))
	_check("get_item_count(sigil) == 1", _inv.get_item_count(sigil.id) == 1, str(_inv.get_item_count(sigil.id)))
	_check("slot 0 holds key", _inv.get_slot(0).item_data.id == "letter_old_key")
	_check("slot 2 holds doc", _inv.get_slot(2).item_data.id == "letter_diary_07")
	_check("get_slot(capacity) is null", _inv.get_slot(MANAGER_CAPACITY) == null)
	_check("get_slot(-1) is null", _inv.get_slot(-1) == null)
	_check("duplicate id rejected", not _inv.add_item(key, 0))
	_check("null item rejected", not _inv.add_item(null, 1))


# --- Case B: stacking to max_stack_size + overflow -----------------------

func _case_stack_and_overflow() -> void:
	print("[Case B] stack up to max_stack_size, overflow rejected cleanly")
	_events.clear()
	var pellets: ItemData = _new_item("ammo_pellets", "Iron Pellets", ItemData.ItemType.CONSUMABLE, true, 5)

	_inv = InventoryManagerScript.new(_bus, NARROW_CAPACITY)
	_check("add_item(stackable, 5) fits exactly", _inv.add_item(pellets, 5))
	_check("count == 5", _inv.get_item_count(pellets.id) == 5, str(_inv.get_item_count(pellets.id)))
	_check("item_added emitted with qty 5", _has_event("item_added", pellets.id, 5), str(_events))
	_check("slot at capacity", _inv.get_slot(0).quantity == 5 and _inv.get_slot(0).space() == 0)

	_events.clear()
	_check("add_item(stackable, 10) rejected (no room)", not _inv.add_item(pellets, 10))
	_check("quantity unchanged after overflow", _inv.get_item_count(pellets.id) == 5, str(_inv.get_item_count(pellets.id)))
	_check("no item_added on rejected pickup", not _has_event("item_added", pellets.id, 10), str(_events))

	# Spill into a second slot when a wider inventory has room.
	_inv = InventoryManagerScript.new(_bus, MANAGER_CAPACITY)
	_check("add 12 across 3 slots of 5 -> true", _inv.add_item(pellets, 12))
	_check("count == 12", _inv.get_item_count(pellets.id) == 12, str(_inv.get_item_count(pellets.id)))
	_check("slot 0 capped at 5", _inv.get_slot(0).quantity == 5, str(_inv.get_slot(0).quantity))
	_check("slot 2 holds remainder 2", _inv.get_slot(2).quantity == 2, str(_inv.get_slot(2).quantity))
	_events.clear()
	_check("re-add 4 -> true (tops up slot 2, spills 1)", _inv.add_item(pellets, 4))
	_check("count == 16", _inv.get_item_count(pellets.id) == 16, str(_inv.get_item_count(pellets.id)))
	_check("slot 2 topped up to 5", _inv.get_slot(2).quantity == 5, str(_inv.get_slot(2).quantity))
	_check("slot 3 holds spill 1", _inv.get_slot(3).quantity == 1, str(_inv.get_slot(3).quantity))


# --- Case C: removal -----------------------------------------------------

func _case_remove() -> void:
	print("[Case C] remove partial and full quantities")
	_events.clear()
	var pellets: ItemData = _new_item("ammo_pellets", "Iron Pellets", ItemData.ItemType.CONSUMABLE, true, 5)
	_inv = InventoryManagerScript.new(_bus, MANAGER_CAPACITY)
	_inv.add_item(pellets, 5)
	_events.clear()

	_check("remove_item_by_id(2) -> true", _inv.remove_item_by_id(pellets.id, 2))
	_check("remaining == 3", _inv.get_item_count(pellets.id) == 3, str(_inv.get_item_count(pellets.id)))
	_check("item_removed emitted qty 2", _has_event("item_removed", pellets.id, 2), str(_events))
	_check("has_item(min 3)", _inv.has_item(pellets.id, 3))
	_check("has_item(min 4) false", not _inv.has_item(pellets.id, 4))
	_check("over-removal rejected", not _inv.remove_item_by_id(pellets.id, 99))
	_check("unknown id removal rejected", not _inv.remove_item_by_id("nope", 1))

	_events.clear()
	_check("remove_at(0, 3) -> true", _inv.remove_at(0, 3))
	_check("count == 0 after full removal", _inv.get_item_count(pellets.id) == 0, str(_inv.get_item_count(pellets.id)))
	_check("slot cleared", _inv.get_slot(0).is_empty())
	_check("item_removed emitted qty 3", _has_event("item_removed", pellets.id, 3), str(_events))
	_check("remove_at(empty) false", not _inv.remove_at(0, 1))
	_check("remove_at(out_of_range) false", not _inv.remove_at(MANAGER_CAPACITY, 1))


# --- Case D: serialize / deserialize ------------------------------------

func _case_serialization() -> void:
	print("[Case D] serialize/deserialize round-trip is identical")
	_events.clear()
	var key: ItemData = _new_item("key_rusty", "Rusty Key", ItemData.ItemType.KEY_ITEM)
	var pellet: ItemData = _new_item("parchment_stack", "Sigil Parchment", ItemData.ItemType.SIGIL, true, 3)
	_inv = InventoryManagerScript.new(_bus, MANAGER_CAPACITY)
	_inv.add_item(key, 1)
	_inv.add_item(pellet, 3)

	var before: Array[Dictionary] = _inv.serialize_inventory()
	_check("serialize returns non-empty slots only (2)", before.size() == 2, str(before.size()))
	_check("serialized quantity preserved", before[1].get("quantity") == 3, str(before[1].get("quantity")))

	_events.clear()
	_inv.deserialize_inventory([])
	_check("empty load clears inventory", _inv.get_item_count(key.id) == 0 and _inv.serialize_inventory().is_empty())
	_check("empty load emits inventory_updated", _has_event("inventory_updated", "", 0), str(_events))
	_check("capacity preserved after empty load", _inv.capacity() == MANAGER_CAPACITY, str(_inv.capacity()))

	_inv.deserialize_inventory(before)
	var after: Array[Dictionary] = _inv.serialize_inventory()
	_check("round-trip slot count identical", after.size() == before.size(), "%d vs %d" % [after.size(), before.size()])
	_check("round-trip payload identical", after == before, str(after))
	_check("key count restored == 1", _inv.get_item_count(key.id) == 1, str(_inv.get_item_count(key.id)))
	_check("parchment count restored == 3", _inv.get_item_count(pellet.id) == 3, str(_inv.get_item_count(pellet.id)))
	_check("enum restored on load", _inv.get_slot(0).item_data.item_type == ItemData.ItemType.KEY_ITEM)
	_check("stackability restored on load", _inv.get_slot(1).item_data.is_stackable)