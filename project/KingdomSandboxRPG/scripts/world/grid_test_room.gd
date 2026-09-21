class_name GridTestRoom
extends Node2D

const GRID_WIDTH: int = 48
const GRID_HEIGHT: int = 28
const PLAYER_SPAWN_GRID_POSITION: Vector2i = Vector2i(24, 22)
const TOWN_WALL_Y: int = 12
const GATE_MIN_X: int = 22
const GATE_MAX_X: int = 24

const BLOCKED_CELLS: Array[Vector2i] = [
	Vector2i(11, 3),
	Vector2i(12, 3), Vector2i(9, 4), Vector2i(10, 4),
	Vector2i(35, 4), Vector2i(36, 4), Vector2i(38, 7),
	Vector2i(39, 7), Vector2i(40, 7), Vector2i(31, 8),
	Vector2i(32, 8), Vector2i(33, 8), Vector2i(7, 7),
	Vector2i(8, 7), Vector2i(7, 8), Vector2i(42, 3),
	Vector2i(42, 4),
]

const FLOOR_COLOR: Color = Color("263544")
const GRID_COLOR: Color = Color("4b6170")
const OBSTACLE_COLOR: Color = Color("7c4f54")
const BORDER_COLOR: Color = Color("b58c5a")
const TOWN_COLOR: Color = Color("4b5660")
const OUTSKIRTS_COLOR: Color = Color("29463b")
const ROAD_COLOR: Color = Color("856f52")
const WALL_COLOR: Color = Color("77717a")
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]

@onready var _house: Node2D = $Props/House
@onready var _tree: Node2D = $Props/Tree
@onready var _lamp: Node2D = $Props/Lamp

var _house_base_position: Vector2
var _tree_base_rotation: float
var _lamp_base_rotation: float
var _entity_move_reservations: Dictionary = {}


func _ready() -> void:
	_house_base_position = _house.position
	_tree_base_rotation = _tree.rotation
	_lamp_base_rotation = _lamp.rotation
	for npc: GridNpc in get_npcs():
		npc.configure(self, npc.starting_grid_position)
	for monster_node: Node in $Monsters.get_children():
		var monster: GridMonster = monster_node as GridMonster
		if monster == null:
			continue
		monster.configure(self, monster.starting_grid_position)
		monster.died.connect(_on_monster_died)
	queue_redraw()


func _process(_delta: float) -> void:
	var animation_time: float = Time.get_ticks_msec() * 0.001
	_house.position = _house_base_position + Vector2(0.0, sin(animation_time * 0.8) * 0.35)
	_house.scale = Vector2.ONE * (1.0 + sin(animation_time * 0.8) * 0.003)
	_tree.rotation = _tree_base_rotation + sin(animation_time * 1.15) * 0.025
	_lamp.rotation = _lamp_base_rotation + sin(animation_time * 1.7) * 0.018
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player != null:
		for pickup: LootPickup in $Pickups.get_children():
			if pickup.grid_position == player.grid_position:
				get_parent().get_parent().get_node("InventorySystem").add_item(pickup.item_id, pickup.amount)
				pickup.queue_free()

func debug_attack_at(cell: Vector2i, damage: int, player: Player) -> bool:
	for monster: GridMonster in $Monsters.get_children():
		if monster.grid_position == cell:
			var hit: bool = monster.take_debug_damage(damage, player)
			if hit:
				print("Combat hit: %d damage, %s HP=%d" % [damage, monster.display_name, monster.current_hp])
			return hit
	return false

func _on_monster_died(monster: GridMonster) -> void:
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player != null and monster.last_damage_source == player:
		player.award_experience(monster.xp_reward)
		var event_bus := get_node_or_null("/root/EventBus")
		if event_bus != null:
			event_bus.monster_killed.emit(monster.monster_id)
	var loot_system: LootSystem = get_parent().get_parent().get_node_or_null("LootSystem") as LootSystem
	if loot_system == null:
		push_warning("GridTestRoom: LootSystem is unavailable.")
		return
	var final_luck: int = player.get_final_stats().get("luck", 0) if player != null else 0
	var loot_result: Dictionary = loot_system.resolve_loot(monster.loot_table_id, final_luck)
	var item_amounts: Dictionary = loot_result.get("items", {}) as Dictionary
	if item_amounts.is_empty():
		return
	var pickup_scene: PackedScene = load("res://scenes/world/loot_pickup.tscn") as PackedScene
	for item_id_variant: Variant in item_amounts.keys():
		var pickup: LootPickup = pickup_scene.instantiate() as LootPickup
		$Pickups.add_child(pickup)
		pickup.setup(str(item_id_variant), int(item_amounts[item_id_variant]), monster.grid_position)


