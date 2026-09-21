extends Node

@onready var _grid_test_room: GridTestRoom = $WorldRoot/GridTestRoom
@onready var _player: Player = $EntityRoot/Player
@onready var _relationship_system: RelationshipSystem = $RelationshipSystem
@onready var _inventory_system: InventorySystem = $InventorySystem
@onready var _inventory_screen: InventoryScreen = $ModalUIRoot/InventoryScreen
@onready var _interaction_menu: NpcInteractionMenu = $UIRoot/NpcInteractionMenu
@onready var _equipment_system: EquipmentSystem = $EquipmentSystem
@onready var _combat_hud: CombatHud = $UIRoot/CombatHud
@onready var _skill_system: SkillSystem = $SkillSystem
@onready var _progression_system: ProgressionSystem = $ProgressionSystem
@onready var _loot_system: LootSystem = $LootSystem
@onready var _quest_system: QuestSystem = $QuestSystem
@onready var _quest_tracker: QuestTracker = $UIRoot/QuestTracker


func _ready() -> void:
	_player.configure(_grid_test_room, _grid_test_room.get_player_spawn_grid_position(), _skill_system, _progression_system, _inventory_system)
	for npc: GridNpc in _grid_test_room.get_npcs():
		_relationship_system.get_relationship(npc.npc_id)
	_seed_development_inventory()
	_equipment_system.configure(_inventory_system)
	_loot_system.configure(_inventory_system)
	_quest_system.configure(_player, _inventory_system)
	_quest_tracker.configure(_quest_system)
	_skill_system.configure(_progression_system)
	_inventory_screen.configure(_inventory_system, _player, _equipment_system, _skill_system, _progression_system, _quest_system)
	_interaction_menu.talk_selected.connect(_on_talk_selected)
	_interaction_menu.gift_selected.connect(_on_gift_selected)
	_combat_hud.configure(_player)
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.connect("gift_flow_requested", _on_gift_flow_requested)


func _seed_development_inventory() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null and bool(manager.get("inventory_seeded")):
		return
	_inventory_system.add_item("apple", 3)
	_inventory_system.add_item("flower", 2)
	_inventory_system.add_item("old_coin", 1)
	_inventory_system.add_item("herb", 2)
	_inventory_system.add_item("healing_potion", 3)
	_inventory_system.add_item("cheap_wine", 1)
	_inventory_system.add_item("training_sword", 1)
	_inventory_system.add_item("wooden_shield", 1)
	_inventory_system.add_item("leather_armor", 1)
	_inventory_system.add_item("simple_helmet", 1)
	_inventory_system.add_item("copper_ring", 1)
	_inventory_system.add_item("traveler_boots", 1)
	if manager != null:
		manager.set("inventory_seeded", true)


func _on_talk_selected(npc: GridNpc) -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal("dialogue_requested", npc)


func _on_gift_selected(npc: GridNpc) -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal("gift_flow_requested", npc)


func _on_gift_flow_requested(npc: Node) -> void:
	$DialogueManager.start_gift_flow(npc)
