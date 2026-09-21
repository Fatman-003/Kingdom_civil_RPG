extends SceneTree

const MOVEMENT_TIMEOUT_FRAMES: int = 240

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(
		GridUtils.grid_to_world(Vector2i(2, 3)) == Vector2(80, 112),
		"grid_to_world returns the center of a 32x32 cell"
	)
	_check(
		GridUtils.world_to_grid(Vector2(80, 112)) == Vector2i(2, 3),
		"world_to_grid returns the matching logical cell"
	)

	var room_scene: PackedScene = load("res://scenes/world/grid_test_room.tscn") as PackedScene
	var player_scene: PackedScene = load("res://scenes/characters/player.tscn") as PackedScene
	_check(room_scene != null, "Grid test room scene loads")
	_check(player_scene != null, "Player scene loads")
	if room_scene == null or player_scene == null:
		_finish()
		return

	var room: GridTestRoom = room_scene.instantiate() as GridTestRoom
	# This checks open-floor movement, not random NPC obstruction.
	for npc: GridNpc in room.get_npcs():
		npc.wandering_enabled = false
	var player: Player = player_scene.instantiate() as Player
	root.add_child(room)
	root.add_child(player)
	player.configure(room, room.get_player_spawn_grid_position())
	await process_frame

	var player_camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	_check(player_camera != null and player_camera.enabled, "Player owns an enabled following Camera2D")
	_check(room.can_move_to(room.get_player_spawn_grid_position()), "A valid Town floor cell is walkable")
	_check(not room.can_move_to(Vector2i(11, 3)), "An obstacle cell is blocked")
	_check(not room.can_move_to(Vector2i(-1, 6)), "An out-of-bounds cell is blocked")
	_check(player.grid_position == room.get_player_spawn_grid_position(), "Player uses the room-owned Town spawn cell")

	var expected_after_right: Vector2i = player.grid_position + Vector2i.RIGHT
	var moved_right: bool = player.request_move(Vector2i.RIGHT)
	_check(moved_right, "Player accepts a valid cardinal move")
	await _wait_until_idle(player)
	_check(player.grid_position == expected_after_right, "Player completes exactly one cell transition")
	_check(
		player.position == GridUtils.grid_to_world(expected_after_right),
		"Player finishes exactly aligned to the destination grid cell"
	)

	player.set_grid_position(Vector2i(10, 3))
	_check(
		not player.request_move(Vector2i.RIGHT),
		"Player cannot enter an obstacle cell"
	)
	_check(player.grid_position == Vector2i(10, 3), "Obstacle collision keeps logical position stable")

	player.set_grid_position(Vector2i(1, 1))
	_check(
		not player.request_move(Vector2i.LEFT),
		"Player cannot leave the room bounds"
	)
	_check(player.grid_position == Vector2i(1, 1), "Boundary collision keeps logical position stable")
	_check(
		not player.request_move(Vector2i(1, 1)),
		"Player rejects diagonal movement requests"
	)

	player.set_grid_position(room.get_player_spawn_grid_position())
	await _hold_action_for_steps(player, "move_up", Vector2i.UP, 2)
	player.set_grid_position(room.get_player_spawn_grid_position())
	await _hold_action_for_steps(player, "move_down", Vector2i.DOWN, 2)
	player.set_grid_position(room.get_player_spawn_grid_position())
	await _hold_action_for_steps(player, "move_left", Vector2i.LEFT, 2)
	player.set_grid_position(room.get_player_spawn_grid_position())
	await _hold_action_for_steps(player, "move_right", Vector2i.RIGHT, 2)

	var movement_test_origin: Vector2i = Vector2i(30, 24)
	player.set_grid_position(movement_test_origin)
	await _move_cells(player, Vector2i.UP, 5)
	await _move_cells(player, Vector2i.DOWN, 5)
	await _move_cells(player, Vector2i.LEFT, 5)
	await _move_cells(player, Vector2i.RIGHT, 5)
	_check(player.grid_position == movement_test_origin, "Five-cell movement in each direction returns to the origin")
	await _move_cells(player, Vector2i.UP, 1)
	await _move_cells(player, Vector2i.RIGHT, 1)
	await _move_cells(player, Vector2i.DOWN, 1)
	await _move_cells(player, Vector2i.LEFT, 1)
	_check(player.grid_position == movement_test_origin, "Quick Up-Right-Down-Left alternation stays stable")
	_check(player.position == GridUtils.grid_to_world(player.grid_position), "Repeated movement remains grid-aligned")
	_check(player.get_facing_name() == "LEFT", "Facing direction updates from movement input")

	player.queue_free()
	room.queue_free()
	await process_frame
	_finish()


func _hold_action_for_steps(
	player: Player, action: StringName, direction: Vector2i, minimum_steps: int
) -> void:
	var starting_grid_position: Vector2i = player.grid_position
	Input.action_press(action)
	var frame_count: int = 0
	while _grid_distance(starting_grid_position, player.grid_position, direction) < minimum_steps and frame_count < MOVEMENT_TIMEOUT_FRAMES:
		await process_frame
		frame_count += 1
	Input.action_release(action)
	await _wait_until_idle(player)
	_check(
		_grid_distance(starting_grid_position, player.grid_position, direction) >= minimum_steps,
		"Holding %s continues walking across multiple grid cells" % action
	)


func _move_cells(player: Player, direction: Vector2i, count: int) -> void:
	for _step: int in range(count):
		_check(player.request_move(direction), "Player begins a requested cardinal cell transition")
		await _wait_until_idle(player)


func _grid_distance(start: Vector2i, current: Vector2i, direction: Vector2i) -> int:
	var delta: Vector2i = current - start
	return abs(delta.x * direction.x + delta.y * direction.y)


func _wait_until_idle(player: Player) -> void:
	var frame_count: int = 0
	while player.is_moving() and frame_count < MOVEMENT_TIMEOUT_FRAMES:
		await process_frame
		frame_count += 1
	_check(not player.is_moving(), "Player movement completes within the expected duration")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures.append(description)
	printerr("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("GRID MOVEMENT SMOKE TEST RESULT: PASS")
		quit(0)
		return

	printerr("GRID MOVEMENT SMOKE TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)
