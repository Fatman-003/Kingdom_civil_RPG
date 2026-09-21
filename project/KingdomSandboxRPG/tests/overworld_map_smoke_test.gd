extends SceneTree

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load("res://scenes/core/main.tscn") as PackedScene
	_check(main_scene != null, "Main scene loads")
	if main_scene == null:
		_finish()
		return
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	var room: GridTestRoom = main.get_node("WorldRoot/GridTestRoom") as GridTestRoom
	var player: Player = main.get_node("EntityRoot/Player") as Player
	var skills: SkillSystem = main.get_node("SkillSystem") as SkillSystem
	var interaction_menu: NpcInteractionMenu = main.get_node("UIRoot/NpcInteractionMenu") as NpcInteractionMenu
	_check(room != null and player != null and skills != null and interaction_menu != null, "Overworld dependencies exist")
	if room == null or player == null or skills == null or interaction_menu == null:
		_cleanup(main)
		return

	_check(GridTestRoom.GRID_WIDTH == 48 and GridTestRoom.GRID_HEIGHT == 28, "Overworld has expanded 48 by 28 dimensions")
	_check(room.is_town_cell(player.grid_position), "Player spawns inside Town")
	_check(not room.can_move_to(Vector2i(20, GridTestRoom.TOWN_WALL_Y)), "Town wall blocks movement")
	_check(room.can_move_to(Vector2i(23, GridTestRoom.TOWN_WALL_Y)), "Three-cell Town gate is walkable")
	_check(room.is_outskirts_cell(Vector2i(20, 9)), "Outskirts zone is distinct from Town")

	var guild_master: GridNpc = room.get_node("NPCs/GuildMaster") as GridNpc
	_check(guild_master != null and guild_master.npc_id == "guild_master" and not guild_master.wandering_enabled, "Guild Master is stationary and identified")
	player.set_grid_position(Vector2i(16, 19))
	player.request_move(Vector2i.UP)
	player.request_interaction()
	await process_frame
	_check(interaction_menu.visible, "Guild Master opens the existing interaction menu")
	interaction_menu.close_menu()

	var dummy: GridMonster = room.get_node("Monsters/TrainingDummy") as GridMonster
	var xp_before_dummy: int = player.get_current_xp()
	var pickups_before_dummy: int = room.get_node("Pickups").get_child_count()
	var dummy_hp_before: int = dummy.current_hp
	_check(room.debug_attack_at(dummy.grid_position, 10, player), "Training Dummy receives normal combat damage")
	_check(dummy.current_hp < dummy_hp_before, "Training Dummy displays reduced HP after hit")
	_check(skills.learn_skill("combat_training"), "Training skill prerequisite learns")
	_check(skills.learn_skill("power_strike") and skills.assign_skill("power_strike", "skill_1"), "Active skill assigns to Q slot")
	player.set_grid_position(Vector2i(20, 19))
	player.request_move(Vector2i.UP)
	var dummy_hp_before_skill: int = dummy.current_hp
	player.call("_try_activate_skill", "skill_1")
	_check(dummy.current_hp < dummy_hp_before_skill, "Training Dummy receives assigned skill damage")
	room.debug_attack_at(dummy.grid_position, 999, player)
	_check(dummy.current_hp == dummy.max_hp, "Training Dummy resets instead of dying")
	_check(player.get_current_xp() == xp_before_dummy and room.get_node("Pickups").get_child_count() == pickups_before_dummy, "Training Dummy grants no XP or loot")

	var real_monsters: Array[GridMonster] = []
	for monster_node: Node in room.get_node("Monsters").get_children():
		var monster: GridMonster = monster_node as GridMonster
		if monster != null and not monster.is_training_dummy:
			real_monsters.append(monster)
			_check(room.is_outskirts_cell(monster.grid_position), "%s starts in Outskirts" % monster.name)
	_check(real_monsters.size() == 4, "Four spaced hostile monsters populate Outskirts")
	var slime: GridMonster = real_monsters[0]
	_check(not room.try_reserve_entity_move_to(Vector2i(23, GridTestRoom.TOWN_WALL_Y), slime), "Hostile monster cannot enter Town gate")
	_check(not room.can_monster_chase_target(slime, player), "Monster disengages from a Town player")
	var path_step: Vector2i = room.get_chase_step(slime.grid_position, Vector2i(24, 9), slime, 1)
	_check(path_step != Vector2i.ZERO, "Monster pathfinding finds an Outskirts route")
	var xp_before_slime: int = player.get_current_xp()
	var pickup_count_before_slime: int = room.get_node("Pickups").get_child_count()
	room.debug_attack_at(slime.grid_position, 999, player)
	_check(player.get_current_xp() == xp_before_slime + slime.xp_reward, "Real monster grants normal XP")
	_check(room.get_node("Pickups").get_child_count() > pickup_count_before_slime, "Real monster produces weighted loot pickup")

	var saved_xp: int = player.get_current_xp()
	main.queue_free()
	await process_frame
	var restarted: Node = main_scene.instantiate()
	root.add_child(restarted)
	await process_frame
	var restarted_room: GridTestRoom = restarted.get_node("WorldRoot/GridTestRoom") as GridTestRoom
	var restarted_player: Player = restarted.get_node("EntityRoot/Player") as Player
	_check(restarted_player.get_current_xp() == saved_xp, "Progression persists through restart")
	_check(restarted_room.is_town_cell(restarted_player.grid_position), "Restart returns player to Town")
	_check(restarted_room.get_node("Pickups").get_child_count() == 0, "Restart clears stale loot pickups")
	_cleanup(restarted)


func _cleanup(main: Node) -> void:
	main.queue_free()
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
		print("OVERWORLD MAP SMOKE TEST RESULT: PASS")
		quit(0)
		return
	printerr("OVERWORLD MAP SMOKE TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)
