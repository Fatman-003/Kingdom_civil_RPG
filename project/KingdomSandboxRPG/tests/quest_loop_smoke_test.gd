extends SceneTree
var failures: PackedStringArray = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: PackedScene = load("res://scenes/core/main.tscn") as PackedScene
	var main := scene.instantiate(); root.add_child(main); await process_frame
	var quests: QuestSystem = main.get_node("QuestSystem") as QuestSystem
	var player: Player = main.get_node("EntityRoot/Player") as Player
	var inventory: InventorySystem = main.get_node("InventorySystem") as InventorySystem
	var room: GridTestRoom = main.get_node("WorldRoot/GridTestRoom") as GridTestRoom
	var screen: InventoryScreen = main.get_node("ModalUIRoot/InventoryScreen") as InventoryScreen
	var dialogue_manager: Node = main.get_node("DialogueManager")
	var guild_master: GridNpc = room.get_node("NPCs/GuildMaster") as GridNpc
	check(quests != null and player != null and inventory != null and room != null and screen != null, "Quest dependencies exist")
	check(quests.get_state("guild_slime_cleanup") == QuestSystem.NOT_STARTED, "Quest starts NOT_STARTED")
	check(quests.get_conversation_for_npc("guild_master").get("start") == "offer", "Guild Master offers quest")
	dialogue_manager.call("_on_dialogue_requested", guild_master); await process_frame
	dialogue_manager.call("_select_choice", 0)
	check(quests.get_state("guild_slime_cleanup") == QuestSystem.ACTIVE, "Quest accepts through Guild Master dialogue")
	dialogue_manager.call("_end_dialogue")
	check(not quests.accept_quest("guild_slime_cleanup") and quests.get_state("guild_slime_cleanup") == QuestSystem.ACTIVE, "Duplicate accept is blocked")
	check(main.get_node("UIRoot/QuestTracker").visible, "Tracker appears for active quest")
	var j := InputEventAction.new(); j.action = "quests"; j.pressed = true; screen._input(j)
	check(screen.visible and bool(screen.get("_quests_tab_active")), "J opens Quest Log")
	screen._input(j); check(not screen.visible, "J closes Quest Log")
	var dummy: GridMonster = room.get_node("Monsters/TrainingDummy") as GridMonster
	room.debug_attack_at(dummy.grid_position, 999, player)
	check(quests.get_objective_text("guild_slime_cleanup").ends_with("0 / 3"), "Dummy does not count")
	var slimes: Array[GridMonster] = []
	for node: Node in room.get_node("Monsters").get_children():
		var monster := node as GridMonster
		if monster != null and monster.monster_id == "slime": slimes.append(monster)
	for index: int in range(3): room.debug_attack_at(slimes[index].grid_position, 999, player)
	check(quests.get_state("guild_slime_cleanup") == QuestSystem.READY_TO_TURN_IN, "Three slime kills reach READY_TO_TURN_IN")
	var level := player.get_level(); var xp := player.get_current_xp(); var potions := inventory.get_amount("healing_potion")
	check(quests.turn_in_quest("guild_slime_cleanup"), "Quest turns in")
	check((player.get_level() > level or player.get_current_xp() == xp + 100) and inventory.get_amount("healing_potion") == potions + 2, "Rewards grant exactly once")
	check(not quests.turn_in_quest("guild_slime_cleanup"), "Duplicate reward claim is blocked")
	var saved_state := quests.get_state("guild_slime_cleanup"); main.queue_free(); await process_frame
	var restarted := scene.instantiate(); root.add_child(restarted); await process_frame
	check((restarted.get_node("QuestSystem") as QuestSystem).get_state("guild_slime_cleanup") == saved_state, "Quest state persists through restart")
	restarted.queue_free(); await process_frame
	if failures.is_empty(): print("QUEST LOOP SMOKE TEST RESULT: PASS"); quit(0); return
	printerr("QUEST LOOP SMOKE TEST RESULT: FAIL"); quit(1)
func check(ok: bool, text: String) -> void:
	if ok: print("PASS: " + text)
	else: failures.append(text); printerr("FAIL: " + text)
