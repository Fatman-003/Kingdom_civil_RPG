extends Node

const DIALOGUE_DATA_PATH: String = "res://data/dialogue/test_npcs.json"
const GIFT_EFFECTS: Dictionary = {
	"liked": {"affinity": 5, "trust": 2},
	"neutral": {"affinity": 1},
	"disliked": {"affinity": -3},
}
const GIFT_REACTIONS: Dictionary = {
	"liked": "I really like this.",
	"neutral": "Thank you.",
	"disliked": "...I'll take it.",
}

@onready var _dialogue_box: DialogueBox = $"../UIRoot/DialogueBox"
@onready var _relationship_system: RelationshipSystem = $"../RelationshipSystem"
@onready var _inventory_system: InventorySystem = $"../InventorySystem"
@onready var _quest_system: QuestSystem = $"../QuestSystem"

var _dialogues: Dictionary = {}
var _active_npc: GridNpc
var _active_nodes: Dictionary = {}
var _current_node_id: String = ""
var _current_choices: Array = []
var _pending_choice_next: String = ""
var _can_advance: bool = false
var _gift_selection_open: bool = false
var _gift_only_flow: bool = false


func _ready() -> void:
	_load_dialogues()
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.connect("dialogue_requested", _on_dialogue_requested)
	_dialogue_box.advance_requested.connect(_advance_dialogue)
	_dialogue_box.choice_selected.connect(_select_choice)
	_dialogue_box.gift_selected.connect(_give_gift)
	_dialogue_box.gift_cancelled.connect(_cancel_gift_selection)
	_dialogue_box.close_requested.connect(_end_dialogue)


func is_dialogue_active() -> bool:
	return _active_npc != null


func _on_dialogue_requested(npc: Node) -> void:
	if is_dialogue_active():
		return
	var conversation: Dictionary = _quest_system.get_conversation_for_npc(str(npc.get("npc_id"))) if _quest_system != null else {}
	if conversation.is_empty():
		conversation = _dialogues.get(str(npc.get("dialogue_id")), {}) as Dictionary
	if conversation.is_empty():
		printerr("DialogueManager: dialogue data not found.")
		return
	_active_npc = npc as GridNpc
	_active_nodes = conversation.get("nodes", {}) as Dictionary
	_current_node_id = str(conversation.get("start", "start"))
	if _active_npc == null or not _active_nodes.has(_current_node_id):
		_active_npc = null
		printerr("DialogueManager: dialogue start node not found.")
		return
	_active_npc.set_dialogue_active(true, get_tree().get_first_node_in_group("player"))
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null: event_bus.npc_talked_to.emit(_active_npc.npc_id)
	_emit_event("dialogue_started", _active_npc)
	_print_relationship(_active_npc)
	_show_current_node()


func _advance_dialogue() -> void:
	if not is_dialogue_active() or not _can_advance or not _current_choices.is_empty():
		return
	if _gift_only_flow:
		_end_dialogue()
		return
	if not _pending_choice_next.is_empty():
		var choice_next_node_id := _pending_choice_next
		_pending_choice_next = ""
		_go_to_node(choice_next_node_id)
		return
	var node: Dictionary = _active_nodes.get(_current_node_id, {}) as Dictionary
	var next_node_id: String = str(node.get("next", ""))
	if next_node_id.is_empty():
		_end_dialogue()
		return
	_go_to_node(next_node_id)


func _select_choice(choice_index: int) -> void:
	if not is_dialogue_active() or choice_index < 0 or choice_index >= _current_choices.size():
		return
	var choice: Dictionary = _current_choices[choice_index] as Dictionary
	var quest_action: String = str(choice.get("quest_action", ""))
	if not quest_action.is_empty() and (_quest_system == null or not (_quest_system.accept_quest(str(choice.get("quest_id", ""))) if quest_action == "accept" else _quest_system.turn_in_quest(str(choice.get("quest_id", ""))))):
		return
	var effects: Dictionary = choice.get("effects", {}) as Dictionary
	if not effects.is_empty():
		_relationship_system.apply_effects(_active_npc.npc_id, effects)
		_print_relationship(_active_npc)
		_dialogue_box.show_relationship(_relationship_system.get_relationship(_active_npc.npc_id))
	var next_node_id: String = str(choice.get("next", ""))
	if next_node_id.is_empty():
		_end_dialogue()
		return
	_pending_choice_next = next_node_id
	_current_choices = []
	_dialogue_box.show_choice_response(str(choice.get("text", "")))
	_can_advance = false
	call_deferred("_allow_advance")


