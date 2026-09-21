class_name CombatHud
extends CanvasLayer

@onready var _hp_label: Label = $HpLabel
@onready var _hp_bar: ProgressBar = $HpBar
@onready var _defeat: PanelContainer = $DefeatLayer/Defeat
@onready var _level_up_label: Label = $LevelUpLabel

var _player: Player
var _restart_in_progress: bool = false
var _previous_hp: int = -1
var _hp_flash: Tween

func configure(player: Player) -> void:
	_player = player
	_player.hp_changed.connect(_update_hp)
	_player.defeated.connect(_show_defeat)
	_player.level_up.connect(_show_level_up)
	_update_hp(player.current_hp, player.get_current_max_hp())

func _ready() -> void:
	_build_presentation()
	_defeat.visible = false
	_update_action_hud()


func _process(_delta: float) -> void:
	_update_action_hud()

func _update_hp(current_hp: int, max_hp: int) -> void:
	_hp_label.text = "HP %d / %d" % [current_hp, max_hp]
	_hp_bar.max_value = maxi(max_hp, 1)
	_hp_bar.value = clampf(float(current_hp), 0.0, float(maxi(max_hp, 1)))
	if _previous_hp >= 0 and current_hp < _previous_hp:
		if _hp_flash != null:
			_hp_flash.kill()
		_hp_bar.modulate = Color(1.5, 0.6, 0.5)
		_hp_flash = create_tween()
		_hp_flash.tween_property(_hp_bar, "modulate", Color.WHITE, 0.2)
	_previous_hp = current_hp

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
		var state: String = "EMPTY" if labels[index] == "Empty" else "READY"
		if state != "EMPTY" and (_player.current_hp <= 0 or bool(_player.get("_inventory_open")) or _player.is_dialogue_active() or bool(_player.get("_npc_interaction_open"))):
			state = "UNAVAILABLE"
		elif state != "EMPTY" and cooldown > 0.0:
			state = "COOLDOWN"
		var icon: ActionIcon = slot.get_node("VBox/Icon") as ActionIcon
		icon.state = state
		icon.fraction = clampf(cooldown / maxf(_player.get_action_cooldown_duration(actions[index]), 0.01), 0, 1)
		icon.queue_redraw()
		slot.modulate = Color(0.7, 0.77, 0.76) if state == "UNAVAILABLE" else Color.WHITE
		var key_label: Label = slot.get_node("VBox/Key") as Label
		var name_label: Label = slot.get_node("VBox/Name") as Label
		var cooldown_label: Label = slot.get_node("VBox/Cooldown") as Label
		key_label.text = "[ %s ]" % keys[index]
		name_label.text = labels[index]
		cooldown_label.text = "%.1fs" % cooldown if cooldown > 0.0 else state.capitalize()
		cooldown_label.add_theme_color_override("font_color", FantasyTheme.JADE if state == "READY" else FantasyTheme.MUTED)

func _build_presentation() -> void:
	for child in get_children():
		if child is Control:
			child.theme = FantasyTheme.shared()
	_defeat.theme = FantasyTheme.shared()
	var hp_frame := Panel.new()
	hp_frame.theme = FantasyTheme.shared()
	hp_frame.position = Vector2(16, 16)
	hp_frame.size = Vector2(282, 76)
	hp_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_frame)
	move_child(hp_frame, 0)
	_hp_label.position = Vector2(32, 25)
	_hp_label.add_theme_font_size_override("font_size", 20)
	_hp_bar.position = Vector2(32, 58)
	_hp_bar.size = Vector2(248, 17)
	_hp_bar.add_theme_stylebox_override("fill", FantasyTheme.frame(Color("#ce7372"), Color("#e9b4a0"), 4))
	var bar: HBoxContainer = $ActionBar
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -405
	bar.offset_right = 405
	bar.offset_top = -132
	bar.offset_bottom = -16
	for index in bar.get_child_count():
		var slot: PanelContainer = bar.get_child(index) as PanelContainer
		slot.custom_minimum_size = Vector2(98, 112)
		var column: VBoxContainer = slot.get_node("VBox")
		column.add_theme_constant_override("separation", 2)
		var icon := ActionIcon.new()
		icon.name = "Icon"
		icon.icon_index = index
		column.add_child(icon)
		column.move_child(icon, 1)
		var title: Label = column.get_node("Name")
		title.custom_minimum_size = Vector2(78, 30)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 13)
		column.get_node("Cooldown").add_theme_font_size_override("font_size", 13)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 10
	bar.add_child(spacer)
	for index in range(4):
		var slot := PanelContainer.new()
		slot.name = "QuickItem%d" % (index + 1)
		slot.custom_minimum_size = Vector2(58, 92)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.add_theme_stylebox_override("panel", FantasyTheme.frame(Color("#3d4748"), FantasyTheme.BRASS))
		bar.add_child(slot)
		var column := VBoxContainer.new()
		slot.add_child(column)
		var key := Label.new()
		key.text = str(index + 1)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(key)
		var icon := ActionIcon.new()
		icon.item_slot = true
		column.add_child(icon)
		var label := Label.new()
		label.text = "Empty"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		column.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if not _defeat.visible or _restart_in_progress or not event.is_action_pressed("interact", false):
		return
	_restart_in_progress = true
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	get_tree().reload_current_scene()
