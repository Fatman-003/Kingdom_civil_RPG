class_name Player
extends CharacterBody2D

enum FacingDirection {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

const BASE_MOVE_DURATION: float = 0.15
const BASE_MOBILITY: int = 10
const MIN_MOVE_DURATION: float = 0.08
const MAX_MOVE_DURATION: float = 0.30
const FALLBACK_MAX_HP: int = 100
const VISUAL_BOB_HEIGHT: float = 1.5
const VISUAL_BOB_SPEED: float = 16.0
const IDLE_BOB_HEIGHT: float = 0.6
const IDLE_BOB_SPEED: float = 2.4
const BASIC_ATTACK_COOLDOWN: float = 0.5

@onready var _visual: Node2D = $Visual
var presentation: ActorPresentation

var grid_position: Vector2i = Vector2i.ZERO
var facing_direction: FacingDirection = FacingDirection.DOWN

var _grid_world: Node
var _is_moving: bool = false
var _dialogue_active: bool = false
var _awaiting_interact_release: bool = false
var _inventory_open: bool = false
var _npc_interaction_open: bool = false
var current_hp: int = FALLBACK_MAX_HP
var _defeated: bool = false
var _skill_system: SkillSystem
var _progression: ProgressionSystem
var _last_max_hp: int = FALLBACK_MAX_HP
var _combat_cooldowns: Dictionary = {}
var _combat_cooldown_durations: Dictionary = {}
signal hp_changed(current_hp: int, max_hp: int)
signal defeated
signal combat_cooldowns_changed
signal level_up(level: int, stat_points_awarded: int, skill_points_awarded: int)


func configure(
	grid_world: Node,
	spawn_grid_position: Vector2i,
	skill_system: SkillSystem = null,
	progression: ProgressionSystem = null
) -> void:
	_grid_world = grid_world
	_skill_system = skill_system
	_progression = progression
	if _progression != null:
		if not _progression.base_stats_changed.is_connected(_on_base_stats_changed):
			_progression.base_stats_changed.connect(_on_base_stats_changed)
		if not _progression.level_up.is_connected(_on_progression_level_up):
			_progression.level_up.connect(_on_progression_level_up)
		current_hp = get_current_max_hp()
	_last_max_hp = get_current_max_hp()
	hp_changed.emit(current_hp, _last_max_hp)
	set_grid_position(spawn_grid_position)
	var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if camera != null and _grid_world != null and _grid_world.has_method("get_camera_limits"):
		var limits: Dictionary = _grid_world.get_camera_limits()
		camera.limit_left = int(limits.get("left", 0))
		camera.limit_top = int(limits.get("top", 0))
		camera.limit_right = int(limits.get("right", 0))
		camera.limit_bottom = int(limits.get("bottom", 0))
	_emit_facing_changed()


func _ready() -> void:
	presentation = ActorPresentation.new()
	add_child(presentation)
	presentation.configure(_visual)
	add_to_group("grid_entities")
	add_to_group("player")
	current_hp = get_current_max_hp()
	hp_changed.emit(current_hp, get_current_max_hp())
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.connect("dialogue_started", _on_dialogue_started)
		event_bus.connect("dialogue_ended", _on_dialogue_ended)
		event_bus.connect("inventory_opened", _on_inventory_opened)
		event_bus.connect("inventory_closed", _on_inventory_closed)
		event_bus.connect("npc_interaction_opened", _on_npc_interaction_opened)
		event_bus.connect("npc_interaction_closed", _on_npc_interaction_closed)


func set_grid_position(new_grid_position: Vector2i) -> void:
	grid_position = new_grid_position
	position = GridUtils.grid_to_world(grid_position)
	_emit_grid_position_changed()


func request_move(direction: Vector2i) -> bool:
	if _defeated or _dialogue_active or _inventory_open or _npc_interaction_open:
		return false
	if not _is_cardinal_direction(direction):
		return false

	if _is_moving:
		return false

	return _start_move(direction)


func is_moving() -> bool:
	return _is_moving


func is_dialogue_active() -> bool:
	return _dialogue_active


func request_interaction() -> void:
	if _awaiting_interact_release:
		if Input.is_action_pressed("interact"):
			return
		_awaiting_interact_release = false
	if _grid_world == null or _is_moving or _dialogue_active or _inventory_open or _npc_interaction_open:
		return

	var target_grid_position: Vector2i = grid_position + _facing_to_direction()
	var npc: GridNpc = _grid_world.get_interactable_npc_at(target_grid_position)
	if npc == null:
		return

	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal("npc_interaction_requested", npc)


func get_facing_name() -> String:
	match facing_direction:
		FacingDirection.UP:
			return "UP"
		FacingDirection.DOWN:
			return "DOWN"
		FacingDirection.LEFT:
			return "LEFT"
		FacingDirection.RIGHT:
			return "RIGHT"
	return "DOWN"


func _process(_delta: float) -> void:
	presentation.set_moving(_is_moving)
	_tick_combat_cooldowns(_delta)
	if _defeated:
		return
	if _dialogue_active:
		return
	if _inventory_open:
		return
	if _npc_interaction_open:
		return

