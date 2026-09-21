class_name ProgressionSystem
extends Node

const STARTING_LEVEL: int = 1
const STARTING_XP: int = 0
const STARTING_STAT_POINTS: int = 3
const STARTING_SKILL_POINTS: int = 3
const STAT_POINTS_PER_LEVEL: int = 3
const SKILL_POINTS_PER_LEVEL: int = 1
const HP_PER_POINT: int = 10
const BASE_SPEED: int = 4
const XP_BASE_REQUIREMENT: int = 100
const XP_REQUIREMENT_STEP: int = 50
const MIN_BASE_STAT: int = 1
const BASE_STATS_DEFAULT: Dictionary = {
	"hp": 10,
	"attack": 5,
	"defense": 0,
	"mobility": 10,
	"luck": 5,
}

signal xp_changed(current_xp: int, required_xp: int)
signal level_changed(level: int)
signal base_stats_changed(base_stats: Dictionary)
signal stat_points_changed(stat_points: int)
signal skill_points_changed(skill_points: int)
signal level_up(level: int, stat_points_awarded: int, skill_points_awarded: int)

var level: int = STARTING_LEVEL
var current_xp: int = STARTING_XP
var stat_points: int = STARTING_STAT_POINTS
var skill_points: int = STARTING_SKILL_POINTS
var base_stats: Dictionary = BASE_STATS_DEFAULT.duplicate()


func _ready() -> void:
	_restore_runtime_state()


func xp_required_for_level(target_level: int = level) -> int:
	return XP_BASE_REQUIREMENT + maxi(target_level - 1, 0) * XP_REQUIREMENT_STEP


func get_max_hp() -> int:
	return maxi(int(base_stats.get("hp", BASE_STATS_DEFAULT["hp"])), MIN_BASE_STAT) * HP_PER_POINT


func get_base_stat(stat_name: String) -> int:
	return maxi(int(base_stats.get(stat_name, MIN_BASE_STAT)), _minimum_for_stat(stat_name))


func get_base_stats() -> Dictionary:
	return base_stats.duplicate()


func get_skill_points() -> int:
	return skill_points


func get_level() -> int:
	return level


func get_current_xp() -> int:
	return current_xp


func get_stat_points() -> int:
	return stat_points


func get_final_stats(equipment: EquipmentSystem = null) -> Dictionary:
	var stats: Dictionary = {
		"attack": get_base_stat("attack"),
		"defense": get_base_stat("defense"),
		"mobility": get_base_stat("mobility"),
		"luck": get_base_stat("luck"),
		"speed": BASE_SPEED,
	}
	if equipment != null:
		var modifiers: Dictionary = equipment.get_equipment_modifiers()
		for stat_name_variant in modifiers.keys():
			var stat_name: String = str(stat_name_variant)
			if stats.has(stat_name):
				stats[stat_name] = int(stats[stat_name]) + int(modifiers[stat_name])
	stats["mobility"] = maxi(int(stats.get("mobility", MIN_BASE_STAT)), MIN_BASE_STAT)
	return stats


func allocate_stat(stat_name: String) -> bool:
	if stat_points <= 0 or not base_stats.has(stat_name):
		return false
	stat_points -= 1
	base_stats[stat_name] = get_base_stat(stat_name) + 1
	_save_runtime_state()
	base_stats_changed.emit(get_base_stats())
	stat_points_changed.emit(stat_points)
	return true


func spend_skill_points(amount: int) -> bool:
	if amount <= 0 or skill_points < amount:
		return false
	skill_points -= amount
	_save_runtime_state()
	skill_points_changed.emit(skill_points)
	return true


func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	while current_xp >= xp_required_for_level(level):
		current_xp -= xp_required_for_level(level)
		level += 1
		stat_points += STAT_POINTS_PER_LEVEL
		skill_points += SKILL_POINTS_PER_LEVEL
		level_changed.emit(level)
		stat_points_changed.emit(stat_points)
		skill_points_changed.emit(skill_points)
		level_up.emit(level, STAT_POINTS_PER_LEVEL, SKILL_POINTS_PER_LEVEL)
	_save_runtime_state()
	xp_changed.emit(current_xp, xp_required_for_level(level))


func _restore_runtime_state() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return
	level = maxi(int(game_manager.get("progression_level")), STARTING_LEVEL)
	current_xp = maxi(int(game_manager.get("progression_xp")), 0)
	stat_points = maxi(int(game_manager.get("progression_stat_points")), 0)
	skill_points = maxi(int(game_manager.get("progression_skill_points")), 0)
	var stored_base_stats: Variant = game_manager.get("progression_base_stats")
	if stored_base_stats is Dictionary and not (stored_base_stats as Dictionary).is_empty():
		for stat_name in BASE_STATS_DEFAULT.keys():
			base_stats[stat_name] = maxi(int((stored_base_stats as Dictionary).get(stat_name, BASE_STATS_DEFAULT[stat_name])), _minimum_for_stat(str(stat_name)))
	_save_runtime_state()


func _minimum_for_stat(stat_name: String) -> int:
	return 0 if stat_name == "defense" else MIN_BASE_STAT


func _save_runtime_state() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return
	game_manager.set("progression_level", level)
	game_manager.set("progression_xp", current_xp)
	game_manager.set("progression_stat_points", stat_points)
	game_manager.set("progression_skill_points", skill_points)
	game_manager.set("progression_base_stats", base_stats.duplicate())
