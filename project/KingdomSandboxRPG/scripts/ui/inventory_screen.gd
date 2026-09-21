class_name InventoryScreen
extends Control

@onready var _list: VBoxContainer = $Panel/Margin/HBox/ListColumn/ItemList
@onready var _empty_label: Label = $Panel/Margin/HBox/ListColumn/EmptyLabel
@onready var _name_label: Label = $Panel/Margin/HBox/Details/NameLabel
@onready var _description_label: Label = $Panel/Margin/HBox/Details/DescriptionLabel
@onready var _category_label: Label = $Panel/Margin/HBox/Details/CategoryLabel
@onready var _value_label: Label = $Panel/Margin/HBox/Details/ValueLabel
@onready var _owned_label: Label = $Panel/Margin/HBox/Details/OwnedLabel
@onready var _equip_button: Button = $Panel/Margin/HBox/Details/EquipButton
@onready var _equipment_label: Label = $Panel/Margin/HBox/Details/EquipmentLabel
@onready var _list_column: VBoxContainer = $Panel/Margin/HBox/ListColumn
@onready var _details: VBoxContainer = $Panel/Margin/HBox/Details
@onready var _inventory_tab: Button = $Panel/Margin/HBox/Tabs/InventoryTab
@onready var _equipment_tab: Button = $Panel/Margin/HBox/Tabs/EquipmentTab
@onready var _skills_tab: Button = $Panel/Margin/HBox/Tabs/SkillsTab
@onready var _stats_tab: Button = $Panel/Margin/HBox/Tabs/StatsTab
@onready var _quests_tab: Button = $Panel/Margin/HBox/Tabs/QuestsTab
@onready var _character_column: VBoxContainer = $Panel/Margin/HBox/CharacterColumn
@onready var _character_stats: VBoxContainer = $Panel/Margin/HBox/CharacterColumn/Stats
@onready var _skill_points_label: Label = $Panel/Margin/HBox/ListColumn/SkillPoints
@onready var _skill_assignment_label: Label = $Panel/Margin/HBox/Details/SkillAssignmentLabel
@onready var _stats_xp_bar: ProgressBar = $Panel/Margin/HBox/ListColumn/StatsXpBar
@onready var _stats_derived: VBoxContainer = $Panel/Margin/HBox/Details/StatsDerived

var _inventory: InventorySystem
var _player: Player
var _equipment: EquipmentSystem
var _skill_system: SkillSystem
var _progression: ProgressionSystem
var _quest_system: QuestSystem
var _items: Array = []
var _selected_index: int = 0
var _selected_skill_index: int = 0
var _equipment_tab_active: bool = false
var _skills_tab_active: bool = false
var _stats_tab_active: bool = false
var _quests_tab_active: bool = false
var _selected_quest_index: int = 0
var _active_tab: int = 0
var _selected_stat_index: int = 0
var _stat_plus_buttons: Array[Button] = []
var _selected_slot: String = "main_hand"
var _tab_held: bool = false
var _skill_assignment_mode: bool = false
var _skill_assignment_slot_index: int = 0


func configure(
	inventory: InventorySystem,
	player: Player,
	equipment: EquipmentSystem,
	skill_system: SkillSystem = null,
	progression: ProgressionSystem = null,
	quest_system: QuestSystem = null
) -> void:
	_inventory = inventory
	_player = player
	_equipment = equipment
	_skill_system = skill_system
	_progression = progression
	_quest_system = quest_system
	_inventory.inventory_changed.connect(_on_inventory_changed)
	_equip_button.pressed.connect(_toggle_equipment)
	_inventory_tab.pressed.connect(_show_inventory_tab)
	_equipment_tab.pressed.connect(_show_equipment_tab)
	_skills_tab.pressed.connect(_show_skills_tab)
	_stats_tab.pressed.connect(_show_stats_tab)
	_quests_tab.pressed.connect(_show_quests_tab)
	if _skill_system != null:
		_skill_system.skills_changed.connect(_on_skills_changed)
	if _progression != null:
		_progression.xp_changed.connect(_on_progression_changed)
		_progression.level_changed.connect(_on_progression_level_changed)
		_progression.base_stats_changed.connect(_on_progression_base_stats_changed)
		_progression.stat_points_changed.connect(_on_progression_points_changed)
		_progression.skill_points_changed.connect(_on_progression_points_changed)


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	var tab_pressed: bool = Input.is_key_pressed(KEY_TAB)
	if not visible and tab_pressed and not _tab_held and _player != null and not _player.is_dialogue_active():
		open_screen()
		_show_tab(true)
	_tab_held = tab_pressed


func toggle_character_panel() -> void:
	if visible:
		close_screen()
		return
	if _player != null and not _player.is_dialogue_active():
		open_screen()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory", false):
		toggle_character_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skills", false):
		if visible and _skills_tab_active:
			close_screen()
		elif visible:
			_show_skills_tab()
		elif _player != null and not _player.is_dialogue_active():
			open_screen()
			_show_skills_tab()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("stats", false):
		if visible and _stats_tab_active:
			close_screen()
		elif visible:
			_show_stats_tab()
		elif _player != null and not _player.is_dialogue_active():
			open_screen()
			_show_stats_tab()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quests", false):
		if visible and _quests_tab_active: close_screen()
		elif visible: _show_quests_tab()
		elif _player != null and not _player.is_dialogue_active(): open_screen(); _show_quests_tab()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_set_active_tab(_active_tab + 1)
		get_viewport().set_input_as_handled()
	elif visible and _skills_tab_active and event.is_action_pressed("interact", false):
		_confirm_skill_action()
		get_viewport().set_input_as_handled()
	elif visible and _stats_tab_active and event.is_action_pressed("interact", false):
		_allocate_selected_stat()
		get_viewport().set_input_as_handled()


func open_screen() -> void:
	if _inventory == null:
		return
	visible = true
	_show_tab(false)
	_refresh()
	_emit_event("inventory_opened")


func close_screen() -> void:
	if not visible:
		return
	visible = false
	_emit_event("inventory_closed")


func _refresh() -> void:
	if _skills_tab_active:
		return
	_items = _inventory.get_owned_items()
	_selected_index = clampi(_selected_index, 0, maxi(_items.size() - 1, 0))
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_empty_label.visible = _items.is_empty()
	if _items.is_empty():
		_clear_details()
		return
	for item_index in _items.size():
		var item: Dictionary = _items[item_index] as Dictionary
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_item.bind(item_index))
		_list.add_child(button)
	_refresh_selection()


func _select_item(item_index: int) -> void:
	if item_index < 0 or item_index >= _items.size():
		return
	_selected_index = item_index
	_refresh_selection()


func _refresh_selection() -> void:
	if _items.is_empty():
		return
	_selected_index = clampi(_selected_index, 0, _items.size() - 1)
	for item_index in _list.get_child_count():
		var item: Dictionary = _items[item_index] as Dictionary
		var button: Button = _list.get_child(item_index) as Button
		button.text = ("> " if item_index == _selected_index else "  ") + "%s x%d" % [str(item.get("display_name", "Item")), int(item.get("amount", 0))]
	var selected_item: Dictionary = _items[_selected_index] as Dictionary
	var definition: Dictionary = _inventory.get_item_definition(str(selected_item.get("item_id", "")))
	_name_label.text = str(definition.get("display_name", ""))
	_description_label.text = str(definition.get("description", ""))
	_category_label.text = "Category: %s" % str(definition.get("item_type", ""))
	_value_label.text = "Value: %d" % int(definition.get("base_value", 0))
	_owned_label.text = "Owned: %d" % int(selected_item.get("amount", 0))
	var modifiers: Dictionary = definition.get("stat_modifiers", {}) as Dictionary
	if not modifiers.is_empty():
		_owned_label.text += "\n" + _format_modifiers(modifiers)
	var slot: String = str(definition.get("equip_slot", ""))
	_equip_button.visible = not slot.is_empty()
	_equip_button.text = "Unequip" if not slot.is_empty() and _equipment.get_equipped_item(slot) == str(selected_item.get("item_id", "")) else "Equip"
	if _equipment_tab_active:
		_refresh_equipment_panel()


func _clear_details() -> void:
	_name_label.text = ""
	_description_label.text = ""
	_category_label.text = ""
	_value_label.text = ""
	_owned_label.text = ""
	_equip_button.visible = false
	_skill_assignment_label.visible = false
	_refresh_equipment_panel()


func _toggle_equipment() -> void:
	if _equipment_tab_active:
		if _equipment.unequip_slot(_selected_slot):
			_refresh_slot_cards()
			_refresh_selected_slot()
			_refresh_stat_cards()
		return
	if _items.is_empty() or _equipment == null:
		return
	var item_id: String = str((_items[_selected_index] as Dictionary).get("item_id", ""))
	var slot: String = str(_inventory.get_item_definition(item_id).get("equip_slot", ""))
	if _equipment.get_equipped_item(slot) == item_id:
		_equipment.unequip_slot(slot)
	else:
		_equipment.equip_item(item_id)
	_refresh_selection()


