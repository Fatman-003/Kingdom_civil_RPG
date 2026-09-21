class_name DialogueBox
extends Control

signal advance_requested
signal close_requested
signal choice_selected(choice_index: int)
signal gift_selected(item_id: String)
signal gift_cancelled

const EXPRESSION_COLORS: Dictionary = {
	"neutral": Color("718096"),
	"happy": Color("e9b949"),
	"angry": Color("dc5f5f"),
	"sad": Color("6387c5"),
	"surprised": Color("b17cc8"),
}

@onready var _portrait: ColorRect = $PanelContainer/MarginContainer/HBoxContainer/Portrait
@onready var _portrait_texture: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Portrait/PortraitTexture
@onready var _expression_label: Label = $PanelContainer/MarginContainer/HBoxContainer/Portrait/ExpressionLabel
@onready var _name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/Content/NameLabel
@onready var _dialogue_text_label: Label = $PanelContainer/MarginContainer/HBoxContainer/Content/DialogueText
@onready var _choice_container: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/Content/ChoiceContainer
@onready var _advance_label: Label = $PanelContainer/MarginContainer/HBoxContainer/Content/AdvanceLabel
@onready var _relationship_panel: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel
@onready var _affinity_value: Label = $PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/AffinityValue
@onready var _affinity_negative: ProgressBar = $PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/AffinityGauge/Negative
@onready var _affinity_positive: ProgressBar = $PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/AffinityGauge/Positive
@onready var _trust_value: Label = $PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/TrustValue
@onready var _trust_negative: ProgressBar = $PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/TrustGauge/Negative
@onready var _trust_positive: ProgressBar = $PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/TrustGauge/Positive
@onready var _respect_value: Label = $PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/RespectValue
@onready var _respect_negative: ProgressBar = $PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/RespectGauge/Negative
@onready var _respect_positive: ProgressBar = $PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/RespectGauge/Positive
@onready var _gift_panel: PanelContainer = $GiftPanel
@onready var _gift_items_container: VBoxContainer = $GiftPanel/MarginContainer/Content/Items

var _choices: Array = []
var _selected_choice: int = 0
var _gift_items: Array = []
var _selected_gift: int = 0
var _gift_mode: bool = false


func _ready() -> void:
	visible = false
	_relationship_panel.visible = false


func show_dialogue_node(npc_id: String, display_name: String, dialogue_text: String, expression: String, choices: Array) -> void:
	_name_label.text = display_name
	_dialogue_text_label.text = dialogue_text
	_set_portrait(npc_id, expression)
	_set_choices(choices)
	visible = true


func hide_dialogue() -> void:
	visible = false
	_relationship_panel.visible = false
	hide_gift_selection()
	_set_choices([])


func show_choice_response(response_text: String) -> void:
	_name_label.text = "You"
	_dialogue_text_label.text = response_text
	_set_choices([])


func show_npc_reaction(display_name: String, reaction_text: String) -> void:
	_name_label.text = display_name
	_dialogue_text_label.text = reaction_text
	_set_choices([])


func show_gift_selection(items: Array) -> void:
	_gift_items = items.duplicate()
	_selected_gift = 0
	_gift_mode = true
	for child in _gift_items_container.get_children():
		_gift_items_container.remove_child(child)
		child.queue_free()
	for gift_index in _gift_items.size():
		var item: Dictionary = _gift_items[gift_index] as Dictionary
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_gift_button_pressed.bind(gift_index))
		_gift_items_container.add_child(button)
	_gift_panel.visible = true
	_refresh_gift_highlight()


func hide_gift_selection() -> void:
	_gift_mode = false
	_gift_items = []
	_selected_gift = 0
	_gift_panel.visible = false


func _refresh_gift_highlight() -> void:
	var item_count: int = mini(_gift_items.size(), _gift_items_container.get_child_count())
	if item_count == 0:
		return
	_selected_gift = clampi(_selected_gift, 0, item_count - 1)
	for gift_index in item_count:
		var item: Dictionary = _gift_items[gift_index] as Dictionary
		var button: Button = _gift_items_container.get_child(gift_index) as Button
		button.text = ("> " if gift_index == _selected_gift else "  ") + "%s x%d" % [str(item.get("display_name", "Item")), int(item.get("amount", 0))]


func _on_gift_button_pressed(gift_index: int) -> void:
	if not _gift_mode or gift_index < 0 or gift_index >= _gift_items.size():
		return
	var item: Dictionary = _gift_items[gift_index] as Dictionary
	_gift_mode = false
	_gift_panel.visible = false
	gift_selected.emit(str(item.get("item_id", "")))


