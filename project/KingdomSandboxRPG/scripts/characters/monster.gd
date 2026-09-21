class_name GridMonster
extends CharacterBody2D

enum CombatState {
	IDLE,
	AGGRO,
	ATTACKING,
	DEAD,
}

enum FacingDirection {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

const MOVE_DURATION: float = 0.15
const DEFAULT_MOVE_INTERVAL: float = 0.45
const DEFAULT_ATTACK_WINDUP: float = 0.25

@export var monster_id: String = "slime"
@export var display_name: String = "Slime"
@export var max_hp: int = 10
@export var xp_reward: int = 15
@export var loot_table_id: String = "slime_loot"
@export var is_training_dummy: bool = false
@export var attack_damage: int = 2
@export var defense: int = 0
@export var attack_cooldown: float = 1.0
@export var attack_range: int = 1
@export var aggro_type: String = "AGGRESSIVE"
@export var aggro_range: int = 3
@export var chase_range: int = 7
@export var requires_facing: bool = false
@export var attack_windup: float = DEFAULT_ATTACK_WINDUP
@export var move_interval: float = DEFAULT_MOVE_INTERVAL
@export var placeholder_color: Color = Color(0.3, 0.8, 0.45, 1.0)
@export var starting_grid_position: Vector2i = Vector2i.ZERO

@onready var _visual: Polygon2D = $Visual
@onready var _hp_label: Label = $HpLabel

var current_hp: int
var grid_position: Vector2i
var combat_state: CombatState = CombatState.IDLE

var _grid_world: Node
var _is_moving: bool = false
var _movement_tween: Tween
var _reserved_target: Vector2i = Vector2i.ZERO
var _has_reserved_target: bool = false
var _move_seconds_remaining: float = 0.0
var _attack_seconds_remaining: float = 0.0
var _attack_windup_remaining: float = 0.0
var facing_direction: FacingDirection = FacingDirection.DOWN
var last_damage_source: Node
var presentation: ActorPresentation

signal died(monster: GridMonster)


func _ready() -> void:
	presentation = ActorPresentation.new()
	add_child(presentation)
	presentation.configure(_visual)
	add_to_group("grid_entities")
	current_hp = maxi(max_hp, 1)
	grid_position = starting_grid_position
	position = GridUtils.grid_to_world(grid_position)
	_visual.color = placeholder_color
	_update_hp_label()


func configure(grid_world: Node, spawn_grid_position: Vector2i = Vector2i.ZERO) -> void:
	_grid_world = grid_world
	set_grid_position(spawn_grid_position)
	combat_state = CombatState.IDLE
	_move_seconds_remaining = 0.0
	_attack_seconds_remaining = 0.0
	_attack_windup_remaining = 0.0


func set_grid_position(new_grid_position: Vector2i) -> void:
	grid_position = new_grid_position
	position = GridUtils.grid_to_world(grid_position)


func is_dead() -> bool:
	return combat_state == CombatState.DEAD or current_hp <= 0


func get_combat_state_name() -> String:
	match combat_state:
		CombatState.IDLE:
			return "IDLE"
		CombatState.AGGRO:
			return "AGGRO"
		CombatState.ATTACKING:
			return "ATTACKING"
		CombatState.DEAD:
			return "DEAD"
	return "IDLE"


func take_debug_damage(amount: int, source: Node = null) -> bool:
	return take_damage(amount, source)


func take_damage(amount: int, source: Node = null) -> bool:
	if is_dead() or amount <= 0:
		return false
	var resolved_damage: int = CombatMath.resolve_physical_damage(amount, defense)
	last_damage_source = source
	current_hp = maxi(current_hp - resolved_damage, 0)
	_update_hp_label()
	presentation.play(ActorPresentation.State.HURT)
	ActorPresentation.floating_text(self, str(resolved_damage))
	if is_training_dummy and current_hp == 0:
		current_hp = maxi(max_hp, 1)
		_update_hp_label()
	elif current_hp == 0:
		_die()
	elif aggro_type == "RETALIATORY":
		_set_aggro(source)
	return true


func _process(delta: float) -> void:
	if is_dead():
		return
	_update_visual_motion()
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player == null or player.current_hp <= 0:
		_disengage()
		return
	if _grid_world != null and _grid_world.has_method("can_monster_chase_target") and not _grid_world.can_monster_chase_target(self, player):
		_disengage()
		return

	var distance: int = _manhattan_distance(grid_position, player.grid_position)
	if combat_state == CombatState.IDLE:
		if aggro_type == "AGGRESSIVE" and distance <= maxi(aggro_range, 0):
			combat_state = CombatState.AGGRO
		else:
			return

	if distance > maxi(chase_range, attack_range):
		_disengage()
		return

	if combat_state == CombatState.ATTACKING:
		_process_attack_windup(delta, player)
		return
	if _is_moving:
		return

	_attack_seconds_remaining = maxf(_attack_seconds_remaining - delta, 0.0)
	if distance <= maxi(attack_range, 0):
		_face_player(player)
		if _attack_seconds_remaining <= 0.0:
			_begin_attack()
		return