func _refresh_equipment_panel() -> void:
	if _equipment == null:
		return
	var lines: PackedStringArray = ["Equipment"]
	for slot in EquipmentSystem.SLOTS:
		var item_id := _equipment.get_equipped_item(slot)
		var item_name := "Empty" if item_id.is_empty() else str(_inventory.get_item_definition(item_id).get("display_name", item_id))
		lines.append("%s: %s" % [slot.capitalize().replace("_", " "), item_name])
	var stats: Dictionary = _player.get_final_stats() if _player != null else _equipment.get_final_stats()
	var max_hp: int = _player.get_current_max_hp() if _player != null else 100
	lines.append("HP %d  ATK %d  DEF %d  MOB %d" % [max_hp, int(stats.get("attack", 0)), int(stats.get("defense", 0)), int(stats.get("mobility", 0))])
	_equipment_label.text = "\n".join(lines)


func _show_inventory_tab() -> void:
	_show_tab(false)


func _show_tab(show_equipment: bool) -> void:
	_set_active_tab(1 if show_equipment else 0)


func _set_active_tab(tab_index: int) -> void:
	_active_tab = posmod(tab_index, 5)
	_equipment_tab_active = _active_tab == 1
	_skills_tab_active = _active_tab == 2
	_stats_tab_active = _active_tab == 3
	_quests_tab_active = _active_tab == 4
	# The unified panel owns one content state; rebuilding prevents reused slot cards
	# or details from remaining over the other tab.
	if _active_tab == 0:
		_show_inventory_content()
	elif _active_tab == 1:
		_show_equipment_content()
	elif _active_tab == 2:
		_show_skills_content()
	elif _active_tab == 3:
		_show_stats_content()
	else:
		_show_quests_content()


func _show_inventory_content() -> void:
	_list_column.visible = true
	$Panel/Margin/HBox/ListColumn/Title.text = "INVENTORY"
	$Panel/Margin/HBox/ListColumn/Hint.visible = true
	for child in _details.get_children():
		child.visible = child != _equipment_label and child != _skill_assignment_label and child != _stats_derived
	_equipment_label.visible = false
	_skill_assignment_label.visible = false
	_stats_derived.visible = false
	_skill_points_label.visible = false
	_stats_xp_bar.visible = false
	_character_column.visible = false
	_inventory_tab.disabled = true
	_equipment_tab.disabled = false
	_skills_tab.disabled = false
	_stats_tab.disabled = false
	if visible and _inventory != null:
		_refresh()


func _show_equipment_tab() -> void:
	_show_tab(true)


func _show_equipment_content() -> void:
	_list_column.visible = true
	_character_column.visible = true
	$Panel/Margin/HBox/ListColumn/Title.text = "EQUIPMENT SLOTS"
	$Panel/Margin/HBox/ListColumn/EmptyLabel.visible = false
	$Panel/Margin/HBox/ListColumn/Hint.visible = false
	for child in _details.get_children():
		child.visible = child != _equipment_label and child != _skill_assignment_label and child != _stats_derived
	_equipment_label.visible = false
	_skill_assignment_label.visible = false
	_stats_derived.visible = false
	_skill_points_label.visible = false
	_stats_xp_bar.visible = false
	_refresh_slot_cards()
	_refresh_selected_slot()
	_refresh_stat_cards()
	_inventory_tab.disabled = false
	_equipment_tab.disabled = true
	_skills_tab.disabled = false
	_stats_tab.disabled = false


func _show_skills_tab() -> void:
	_skill_assignment_mode = false
	_set_active_tab(2)


func _show_stats_tab() -> void:
	_skill_assignment_mode = false
	_set_active_tab(3)

func _show_quests_tab() -> void:
	_skill_assignment_mode = false
	_set_active_tab(4)

func _show_quests_content() -> void:
	_list_column.visible = true
	$Panel/Margin/HBox/ListColumn/Title.text = "QUEST LOG"
	$Panel/Margin/HBox/ListColumn/EmptyLabel.visible = false
	$Panel/Margin/HBox/ListColumn/Hint.visible = true
	$Panel/Margin/HBox/ListColumn/Hint.text = "J / Esc: Close     Arrows: Select"
	_skill_points_label.visible = false; _stats_xp_bar.visible = false; _character_column.visible = false
	for child in _details.get_children(): child.visible = child != _equipment_label and child != _skill_assignment_label and child != _stats_derived
	_equipment_label.visible = false; _skill_assignment_label.visible = false; _stats_derived.visible = false
	_inventory_tab.disabled = false; _equipment_tab.disabled = false; _skills_tab.disabled = false; _stats_tab.disabled = false; _quests_tab.disabled = true
	_refresh_quests()