func _go_to_node(node_id: String) -> void:
	if not _active_nodes.has(node_id):
		printerr("DialogueManager: dialogue node not found: %s" % node_id)
		_end_dialogue()
		return
	_current_node_id = node_id
	_show_current_node()


func _end_dialogue() -> void:
	if not is_dialogue_active():
		return
	_dialogue_box.hide_dialogue()
	_active_npc.set_dialogue_active(false, null)
	_emit_event("dialogue_ended", _active_npc)
	_active_npc = null
	_active_nodes = {}
	_current_node_id = ""
	_current_choices = []
	_pending_choice_next = ""
	_can_advance = false
	_gift_selection_open = false
	_gift_only_flow = false


func _show_current_node() -> void:
	var node: Dictionary = _active_nodes[_current_node_id] as Dictionary
	_current_choices = _get_available_choices(node.get("choices", []) as Array)
	_dialogue_box.show_dialogue_node(_active_npc.npc_id, str(node.get("speaker", _active_npc.display_name)), str(node.get("text", "")), str(node.get("expression", "neutral")), _current_choices)
	_dialogue_box.show_relationship(_relationship_system.get_relationship(_active_npc.npc_id))
	_can_advance = false
	call_deferred("_allow_advance")


func _allow_advance() -> void:
	_can_advance = true


func _open_gift_selection() -> void:
	if not is_dialogue_active() or _gift_selection_open:
		return
	var giftable_items: Array = _inventory_system.get_giftable_items()
	if giftable_items.is_empty():
		return
	_gift_selection_open = true
	_dialogue_box.show_gift_selection(giftable_items)


func start_gift_flow(npc: Node) -> void:
	if is_dialogue_active():
		return
	_active_npc = npc as GridNpc
	if _active_npc == null:
		return
	_active_npc.set_dialogue_active(true, get_tree().get_first_node_in_group("player"))
	_gift_only_flow = true
	_emit_event("dialogue_started", _active_npc)
	_dialogue_box.visible = true
	_dialogue_box.show_relationship(_relationship_system.get_relationship(_active_npc.npc_id))
	_open_gift_selection()
	_can_advance = false
	call_deferred("_allow_advance")


func _cancel_gift_selection() -> void:
	_gift_selection_open = false
	if _gift_only_flow:
		_end_dialogue()


func _give_gift(item_id: String) -> void:
	if not is_dialogue_active() or not _gift_selection_open:
		return
	_gift_selection_open = false
	_dialogue_box.hide_gift_selection()
	if not _inventory_system.remove_item(item_id, 1):
		return
	var reaction_category := _get_gift_reaction_category(item_id)
	var effects: Dictionary = GIFT_EFFECTS.get(reaction_category, GIFT_EFFECTS["neutral"]) as Dictionary
	_relationship_system.apply_effects(_active_npc.npc_id, effects)
	_dialogue_box.show_relationship(_relationship_system.get_relationship(_active_npc.npc_id))
	_dialogue_box.show_npc_reaction(_active_npc.display_name, str(GIFT_REACTIONS.get(reaction_category, GIFT_REACTIONS["neutral"])))
	_print_relationship(_active_npc)


func _get_gift_reaction_category(item_id: String) -> String:
	if _active_npc.liked_gifts.has(item_id):
		return "liked"
	if _active_npc.disliked_gifts.has(item_id):
		return "disliked"
	return "neutral"


func _get_available_choices(choices: Array) -> Array:
	var available_choices: Array = []
	for choice_variant in choices:
		var choice: Dictionary = choice_variant as Dictionary
		var requirements: Dictionary = choice.get("requires", {}) as Dictionary
		if requirements.is_empty() or _relationship_system.meets_requirements(_active_npc.npc_id, requirements):
			available_choices.append(choice)
	return available_choices


func _print_relationship(npc: GridNpc) -> void:
	var relationship: Dictionary = _relationship_system.get_relationship(npc.npc_id)
	print("Relationship [%s] affinity=%d trust=%d respect=%d" % [
		npc.display_name,
		int(relationship.get("affinity", 0)),
		int(relationship.get("trust", 0)),
		int(relationship.get("respect", 0)),
	])


func _load_dialogues() -> void:
	var dialogue_file: FileAccess = FileAccess.open(DIALOGUE_DATA_PATH, FileAccess.READ)
	if dialogue_file == null:
		printerr("DialogueManager: could not open dialogue data.")
		return
	var parsed_data: Variant = JSON.parse_string(dialogue_file.get_as_text())
	dialogue_file.close()
	if typeof(parsed_data) == TYPE_DICTIONARY:
		_dialogues = parsed_data.get("dialogues", {})


func _emit_event(signal_name: StringName, npc: GridNpc) -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal(signal_name, npc)
