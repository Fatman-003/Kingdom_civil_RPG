extends SceneTree

var _failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://scenes/core/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player: Player = main.get_node("EntityRoot/Player") as Player
	var inventory: InventorySystem = main.get_node("InventorySystem") as InventorySystem
	var hud: CombatHud = main.get_node("UIRoot/CombatHud") as CombatHud
	var screen: InventoryScreen = main.get_node("ModalUIRoot/InventoryScreen") as InventoryScreen
	_check(player != null and inventory != null and hud != null and screen != null, "Quick item dependencies exist")

	_check(inventory.get_item_definition("healing_potion").get("use_effect", "") == "heal", "Healing Potion is data-driven")
	_check(int(inventory.get_item_definition("healing_potion").get("use_value", 0)) == 30, "Healing Potion heals 30")
	_check(is_equal_approx(float(inventory.get_item_definition("healing_potion").get("cooldown", 0.0)), 2.0), "Healing Potion cooldown is 2 seconds")
	_check(player.assign_quick_item(0, "healing_potion"), "Potion assigns to slot 1")
	_check(player.assign_quick_item(1, "healing_potion"), "Same potion assigns to slot 2")
	_check(player.get_quick_item(0) == "healing_potion" and player.get_quick_item(1) == "healing_potion", "Quick slots store item references")

	player.take_damage(40)
	var before_use: int = inventory.get_amount("healing_potion")
	_check(player._try_use_quick_item(0), "Potion uses while HP is missing")
	_check(player.current_hp == 90 and inventory.get_amount("healing_potion") == before_use - 1, "Potion heals and consumes one")
	_check(player.get_quick_item_cooldown(1) > 0.0, "Potion cooldown starts in slot 1")
	_check(not player._try_use_quick_item(1) and inventory.get_amount("healing_potion") == before_use - 1, "Shared cooldown blocks slot 2 exploit")
	await create_timer(2.1).timeout
	player.take_damage(15)
	_check(player._try_use_quick_item(1) and player.current_hp == 100, "Potion can be used after cooldown")
	var full_hp_amount: int = inventory.get_amount("healing_potion")
	_check(not player._try_use_quick_item(0) and inventory.get_amount("healing_potion") == full_hp_amount, "Full HP does not consume potion")

	var remove_amount: int = inventory.get_amount("healing_potion")
	_check(inventory.remove_item("healing_potion", remove_amount), "Potion stack can reach zero")
	await process_frame
	_check(player.get_quick_item(0) == "healing_potion" and player.get_quick_item_amount(0) == 0, "Zero stock preserves assignment")
	_check(not player._try_use_quick_item(0), "Zero stock use is safe")
	inventory.add_item("healing_potion", 2)
	await process_frame
	_check(player.get_quick_item_amount(0) == 2, "Refill updates assigned quantity")
	_check(hud.get_node("ActionBar/QuickItem1/VBox/Quantity").text == "x2", "HUD quantity updates immediately")

	screen.open_screen()
	var isolated_amount: int = inventory.get_amount("healing_potion")
	player._process(0.016)
	_check(inventory.get_amount("healing_potion") == isolated_amount, "Modal panel blocks gameplay item use")
	screen.close_screen()
	player.take_damage(9999)
	_check(player.is_defeated() and not player._try_use_quick_item(0), "Defeated player cannot use quick items")

	# Exercise the keyboard-only assignment path using the real InventoryScreen state.
	var main2: Node = load("res://scenes/core/main.tscn").instantiate()
	root.add_child(main2)
	await process_frame
	var player2: Player = main2.get_node("EntityRoot/Player") as Player
	var screen2: InventoryScreen = main2.get_node("ModalUIRoot/InventoryScreen") as InventoryScreen
	screen2.open_screen()
	var potion_index: int = 0
	for item_index in screen2._items.size():
		if str((screen2._items[item_index] as Dictionary).get("item_id", "")) == "healing_potion":
			potion_index = item_index
	screen2._select_item(potion_index)
	screen2._toggle_equipment()
	screen2._unhandled_input(_action("quick_item_3"))
	screen2._unhandled_input(_action("interact"))
	_check(player2.get_quick_item(2) == "healing_potion", "Keyboard assignment selects slot 3")
	_check(player2.get_quick_item(0) == "healing_potion" and player2.get_quick_item_amount(0) == 2 and player2.get_quick_item_cooldown(0) == 0.0, "Assignment, inventory and cooldown reset persist after restart")
	main.queue_free()
	main2.queue_free()
	await process_frame
	if _failures.is_empty():
		print("QUICK ITEM SMOKE TEST RESULT: PASS")
		quit(0)
	else:
		printerr("QUICK ITEM SMOKE TEST RESULT: FAIL: " + str(_failures))
		quit(1)

func _action(action_name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	return event

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures.append(description)
		printerr("FAIL: " + description)
