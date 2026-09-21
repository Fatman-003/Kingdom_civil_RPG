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
	var inventory: InventorySystem = main.get_node("InventorySystem") as InventorySystem
	var loot_system: LootSystem = main.get_node("LootSystem") as LootSystem
	var screen: InventoryScreen = main.get_node("ModalUIRoot/InventoryScreen") as InventoryScreen
	_check(player != null and progression != null and equipment != null and inventory != null and loot_system != null and screen != null, "Luck dependencies exist")
	if player == null or progression == null or equipment == null or inventory == null or loot_system == null or screen == null:
		_cleanup(main)
		return
	inventory.add_item("lucky_test_ring", 1)

	_check(int(player.get_base_stats().get("luck", 0)) == 5, "Starting base Luck is 5")
	_check(int(player.get_final_stats().get("luck", 0)) == 5, "Final Luck starts from base Luck")
	var stats_event: InputEventAction = InputEventAction.new()
	stats_event.action = "stats"
	stats_event.pressed = true
	screen._input(stats_event)
	var down_event: InputEventAction = InputEventAction.new()
	down_event.action = "move_down"
	down_event.pressed = true
	for _index: int in range(4):
		screen._unhandled_input(down_event)
	_check(int(screen.get("_selected_stat_index")) == 4, "Keyboard navigation reaches Luck")
	var points_before: int = player.get_stat_points()
	var luck_before: int = int(player.get_base_stats().get("luck", 0))
	var interact_event: InputEventAction = InputEventAction.new()
	interact_event.action = "interact"
	interact_event.pressed = true
	screen._input(interact_event)
	_check(int(player.get_base_stats().get("luck", 0)) == luck_before + 1, "Luck allocation increases base Luck once")
	_check(player.get_stat_points() == points_before - 1, "Luck allocation spends one Stat Point")
	_check(int(player.get_final_stats().get("luck", 0)) == luck_before + 1, "Luck allocation refreshes final Luck")
	screen.close_screen()

	var base_luck: int = int(player.get_base_stats().get("luck", 0))
	var final_luck_before_ring: int = int(player.get_final_stats().get("luck", 0))
	_check(equipment.equip_item("lucky_test_ring"), "Lucky Test Ring equips")
	_check(int(player.get_base_stats().get("luck", 0)) == base_luck, "Equipment does not alter base Luck")
	_check(int(player.get_final_stats().get("luck", 0)) == final_luck_before_ring + 20, "Equipment modifier increases final Luck")
	_check(equipment.unequip_slot("accessory"), "Lucky Test Ring unequips")
	_check(int(player.get_final_stats().get("luck", 0)) == final_luck_before_ring, "Unequipping restores final Luck")

	_check(is_equal_approx(loot_system.get_bonus_roll_2_chance(5), 0.15), "Second-roll formula uses 3 percent per Luck")
	_check(is_equal_approx(loot_system.get_bonus_roll_2_chance(99), 0.60), "Second-roll chance caps at 60 percent")
	_check(is_equal_approx(loot_system.get_bonus_roll_3_chance(5), 0.0), "Third roll requires Luck above 5")
	_check(is_equal_approx(loot_system.get_bonus_roll_3_chance(20), 0.225), "Third-roll formula uses 1.5 percent above threshold")
	_check(is_equal_approx(loot_system.get_bonus_roll_3_chance(99), 0.25), "Third-roll chance caps at 25 percent")
	loot_system.set_debug_seed(18018)
	var saw_single: bool = false
	var saw_double: bool = false
	var saw_triple: bool = false
	var saw_stacked_duplicate: bool = false
	for _index: int in range(300):
		var result: Dictionary = loot_system.resolve_loot("slime_loot", 25)
		var roll_count: int = int(result.get("roll_count", 0))
		var items: Dictionary = result.get("items", {}) as Dictionary
		_check(roll_count >= 1 and roll_count <= LootSystem.MAX_LOOT_ROLLS, "Loot roll count remains within one to three")
		_check(not items.is_empty(), "Weighted roll produces a valid item")
		saw_single = saw_single or roll_count == 1
		saw_double = saw_double or roll_count == 2
		saw_triple = saw_triple or roll_count == 3
		for amount_variant: Variant in items.values():
			if int(amount_variant) > 2:
				saw_stacked_duplicate = true
	_check(saw_single and saw_double and saw_triple, "Seeded high-Luck test produces x1, x2, and x3 results")
	_check(saw_stacked_duplicate, "Duplicate weighted results merge into valid pickup stacks")
	var room: GridTestRoom = main.get_node("WorldRoot/GridTestRoom") as GridTestRoom
	var slime_low: GridMonster = room.get_node("Monsters/SlimeA") as GridMonster
	var slime_high: GridMonster = room.get_node("Monsters/SlimeB") as GridMonster
	var xp_before_low_luck: int = player.get_current_xp()
	slime_low.take_debug_damage(999, player)
	_check(player.get_current_xp() == xp_before_low_luck + slime_low.xp_reward, "Low-Luck kill awards the monster XP reward")
	_check(equipment.equip_item("lucky_test_ring"), "Lucky Test Ring re-equips for high-Luck XP check")
	var xp_before_high_luck: int = player.get_current_xp()
	slime_high.take_debug_damage(999, player)
	_check(player.get_current_xp() == xp_before_high_luck + slime_high.xp_reward, "High Luck does not change monster XP reward")
	equipment.unequip_slot("accessory")

	var saved_luck: int = int(player.get_base_stats().get("luck", 0))
	var saved_points: int = player.get_stat_points()
	main.queue_free()
	await process_frame
	var restarted: Node = main_scene.instantiate()
	root.add_child(restarted)
	await process_frame
	var restarted_player: Player = restarted.get_node("EntityRoot/Player") as Player
	_check(int(restarted_player.get_base_stats().get("luck", 0)) == saved_luck, "Base Luck persists through encounter restart")
	_check(restarted_player.get_stat_points() == saved_points, "Stat Points persist through encounter restart")
	_cleanup(restarted)


func _cleanup(main: Node) -> void:
	main.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	_failures.append(description)
	printerr("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("LUCK LOOT SMOKE TEST RESULT: PASS")
		quit(0)
		return
	printerr("LUCK LOOT SMOKE TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)
