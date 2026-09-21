extends Node

const SAVE_VERSION: int = 1
const TEST_VALUE: String = "foundation"

# TODO: Decide the production save-path policy in the dedicated save-system
# ticket. For now this intentionally uses Godot's standard user:// location.

var last_loaded_data: Dictionary = {}


func save_game(slot: int = 0) -> bool:
	if slot < 0:
		printerr("SaveManager.save_game: slot must be zero or greater.")
		return false

	var save_file: FileAccess = FileAccess.open(_get_save_path(slot), FileAccess.WRITE)
	if save_file == null:
		printerr(
			"SaveManager.save_game: could not open slot %d (error %d)."
			% [slot, FileAccess.get_open_error()]
		)
		return false

	var payload: Dictionary = {
		"save_version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(true),
		"test_value": TEST_VALUE,
	}
	save_file.store_string(JSON.stringify(payload))
	save_file.close()
	return true


func load_game(slot: int = 0) -> bool:
	if slot < 0:
		printerr("SaveManager.load_game: slot must be zero or greater.")
		return false

	var save_path: String = _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		printerr("SaveManager.load_game: save file does not exist for slot %d." % slot)
		return false

	var save_file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		printerr(
			"SaveManager.load_game: could not open slot %d (error %d)."
			% [slot, FileAccess.get_open_error()]
		)
		return false

	var parsed_payload: Variant = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	if typeof(parsed_payload) != TYPE_DICTIONARY:
		printerr("SaveManager.load_game: slot %d contains invalid JSON data." % slot)
		return false

	last_loaded_data = parsed_payload
	return true


func _get_save_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot
