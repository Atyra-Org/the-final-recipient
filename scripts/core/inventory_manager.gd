class_name InventoryManager
extends RefCounted
## Runtime inventory state: fixed number of slots, merge on pick-up, no UI.
## RefCounted - so the EventBus is injected via _init(); there is no _ready().

const DEFAULT_CAPACITY := 16

var _slots: Array[InventorySlot] = []
var _bus: Node = null


func _init(bus: Node, capacity: int = DEFAULT_CAPACITY) -> void:
	_bus = bus
	_reset_slots(capacity)


# --- Public API ------------------------------------------------------------

func capacity() -> int:
	return _slots.size()


func has_item(item_id: String, min_quantity: int = 1) -> bool:
	return get_item_count(item_id) >= maxi(min_quantity, 1)


func get_item_count(item_id: String) -> int:
	if item_id.is_empty():
		return 0
	var total: int = 0
	for slot in _slots:
		if slot.item_data != null and slot.item_data.id == item_id:
			total += slot.quantity
	return total


func get_slot(slot_index: int) -> InventorySlot:
	if slot_index < 0 or slot_index >= _slots.size():
		return null
	return _slots[slot_index]


## All-or-nothing pickup. Emits item_added + inventory_updated on success.
func add_item(item: ItemData, quantity: int = 1) -> bool:
	if item == null or item.id.is_empty() or quantity <= 0:
		return false
	if _free_space_for(item) < quantity:
		return false

	var remaining: int = quantity
	for slot in _slots:
		if remaining <= 0:
			break
		if slot.item_data == null:
			slot.item_data = item
			slot.quantity = 0
			remaining = slot.try_add(remaining)
		elif slot.can_merge_with(item):
			remaining = slot.try_add(remaining)

	_emit(&"item_added", item.id, quantity)
	_emit(&"inventory_updated")
	return true


## All-or-nothing removal across slots. Emits item_removed + inventory_updated on success.
func remove_item_by_id(item_id: String, quantity: int = 1) -> bool:
	if item_id.is_empty() or quantity <= 0 or get_item_count(item_id) < quantity:
		return false

	var remaining: int = quantity
	for slot in _slots:
		if remaining <= 0:
			break
		if slot.item_data == null or slot.item_data.id != item_id:
			continue
		var take: int = mini(remaining, slot.quantity)
		slot.quantity -= take
		remaining -= take
		if slot.quantity <= 0:
			slot.clear()

	_emit(&"item_removed", item_id, quantity)
	_emit(&"inventory_updated")
	return true


func remove_at(slot_index: int, quantity: int = 1) -> bool:
	var slot: InventorySlot = get_slot(slot_index)
	if slot == null or slot.item_data == null or quantity <= 0:
		return false
	var item_id: String = slot.item_data.id
	var take: int = mini(quantity, slot.quantity)
	slot.quantity -= take
	if slot.quantity <= 0:
		slot.clear()
	_emit(&"item_removed", item_id, take)
	_emit(&"inventory_updated")
	return true


# --- Persistence -----------------------------------------------------------

## Non-empty slots only, in slot order.
func serialize_inventory() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in _slots:
		if slot.item_data != null:
			out.append(slot.to_dict())
	return out


## Replaces all slots; capacity is preserved (empty slots re-padded).
func deserialize_inventory(data: Array) -> void:
	var restored: Array[InventorySlot] = []
	for entry in data:
		if entry is Dictionary:
			var slot: InventorySlot = InventorySlot.from_dict(entry)
			if slot.item_data != null:
				restored.append(slot)
	_reset_slots(maxi(restored.size(), _slots.size()))
	for i in restored.size():
		_slots[i] = restored[i]
	_emit(&"inventory_updated")


# --- Internals -------------------------------------------------------------

func _reset_slots(capacity: int) -> void:
	_slots.clear()
	for _i in maxi(capacity, 1):
		_slots.append(InventorySlot.new())


## Units of `item` that could still be stored without dropping anything.
func _free_space_for(item: ItemData) -> int:
	var per_slot: int = item.max_stack_size if item.is_stackable else 1
	var space: int = 0
	for slot in _slots:
		if slot.item_data == null:
			space += per_slot
		elif slot.can_merge_with(item):
			space += slot.space()
	return space


func _emit(signal_name: StringName, item_id: String = "", quantity: int = 0) -> void:
	if _bus == null or not _bus.has_signal(signal_name):
		return
	if signal_name == &"inventory_updated":
		_bus.emit_signal(signal_name)
	else:
		_bus.emit_signal(signal_name, item_id, quantity)
