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
	var npc: GridNpc = room.get_node("NPCs/NPC_A") as GridNpc
	var mira: GridNpc = room.get_node("NPCs/NPC_B") as GridNpc
	var dialogue_box: DialogueBox = main.get_node("UIRoot/DialogueBox") as DialogueBox
	var dialogue_manager: Node = main.get_node("DialogueManager")
	var relationship_system: RelationshipSystem = main.get_node("RelationshipSystem") as RelationshipSystem
	var inventory_system: InventorySystem = main.get_node("InventorySystem") as InventorySystem
	var interaction_menu: NpcInteractionMenu = main.get_node("UIRoot/NpcInteractionMenu") as NpcInteractionMenu
	_check(room != null and player != null and npc != null, "Dialogue test scene entities exist")
	_check(dialogue_box != null and dialogue_manager != null and relationship_system != null and inventory_system != null and interaction_menu != null, "Dialogue UI, manager, relationships, inventory, and menu exist")
	if room == null or player == null or npc == null or dialogue_box == null or dialogue_manager == null or relationship_system == null or inventory_system == null or interaction_menu == null:
		await _cleanup(main)
		return

	for room_npc: GridNpc in room.get_npcs():
		room_npc.wandering_enabled = false
	npc.set_grid_position(Vector2i(3, 3))
	player.set_grid_position(Vector2i(3, 4))
	player.request_move(Vector2i.UP)
	_check(player.get_facing_name() == "UP", "Player faces the adjacent NPC")
	player.request_interaction()
	await process_frame

	_check(interaction_menu.visible, "Adjacent facing interaction opens the menu")
	_check(not bool(dialogue_manager.call("is_dialogue_active")), "Dialogue does not open automatically")
	_check(not player.request_move(Vector2i.RIGHT), "Player movement is disabled during interaction menu")
	interaction_menu.call("_confirm", 0)
	await process_frame
	_check(bool(dialogue_manager.call("is_dialogue_active")), "Talk starts dialogue")
	_check(dialogue_box.visible, "Dialogue box becomes visible")
	_check(
		dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/NameLabel").text == "Arin",
		"Dialogue box shows the NPC name"
	)
	_check(
		dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/DialogueText").text == "Nice weather today.",
		"Dialogue box shows the first dialogue line"
	)
	_check(
		dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Portrait/ExpressionLabel").text == "Happy",
		"Portrait placeholder shows the expression state"
	)
	_check(
		not dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Portrait/PortraitTexture").visible,
		"Missing expression and neutral portraits safely use the placeholder"
	)
	_check(npc.dialogue_active, "Speaking NPC pauses wandering")
	_check(dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel").visible, "Relationship gauge is visible during dialogue")
	_check(dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/AffinityValue").text == "Affinity  0", "Relationship gauge shows neutral affinity")
	_check(not player.request_move(Vector2i.RIGHT), "Player movement is disabled during dialogue")

	await process_frame
	dialogue_box.advance_requested.emit()
	await process_frame
	_check(
		dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/DialogueText").text == "What do you think about leaving town someday?",
		"Interact advance reaches the branching question"
	)
	_check(dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/ChoiceContainer").get_child_count() == 3, "Branching question displays three choices")

	await process_frame
	dialogue_box.choice_selected.emit(1)
	await process_frame
	var arin_relationship: Dictionary = relationship_system.get_relationship("npc_a")
	_check(int(arin_relationship.get("affinity", 0)) == -5 and int(arin_relationship.get("trust", 0)) == 0 and int(arin_relationship.get("respect", 0)) == -2, "Negative dialogue effects modify Arin")
	_check(dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/AffinityValue").text == "Affinity  -5", "Gauge updates immediately after a choice effect")
	_check(
		dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/DialogueText").text == "I don't trust this.",
		"Selected choice is shown as the player response"
	)
	_check(dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/ChoiceContainer").get_child_count() == 0, "Choice response clears choice buttons safely")
	await process_frame
	dialogue_box.advance_requested.emit()
	await process_frame
	_check(
		dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/DialogueText").text == "Fair enough. The road asks a lot of anyone.",
		"Selected choice reaches its configured follow-up"
	)

	await process_frame
	Input.action_press("interact")
	dialogue_box.advance_requested.emit()
	await process_frame
	_check(not bool(dialogue_manager.call("is_dialogue_active")), "Dialogue closes after the final line")
	_check(not dialogue_box.visible, "Dialogue box hides after the final line")
	_check(not npc.dialogue_active, "NPC resumes wandering after dialogue")
	player.request_interaction()
	_check(not bool(dialogue_manager.call("is_dialogue_active")), "Closing interact press cannot reopen dialogue")
	Input.action_release("interact")
	await process_frame
	player.request_interaction()
	_check(bool(dialogue_manager.call("is_dialogue_active")), "Release and fresh interaction reopens dialogue")
	dialogue_box.close_requested.emit()
	await process_frame
	_check(not bool(dialogue_manager.call("is_dialogue_active")), "Escape-style close ends dialogue")
	dialogue_box.show_dialogue_node("missing", "Test", "A single option.", "neutral", [{"text": "Continue"}])
	_check(dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/ChoiceContainer").get_child_count() == 1, "Single-choice UI creates one safe button")
	dialogue_box.show_choice_response("Continue")
	_check(dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/ChoiceContainer").get_child_count() == 0, "Single-choice response clears safely")
	dialogue_box.hide_dialogue()
	var expected_followups := [
		"Then perhaps we will see the road together one day.",
		"Fair enough. The road asks a lot of anyone.",
		"No pressure. It is only a passing thought.",
		"The old road is not as empty as it looks."
	]
	for cycle in range(10):
		player.request_interaction()
		await process_frame
		await process_frame
		dialogue_box.advance_requested.emit()
		await process_frame
		if cycle == 4:
			_check(dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/ChoiceContainer").get_child_count() == 4, "Trust threshold unlocks the special choice")
		var selected_choice := 3 if cycle == 4 else cycle % 3
		dialogue_box.choice_selected.emit(selected_choice)
		await process_frame
		if cycle == 0:
			arin_relationship = relationship_system.get_relationship("npc_a")
			_check(int(arin_relationship.get("trust", 0)) == 5, "Positive dialogue effects increase trust")
		dialogue_box.advance_requested.emit()
		await process_frame
		_check(
			dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/DialogueText").text == expected_followups[selected_choice],
			"Spam cycle %d reaches the selected branch" % (cycle + 1)
		)
		Input.action_press("interact")
		dialogue_box.advance_requested.emit()
		await process_frame
		_check(not bool(dialogue_manager.call("is_dialogue_active")), "Spam cycle %d closes once" % (cycle + 1))
		player.request_interaction()
		_check(not bool(dialogue_manager.call("is_dialogue_active")), "Spam cycle %d does not reopen" % (cycle + 1))
		Input.action_release("interact")
		await process_frame
	relationship_system.modify_affinity("npc_b", 500)
	relationship_system.modify_trust("npc_b", -500)
	var mira_relationship: Dictionary = relationship_system.get_relationship("npc_b")
	var rowan_relationship: Dictionary = relationship_system.get_relationship("npc_c")
	_check(int(mira_relationship.get("affinity", 0)) == 100 and int(mira_relationship.get("trust", 0)) == -100, "Relationship values clamp to the supported range")
	_check(int(rowan_relationship.get("affinity", 0)) == 0 and int(rowan_relationship.get("trust", 0)) == 0, "NPC relationships remain independent")
	_check(player.request_move(Vector2i.RIGHT), "Player movement returns after dialogue")
	await _wait_until_idle(player)

	await process_frame
	player.set_grid_position(Vector2i(6, 6))
	player.request_interaction()
	await process_frame
	_check(not bool(dialogue_manager.call("is_dialogue_active")), "No dialogue starts without an adjacent NPC")
	mira.set_grid_position(Vector2i(6, 5))
	player.request_move(Vector2i.UP)
	player.request_interaction()
	await process_frame
	_check(bool(dialogue_manager.call("is_dialogue_active")), "Dialogue switches to a second NPC")
	_check(dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/AffinityValue").text == "Affinity  100", "Second NPC gauge shows its independent affinity")
	_check(dialogue_box.get_node("PanelContainer/MarginContainer/HBoxContainer/RelationshipPanel/TrustValue").text == "Trust  -100", "Second NPC gauge shows its independent trust")
	dialogue_box.close_requested.emit()
	await process_frame

	await _cleanup(main)


func _cleanup(main: Node) -> void:
	main.queue_free()
	await process_frame
	_finish()


func _wait_until_idle(player: Player) -> void:
	var frames := 0
	while player.is_moving() and frames < 240:
		await process_frame
		frames += 1
	_check(not player.is_moving(), "Player move completes after dialogue")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures.append(description)
	printerr("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("DIALOGUE INTERACTION SMOKE TEST RESULT: PASS")
		quit(0)
		return

	printerr("DIALOGUE INTERACTION SMOKE TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)
