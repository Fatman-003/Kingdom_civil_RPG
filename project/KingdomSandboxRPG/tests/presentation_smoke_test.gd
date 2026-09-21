extends SceneTree

const MAIN = preload("res://scenes/core/main.tscn")
var failures: PackedStringArray = []
var capture: bool = false

func _initialize() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	call_deferred("_run")

func _event(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

func _run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var player: Player = main.get_node("EntityRoot/Player")
	var room: GridTestRoom = main.get_node("WorldRoot/GridTestRoom")
	var screen: InventoryScreen = main.get_node("ModalUIRoot/InventoryScreen")
	var hud: CombatHud = main.get_node("UIRoot/CombatHud")
	var quests: QuestSystem = main.get_node("QuestSystem")
	var skills: SkillSystem = main.get_node("SkillSystem")
	for npc: GridNpc in room.get_npcs():
		npc.wandering_enabled = false
	quests.accept_quest("guild_slime_cleanup")
	skills.learn_skill("combat_training")
	skills.learn_skill("power_strike")
	skills.assign_skill("power_strike", "skill_1")
	skills.learn_skill("quick_slash")
	skills.assign_skill("quick_slash", "skill_2")
	await _snapshot("hud")
	_check(hud.get_node("ActionBar/QuickItem4") != null, "Four reserved quick item slots")
	_check(main.get_node("ModalUIRoot").layer > hud.layer, "Character panel above combat HUD")
	_check(main.get_node("UIRoot").layer > main.get_node("ModalUIRoot").layer, "Dialogue above Character Panel")
	var debug: Control = main.get_node("DebugRoot/DebugHUD")
	debug._unhandled_input(_event("debug_toggle"))
	# Exercise the real viewport dispatch path as well as focused component checks.
	await _press(KEY_I)
	_check(screen.visible and screen._active_tab == 0, "I opens Inventory through viewport input")
	await _press(KEY_TAB)
	_check(screen.visible and screen._active_tab == 1, "Tab switches Equipment")
	await _press(KEY_I)
	_check(not screen.visible, "I closes Equipment")
	for shortcut: Key in [KEY_TAB, KEY_K, KEY_C, KEY_J]:
		await _press(shortcut)
		_check(screen.visible, "Character shortcut opens panel")
		await _press(KEY_ESCAPE)
		_check(not screen.visible, "Escape restores gameplay")
	for repeat in range(3):
		await _press(KEY_I)
		await _press(KEY_I)
	_check(not screen.visible and not player.is_dialogue_active(), "Repeated toggles leave no stale lock")
	_check(not debug.visible and hud.visible, "F3 hides debug only")
	debug._unhandled_input(_event("debug_toggle"))

	for index in range(5):
		screen.open_screen()
		screen._set_active_tab(index)
		await _snapshot(["inventory", "equipment", "skills", "stats", "quests"][index])
		_check(not player.request_move(Vector2i.RIGHT), "Panel locks gameplay")
		var panel: Control = screen.get_node("Panel")
		_check(panel.get_global_rect().end.x <= 1280 and panel.get_global_rect().end.y <= 720, "Panel stays inside viewport")
		screen._unhandled_input(_event("move_down"))
		if index == 4:
			var inventory_before: Array = main.get_node("InventorySystem").get_owned_items().duplicate(true)
			screen._input(_event("interact"))
			_check(main.get_node("InventorySystem").get_owned_items() == inventory_before, "Quest confirm does not equip inventory item")
		screen._unhandled_input(_event("pause"))
		_check(not screen.visible, "Escape closes every tab")

	var manager: Node = main.get_node("DialogueManager")
	var box: DialogueBox = main.get_node("UIRoot/DialogueBox")
	var menu: NpcInteractionMenu = main.get_node("UIRoot/NpcInteractionMenu")
	var master: GridNpc = room.get_node("NPCs/GuildMaster")
	menu.open_for_npc(master)
	await _snapshot("interaction")
	menu._confirm(0)
	await _snapshot("dialogue")
	_check(box.visible, "Talk opens themed dialogue")
	box._unhandled_input(_event("pause"))
	var arin: GridNpc = room.get_node("NPCs/NPC_A")
	manager._on_dialogue_requested(arin)
	await process_frame
	box._unhandled_input(_event("interact"))
	await _snapshot("choices")
	box._unhandled_input(_event("move_down"))
	box._unhandled_input(_event("interact"))
	_check(box.get_node("PanelContainer/MarginContainer/HBoxContainer/Content/ChoiceContainer").get_child_count() == 0, "Choice safely clears themed buttons")
	box._unhandled_input(_event("pause"))
	manager.start_gift_flow(arin)
	await _snapshot("gift")
	box._unhandled_input(_event("pause"))

	player.set_grid_position(Vector2i(20, 19))
	player.request_move(Vector2i.UP)
	var grid_before := player.grid_position
	await _press(KEY_A)
	_check(player.presentation.state == ActorPresentation.State.BASIC_ATTACK, "Basic attack has visual state")
	_check(hud._player.get_action_cooldown_remaining("attack") > 0, "Attack cooldown remains authoritative")
	await create_timer(0.25).timeout
	await _press(KEY_Q)
	_check(player.presentation.state == ActorPresentation.State.SKILL_CAST, "Skill activation has visual state")
	await _press(KEY_W)
	_check(player.get_action_cooldown_remaining("skill_2") > 0, "W skill cooldown remains functional")
	await _snapshot("combat")
	player.take_damage(2)
	_check(player.presentation.state == ActorPresentation.State.HURT, "Hurt interrupts skill animation")
	_check(hud.get_node("HpBar").value == player.current_hp, "HP bar updates immediately")
	_check(player.grid_position == grid_before, "Animation never drifts logical grid")
	var dummy: GridMonster = room.get_node("Monsters/TrainingDummy")
	_check(dummy.presentation.state == ActorPresentation.State.HURT, "Dummy has hit feedback")
	var slime: GridMonster = room.get_node("Monsters/SlimeA")
	slime.take_damage(999, player)
	_check(slime.is_dead() and not slime.is_in_group("grid_entities"), "Death immediately releases occupancy")
	await process_frame
	await create_timer(0.7).timeout
	player.take_damage(9999)
	_check(player.presentation.state == ActorPresentation.State.DEATH, "Death has highest animation priority")
	player.presentation.play(ActorPresentation.State.HURT)
	_check(player.presentation.state == ActorPresentation.State.DEATH, "Hurt cannot interrupt death")
	await _snapshot("defeat")
	_check(hud.get_node("DefeatLayer").layer > main.get_node("UIRoot").layer, "Defeat confirmation is highest layer")

	if OS.get_cmdline_user_args().has("--soak"):
		await _soak(main)
	else:
		main.queue_free()
		await process_frame
	if failures.is_empty():
		print("PRESENTATION SMOKE TEST RESULT: PASS")
		quit(0)
	else:
		printerr("PRESENTATION SMOKE TEST RESULT: FAIL: " + str(failures))
		quit(1)

func _snapshot(label: String) -> void:
	await process_frame
	await process_frame
	if capture:
		await RenderingServer.frame_post_draw
		var path: String = "user://presentation-captures"
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--capture-dir="):
				path = argument.trim_prefix("--capture-dir=")
		DirAccess.make_dir_recursive_absolute(path)
		root.get_texture().get_image().save_png(path.path_join(label + ".png"))

func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _soak(main: Node) -> void:
	var start: int = Time.get_ticks_msec()
	var cycle: int = 0
	while Time.get_ticks_msec() - start < 600000:
		main.queue_free()
		await process_frame
		main = MAIN.instantiate()
		root.add_child(main)
		current_scene = main
		await process_frame
		var player: Player = main.get_node("EntityRoot/Player")
		var screen: InventoryScreen = main.get_node("ModalUIRoot/InventoryScreen")
		player.set_grid_position(Vector2i(23, 14))
		for step in range(4):
			player.request_move(Vector2i.UP)
			await create_timer(0.25).timeout
		for hit in range(10):
			player._try_basic_attack()
			player._try_activate_skill("skill_1")
			if hit % 3 == 0:
				screen.open_screen()
				screen._set_active_tab(hit % 5)
				screen.close_screen()
			await create_timer(0.6).timeout
		player.take_damage(9999)
		await create_timer(0.8).timeout
		cycle += 1
		if cycle % 5 == 0:
			print("SOAK: %ds, %d encounter restarts, nodes=%d" % [(Time.get_ticks_msec() - start) / 1000, cycle, get_node_count()])
	print("SOAK COMPLETE: 600 seconds")
	main.queue_free()
	await process_frame

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
		printerr("FAIL: " + description)
