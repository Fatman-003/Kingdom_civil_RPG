class_name QuestSystem
extends Node

const DATA_PATH := "res://data/quests/quest_definitions.json"
const NOT_STARTED := "NOT_STARTED"
const ACTIVE := "ACTIVE"
const READY_TO_TURN_IN := "READY_TO_TURN_IN"
const COMPLETED := "COMPLETED"

signal quest_state_changed(quest_id: String, state: String)
signal quest_progress_changed(quest_id: String)
signal quest_feedback(text: String)

var _definitions: Dictionary = {}
var _states: Dictionary = {}
var _progress: Dictionary = {}
var _player: Player
var _inventory: InventorySystem

func _ready() -> void:
	_load_data()
	var bus := get_node_or_null("/root/EventBus")
	if bus != null:
		bus.monster_killed.connect(_on_monster_killed)
		bus.item_added.connect(_on_item_added)
		bus.npc_talked_to.connect(_on_npc_talked_to)

func configure(player: Player, inventory: InventorySystem) -> void:
	_player = player
	_inventory = inventory
	_restore()

func get_state(quest_id: String) -> String:
	return str(_states.get(quest_id, NOT_STARTED))

func get_quests() -> Array[Dictionary]:
	var quests: Array[Dictionary] = []
	for id_variant in _definitions.keys():
		quests.append(get_quest_details(str(id_variant)))
	return quests

func get_quest_details(quest_id: String) -> Dictionary:
	var definition: Dictionary = _definitions.get(quest_id, {}) as Dictionary
	var result := definition.duplicate(true)
	result["state"] = get_state(quest_id)
	result["progress"] = (_progress.get(quest_id, {}) as Dictionary).duplicate()
	return result

func accept_quest(quest_id: String) -> bool:
	if not _definitions.has(quest_id) or get_state(quest_id) != NOT_STARTED:
		return false
	_states[quest_id] = ACTIVE
	var values: Dictionary = {}
	for objective_variant: Variant in (_definitions[quest_id] as Dictionary).get("objectives", []):
		var objective: Dictionary = objective_variant as Dictionary
		values[str(objective.get("objective_id", ""))] = 0
	_progress[quest_id] = values
	_save()
	quest_state_changed.emit(quest_id, ACTIVE)
	quest_feedback.emit("QUEST ACCEPTED\n%s" % str((_definitions[quest_id] as Dictionary).get("display_name", quest_id)))
	return true

func turn_in_quest(quest_id: String) -> bool:
	if get_state(quest_id) != READY_TO_TURN_IN or _player == null or _inventory == null:
		return false
	var definition: Dictionary = _definitions[quest_id] as Dictionary
	var rewards: Dictionary = definition.get("rewards", {}) as Dictionary
	var xp: int = maxi(int(rewards.get("xp", 0)), 0)
	if xp > 0:
		_player.award_experience(xp)
	for reward_variant: Variant in rewards.get("items", []):
		var reward: Dictionary = reward_variant as Dictionary
		_inventory.add_item(str(reward.get("item_id", "")), maxi(int(reward.get("quantity", 0)), 0))
	_states[quest_id] = COMPLETED
	_save()
	quest_state_changed.emit(quest_id, COMPLETED)
	quest_feedback.emit("QUEST COMPLETE\n%s" % str(definition.get("display_name", quest_id)))
	return true

func get_conversation_for_npc(npc_id: String) -> Dictionary:
	for id_variant: Variant in _definitions.keys():
		var quest_id := str(id_variant)
		var definition: Dictionary = _definitions[quest_id] as Dictionary
		if str(definition.get("giver_npc_id", "")) != npc_id:
			continue
		var dialogue: Dictionary = definition.get("dialogue", {}) as Dictionary
		match get_state(quest_id):
			NOT_STARTED:
				return {"start":"offer", "nodes":{"offer":{"speaker":"Guild Master","text":str(dialogue.get("offer", "")),"choices":[{"text":"Accept","quest_action":"accept","quest_id":quest_id,"next":"accepted"},{"text":"Decline","next":"declined"}]},"accepted":{"speaker":"Guild Master","text":str(dialogue.get("accepted", ""))},"declined":{"speaker":"Guild Master","text":str(dialogue.get("declined", ""))}}}
			ACTIVE:
				return {"start":"active", "nodes":{"active":{"speaker":"Guild Master","text":str(dialogue.get("active", "")) + "\n" + get_objective_text(quest_id)}}}
			READY_TO_TURN_IN:
				return {"start":"ready", "nodes":{"ready":{"speaker":"Guild Master","text":str(dialogue.get("ready", "")),"choices":[{"text":"Turn In","quest_action":"turn_in","quest_id":quest_id,"next":"complete"}]},"complete":{"speaker":"Guild Master","text":str(dialogue.get("completed", ""))}}}
			COMPLETED:
				return {"start":"done", "nodes":{"done":{"speaker":"Guild Master","text":str(dialogue.get("ambient", ""))}}}
	return {}