func can_move_to(grid_position: Vector2i) -> bool:
	return is_within_bounds(grid_position) and not _is_static_blocked(grid_position)


func try_reserve_entity_move_to(grid_position: Vector2i, entity: Node) -> bool:
	if not can_move_to(grid_position):
		return false
	if entity is GridNpc and not is_town_cell(grid_position):
		return false
	if entity is GridMonster and not (entity as GridMonster).is_training_dummy and not is_outskirts_cell(grid_position):
		return false

	var reserved_by: Variant = _entity_move_reservations.get(grid_position)
	if reserved_by != null and reserved_by != entity:
		return false

	for other_entity: Node in get_tree().get_nodes_in_group("grid_entities"):
		if other_entity != entity and other_entity.get("grid_position") == grid_position:
			return false

	_entity_move_reservations[grid_position] = entity
	return true


func release_entity_move_reservation(grid_position: Vector2i, entity: Node) -> void:
	if _entity_move_reservations.get(grid_position) == entity:
		_entity_move_reservations.erase(grid_position)


func get_chase_step(start: Vector2i, target: Vector2i, entity: Node, attack_range: int) -> Vector2i:
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var goal: Vector2i = Vector2i.ZERO
	var found_goal: bool = false
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current != start and _manhattan_distance(current, target) <= attack_range:
			goal = current
			found_goal = true
			break
		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var next: Vector2i = current + direction
			if came_from.has(next) or not can_move_to(next):
				continue
			if not _is_path_cell_available(next, entity):
				continue
			came_from[next] = current
			frontier.append(next)
	if not found_goal:
		return Vector2i.ZERO
	var first_step: Vector2i = goal
	var parent: Vector2i = came_from[goal]
	while parent != start:
		first_step = parent
		parent = came_from[parent]
	return first_step - start


func _is_path_cell_available(grid_position: Vector2i, entity: Node) -> bool:
	var reserved_by: Variant = _entity_move_reservations.get(grid_position)
	if reserved_by != null and reserved_by != entity:
		return false
	for other_entity: Node in get_tree().get_nodes_in_group("grid_entities"):
		if other_entity != entity and other_entity.get("grid_position") == grid_position:
			return false
	return true


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func get_npcs() -> Array[GridNpc]:
	var npcs: Array[GridNpc] = []
	for child: Node in $NPCs.get_children():
		var npc: GridNpc = child as GridNpc
		if npc != null:
			npcs.append(npc)
	return npcs


func get_interactable_npc_at(grid_position: Vector2i) -> GridNpc:
	for npc: GridNpc in get_npcs():
		if npc.grid_position == grid_position:
			return npc
	return null


func is_within_bounds(grid_position: Vector2i) -> bool:
	return (
		grid_position.x >= 1
		and grid_position.x < GRID_WIDTH - 1
		and grid_position.y >= 1
		and grid_position.y < GRID_HEIGHT - 1
	)


func get_player_spawn_grid_position() -> Vector2i:
	return PLAYER_SPAWN_GRID_POSITION


func is_town_cell(grid_position: Vector2i) -> bool:
	return is_within_bounds(grid_position) and grid_position.y > TOWN_WALL_Y


func is_outskirts_cell(grid_position: Vector2i) -> bool:
	return is_within_bounds(grid_position) and grid_position.y < TOWN_WALL_Y


func can_monster_chase_target(_monster: GridMonster, player: Player) -> bool:
	return player != null and is_outskirts_cell(player.grid_position)


func get_camera_limits() -> Dictionary:
	return {
		"left": 0,
		"top": 0,
		"right": GRID_WIDTH * GridUtils.CELL_SIZE,
		"bottom": GRID_HEIGHT * GridUtils.CELL_SIZE,
	}


