class_name NpcInteractionMenu
extends Control

signal talk_selected(npc: GridNpc)
signal gift_selected(npc: GridNpc)

@onready var _name_label: Label = $Panel/Margin/Content/NameLabel
@onready var _options: VBoxContainer = $Panel/Margin/Content/Options

var _npc: GridNpc
var _selected_index: int = 0
var _can_confirm: bool = false
const OPTION_NAMES: Array[String] = ["Talk", "Give Gift", "Leave"]


func _ready() -> void:
	theme = FantasyTheme.shared()
	_name_label.add_theme_color_override("font_color", FantasyTheme.BRASS)
	visible = false
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.connect("npc_interaction_requested", open_for_npc)
	for option_index in OPTION_NAMES.size():
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_confirm.bind(option_index))
		_options.add_child(button)


func open_for_npc(npc: Node) -> void:
	if visible:
		return
	_npc = npc as GridNpc
	if _npc == null:
		return
	_npc.set_dialogue_active(true, get_tree().get_first_node_in_group("player"))
	_name_label.text = _npc.display_name
	_selected_index = 0
	_can_confirm = false
	visible = true
	_refresh_options()
	_emit_event("npc_interaction_opened")
	call_deferred("_allow_confirm")


func _allow_confirm() -> void:
	_can_confirm = true


func _confirm(option_index: int) -> void:
	if not visible or not _can_confirm or _npc == null:
		return
	match option_index:
		0:
			_close_for_handoff()
			talk_selected.emit(_npc)
		1:
			_close_for_handoff()
			gift_selected.emit(_npc)
		_:
			close_menu()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	if _npc != null:
		_npc.set_dialogue_active(false, null)
	_npc = null
	_emit_event("npc_interaction_closed")


func _close_for_handoff() -> void:
	visible = false
	_emit_event("npc_interaction_closed")


func _refresh_options() -> void:
	for option_index in _options.get_child_count():
		var button: Button = _options.get_child(option_index) as Button
		button.text = ("> " if option_index == _selected_index else "  ") + OPTION_NAMES[option_index]
		FantasyTheme.select(button, option_index == _selected_index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("move_up", false):
		_selected_index = posmod(_selected_index - 1, OPTION_NAMES.size())
		_refresh_options()
	elif event.is_action_pressed("move_down", false):
		_selected_index = posmod(_selected_index + 1, OPTION_NAMES.size())
		_refresh_options()
	elif event.is_action_pressed("interact", false):
		_confirm(_selected_index)
	elif event.is_action_pressed("pause", false):
		close_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func _emit_event(signal_name: StringName) -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal(signal_name)