func get_objective_text(quest_id: String) -> String:
	var definition: Dictionary = _definitions.get(quest_id, {}) as Dictionary
	var objectives: Array = definition.get("objectives", []) as Array
	if objectives.is_empty(): return ""
	var objective: Dictionary = objectives[0] as Dictionary
	var current: int = int((_progress.get(quest_id, {}) as Dictionary).get(str(objective.get("objective_id", "")), 0))
	return "%s: %d / %d" % [str(objective.get("display", "Objective")), current, int(objective.get("required_count", 1))]

func _on_monster_killed(monster_id: String) -> void: _update_objectives("KILL", monster_id)
func _on_npc_talked_to(npc_id: String) -> void: _update_objectives("TALK", npc_id)
func _on_item_added(_item_id: String, _amount: int) -> void:
	for id_variant: Variant in _definitions.keys(): _refresh_collect(str(id_variant))

func _update_objectives(type: String, target_id: String) -> void:
	for id_variant: Variant in _definitions.keys():
		var quest_id := str(id_variant)
		if get_state(quest_id) != ACTIVE: continue
		var definition: Dictionary = _definitions[quest_id] as Dictionary
		for objective_variant: Variant in definition.get("objectives", []):
			var objective: Dictionary = objective_variant as Dictionary
			if str(objective.get("objective_type", "")) == type and str(objective.get("target_id", "")) == target_id:
				var key := str(objective.get("objective_id", "")); var values: Dictionary = _progress[quest_id] as Dictionary
				values[key] = mini(int(values.get(key, 0)) + 1, int(objective.get("required_count", 1)))
				_progress[quest_id] = values; _check_completion(quest_id)

func _refresh_collect(quest_id: String) -> void:
	if get_state(quest_id) != ACTIVE or _inventory == null: return
	var definition: Dictionary = _definitions[quest_id] as Dictionary
	for objective_variant: Variant in definition.get("objectives", []):
		var objective: Dictionary = objective_variant as Dictionary
		if str(objective.get("objective_type", "")) == "COLLECT":
			var values: Dictionary = _progress[quest_id] as Dictionary
			values[str(objective.get("objective_id", ""))] = mini(_inventory.get_amount(str(objective.get("target_id", ""))), int(objective.get("required_count", 1)))
			_progress[quest_id] = values; _check_completion(quest_id)

func _check_completion(quest_id: String) -> void:
	var definition: Dictionary = _definitions[quest_id] as Dictionary; var values: Dictionary = _progress[quest_id] as Dictionary
	for objective_variant: Variant in definition.get("objectives", []):
		var objective: Dictionary = objective_variant as Dictionary
		if int(values.get(str(objective.get("objective_id", "")), 0)) < int(objective.get("required_count", 1)):
			_save(); quest_progress_changed.emit(quest_id); return
	_states[quest_id] = READY_TO_TURN_IN; _save(); quest_progress_changed.emit(quest_id); quest_state_changed.emit(quest_id, READY_TO_TURN_IN); quest_feedback.emit("OBJECTIVE COMPLETE\nReturn to Guild Master")

func _load_data() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text()); file.close()
	if parsed is Dictionary: _definitions = (parsed as Dictionary).get("quests", {}) as Dictionary

func _restore() -> void:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null: return
	_states = (manager.get("quest_states") as Dictionary).duplicate(true)
	_progress = (manager.get("quest_progress") as Dictionary).duplicate(true)

func _save() -> void:
	var manager := get_node_or_null("/root/GameManager")
	if manager != null: manager.set("quest_states", _states.duplicate(true)); manager.set("quest_progress", _progress.duplicate(true))