func _refresh_quests() -> void:
	for child in _list.get_children(): _list.remove_child(child); child.queue_free()
	if _quest_system == null: return
	var quests: Array[Dictionary] = _quest_system.get_quests()
	if quests.is_empty(): _name_label.text = "No quests"; return
	_selected_quest_index = clampi(_selected_quest_index, 0, quests.size() - 1)
	for index: int in quests.size():
		var quest: Dictionary = quests[index]; var button := Button.new(); button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = ("> " if index == _selected_quest_index else "  ") + "%s [%s]" % [str(quest.get("display_name", "Quest")), str(quest.get("state", ""))]
		button.pressed.connect(_select_quest.bind(index)); _list.add_child(button)
	_show_quest_details(quests[_selected_quest_index])

func _select_quest(index: int) -> void:
	_selected_quest_index = index; _refresh_quests()

func _show_quest_details(quest: Dictionary) -> void:
	_name_label.text = str(quest.get("display_name", "Quest")); _description_label.text = str(quest.get("description", ""))
	_category_label.text = "State: " + str(quest.get("state", ""))
	_value_label.text = _quest_system.get_objective_text(str(quest.get("quest_id", "")))
	var rewards: Dictionary = quest.get("rewards", {}) as Dictionary
	_owned_label.text = "Rewards: %d XP" % int(rewards.get("xp", 0))
	for reward: Dictionary in rewards.get("items", []) as Array: _owned_label.text += "\n%s x%d" % [str(reward.get("item_id", "")), int(reward.get("quantity", 0))]


func _show_skills_content() -> void:
	_list_column.visible = true
	$Panel/Margin/HBox/ListColumn/Title.text = "SKILL TREE"
	$Panel/Margin/HBox/ListColumn/EmptyLabel.visible = false
	$Panel/Margin/HBox/ListColumn/Hint.visible = true
	$Panel/Margin/HBox/ListColumn/Hint.text = "Arrows: Navigate   Enter: Learn / Assign   Esc: Back"
	_skill_points_label.visible = true
	_stats_xp_bar.visible = false
	for child in _details.get_children():
		child.visible = child != _equipment_label and child != _stats_derived
	_equipment_label.visible = false
	_skill_assignment_label.visible = true
	_stats_derived.visible = false
	_character_column.visible = false
	_inventory_tab.disabled = false
	_equipment_tab.disabled = false
	_skills_tab.disabled = true
	_stats_tab.disabled = false
	_inventory_tab.release_focus()
	_equipment_tab.release_focus()
	_skills_tab.release_focus()
	_refresh_skill_tree()
	_refresh_skill_details()


func _show_stats_content() -> void:
	_list_column.visible = true
	$Panel/Margin/HBox/ListColumn/Title.text = "CHARACTER STATS"
	$Panel/Margin/HBox/ListColumn/EmptyLabel.visible = false
	$Panel/Margin/HBox/ListColumn/Hint.visible = true
	$Panel/Margin/HBox/ListColumn/Hint.text = "Arrows: Select Base Stat   Enter: Spend Point   C / Esc: Close"
	_skill_points_label.visible = true
	_stats_xp_bar.visible = true
	for child in _details.get_children():
		child.visible = child == _stats_derived
	_equipment_label.visible = false
	_skill_assignment_label.visible = false
	_stats_derived.visible = true
	_character_column.visible = false
	_inventory_tab.disabled = false
	_equipment_tab.disabled = false
	_skills_tab.disabled = false
	_stats_tab.disabled = true
	_inventory_tab.release_focus()
	_equipment_tab.release_focus()
	_skills_tab.release_focus()
	_stats_tab.release_focus()
	_refresh_stats_tab()


