extends SceneTree

const MOVEMENT_TIMEOUT_FRAMES: int = 240

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var room_scene: PackedScene = load("res://scenes/world/grid_test_room.tscn") as PackedScene
	var player_scene: PackedScene = load("res://scenes/characters/player.tscn") as PackedScene
	_check(room_scene != null, "Grid test room scene loads")
	_check(player_scene != null, "Player scene loads")
	if room_scene == null or player_scene == null:
		_finish()
		return

	var room: GridTestRoom = room_scene.instantiate() as GridTestRoom
	for npc: GridNpc in room.get_npcs():
		npc.wandering_enabled = false
	var player: Player = player_scene.instantiate() as Player
	root.add_child(room)
	root.add_child(player)
	player.configure(room, room.get_player_spawn_grid_position())
	await process_frame

	var npcs: Array[GridNpc] = room.get_npcs()
	_check(npcs.size() == 4, "Grid test room has three Town NPCs and a Guild Master")
	_check(_has_unique_npc_positions(npcs), "NPC spawns occupy distinct cells")
	for npc: GridNpc in npcs:
		_check(room.can_move_to(npc.grid_position), "%s spawns on a walkable cell" % npc.name)

	var npc_a: GridNpc = room.get_node("NPCs/NPC_A") as GridNpc
	var npc_b: GridNpc = room.get_node("NPCs/NPC_B") as GridNpc
	_check(npc_a != null and npc_b != null, "Named NPC instances exist")
	if npc_a == null or npc_b == null:
		await _cleanup(room, player)
		return

	player.set_grid_position(Vector2i(25, 23))
	npc_a.set_grid_position(Vector2i(24, 23))
	_check(not npc_a.request_move(Vector2i.RIGHT), "NPC cannot enter the player's occupied cell")
	_check(not player.request_move(Vector2i.LEFT), "Player cannot enter an NPC occupied cell")

	player.set_grid_position(room.get_player_spawn_grid_position())
	npc_a.set_grid_position(Vector2i(24, 24))
	npc_b.set_grid_position(Vector2i(26, 24))
	_check(npc_a.request_move(Vector2i.RIGHT), "First NPC reserves a valid destination")
	_check(not npc_b.request_move(Vector2i.LEFT), "Second NPC cannot reserve the same destination")
	await _wait_until_idle(npc_a)
	_check(npc_a.grid_position == Vector2i(25, 24), "Reserved NPC reaches its destination")
	_check(npc_b.grid_position == Vector2i(26, 24), "Blocked NPC remains in its original cell")

	npc_a.set_grid_position(Vector2i(1, 13))
	_check(not npc_a.request_move(Vector2i.LEFT), "NPC cannot leave room bounds")
	npc_a.set_grid_position(Vector2i(3, 18))
	_check(not npc_a.request_move(Vector2i.RIGHT), "NPC cannot enter a blocked environment cell")
	npc_a.set_grid_position(Vector2i(21, 13))
	_check(not npc_a.request_move(Vector2i.UP), "Town NPC cannot wander through the gate into Outskirts")

	npc_a.set_grid_position(Vector2i(25, 25))
	_check(npc_a.request_move(Vector2i.RIGHT), "NPC begins a smooth valid grid move")
	await _wait_until_idle(npc_a)
	_check(npc_a.grid_position == Vector2i(26, 25), "NPC completes one grid cell move")
	_check(
		npc_a.position == GridUtils.grid_to_world(npc_a.grid_position),
		"NPC finishes movement exactly grid-aligned"
	)

	await _cleanup(room, player)


func _has_unique_npc_positions(npcs: Array[GridNpc]) -> bool:
	var occupied_cells: Dictionary = {}
	for npc: GridNpc in npcs:
		if occupied_cells.has(npc.grid_position):
			return false
		occupied_cells[npc.grid_position] = true
	return true


func _wait_until_idle(npc: GridNpc) -> void:
	var frame_count: int = 0
	while npc.is_moving() and frame_count < MOVEMENT_TIMEOUT_FRAMES:
		await process_frame
		frame_count += 1
	_check(not npc.is_moving(), "NPC movement completes within the expected duration")


func _cleanup(room: GridTestRoom, player: Player) -> void:
	room.queue_free()
	player.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures.append(description)
	printerr("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("NPC OCCUPANCY SMOKE TEST RESULT: PASS")
		quit(0)
		return

	printerr("NPC OCCUPANCY SMOKE TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)
