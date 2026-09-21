class_name RelationshipSystem
extends Node

const MIN_VALUE: int = -100
const MAX_VALUE: int = 100
const STAT_NAMES: Array[String] = ["affinity", "trust", "respect"]

var _relationships: Dictionary = {}


func get_relationship(npc_id: String) -> Dictionary:
	return _ensure_relationship(npc_id).duplicate()


func modify_affinity(npc_id: String, amount: int) -> Dictionary:
	return _modify_stat(npc_id, "affinity", amount)


func modify_trust(npc_id: String, amount: int) -> Dictionary:
	return _modify_stat(npc_id, "trust", amount)


func modify_respect(npc_id: String, amount: int) -> Dictionary:
	return _modify_stat(npc_id, "respect", amount)


func apply_effects(npc_id: String, effects: Dictionary) -> Dictionary:
	for stat_name_variant in effects.keys():
		var stat_name: String = str(stat_name_variant)
		if STAT_NAMES.has(stat_name):
			_modify_stat(npc_id, stat_name, int(effects.get(stat_name, 0)))
	return get_relationship(npc_id)


func meets_requirements(npc_id: String, requirements: Dictionary) -> bool:
	var relationship: Dictionary = _ensure_relationship(npc_id)
	for stat_name_variant in requirements.keys():
		var stat_name: String = str(stat_name_variant)
		if not STAT_NAMES.has(stat_name):
			return false
		if int(relationship.get(stat_name, 0)) < int(requirements.get(stat_name, 0)):
			return false
	return true


func _ensure_relationship(npc_id: String) -> Dictionary:
	if not _relationships.has(npc_id):
		_relationships[npc_id] = {"affinity": 0, "trust": 0, "respect": 0}
	return _relationships[npc_id] as Dictionary


func _modify_stat(npc_id: String, stat_name: String, amount: int) -> Dictionary:
	var relationship: Dictionary = _ensure_relationship(npc_id)
	var current_value: int = int(relationship.get(stat_name, 0))
	relationship[stat_name] = clampi(current_value + amount, MIN_VALUE, MAX_VALUE)
	return get_relationship(npc_id)