	if _awaiting_interact_release and not Input.is_action_pressed("interact"):
		_awaiting_interact_release = false

	if _is_moving:
		return

	if not _awaiting_interact_release and Input.is_action_just_pressed("interact"):
		request_interaction()
		return
	if Input.is_action_just_pressed("attack"):
		_try_basic_attack()
		return
	for skill_slot: String in SkillSystem.SKILL_SLOTS:
		if Input.is_action_just_pressed(skill_slot):
			_try_activate_skill(skill_slot)
			return
	var requested_direction := _get_intended_direction()
	if requested_direction != Vector2i.ZERO:
		_start_move(requested_direction)


func _get_melee_damage() -> int:
	return int(_get_final_stats().get("attack", 5))

func get_current_max_hp() -> int:
	if _progression != null:
		return _progression.get_max_hp()
	return FALLBACK_MAX_HP

func _get_final_stats() -> Dictionary:
	var equipment: EquipmentSystem = null
	var parent_node: Node = get_parent()
	if parent_node != null:
		var root_node: Node = parent_node.get_parent()
		if root_node != null:
			equipment = root_node.get_node_or_null("EquipmentSystem") as EquipmentSystem
	if _progression != null:
		return _progression.get_final_stats(equipment)
	if equipment == null:
		return {"attack": 5, "defense": 0, "speed": 4, "mobility": BASE_MOBILITY}
	return equipment.get_final_stats()


func get_final_mobility() -> int:
	return maxi(int(_get_final_stats().get("mobility", BASE_MOBILITY)), 1)


func get_move_duration() -> float:
	var duration: float = BASE_MOVE_DURATION * float(BASE_MOBILITY) / float(get_final_mobility())
	return clampf(duration, MIN_MOVE_DURATION, MAX_MOVE_DURATION)


func get_level() -> int:
	return _progression.get_level() if _progression != null else 1


func get_current_xp() -> int:
	return _progression.get_current_xp() if _progression != null else 0


func get_xp_required_for_level() -> int:
	return _progression.xp_required_for_level() if _progression != null else 100


func get_stat_points() -> int:
	return _progression.get_stat_points() if _progression != null else 0


func get_skill_points() -> int:
	return _progression.get_skill_points() if _progression != null else 0


func get_base_stats() -> Dictionary:
	return _progression.get_base_stats() if _progression != null else {"hp": 10, "attack": 5, "defense": 0, "mobility": BASE_MOBILITY, "luck": 5}


func get_final_stats() -> Dictionary:
	return _get_final_stats()


func allocate_stat(stat_name: String) -> bool:
	return _progression != null and _progression.allocate_stat(stat_name)


func award_experience(amount: int) -> void:
	if _progression != null:
		_progression.add_experience(amount)

func take_damage(amount: int, _source: Node = null) -> void:
	if _defeated:
		return
	if amount <= 0:
		return
	var final_stats: Dictionary = _get_final_stats()
	var defense: int = int(final_stats.get("defense", 0))
	var resolved_damage: int = CombatMath.resolve_physical_damage(amount, defense)
	current_hp = maxi(current_hp - resolved_damage, 0)
	presentation.play(ActorPresentation.State.HURT)
	ActorPresentation.floating_text(self, str(resolved_damage), FantasyTheme.ROSE)
	hp_changed.emit(current_hp, get_current_max_hp())
	if current_hp == 0:
		_defeated = true
		presentation.play(ActorPresentation.State.DEATH, Vector2.DOWN, 0.3)
		defeated.emit()


func get_action_cooldown_remaining(action: String) -> float:
	return maxf(float(_combat_cooldowns.get(action, 0.0)), 0.0)


func get_action_cooldown_duration(action: String) -> float:
	return maxf(float(_combat_cooldown_durations.get(action, 0.0)), 0.0)


func get_assigned_skill(slot: String) -> String:
	if _skill_system == null:
		return ""
	return _skill_system.get_assigned_skill(slot)


func _try_basic_attack() -> void:
	if get_action_cooldown_remaining("attack") > 0.0:
		return
	_start_action_cooldown("attack", BASIC_ATTACK_COOLDOWN)
	presentation.play(ActorPresentation.State.BASIC_ATTACK, Vector2(_facing_to_direction()))
	if _grid_world != null:
		_grid_world.debug_attack_at(grid_position + _facing_to_direction(), _get_melee_damage(), self)


func _try_activate_skill(skill_slot: String) -> void:
	if _skill_system == null:
		return
	var skill_id: String = _skill_system.get_skill_for_action(skill_slot)
	if skill_id.is_empty() or not _skill_system.is_learned(skill_id):
		return
	var definition: Dictionary = _skill_system.get_skill_definition(skill_id)
	var cooldown: float = maxf(float(definition.get("cooldown", 0.0)), 0.0)
	if get_action_cooldown_remaining(skill_slot) > 0.0:
		return
	_start_action_cooldown(skill_slot, cooldown)
	presentation.play(ActorPresentation.State.SKILL_CAST, Vector2(_facing_to_direction()), 0.26)
	if _grid_world == null:
		return
	var multiplier: float = maxf(float(definition.get("damage_multiplier", 1.0)), 0.0)
	var damage: int = maxi(roundi(float(_get_melee_damage()) * multiplier), 1)
	_grid_world.debug_attack_at(grid_position + _facing_to_direction(), damage, self)


func _start_action_cooldown(action: String, duration: float) -> void:
	_combat_cooldowns[action] = duration
	_combat_cooldown_durations[action] = duration
	combat_cooldowns_changed.emit()


func _tick_combat_cooldowns(delta: float) -> void:
	var changed: bool = false
	for action_variant in _combat_cooldowns.keys():
		var action: String = str(action_variant)
		var previous: float = float(_combat_cooldowns[action])
		var current: float = maxf(previous - delta, 0.0)
		_combat_cooldowns[action] = current
		if (previous > 0.0 and current <= 0.0) or (previous <= 0.0 and current > 0.0):
			changed = true
	if changed:
		combat_cooldowns_changed.emit()


func _start_move(direction: Vector2i) -> bool:
	if _grid_world == null:
		return false