func _refresh_stats_tab() -> void:
	if _player == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_stat_plus_buttons.clear()
	var required_xp: int = maxi(_player.get_xp_required_for_level(), 1)
	_stats_xp_bar.max_value = required_xp
	_stats_xp_bar.value = clampf(float(_player.get_current_xp()), 0.0, float(required_xp))
	_skill_points_label.text = "Stat Points: %d    Skill Points: %d" % [_player.get_stat_points(), _player.get_skill_points()]
	var level_label: Label = Label.new()
	level_label.text = "LEVEL %d" % _player.get_level()
	level_label.add_theme_font_size_override("font_size", 20)
	_list.add_child(level_label)
	var xp_label: Label = Label.new()
	xp_label.text = "XP  %d / %d  (next level)" % [_player.get_current_xp(), required_xp]
	_list.add_child(xp_label)
	var header: Label = Label.new()
	header.text = "BASE STATS"
	header.add_theme_font_size_override("font_size", 16)
	_list.add_child(header)
	var base_stats: Dictionary = _player.get_base_stats()
	var stat_names: Array[String] = ["hp", "attack", "defense", "mobility", "luck"]
	_selected_stat_index = clampi(_selected_stat_index, 0, stat_names.size() - 1)
	for stat_index in stat_names.size():
		var stat_name: String = stat_names[stat_index]
		var stat_row: HBoxContainer = HBoxContainer.new()
		stat_row.custom_minimum_size = Vector2(0, 34)
		stat_row.add_theme_constant_override("separation", 8)
		stat_row.modulate = Color(0.82, 0.9, 1.0, 1.0) if stat_index == _selected_stat_index else Color.WHITE
		var stat_name_label: Label = Label.new()
		stat_name_label.custom_minimum_size = Vector2(110, 30)
		stat_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_name_label.text = ("> " if stat_index == _selected_stat_index else "  ") + _stat_display_name(stat_name)
		var stat_value_label: Label = Label.new()
		stat_value_label.custom_minimum_size = Vector2(52, 30)
		stat_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_value_label.text = str(int(base_stats.get(stat_name, 0)))
		var plus_button: Button = Button.new()
		plus_button.custom_minimum_size = Vector2(34, 30)
		plus_button.focus_mode = Control.FOCUS_NONE
		plus_button.text = "+"
		plus_button.tooltip_text = "Increase %s by 1" % _stat_display_name(stat_name)
		plus_button.disabled = _player.get_stat_points() <= 0
		plus_button.pressed.connect(_allocate_stat_from_button.bind(stat_name))
		stat_row.add_child(stat_name_label)
		stat_row.add_child(stat_value_label)
		stat_row.add_child(plus_button)
		_list.add_child(stat_row)
		_stat_plus_buttons.append(plus_button)
	var derived_header: Label = Label.new()
	derived_header.text = "FINAL / DERIVED STATS"
	derived_header.add_theme_font_size_override("font_size", 18)
	_clear_stats_derived()
	_stats_derived.add_child(derived_header)
	var final_stats: Dictionary = _player.get_final_stats()
	var base_values: Dictionary = _player.get_base_stats()
	var derived_stats: Array[Dictionary] = [
		{"name": "Max HP", "value": _player.get_current_max_hp(), "base": -1},
		{"name": "Attack", "value": int(final_stats.get("attack", 0)), "base": int(base_values.get("attack", 0))},
		{"name": "Defense", "value": int(final_stats.get("defense", 0)), "base": int(base_values.get("defense", 0))},
		{"name": "Mobility", "value": int(final_stats.get("mobility", 0)), "base": int(base_values.get("mobility", 0))},
		{"name": "Luck", "value": int(final_stats.get("luck", 0)), "base": int(base_values.get("luck", 0))},
	]
	for stat: Dictionary in derived_stats:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label: Label = Label.new()
		name_label.text = str(stat["name"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label: Label = Label.new()
		value_label.custom_minimum_size = Vector2(48, 28)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.text = str(int(stat["value"]))
		row.add_child(name_label)
		row.add_child(value_label)
		var base_value: int = int(stat["base"])
		if base_value >= 0:
			var delta_label: Label = Label.new()
			delta_label.custom_minimum_size = Vector2(68, 28)
			delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var delta: int = int(stat["value"]) - base_value
			delta_label.text = "(%+d gear)" % delta if delta != 0 else ""
			row.add_child(delta_label)
		_stats_derived.add_child(row)
	var current_hp_label: Label = Label.new()
	current_hp_label.text = "Current HP: %d / %d" % [_player.current_hp, _player.get_current_max_hp()]
	_stats_derived.add_child(current_hp_label)
	var derived_hint: Label = Label.new()
	derived_hint.text = "Final values include equipment."
	derived_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_derived.add_child(derived_hint)
	_refresh_stat_details(stat_names[_selected_stat_index])


func _clear_stats_derived() -> void:
	for child in _stats_derived.get_children():
		_stats_derived.remove_child(child)
		child.queue_free()


func _select_stat(stat_index: int) -> void:
	_selected_stat_index = clampi(stat_index, 0, 4)
	_refresh_stats_tab()


func _allocate_stat_from_button(stat_name: String) -> void:
	if _player == null or _player.get_stat_points() <= 0:
		return
	var stat_names: Array[String] = ["hp", "attack", "defense", "mobility", "luck"]
	if not stat_names.has(stat_name):
		return
	_selected_stat_index = stat_names.find(stat_name)
	if _player.allocate_stat(stat_name):
		_refresh_stats_tab()


func _refresh_stat_details(stat_name: String) -> void:
	var base_stats: Dictionary = _player.get_base_stats()
	_name_label.text = _stat_display_name(stat_name)
	_description_label.text = "Permanent BaseStat. Enter / Space spends one Stat Point."
	_category_label.text = "Base Value: %d" % int(base_stats.get(stat_name, 0))
	_value_label.text = "Stat Points: %d" % _player.get_stat_points()
	_owned_label.text = "Current Max HP: %d" % _player.get_current_max_hp()
	_equip_button.visible = false
	_skill_assignment_label.visible = false


func _stat_display_name(stat_name: String) -> String:
	return {"hp": "HP", "attack": "Attack", "defense": "Defense", "mobility": "Mobility"}.get(stat_name, stat_name)


func _refresh_slot_cards() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for slot in EquipmentSystem.SLOTS:
		var item_id: String = _equipment.get_equipped_item(slot)
		var item_name: String = "Empty" if item_id.is_empty() else str(_inventory.get_item_definition(item_id).get("display_name", item_id))
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 44)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.text = ("> " if slot == _selected_slot else "  ") + "%s\n     %s" % [slot.capitalize().replace("_", " "), item_name]
		card.pressed.connect(_select_slot.bind(slot))
		_list.add_child(card)


func _refresh_skill_tree() -> void:
	if _skill_system == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var skill_ids: Array[String] = _skill_system.get_skill_ids()
	_selected_skill_index = clampi(_selected_skill_index, 0, maxi(skill_ids.size() - 1, 0))
	_skill_points_label.text = "Skill Points: %d" % _skill_system.get_skill_points()
	if skill_ids.is_empty():
		return
	for skill_index in skill_ids.size():
		var skill_id: String = skill_ids[skill_index]
		var definition: Dictionary = _skill_system.get_skill_definition(skill_id)
		var state: String = _skill_system.get_skill_state(skill_id)
		if skill_index > 0:
			var connector: Label = Label.new()
			connector.text = "        |\n        v"
			connector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_list.add_child(connector)
		var card: Button = Button.new()
		card.custom_minimum_size = Vector2(250, 58)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.focus_mode = Control.FOCUS_NONE
		var prerequisites: Array = definition.get("prerequisites", []) as Array
		var relation_text: String = ""
		if not prerequisites.is_empty():
			relation_text = "\n  requires: " + str(prerequisites[0])
		card.text = ("> " if skill_index == _selected_skill_index else "  ") + "[%s] %s%s" % [state, str(definition.get("display_name", skill_id)), relation_text]
		card.modulate = _skill_state_color(state)
		card.pressed.connect(_select_skill.bind(skill_index))
		_list.add_child(card)


func _skill_state_color(state: String) -> Color:
	match state:
		"LEARNED":
			return Color(0.65, 1.0, 0.7, 1.0)
		"AVAILABLE":
			return Color(1.0, 0.9, 0.55, 1.0)
	return Color(0.62, 0.68, 0.75, 1.0)


func _select_skill(skill_index: int) -> void:
	if _skill_system == null:
		return
	var skill_ids: Array[String] = _skill_system.get_skill_ids()
	if skill_index < 0 or skill_index >= skill_ids.size():
		return
	_selected_skill_index = skill_index
	_skill_assignment_mode = false
	_refresh_skill_tree()
	_refresh_skill_details()


func _refresh_skill_details() -> void:
	if _skill_system == null:
		return
	var skill_ids: Array[String] = _skill_system.get_skill_ids()
	if skill_ids.is_empty():
		_clear_details()
		return
	_selected_skill_index = clampi(_selected_skill_index, 0, skill_ids.size() - 1)
	var skill_id: String = skill_ids[_selected_skill_index]
	var definition: Dictionary = _skill_system.get_skill_definition(skill_id)
	var state: String = _skill_system.get_skill_state(skill_id)
	_name_label.text = str(definition.get("display_name", skill_id))
	_description_label.text = str(definition.get("description", ""))
	_category_label.text = "Type: %s   State: %s" % [str(definition.get("skill_type", "")), state]
	_value_label.text = "Cooldown: %.1f sec" % float(definition.get("cooldown", 0.0))
	_owned_label.text = "Skill Point Cost: %d" % _skill_system.get_skill_point_cost(skill_id)
	var multiplier: float = float(definition.get("damage_multiplier", 1.0))
	if str(definition.get("skill_type", "")).to_upper() == "ACTIVE":
		_owned_label.text += "\nDamage: %d%% ATK" % roundi(multiplier * 100.0)
	_equip_button.visible = false
	_skill_assignment_label.visible = true
	if _skill_assignment_mode:
		_skill_assignment_label.text = "Assign to: %s\nQ / W / E / R choose slot; Enter confirms; Esc cancels" % _skill_slot_name(_skill_assignment_slot_index)
	elif state == "AVAILABLE":
		if _skill_system.get_skill_points() < _skill_system.get_skill_point_cost(skill_id):
			_skill_assignment_label.text = "Not enough skill points"
		else:
			_skill_assignment_label.text = "Enter: Learn skill"
	elif state == "LEARNED" and str(definition.get("skill_type", "")).to_upper() == "ACTIVE":
		_skill_assignment_label.text = "Enter: Assign to Q / W / E / R"
	else:
		_skill_assignment_label.text = "Prerequisites not learned"


func _skill_slot_name(slot_index: int) -> String:
	return ["Q", "W", "E", "R"][posmod(slot_index, 4)]


func _select_slot(slot: String) -> void:
	_selected_slot = slot
	_refresh_slot_cards()
	_refresh_selected_slot()


func _refresh_selected_slot() -> void:
	var item_id: String = _equipment.get_equipped_item(_selected_slot)
	if item_id.is_empty():
		_name_label.text = _selected_slot.capitalize().replace("_", " ")
		_description_label.text = "No item equipped"
		_category_label.text = ""
		_value_label.text = ""
		_owned_label.text = ""
		_equip_button.visible = false
		return
	var definition: Dictionary = _inventory.get_item_definition(item_id)
	_name_label.text = str(definition.get("display_name", item_id))
	_description_label.text = str(definition.get("description", ""))
	_category_label.text = "Category: %s  Slot: %s" % [str(definition.get("item_type", "")), _selected_slot.capitalize().replace("_", " ")]
	_value_label.text = "Value: %d" % int(definition.get("base_value", 0))
	_owned_label.text = _format_modifiers(definition.get("stat_modifiers", {}) as Dictionary)
	_equip_button.visible = true
	_equip_button.text = "Unequip"


func _refresh_stat_cards() -> void:
	for child in _character_stats.get_children():
		child.queue_free()
	var stats: Dictionary = _player.get_final_stats() if _player != null else _equipment.get_final_stats()
	for stat_name in ["max_hp", "attack", "defense", "mobility", "luck"]:
		var label := Label.new()
		var short_name: String = {"max_hp":"HP", "attack":"ATK", "defense":"DEF", "mobility":"MOB", "luck":"LUCK"}.get(stat_name, stat_name)
		var value: int = _player.get_current_max_hp() if stat_name == "max_hp" and _player != null else int(stats.get(stat_name, 0))
		label.text = "%s   %d" % [short_name, value]
		_character_stats.add_child(label)


func _format_modifiers(modifiers: Dictionary) -> String:
	var names: Dictionary = {"attack": "Attack", "defense": "Defense", "mobility": "Mobility", "luck": "Luck"}
	var lines: PackedStringArray = []
	for stat_key in modifiers.keys():
		if str(stat_key) == "max_hp":
			continue
		var value: int = int(modifiers.get(stat_key, 0))
		if value != 0:
			lines.append("%s %+d" % [str(names.get(str(stat_key), stat_key)), value])
	return "\n".join(lines)


func _on_inventory_changed() -> void:
	if visible and not _skills_tab_active and not _stats_tab_active and not _equipment_tab_active:
		_refresh()


func _on_skills_changed() -> void:
	if visible and _skills_tab_active:
		_refresh_skill_tree()
		_refresh_skill_details()


func _on_progression_changed(_current_xp: int, _required_xp: int) -> void:
	if visible and _stats_tab_active:
		_refresh_stats_tab()


func _on_progression_level_changed(_level: int) -> void:
	if visible and _stats_tab_active:
		_refresh_stats_tab()


func _on_progression_base_stats_changed(_base_stats: Dictionary) -> void:
	if visible:
		if _stats_tab_active:
			_refresh_stats_tab()
		elif _equipment_tab_active:
			_refresh_stat_cards()


func _on_progression_points_changed(_points: int) -> void:
	if not visible:
		return
	if _stats_tab_active:
		_refresh_stats_tab()
	elif _skills_tab_active:
		_refresh_skill_tree()
		_refresh_skill_details()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause", false):
		if _skills_tab_active and _skill_assignment_mode:
			_skill_assignment_mode = false
			_refresh_skill_details()
		else:
			close_screen()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_set_active_tab(_active_tab + 1)
	elif event.is_action_pressed("skills", false):
		if _skills_tab_active:
			close_screen()
		else:
			_show_skills_tab()
	elif _skills_tab_active and event.is_action_pressed("move_up", false):
		_move_skill_selection(-1)
	elif _skills_tab_active and event.is_action_pressed("move_down", false):
		_move_skill_selection(1)
	elif _skills_tab_active and event.is_action_pressed("move_left", false):
		_move_skill_selection(-1)
	elif _skills_tab_active and event.is_action_pressed("move_right", false):
		_move_skill_selection(1)
	elif _stats_tab_active and event.is_action_pressed("move_up", false):
		_select_stat(posmod(_selected_stat_index - 1, 5))
	elif _stats_tab_active and event.is_action_pressed("move_down", false):
		_select_stat(posmod(_selected_stat_index + 1, 5))
	elif _stats_tab_active and event.is_action_pressed("move_left", false):
		_select_stat(posmod(_selected_stat_index - 1, 5))
	elif _stats_tab_active and event.is_action_pressed("move_right", false):
		_select_stat(posmod(_selected_stat_index + 1, 5))
	elif _quests_tab_active and event.is_action_pressed("move_up", false):
		var quest_count: int = _quest_system.get_quests().size() if _quest_system != null else 0
		if quest_count > 0: _selected_quest_index = posmod(_selected_quest_index - 1, quest_count); _refresh_quests()
	elif _quests_tab_active and event.is_action_pressed("move_down", false):
		var quest_count: int = _quest_system.get_quests().size() if _quest_system != null else 0
		if quest_count > 0: _selected_quest_index = posmod(_selected_quest_index + 1, quest_count); _refresh_quests()
	elif _skills_tab_active and _skill_assignment_mode and event.is_action_pressed("skill_1", false):
		_skill_assignment_slot_index = 0
		_refresh_skill_details()
	elif _skills_tab_active and _skill_assignment_mode and event.is_action_pressed("skill_2", false):
		_skill_assignment_slot_index = 1
		_refresh_skill_details()
	elif _skills_tab_active and _skill_assignment_mode and event.is_action_pressed("skill_3", false):
		_skill_assignment_slot_index = 2
		_refresh_skill_details()
	elif _skills_tab_active and _skill_assignment_mode and event.is_action_pressed("skill_4", false):
		_skill_assignment_slot_index = 3
		_refresh_skill_details()
	elif _skills_tab_active and event.is_action_pressed("interact", false):
		_confirm_skill_action()
	elif event.is_action_pressed("move_up", false) and (_equipment_tab_active or not _items.is_empty()):
		if _equipment_tab_active:
			_select_equipment_offset(-1)
		else:
			_select_item(posmod(_selected_index - 1, _items.size()))
	elif event.is_action_pressed("move_down", false) and (_equipment_tab_active or not _items.is_empty()):
		if _equipment_tab_active:
			_select_equipment_offset(1)
		else:
			_select_item(posmod(_selected_index + 1, _items.size()))
	elif event.is_action_pressed("interact", false):
		_toggle_equipment()
	else:
		return
	get_viewport().set_input_as_handled()


func _move_skill_selection(offset: int) -> void:
	if _skill_system == null:
		return
	var skill_ids: Array[String] = _skill_system.get_skill_ids()
	if skill_ids.is_empty():
		return
	_selected_skill_index = posmod(_selected_skill_index + offset, skill_ids.size())
	_skill_assignment_mode = false
	_refresh_skill_tree()
	_refresh_skill_details()


func _confirm_skill_action() -> void:
	if _skill_system == null:
		return
	var skill_ids: Array[String] = _skill_system.get_skill_ids()
	if skill_ids.is_empty():
		return
	var skill_id: String = skill_ids[_selected_skill_index]
	var definition: Dictionary = _skill_system.get_skill_definition(skill_id)
	var state: String = _skill_system.get_skill_state(skill_id)
	if _skill_assignment_mode:
		if _skill_system.assign_skill(skill_id, "skill_%d" % (_skill_assignment_slot_index + 1)):
			_skill_assignment_mode = false
			_refresh_skill_details()
		return
	if state == "AVAILABLE":
		_skill_system.learn_skill(skill_id)
		_refresh_skill_tree()
		_refresh_skill_details()
		return
	if state == "LEARNED" and str(definition.get("skill_type", "")).to_upper() == "ACTIVE":
		_skill_assignment_mode = true
		_skill_assignment_slot_index = 0
		_refresh_skill_details()


func _allocate_selected_stat() -> void:
	if _player == null:
		return
	var stat_names: Array[String] = ["hp", "attack", "defense", "mobility", "luck"]
	var stat_name: String = stat_names[clampi(_selected_stat_index, 0, stat_names.size() - 1)]
	if _player.allocate_stat(stat_name):
		_refresh_stats_tab()
		return
	_refresh_stat_details(stat_name)
	_description_label.text = "No Stat Points available."


func _select_equipment_offset(offset: int) -> void:
	var slot_index: int = EquipmentSystem.SLOTS.find(_selected_slot)
	_selected_slot = EquipmentSystem.SLOTS[posmod(slot_index + offset, EquipmentSystem.SLOTS.size())]
	_refresh_slot_cards()
	_refresh_selected_slot()


func _emit_event(signal_name: StringName) -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal(signal_name)