	combat_state = CombatState.AGGRO
	_move_seconds_remaining = maxf(_move_seconds_remaining - delta, 0.0)
	if _move_seconds_remaining > 0.0 or _grid_world == null:
		return
	var next_step: Vector2i = _grid_world.get_chase_step(
		grid_position, player.grid_position, self, maxi(attack_range, 1)
	)
	if next_step == Vector2i.ZERO:
		return
	if _start_move(next_step):
		_move_seconds_remaining = maxf(move_interval, 0.05)


func _update_visual_motion() -> void:
	presentation.set_moving(_is_moving)


func _begin_attack() -> void:
	presentation.play(ActorPresentation.State.ATTACK, Vector2(_facing_to_vector()), maxf(attack_windup, 0.1))
	combat_state = CombatState.ATTACKING
	_attack_windup_remaining = maxf(attack_windup, 0.0)
	if _attack_windup_remaining <= 0.0:
		_attack_windup_remaining = 0.01


func _process_attack_windup(delta: float, player: Player) -> void:
	_attack_windup_remaining -= delta
	if _attack_windup_remaining > 0.0:
		return
	combat_state = CombatState.AGGRO
	_attack_seconds_remaining = maxf(attack_cooldown, 0.05)
	var distance: int = _manhattan_distance(grid_position, player.grid_position)
	if player.current_hp <= 0 or distance > maxi(attack_range, 0):
		return
	if requires_facing and _facing_to_player(player) != _facing_to_vector():
		return
	player.take_damage(attack_damage, self)


func _start_move(direction: Vector2i) -> bool:
	if _grid_world == null or _is_moving or not _is_cardinal_direction(direction):
		return false
	_set_facing_direction(direction)
	var target_grid_position: Vector2i = grid_position + direction
	if not _grid_world.try_reserve_entity_move_to(target_grid_position, self):
		return false
	_is_moving = true
	_reserved_target = target_grid_position
	_has_reserved_target = true
	var target_world_position: Vector2 = GridUtils.grid_to_world(target_grid_position)
	_movement_tween = create_tween()
	_movement_tween.tween_property(self, "position", target_world_position, MOVE_DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	_movement_tween.tween_callback(_finish_move.bind(target_grid_position))
	return true


func _finish_move(target_grid_position: Vector2i) -> void:
	grid_position = target_grid_position
	position = GridUtils.grid_to_world(grid_position)
	_visual.position = Vector2.ZERO
	_is_moving = false
	if _grid_world != null:
		_grid_world.release_entity_move_reservation(target_grid_position, self)
	_has_reserved_target = false
	_movement_tween = null


func _stop_active_movement() -> void:
	if _movement_tween != null:
		_movement_tween.kill()
	_movement_tween = null
	if _grid_world != null and _has_reserved_target:
		_grid_world.release_entity_move_reservation(_reserved_target, self)
	_has_reserved_target = false
	_is_moving = false
	position = GridUtils.grid_to_world(grid_position)
	_visual.position = Vector2.ZERO


func _die() -> void:
	presentation.play(ActorPresentation.State.DEATH)
	ActorPresentation.death_echo(self, _visual)
	combat_state = CombatState.DEAD
	_attack_windup_remaining = 0.0
	_attack_seconds_remaining = 0.0
	_stop_active_movement()
	remove_from_group("grid_entities")
	_hp_label.visible = false
	died.emit(self)
	queue_free()


func _set_aggro(_source: Node = null) -> void:
	if not is_dead():
		combat_state = CombatState.AGGRO


func _disengage() -> void:
	if combat_state == CombatState.DEAD:
		return
	combat_state = CombatState.IDLE
	_attack_windup_remaining = 0.0
	_attack_seconds_remaining = 0.0


func _face_player(player: Player) -> void:
	_set_facing_direction(_facing_to_player(player))


func _facing_to_player(player: Player) -> Vector2i:
	var offset: Vector2i = player.grid_position - grid_position
	if absi(offset.x) > absi(offset.y):
		return Vector2i.RIGHT if offset.x > 0 else Vector2i.LEFT
	return Vector2i.DOWN if offset.y > 0 else Vector2i.UP


func _set_facing_direction(direction: Vector2i) -> void:
	match direction:
		Vector2i.UP:
			facing_direction = FacingDirection.UP
		Vector2i.DOWN:
			facing_direction = FacingDirection.DOWN
		Vector2i.LEFT:
			facing_direction = FacingDirection.LEFT
		Vector2i.RIGHT:
			facing_direction = FacingDirection.RIGHT


func _facing_to_vector() -> Vector2i:
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


func _is_cardinal_direction(direction: Vector2i) -> bool:
	return direction == Vector2i.UP or direction == Vector2i.DOWN or direction == Vector2i.LEFT or direction == Vector2i.RIGHT


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _update_hp_label() -> void:
	_hp_label.text = "%d / %d" % [current_hp, max_hp]
