extends Node

var is_game_paused: bool = false
var learned_skills: Array[String] = []
var assigned_skills: Dictionary = {
	"skill_1": "",
	"skill_2": "",
	"skill_3": "",
	"skill_4": "",
}
var equipped_items: Dictionary = {
	"main_hand": "",
	"off_hand": "",
	"head": "",
	"body": "",
	"boots": "",
	"accessory": "",
}
var progression_level: int = 1
var progression_xp: int = 0
var progression_stat_points: int = 3
var progression_skill_points: int = 3
var progression_base_stats: Dictionary = {"hp": 10, "attack": 5, "defense": 0, "mobility": 10, "luck": 5}
var quest_states: Dictionary = {}
var quest_progress: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_paused(value: bool) -> void:
	is_game_paused = value
	get_tree().paused = value
