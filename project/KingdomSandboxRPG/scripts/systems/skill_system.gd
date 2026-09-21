class_name SkillSystem
extends Node

const SKILL_DATA_PATH: String = "res://data/skills/skill_definitions.json"
const SKILL_SLOTS: Array[String] = ["skill_1", "skill_2", "skill_3", "skill_4"]

signal skills_changed

var _progression: ProgressionSystem

var _definitions: Dictionary = {}
var _learned: Dictionary = {}
var _assigned: Dictionary = {
	"skill_1": "",
	"skill_2": "",
	"skill_3": "",
	"skill_4": "",
}


func _ready() -> void:
	_load_definitions()


func configure(progression: ProgressionSystem) -> void:
	_progression = progression
	_restore_run_state()
	if not _progression.skill_points_changed.is_connected(_on_progression_changed):
		_progression.skill_points_changed.connect(_on_progression_changed)


func get_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for skill_id_variant in _definitions.keys():
		ids.append(str(skill_id_variant))
	return ids


func get_skill_definition(skill_id: String) -> Dictionary:
	return (_definitions.get(skill_id, {}) as Dictionary).duplicate(true)


func get_skill_state(skill_id: String) -> String:
	if _learned.get(skill_id, false):
		return "LEARNED"
	var definition: Dictionary = get_skill_definition(skill_id)
	if definition.is_empty():
		return "LOCKED"
	var prerequisites: Array = definition.get("prerequisites", []) as Array
	for prerequisite_variant in prerequisites:
		if not _learned.get(str(prerequisite_variant), false):
			return "LOCKED"
	return "AVAILABLE"


func is_learned(skill_id: String) -> bool:
	return bool(_learned.get(skill_id, false))


func can_learn(skill_id: String) -> bool:
	return get_skill_state(skill_id) == "AVAILABLE" and get_skill_points() >= get_skill_point_cost(skill_id)


func learn_skill(skill_id: String) -> bool:
	if not can_learn(skill_id):
		return false
	if _progression == null or not _progression.spend_skill_points(get_skill_point_cost(skill_id)):
		return false
	_learned[skill_id] = true
	_save_run_state()
	skills_changed.emit()
	return true


func get_skill_point_cost(skill_id: String) -> int:
	return maxi(int(get_skill_definition(skill_id).get("skill_point_cost", 1)), 1)


func get_skill_points() -> int:
	return _progression.get_skill_points() if _progression != null else 0


func assign_skill(skill_id: String, slot: String) -> bool:
	if not SKILL_SLOTS.has(slot) or not is_learned(skill_id):
		return false
	var definition: Dictionary = get_skill_definition(skill_id)
	if str(definition.get("skill_type", "")).to_upper() != "ACTIVE":
		return false
	_assigned[slot] = skill_id
	_save_run_state()
	skills_changed.emit()
	return true


func get_assigned_skill(slot: String) -> String:
	return str(_assigned.get(slot, ""))


func get_skill_for_action(action: String) -> String:
	return get_assigned_skill(action)


func _load_definitions() -> void:
	var file: FileAccess = FileAccess.open(SKILL_DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("SkillSystem: skill data missing.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_definitions = (parsed as Dictionary).get("skills", {}) as Dictionary


func _restore_run_state() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return
	var learned_state: Variant = game_manager.get("learned_skills")
	if learned_state is Array:
		_learned.clear()
		for skill_id_variant in learned_state:
			_learned[str(skill_id_variant)] = true
	var assigned_state: Variant = game_manager.get("assigned_skills")
	if assigned_state is Dictionary:
		for slot in SKILL_SLOTS:
			_assigned[slot] = str((assigned_state as Dictionary).get(slot, ""))


func _on_progression_changed(_value: int) -> void:
	skills_changed.emit()


func _save_run_state() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return
	var learned_ids: Array[String] = []
	for skill_id_variant in _learned.keys():
		if _learned[skill_id_variant]:
			learned_ids.append(str(skill_id_variant))
	game_manager.set("learned_skills", learned_ids)
	game_manager.set("assigned_skills", _assigned.duplicate())
