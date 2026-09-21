class_name LootSystem
extends Node

const LOOT_DATA_PATH: String = "res://data/items/slime_loot.json"
const MAX_LOOT_ROLLS: int = 3
const SECOND_ROLL_CHANCE_PER_LUCK: float = 0.03
const SECOND_ROLL_CHANCE_CAP: float = 0.60
const THIRD_ROLL_LUCK_THRESHOLD: int = 5
const THIRD_ROLL_CHANCE_PER_LUCK: float = 0.015
const THIRD_ROLL_CHANCE_CAP: float = 0.25

var _inventory: InventorySystem
var _loot_tables: Dictionary = {}
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_load_loot_tables()
	_random.randomize()


func configure(inventory: InventorySystem) -> void:
	_inventory = inventory


func get_bonus_roll_2_chance(final_luck: int) -> float:
	return minf(SECOND_ROLL_CHANCE_CAP, maxf(float(final_luck), 0.0) * SECOND_ROLL_CHANCE_PER_LUCK)


func get_bonus_roll_3_chance(final_luck: int) -> float:
	var bonus_luck: int = maxi(final_luck - THIRD_ROLL_LUCK_THRESHOLD, 0)
	return minf(THIRD_ROLL_CHANCE_CAP, float(bonus_luck) * THIRD_ROLL_CHANCE_PER_LUCK)


func resolve_loot(table_id: String, final_luck: int) -> Dictionary:
	var roll_count: int = _resolve_roll_count(final_luck)
	var item_amounts: Dictionary = {}
	for _roll_index: int in range(roll_count):
		var result: Dictionary = _roll_weighted_item(table_id)
		if result.is_empty():
			continue
		var item_id: String = str(result.get("item_id", ""))
		item_amounts[item_id] = int(item_amounts.get(item_id, 0)) + int(result.get("amount", 0))
	return {"roll_count": roll_count, "items": item_amounts}


func set_debug_seed(seed: int) -> void:
	_random.seed = seed


func _resolve_roll_count(final_luck: int) -> int:
	var rolls: int = 1
	if _random.randf() >= get_bonus_roll_2_chance(final_luck):
		return rolls
	rolls += 1
	if _random.randf() < get_bonus_roll_3_chance(final_luck):
		rolls += 1
	return mini(rolls, MAX_LOOT_ROLLS)


func _roll_weighted_item(table_id: String) -> Dictionary:
	var table: Dictionary = _loot_tables.get(table_id, {}) as Dictionary
	var drops: Array = table.get("drops", []) as Array
	var total_weight: int = 0
	for drop_variant: Variant in drops:
		if drop_variant is Dictionary:
			total_weight += maxi(int((drop_variant as Dictionary).get("weight", 0)), 0)
	if total_weight <= 0:
		return {}
	var roll: int = _random.randi_range(1, total_weight)
	for drop_variant: Variant in drops:
		if not drop_variant is Dictionary:
			continue
		var drop: Dictionary = drop_variant as Dictionary
		roll -= maxi(int(drop.get("weight", 0)), 0)
		if roll > 0:
			continue
		var item_id: String = str(drop.get("item_id", ""))
		if _inventory == null or _inventory.get_item_definition(item_id).is_empty():
			push_warning("LootSystem: invalid loot item '%s'." % item_id)
			return {}
		var minimum: int = maxi(int(drop.get("min_amount", 1)), 1)
		var maximum: int = maxi(int(drop.get("max_amount", minimum)), minimum)
		return {"item_id": item_id, "amount": _random.randi_range(minimum, maximum)}
	return {}


func _load_loot_tables() -> void:
	var loot_file: FileAccess = FileAccess.open(LOOT_DATA_PATH, FileAccess.READ)
	if loot_file == null:
		push_warning("LootSystem: loot data missing.")
		return
	var parsed: Variant = JSON.parse_string(loot_file.get_as_text())
	loot_file.close()
	if parsed is Dictionary:
		_loot_tables = (parsed as Dictionary).get("loot_tables", {}) as Dictionary
	else:
		push_warning("LootSystem: loot data is invalid.")
