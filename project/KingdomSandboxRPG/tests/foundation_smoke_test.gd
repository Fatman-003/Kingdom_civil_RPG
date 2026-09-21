extends SceneTree

const TEST_SAVE_SLOT: int = 987654
const TEST_SAVE_PATH: String = "user://save_slot_%d.json" % TEST_SAVE_SLOT

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_manager: Node = root.get_node_or_null("GameManager")
	var scene_manager: Node = root.get_node_or_null("SceneManager")
	var event_bus: Node = root.get_node_or_null("EventBus")
	var save_manager: Node = root.get_node_or_null("SaveManager")

	_check(game_manager != null, "GameManager autoload initializes")
	_check(scene_manager != null, "SceneManager autoload initializes")
	_check(event_bus != null, "EventBus autoload initializes")
	_check(save_manager != null, "SaveManager autoload initializes")

	for action: String in [
		"move_up",
		"move_down",
		"move_left",
		"move_right",
		"interact",
		"inventory",
		"pause",
		"debug_toggle",
	]:
		_check(InputMap.has_action(action), "Input action exists: %s" % action)

	_check(_has_key_binding("move_up", KEY_W, true), "move_up is bound to W")
	_check(_has_key_binding("move_up", KEY_UP), "move_up is bound to Up")
	_check(_has_key_binding("move_down", KEY_S, true), "move_down is bound to S")
	_check(_has_key_binding("move_down", KEY_DOWN), "move_down is bound to Down")
	_check(_has_key_binding("move_left", KEY_A, true), "move_left is bound to A")
	_check(_has_key_binding("move_left", KEY_LEFT), "move_left is bound to Left")
	_check(_has_key_binding("move_right", KEY_D, true), "move_right is bound to D")
	_check(_has_key_binding("move_right", KEY_RIGHT), "move_right is bound to Right")
	_check(_has_key_binding("interact", KEY_E, true), "interact is bound to E")
	_check(_has_key_binding("interact", KEY_SPACE), "interact is bound to Space")
	_check(_has_key_binding("inventory", KEY_I, true), "inventory is bound to I")
	_check(_has_key_binding("pause", KEY_ESCAPE), "pause is bound to Escape")
	_check(_has_key_binding("debug_toggle", KEY_F3), "debug_toggle is bound to F3")

	var main_scene: PackedScene = load("res://scenes/core/main.tscn") as PackedScene
	_check(main_scene != null, "Main scene resource loads")
	if main_scene == null:
		_finish()
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	_check(main.name == "Main", "Main scene instantiates")

	var hud: Control = main.get_node_or_null("UIRoot/DebugHUD") as Control
	_check(hud != null, "Debug HUD is instantiated under UIRoot")
	if hud != null:
		_check(hud.visible, "Debug HUD starts visible")
		var project_label: Label = hud.get_node_or_null(
			"MarginContainer/VBoxContainer/ProjectLabel"
		) as Label
		var milestone_label: Label = hud.get_node_or_null(
			"MarginContainer/VBoxContainer/MilestoneLabel"
		) as Label
		var fps_label: Label = hud.get_node_or_null(
			"MarginContainer/VBoxContainer/FPSLabel"
		) as Label
		var grid_label: Label = hud.get_node_or_null(
			"MarginContainer/VBoxContainer/GridLabel"
		) as Label
		var facing_label: Label = hud.get_node_or_null(
			"MarginContainer/VBoxContainer/FacingLabel"
		) as Label
		_check(
			project_label != null and project_label.text == "Kingdom Sandbox RPG",
			"Debug HUD displays the project name"
		)
		_check(
			milestone_label != null and milestone_label.text == "Prototype",
			"Debug HUD displays the prototype label"
		)
		_check(
			fps_label != null and fps_label.text.begins_with("FPS: ")
			and fps_label.text != "FPS: pending",
			"Debug HUD updates the FPS value"
		)
		_check(
			grid_label != null and grid_label.text == "Grid: 6, 6",
			"Debug HUD receives the player grid position through EventBus"
		)
		_check(
			facing_label != null and facing_label.text == "Facing: DOWN",
			"Debug HUD receives the player facing direction through EventBus"
		)

		var f3_event := InputEventKey.new()
		f3_event.keycode = KEY_F3
		f3_event.pressed = true
		hud._unhandled_input(f3_event)
		_check(not hud.visible, "F3 hides the Debug HUD")
		hud._unhandled_input(f3_event)
		_check(hud.visible, "F3 restores the Debug HUD")

	if save_manager != null:
		var save_succeeded: bool = bool(save_manager.call("save_game", TEST_SAVE_SLOT))
		_check(save_succeeded, "SaveManager test save succeeds")
		var load_succeeded: bool = bool(save_manager.call("load_game", TEST_SAVE_SLOT))
		_check(load_succeeded, "SaveManager test load succeeds")
		var loaded_data: Dictionary = save_manager.get("last_loaded_data")
		_check(
			loaded_data.get("test_value", "") == "foundation",
			"SaveManager restores the test payload"
		)

	if scene_manager != null:
		var invalid_change_succeeded: bool = bool(
			scene_manager.call("change_scene", "res://missing/foundation_smoke_test.tscn")
		)
		_check(
			not invalid_change_succeeded,
			"SceneManager rejects an invalid path without crashing"
		)

	if FileAccess.file_exists(TEST_SAVE_PATH):
		var cleanup_result: Error = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(TEST_SAVE_PATH)
		)
		_check(cleanup_result == OK, "Smoke-test save file is removed")

	main.queue_free()
	await process_frame
	_finish()


func _has_key_binding(action: StringName, key: int, physical: bool = false) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event == null:
			continue
		if physical and key_event.physical_keycode == key:
			return true
		if not physical and key_event.keycode == key:
			return true

	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures.append(description)
	printerr("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE TEST RESULT: PASS")
		quit(0)
		return

	printerr("SMOKE TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)
