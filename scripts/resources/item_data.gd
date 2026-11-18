class_name ItemData
extends Resource
## Data definition for every inventoryable object (Mechanic #5).
## Pure data: no UI, no scene, no engine dependency beyond Resource.

enum ItemType { CONSUMABLE, KEY_ITEM, DOCUMENT, SIGIL }

@export_group("Identity")
## Unique, stable identifier - the key used by inventory, save slots, clues.
@export var id: String = ""
@export var name: String = ""
@export var description: String = ""

@export_group("Behavior")
@export var item_type: ItemType = ItemType.KEY_ITEM
## Whether multiple instances occupy one slot.
@export var is_stackable: bool = false
@export var max_stack_size: int = 1

## Extra metadata for item types. Keys are item_type-specific:
##   DOCUMENT -> "letter_text": String
##   SIGIL    -> "template_name": String
##   KEY_ITEM -> "gate_id": String
@export var custom_properties: Dictionary = {}


func _init(p_id: String = "", p_name: String = "", p_description: String = "") -> void:
	id = p_id
	name = p_name
	description = p_description


func type_name() -> String:
	var key: Variant = ItemType.find_key(item_type)
	return str(key) if key != null else "KEY_ITEM"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"item_type": type_name(),
		"is_stackable": is_stackable,
		"max_stack_size": max_stack_size,
		"custom_properties": custom_properties.duplicate(true),
	}


static func from_dict(data: Dictionary) -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = str(data.get("id", ""))
	item.name = str(data.get("name", ""))
	item.description = str(data.get("description", ""))
	var raw_type: Variant = data.get("item_type", "KEY_ITEM")
	if typeof(raw_type) == TYPE_INT:
		item.item_type = clampi(raw_type, 0, ItemType.size() - 1)
	elif ItemType.has(str(raw_type)):
		item.item_type = ItemType[str(raw_type)]
	item.is_stackable = bool(data.get("is_stackable", false))
	item.max_stack_size = maxi(int(data.get("max_stack_size", 1)), 1)
	var props: Variant = data.get("custom_properties", {})
	item.custom_properties = props if props is Dictionary else {}
	return item