class_name InventorySlot
extends Resource
## A single inventory slot holding one ItemData with a quantity.

const EMPTY_MARKER := "empty"

var item_data: ItemData = null
var quantity: int = 0


func _init(p_item_data: ItemData = null, p_quantity: int = 1) -> void:
	item_data = p_item_data
	quantity = maxi(0, p_quantity) if p_item_data != null else 0


func is_empty() -> bool:
	return item_data == null


## Units this slot can hold of its current item (1 for non-stackables).
func capacity() -> int:
	if item_data == null:
		return 0
	return item_data.max_stack_size if item_data.is_stackable else 1


## Free units left before this slot is full.
func space() -> int:
	return maxi(capacity() - quantity, 0) if item_data != null else 0


## True when `other_item` can be stacked into this slot right now.
func can_merge_with(other_item: ItemData) -> bool:
	if other_item == null or item_data == null:
		return false
	if other_item.id != item_data.id or not item_data.is_stackable:
		return false
	return space() > 0


## Adds up to `amount`, clamped to capacity. Returns the overflow (0..amount).
func try_add(amount: int) -> int:
	if amount <= 0:
		return 0
	if item_data == null:
		return amount
	var take: int = mini(amount, space())
	quantity += take
	return amount - take


func clear() -> void:
	item_data = null
	quantity = 0


func to_dict() -> Dictionary:
	if item_data == null:
		return {EMPTY_MARKER: true}
	var d: Dictionary = item_data.to_dict()
	d["quantity"] = quantity
	return d


static func from_dict(data: Dictionary) -> InventorySlot:
	if data.is_empty() or bool(data.get(EMPTY_MARKER, false)):
		return InventorySlot.new()
	return InventorySlot.new(ItemData.from_dict(data), int(data.get("quantity", 1)))