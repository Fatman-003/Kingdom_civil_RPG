class_name EquipmentSystem
extends Node

const SLOTS: Array[String] = ["main_hand", "off_hand", "head", "body", "boots", "accessory"]
const FALLBACK_STATS: Dictionary = {"attack": 5, "defense": 0, "speed": 4, "mobility": 10, "luck": 5}

var _inventory: InventorySystem
var _equipped: Dictionary = {"main_hand": "", "off_hand": "", "head": "", "body": "", "boots": "", "accessory": ""}


func configure(inventory: InventorySystem) -> void:
	_inventory = inventory
	_restore_run_state()


func equip_item(item_id: String) -> bool:
	if _inventory == null or not _inventory.has_item(item_id, 1):
		return false
	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var slot: String = str(definition.get("equip_slot", ""))
	if not SLOTS.has(slot):
		return false
	if not _inventory.remove_item(item_id, 1):
		return false
	var previous_item: String = get_equipped_item(slot)
	if not previous_item.is_empty():
		_inventory.add_item(previous_item, 1)
	_equipped[slot] = item_id
	_save_run_state()
	return true


func unequip_slot(slot: String) -> bool:
	if not SLOTS.has(slot) or str(_equipped.get(slot, "")).is_empty():
		return false
	var item_id: String = get_equipped_item(slot)
	if not _inventory.add_item(item_id, 1):
		return false
	_equipped[slot] = ""
	_save_run_state()
	return true


func get_equipped_item(slot: String) -> String:
	return str(_equipped.get(slot, ""))


func get_equipment_modifiers() -> Dictionary:
	var modifiers_total: Dictionary = {}
	if _inventory == null:
		return modifiers_total
	for slot in SLOTS:
		var item_id := get_equipped_item(slot)
		if item_id.is_empty():
			continue
		var modifiers: Dictionary = _inventory.get_item_definition(item_id).get("stat_modifiers", {}) as Dictionary
		for stat_name_variant in modifiers.keys():
			var stat_name: String = str(stat_name_variant)
			if stat_name == "max_hp":
				continue
			modifiers_total[stat_name] = int(modifiers_total.get(stat_name, 0)) + int(modifiers.get(stat_name, 0))
	return modifiers_total


func get_final_stats(base_stats: Dictionary = {}) -> Dictionary:
	var stats: Dictionary = FALLBACK_STATS.duplicate() if base_stats.is_empty() else base_stats.duplicate()
	var modifiers: Dictionary = get_equipment_modifiers()
	for stat_name_variant in modifiers.keys():
		var stat_name: String = str(stat_name_variant)
		stats[stat_name] = int(stats.get(stat_name, 0)) + int(modifiers.get(stat_name, 0))
	stats["mobility"] = maxi(int(stats.get("mobility", 10)), 1)
	return stats


func _restore_run_state() -> void:
	for slot in SLOTS:
		_equipped[slot] = ""
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null or _inventory == null:
		return
	var saved_items: Variant = game_manager.get("equipped_items")
	if not saved_items is Dictionary:
		return
	for slot in SLOTS:
		var item_id: String = str((saved_items as Dictionary).get(slot, ""))
		if item_id.is_empty():
			continue
		var definition: Dictionary = _inventory.get_item_definition(item_id)
		if str(definition.get("equip_slot", "")) != slot or not _inventory.has_item(item_id, 1):
			continue
		if _inventory.remove_item(item_id, 1):
			_equipped[slot] = item_id


func _save_run_state() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager != null:
		game_manager.set("equipped_items", _equipped.duplicate())
