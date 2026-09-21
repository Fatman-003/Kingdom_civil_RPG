extends SceneTree

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load("res://scenes/core/main.tscn") as PackedScene
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	var player: Player = main.get_node("EntityRoot/Player") as Player
	var inventory: InventorySystem = main.get_node("InventorySystem") as InventorySystem
	var screen: InventoryScreen = main.get_node("ModalUIRoot/InventoryScreen") as InventoryScreen
	_check(player != null and inventory != null and screen != null, "Inventory test dependencies exist")
	if player == null or inventory == null or screen == null:
		_finish()
		return

	screen.open_screen()
	_check(screen.visible, "Inventory opens")
	_check(screen.get_node("Panel/Margin/HBox/ListColumn/ItemList").get_child_count() == 11, "Owned prototype and equipment items are listed")
	_check(not player.request_move(Vector2i.RIGHT), "Player movement is locked while inventory is open")
	screen.call("_select_item", 2)
	_check(not screen.get_node("Panel/Margin/HBox/Details/NameLabel").text.is_empty(), "Selected item shows details")
	_check(screen.get_node("Panel/Margin/HBox/Details/OwnedLabel").text.begins_with("Owned:"), "Details show owned quantity")

	_check(inventory.remove_item("old_coin", 1), "Final item copy can be removed")
	await process_frame
	_check(screen.get_node("Panel/Margin/HBox/ListColumn/ItemList").get_child_count() == 10, "Zero-count item disappears during refresh")
	for item_id in ["apple", "flower", "herb", "cheap_wine", "training_sword", "wooden_shield", "leather_armor", "simple_helmet", "copper_ring", "traveler_boots"]:
		var amount: int = inventory.get_amount(item_id)
		if amount > 0:
			inventory.remove_item(item_id, amount)
	await process_frame
	_check(screen.get_node("Panel/Margin/HBox/ListColumn/EmptyLabel").visible, "Empty inventory is handled safely")
	screen.close_screen()
	_check(not screen.visible, "Inventory closes")
	screen.open_screen()
	_check(screen.visible, "Inventory reopens")
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
		quit(0)
		return
	quit(1)
