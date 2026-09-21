extends Node


func change_scene(scene_path: String) -> bool:
	var normalized_path: String = scene_path.strip_edges()
	if normalized_path.is_empty():
		printerr("SceneManager.change_scene: scene path cannot be empty.")
		return false

	if not ResourceLoader.exists(normalized_path, "PackedScene"):
		printerr("SceneManager.change_scene: PackedScene not found: %s" % normalized_path)
		return false

	EventBus.scene_change_started.emit(normalized_path)
	var result: Error = get_tree().change_scene_to_file(normalized_path)
	if result != OK:
		printerr(
			"SceneManager.change_scene: failed to change to %s (error %d)."
			% [normalized_path, result]
		)
		return false

	EventBus.scene_changed.emit(normalized_path)
	return true
