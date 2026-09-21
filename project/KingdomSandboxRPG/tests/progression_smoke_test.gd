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
	var player: Player = main.get_node("EntityRoot/Player") as Player
	var progression: ProgressionSystem = main.get_node("ProgressionSystem") as ProgressionSystem
	var equipment: EquipmentSystem = main.get_node("EquipmentSystem") as EquipmentSystem
	var skills: SkillSystem = main.get_node("SkillSystem") as SkillSystem
	var room: GridTestRoom = main.get_node("WorldRoot/GridTestRoom") as GridTestRoom
	var screen: InventoryScreen = main.get_node("ModalUIRoot/InventoryScreen") as InventoryScreen
	_check(player != null and progression != null and equipment != null and skills != null and room != null and screen != null, "Progression dependencies exist")
	if player == null or progression == null or equipment == null or skills == null or room == null or screen == null:
		await _cleanup(main)
		return
	var stats_event := InputEventAction.new()
	stats_event.action = "stats"
	stats_event.pressed = true
	screen._input(stats_event)
	_check(screen.visible and bool(screen.get("_stats_tab_active")), "Stats action opens the Stats tab")
	screen._input(stats_event)
	_check(not screen.visible, "Stats action closes the Character Panel when repeated")
	var interaction_menu: NpcInteractionMenu = main.get_node("UIRoot/NpcInteractionMenu") as NpcInteractionMenu
	var dialogue_manager: Node = main.get_node("DialogueManager")
	var dialogue_box: DialogueBox = main.get_node("UIRoot/DialogueBox") as DialogueBox
	var test_npc: GridNpc = room.get_node("NPCs/NPC_A") as GridNpc
	for room_npc: GridNpc in room.get_npcs():
		room_npc.wandering_enabled = false
	test_npc.set_grid_position(Vector2i(6, 5))
	player.set_grid_position(Vector2i(6, 6))
	player.request_move(Vector2i.UP)
	player.request_interaction()
	await process_frame
	_check(interaction_menu.visible and not bool(dialogue_manager.call("is_dialogue_active")), "NPC interaction menu still precedes dialogue")
	await process_frame
	interaction_menu.call("_confirm", 0)
	await process_frame
	_check(bool(dialogue_manager.call("is_dialogue_active")) and dialogue_box.visible, "Talk still opens the dialogue system")
	dialogue_box.close_requested.emit()
	await process_frame
	_check(not bool(dialogue_manager.call("is_dialogue_active")), "Dialogue closes cleanly")
	var training_dummy: GridMonster = room.get_node("Monsters/TrainingDummy") as GridMonster
	player.set_grid_position(Vector2i(14, 3))
	training_dummy.set_grid_position(Vector2i(14, 2))
	player.request_move(Vector2i.UP)
	var dummy_hp_before: int = training_dummy.current_hp
	player.call("_try_basic_attack")
	_check(training_dummy.current_hp < dummy_hp_before, "Basic attack uses the derived player attack")

	_check(player.get_level() == 1 and player.get_current_xp() == 0, "Player starts at level one with zero XP")
	_check(player.get_base_stats() == {"hp": 10, "attack": 5, "defense": 0, "mobility": 10, "luck": 5}, "Starting base stats are authoritative")
	_check(player.get_current_max_hp() == 100, "Max HP derives from base HP")
	_check(player.get_stat_points() == ProgressionSystem.STARTING_STAT_POINTS, "Prototype starting Stat Points come from progression")
	screen._input(stats_event)
	var move_down_event := InputEventAction.new()
	move_down_event.action = "move_down"
	move_down_event.pressed = true
	screen._unhandled_input(move_down_event)
	_check(int(screen.get("_selected_stat_index")) == 1, "Stats keyboard selection moves to Attack")
	var interact_event := InputEventAction.new()
	interact_event.action = "interact"
	interact_event.pressed = true
	var attack_before_keyboard: int = int(player.get_base_stats().get("attack", 0))
	var points_before_keyboard: int = player.get_stat_points()
	screen._input(interact_event)
	_check(int(player.get_base_stats().get("attack", 0)) == attack_before_keyboard + 1, "Enter/Space path allocates selected BaseStat")
	_check(player.get_stat_points() == points_before_keyboard - 1, "Keyboard allocation spends exactly one Stat Point")
	screen._input(stats_event)
	var points_before_level_up: int = player.get_stat_points()

	var slime: GridMonster = room.get_node("Monsters/SlimeA") as GridMonster
	var starting_xp: int = player.get_current_xp()
	var slime_xp_reward: int = slime.xp_reward
	slime.take_debug_damage(999, player)
	await process_frame
	_check(player.get_current_xp() == starting_xp + slime_xp_reward, "Player receives monster XP exactly once")

	progression.add_experience(progression.xp_required_for_level() - player.get_current_xp())
	_check(player.get_level() == 2 and player.get_current_xp() == 0, "XP reaches the next level")
	_check(player.get_stat_points() == points_before_level_up + 3 and player.get_skill_points() == 4, "Level rewards grant stat and skill points")
	progression.add_experience(500)
	_check(player.get_level() == 4 and player.get_current_xp() == 150, "XP overflow and multiple level-ups are processed")
	_check(player.get_stat_points() == points_before_level_up + 9 and player.get_skill_points() == 6, "Multiple level-ups grant every reward")

	player.current_hp = 80
	var before_stats: Dictionary = player.get_base_stats()
	_check(player.allocate_stat("hp"), "HP stat allocation succeeds")
	_check(player.get_base_stats().get("hp") == int(before_stats.get("hp")) + 1, "HP base stat increases by one")
	_check(player.get_current_max_hp() == 110 and player.current_hp == 90, "HP allocation raises max and current HP by the same delta")
	var attack_before: int = int(player.get_final_stats().get("attack", 0))
	_check(player.allocate_stat("attack"), "Attack stat allocation succeeds")
	_check(int(player.get_final_stats().get("attack", 0)) == attack_before + 1, "Attack allocation updates final attack")
	var defense_before: int = int(player.get_final_stats().get("defense", 0))
	_check(player.allocate_stat("defense"), "Defense stat allocation succeeds")
	_check(int(player.get_final_stats().get("defense", 0)) == defense_before + 1, "Defense allocation updates final defense")
	var mobility_before: int = int(player.get_final_stats().get("mobility", 0))
	_check(player.allocate_stat("mobility"), "Mobility stat allocation succeeds")
	_check(int(player.get_final_stats().get("mobility", 0)) == mobility_before + 1, "Mobility allocation updates final mobility")
	screen._input(stats_event)
	var mobility_base_before_click: int = int(player.get_base_stats().get("mobility", 0))
	var points_before_click: int = player.get_stat_points()
	var mobility_row: HBoxContainer = screen.get_node("Panel/Margin/HBox/ListColumn/ItemList").get_child(6) as HBoxContainer
	var mobility_plus: Button = mobility_row.get_child(2) as Button
	mobility_plus.emit_signal("pressed")
	_check(player.get_base_stats().get("mobility") == mobility_base_before_click + 1 and player.get_stat_points() == points_before_click - 1, "Stats plus button allocates exactly one point")
	while player.get_stat_points() > 0:
		player.allocate_stat("attack")
	var mobility_at_zero_points: int = int(player.get_base_stats().get("mobility", 0))
	screen._input(interact_event)
	_check(player.get_stat_points() == 0 and int(player.get_base_stats().get("mobility", 0)) == mobility_at_zero_points, "Zero-point keyboard allocation fails safely")
	var all_plus_buttons_disabled: bool = true
	for button: Button in screen.get("_stat_plus_buttons"):
		if not button.disabled:
			all_plus_buttons_disabled = false
	_check(all_plus_buttons_disabled, "All plus buttons disable at zero Stat Points")
	screen._input(stats_event)

	var max_hp_before_gear: int = player.get_current_max_hp()
	var mobility_before_gear: int = int(player.get_final_stats().get("mobility", 0))
	_check(equipment.equip_item("leather_armor"), "Armor equips")
	_check(player.get_current_max_hp() == max_hp_before_gear, "Equipment cannot modify max HP")
	_check(int(player.get_base_stats().get("defense", 0)) == 1, "Equipment does not mutate base defense")
	_check(int(player.get_final_stats().get("mobility", 0)) == mobility_before_gear - 1, "Armor mobility penalty applies")
	var mobility_after_armor: int = int(player.get_final_stats().get("mobility", 0))
	_check(equipment.equip_item("wooden_shield"), "Shield equips")
	_check(int(player.get_final_stats().get("mobility", 0)) == mobility_after_armor - 1, "Shield mobility penalty applies")
	var mobility_after_shield: int = int(player.get_final_stats().get("mobility", 0))
	_check(equipment.equip_item("traveler_boots"), "Boots equip")
	_check(int(player.get_final_stats().get("mobility", 0)) == mobility_after_shield + 3, "Boots mobility bonus applies")
	_check(skills.get_skill_points() == player.get_skill_points(), "Skill tree reads progression skill points")
	_check(skills.learn_skill("combat_training"), "Skill learning spends progression skill points")
	_check(skills.get_skill_points() == player.get_skill_points(), "Skill point spend stays synchronized")

	var saved_level: int = player.get_level()
	var saved_xp: int = player.get_current_xp()
	var saved_base: Dictionary = player.get_base_stats()
	var saved_stat_points: int = player.get_stat_points()
	var saved_skill_points: int = player.get_skill_points()
	main.queue_free()
	await process_frame
	var restarted: Node = main_scene.instantiate()
	root.add_child(restarted)
	await process_frame
	var restarted_player: Player = restarted.get_node("EntityRoot/Player") as Player
	_check(restarted_player.get_level() == saved_level, "Level persists through encounter restart")
	_check(restarted_player.get_current_xp() == saved_xp, "XP persists through encounter restart")
	_check(restarted_player.get_base_stats() == saved_base, "Base stats persist through encounter restart")
	_check(restarted_player.get_stat_points() == saved_stat_points and restarted_player.get_skill_points() == saved_skill_points, "Unspent points persist through encounter restart")
	_check((restarted.get_node("SkillSystem") as SkillSystem).is_learned("combat_training"), "Learned skills persist through encounter restart")
	_check((restarted.get_node("EquipmentSystem") as EquipmentSystem).get_equipped_item("body") == "leather_armor", "Equipped items persist through encounter restart")
	await _cleanup(restarted)


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
		print("PROGRESSION SMOKE TEST RESULT: PASS")
		quit(0)
		return
	printerr("PROGRESSION SMOKE TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)