func _is_static_blocked(grid_position: Vector2i) -> bool:
	if grid_position.y == TOWN_WALL_Y and (grid_position.x < GATE_MIN_X or grid_position.x > GATE_MAX_X):
		return true
	if BLOCKED_CELLS.has(grid_position):
		return true
	return _is_house_cell(grid_position) or _is_guild_structure_cell(grid_position)


func _is_house_cell(grid_position: Vector2i) -> bool:
	return (
		(grid_position.x >= 4 and grid_position.x <= 8 and grid_position.y >= 18 and grid_position.y <= 20)
		or (grid_position.x >= 37 and grid_position.x <= 41 and grid_position.y >= 18 and grid_position.y <= 20)
	)


func _is_guild_structure_cell(grid_position: Vector2i) -> bool:
	return grid_position.x >= 13 and grid_position.x <= 18 and grid_position.y >= 14 and grid_position.y <= 16


func _draw() -> void:
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var grid_position := Vector2i(x, y)
			var cell_rect := Rect2(
				Vector2(grid_position * GridUtils.CELL_SIZE),
				Vector2.ONE * GridUtils.CELL_SIZE
			)
			var is_border: bool = not is_within_bounds(grid_position)
			var cell_color: Color = BORDER_COLOR if is_border else (TOWN_COLOR if is_town_cell(grid_position) else OUTSKIRTS_COLOR)
			if (grid_position.x >= 22 and grid_position.x <= 24) or (grid_position.y >= 20 and grid_position.x >= 21 and grid_position.x <= 25):
				cell_color = ROAD_COLOR
			if _is_static_blocked(grid_position):
				cell_color = WALL_COLOR if grid_position.y == TOWN_WALL_Y else OBSTACLE_COLOR
			draw_rect(cell_rect, cell_color)
			draw_rect(cell_rect, GRID_COLOR, false, 1.0)
	_draw_landmarks()


func _draw_landmarks() -> void:
	_draw_building(Rect2(4 * 32, 18 * 32, 5 * 32, 3 * 32), Color("a65b4d"), "House")
	_draw_building(Rect2(37 * 32, 18 * 32, 5 * 32, 3 * 32), Color("a65b4d"), "House")
	_draw_building(Rect2(13 * 32, 14 * 32, 6 * 32, 3 * 32), Color("466b93"), "Guild")
	draw_rect(Rect2(8 * 32, 22 * 32, 5 * 32, 3 * 32), Color("506b65"), true)
	draw_rect(Rect2(8 * 32, 22 * 32, 5 * 32, 3 * 32), Color("9aa88a"), false, 2.0)
	draw_circle(GridUtils.grid_to_world(Vector2i(10, 23)), 20.0, Color("4a8ba0"))
	draw_circle(GridUtils.grid_to_world(Vector2i(10, 23)), 12.0, Color("79bfd1"))
	for tree_cell: Vector2i in [Vector2i(7, 6), Vector2i(9, 3), Vector2i(35, 3), Vector2i(40, 6), Vector2i(31, 9), Vector2i(42, 3)]:
		draw_circle(GridUtils.grid_to_world(tree_cell), 13.0, Color("2c6d45"))
		draw_circle(GridUtils.grid_to_world(tree_cell) + Vector2(0, -8), 11.0, Color("3f8a52"))
	draw_rect(Rect2(37 * 32, 7 * 32, 4 * 32, 2 * 32), Color("695d68"), false, 3.0)
	draw_line(GridUtils.grid_to_world(Vector2i(27, 10)), GridUtils.grid_to_world(Vector2i(27, 8)), Color("d4b45a"), 3.0)
	draw_circle(GridUtils.grid_to_world(Vector2i(27, 8)), 5.0, Color("d4b45a"))


func _draw_building(rect: Rect2, roof_color: Color, _label: String) -> void:
	draw_rect(rect, Color("b89369"), true)
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(-6, 4), rect.position + Vector2(rect.size.x * 0.5, -26),
		rect.position + Vector2(rect.size.x + 6, 4),
	]), roof_color)
