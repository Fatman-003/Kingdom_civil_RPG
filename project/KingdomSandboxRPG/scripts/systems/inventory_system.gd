class_name InventorySystem
extends Node

signal inventory_changed

const ITEM_DATA_PATH: String = "res://data/items/prototype_items.json"

var _item_definitions: Dictionary = {}
var _amounts: Dictionary = {}


func _ready() -> void:
	_load_item_definitions()


func add_item(item_id: String, amount: int) -> bool:
	if amount <= 0 or not _item_definitions.has(item_id):
		return false
	_amounts[item_id] = get_amount(item_id) + amount
	inventory_changed.emit()
	var bus := get_node_or_null("/root/EventBus")
	if bus != null: bus.item_added.emit(item_id, amount)
	return true


func remove_item(item_id: String, amount: int) -> bool:
	if amount <= 0 or not has_item(item_id, amount):
		return false
	_amounts[item_id] = get_amount(item_id) - amount
	inventory_changed.emit()
	return true


func get_amount(item_id: String) -> int:
	return int(_amounts.get(item_id, 0))


func has_item(item_id: String, amount: int) -> bool:
	return amount > 0 and get_amount(item_id) >= amount


func get_giftable_items() -> Array:
	var giftable_items: Array = []
	for item_id_variant in _amounts.keys():
		var item_id: String = str(item_id_variant)
		var definition: Dictionary = _item_definitions.get(item_id, {}) as Dictionary
		if get_amount(item_id) > 0 and bool(definition.get("giftable", false)):
			giftable_items.append({
				"item_id": item_id,
				"display_name": str(definition.get("display_name", item_id)),
				"amount": get_amount(item_id),
			})
	return giftable_items


func get_owned_items() -> Array:
	var owned_items: Array = []
	for item_id_variant in _amounts.keys():
		var item_id: String = str(item_id_variant)
		if get_amount(item_id) <= 0:
			continue
		var definition: Dictionary = _item_definitions.get(item_id, {}) as Dictionary
		owned_items.append({"item_id": item_id, "display_name": str(definition.get("display_name", item_id)), "amount": get_amount(item_id)})
	return owned_items


func get_item_definition(item_id: String) -> Dictionary:
	return (_item_definitions.get(item_id, {}) as Dictionary).duplicate()


func _load_item_definitions() -> void:
	var item_file: FileAccess = FileAccess.open(ITEM_DATA_PATH, FileAccess.READ)
	if item_file == null:
		printerr("InventorySystem: could not open item data.")
		return
	var parsed_data: Variant = JSON.parse_string(item_file.get_as_text())
	item_file.close()
	if typeof(parsed_data) == TYPE_DICTIONARY:
		_item_definitions = parsed_data.get("items", {})