	_set_facing_direction(direction)
	var target_grid_position := grid_position + direction
	if not _grid_world.try_reserve_entity_move_to(target_grid_position, self):
		return false

	_is_moving = true
	var target_world_position := GridUtils.grid_to_world(target_grid_position)
	var movement_tween := create_tween()
	movement_tween.tween_property(self, "position", target_world_position, get_move_duration()).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	movement_tween.tween_callback(_finish_move.bind(target_grid_position))
	return true


func _finish_move(target_grid_position: Vector2i) -> void:
	grid_position = target_grid_position
	position = GridUtils.grid_to_world(grid_position)
	_visual.position = Vector2.ZERO
	_is_moving = false
	_grid_world.release_entity_move_reservation(target_grid_position, self)
	_emit_grid_position_changed()


func _get_intended_direction() -> Vector2i:
	if Input.is_action_pressed("move_up"):
		return Vector2i.UP
	if Input.is_action_pressed("move_down"):
		return Vector2i.DOWN
	if Input.is_action_pressed("move_left"):
		return Vector2i.LEFT
	if Input.is_action_pressed("move_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _set_facing_direction(direction: Vector2i) -> void:
	var new_facing_direction: FacingDirection = facing_direction
	if direction == Vector2i.UP:
		new_facing_direction = FacingDirection.UP
	elif direction == Vector2i.DOWN:
		new_facing_direction = FacingDirection.DOWN
	elif direction == Vector2i.LEFT:
		new_facing_direction = FacingDirection.LEFT
	elif direction == Vector2i.RIGHT:
		new_facing_direction = FacingDirection.RIGHT

	if new_facing_direction == facing_direction:
		return

	facing_direction = new_facing_direction
	_emit_facing_changed()


func _emit_facing_changed() -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal("player_facing_changed", get_facing_name())


func _emit_grid_position_changed() -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal("player_grid_position_changed", grid_position)


func _is_cardinal_direction(direction: Vector2i) -> bool:
	return direction == Vector2i.UP or direction == Vector2i.DOWN or direction == Vector2i.LEFT or direction == Vector2i.RIGHT


func _facing_to_direction() -> Vector2i:
	match facing_direction:
		FacingDirection.UP:
			return Vector2i.UP
		FacingDirection.DOWN:
			return Vector2i.DOWN
		FacingDirection.LEFT:
			return Vector2i.LEFT
		FacingDirection.RIGHT:
			return Vector2i.RIGHT
	return Vector2i.DOWN


func _on_dialogue_started(_npc: Node) -> void:
	_dialogue_active = true


func _on_dialogue_ended(_npc: Node) -> void:
	_dialogue_active = false
	_awaiting_interact_release = Input.is_action_pressed("interact")


func _on_inventory_opened() -> void:
	_inventory_open = true


func _on_inventory_closed() -> void:
	_inventory_open = false


func _on_npc_interaction_opened() -> void:
	_npc_interaction_open = true


func _on_npc_interaction_closed() -> void:
	_npc_interaction_open = false


func _on_base_stats_changed(_updated_base_stats: Dictionary) -> void:
	if _progression == null:
		return
	var new_max_hp: int = get_current_max_hp()
	var max_hp_delta: int = new_max_hp - _last_max_hp
	if max_hp_delta > 0:
		current_hp = mini(current_hp + max_hp_delta, new_max_hp)
	_last_max_hp = new_max_hp
	hp_changed.emit(current_hp, new_max_hp)


func _on_progression_level_up(new_level: int, stat_points_awarded: int, skill_points_awarded: int) -> void:
	level_up.emit(new_level, stat_points_awarded, skill_points_awarded)