func show_relationship(relationship: Dictionary) -> void:
	_set_relationship_stat(_affinity_value, _affinity_negative, _affinity_positive, "Affinity", int(relationship.get("affinity", 0)))
	_set_relationship_stat(_trust_value, _trust_negative, _trust_positive, "Trust", int(relationship.get("trust", 0)))
	_set_relationship_stat(_respect_value, _respect_negative, _respect_positive, "Respect", int(relationship.get("respect", 0)))
	_relationship_panel.visible = true


func _set_relationship_stat(value_label: Label, negative_gauge: ProgressBar, positive_gauge: ProgressBar, stat_name: String, value: int) -> void:
	var clamped_value: int = clampi(value, -100, 100)
	value_label.text = "%s  %d" % [stat_name, clamped_value]
	negative_gauge.value = maxi(-clamped_value, 0)
	positive_gauge.value = maxi(clamped_value, 0)


func _set_portrait(npc_id: String, requested_expression: String) -> void:
	var expression := requested_expression if EXPRESSION_COLORS.has(requested_expression) else "neutral"
	var texture := _load_portrait_texture(npc_id, expression)
	if texture == null and expression != "neutral":
		texture = _load_portrait_texture(npc_id, "neutral")
	_portrait_texture.texture = texture
	_portrait_texture.visible = texture != null
	_expression_label.visible = texture == null
	_expression_label.text = expression.capitalize()
	_portrait.color = Color.WHITE if texture != null else EXPRESSION_COLORS[expression]


func _load_portrait_texture(npc_id: String, expression: String) -> Texture2D:
	var portrait_path := "res://assets/portraits/%s/%s.png" % [npc_id, expression]
	if not ResourceLoader.exists(portrait_path):
		return null
	return load(portrait_path) as Texture2D


func _set_choices(choices: Array) -> void:
	for child in _choice_container.get_children():
		_choice_container.remove_child(child)
		child.queue_free()
	_choices = choices.duplicate()
	_selected_choice = 0
	_choice_container.visible = not _choices.is_empty()
	_advance_label.text = "Up / Down or W / S: Select     E / Space: Confirm     Escape: Close" if not _choices.is_empty() else "E / Space: Continue     Escape: Close"
	if _choices.is_empty():
		return
	for choice_index in _choices.size():
		var choice: Dictionary = _choices[choice_index] as Dictionary
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_choice_button_pressed.bind(choice_index))
		_choice_container.add_child(button)
	_refresh_choice_highlight()


func _refresh_choice_highlight() -> void:
	var button_count: int = mini(_choice_container.get_child_count(), _choices.size())
	if button_count == 0:
		return
	_selected_choice = clampi(_selected_choice, 0, button_count - 1)
	for choice_index in button_count:
		var choice: Dictionary = _choices[choice_index] as Dictionary
		var button := _choice_container.get_child(choice_index) as Button
		button.text = ("> " if choice_index == _selected_choice else "  ") + str(choice.get("text", ""))


func _on_choice_button_pressed(choice_index: int) -> void:
	choice_selected.emit(choice_index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _gift_mode:
		var gift_count: int = mini(_gift_items.size(), _gift_items_container.get_child_count())
		if event.is_action_pressed("move_up", false) and gift_count > 0:
			_selected_gift = posmod(_selected_gift - 1, gift_count)
			_refresh_gift_highlight()
		elif event.is_action_pressed("move_down", false) and gift_count > 0:
			_selected_gift = posmod(_selected_gift + 1, gift_count)
			_refresh_gift_highlight()
		elif event.is_action_pressed("interact", false) and gift_count > 0:
			_on_gift_button_pressed(_selected_gift)
		elif event.is_action_pressed("pause", false):
			hide_gift_selection()
			gift_cancelled.emit()
		else:
			return
		get_viewport().set_input_as_handled()
		return

	var choice_count: int = mini(_choice_container.get_child_count(), _choices.size())
	if event.is_action_pressed("move_up", false) and choice_count > 0:
		_selected_choice = posmod(_selected_choice - 1, choice_count)
		_refresh_choice_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down", false) and choice_count > 0:
		_selected_choice = posmod(_selected_choice + 1, choice_count)
		_refresh_choice_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact", false):
		if choice_count == 0:
			advance_requested.emit()
		else:
			choice_selected.emit(_selected_choice)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause", false):
		close_requested.emit()
		get_viewport().set_input_as_handled()
