class_name CombatHud
extends CanvasLayer

@onready var _hp_label: Label = $HpLabel
@onready var _hp_bar: ProgressBar = $HpBar
@onready var _defeat: PanelContainer = $Defeat
@onready var _level_up_label: Label = $LevelUpLabel

var _player: Player
var _restart_in_progress: bool = false

func configure(player: Player) -> void:
	_player = player
	_player.hp_changed.connect(_update_hp)
	_player.defeated.connect(_show_defeat)
	_player.level_up.connect(_show_level_up)
	_update_hp(player.current_hp, player.get_current_max_hp())

func _ready() -> void:
	_defeat.visible = false
	_update_action_hud()


func _process(_delta: float) -> void:
	_update_action_hud()

func _update_hp(current_hp: int, max_hp: int) -> void:
	_hp_label.text = "HP %d / %d" % [current_hp, max_hp]
	_hp_bar.max_value = maxi(max_hp, 1)
	_hp_bar.value = clampf(float(current_hp), 0.0, float(maxi(max_hp, 1)))

func _show_defeat() -> void:
	_defeat.visible = true


func _show_level_up(new_level: int, stat_points_awarded: int, skill_points_awarded: int) -> void:
	_level_up_label.text = "LEVEL UP!\nLevel %d\n+%d Stat Points   +%d Skill Point" % [new_level, stat_points_awarded, skill_points_awarded]
	_level_up_label.visible = true
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(_level_up_label):
			_level_up_label.visible = false
	)


func _update_action_hud() -> void:
	if _player == null:
		return
	var actions: Array[String] = ["attack", "skill_1", "skill_2", "skill_3", "skill_4"]
	var keys: Array[String] = ["A", "Q", "W", "E", "R"]
	var labels: Array[String] = ["Basic Attack", "Empty", "Empty", "Empty", "Empty"]
	for index in range(1, 5):
		var skill_id: String = _player.get_assigned_skill("skill_%d" % index)
		if not skill_id.is_empty() and _player.get_node_or_null("../..") != null:
			var skill_system: SkillSystem = _player.get_node("../../SkillSystem") as SkillSystem
			if skill_system != null:
				labels[index] = str(skill_system.get_skill_definition(skill_id).get("display_name", skill_id))
	var slot_nodes: Array[PanelContainer] = [
		$ActionBar/AttackSlot,
		$ActionBar/Skill1Slot,
		$ActionBar/Skill2Slot,
		$ActionBar/Skill3Slot,
		$ActionBar/Skill4Slot,
	]
	for index in slot_nodes.size():
		var slot: PanelContainer = slot_nodes[index]
		var cooldown: float = _player.get_action_cooldown_remaining(actions[index])
		slot.modulate = Color(0.52, 0.56, 0.62, 1.0) if cooldown > 0.0 else Color.WHITE
		var key_label: Label = slot.get_node("VBox/Key") as Label
		var name_label: Label = slot.get_node("VBox/Name") as Label
		var cooldown_label: Label = slot.get_node("VBox/Cooldown") as Label
		key_label.text = "[ %s ]" % keys[index]
		name_label.text = labels[index]
		cooldown_label.text = "%.1f" % cooldown if cooldown > 0.0 else "Ready"

func _unhandled_input(event: InputEvent) -> void:
	if not _defeat.visible or _restart_in_progress or not event.is_action_pressed("interact", false):
		return
	_restart_in_progress = true
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	get_tree().reload_current_scene()
