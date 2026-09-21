class_name GridNpc
extends CharacterBody2D

enum FacingDirection {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

const MOVE_DURATION: float = 0.15
const IDLE_INTERVAL_MIN: float = 0.8
const IDLE_INTERVAL_MAX: float = 2.5
const IDLE_BOB_HEIGHT: float = 0.5
const IDLE_BOB_SPEED: float = 2.0
const WALK_BOB_HEIGHT: float = 1.2
const WALK_BOB_SPEED: float = 14.0
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]

@export var starting_grid_position: Vector2i = Vector2i.ZERO
@export var placeholder_color: Color = Color(0.96, 0.57, 0.34, 1.0)
@export var visual_polygon: PackedVector2Array = PackedVector2Array()
@export var wandering_enabled: bool = true
@export var npc_id: String = ""
@export var display_name: String = "NPC"
@export var dialogue_id: String = ""
@export var liked_gifts: Array[String] = []
@export var disliked_gifts: Array[String] = []

@onready var _visual: Polygon2D = $Visual

var grid_position: Vector2i = Vector2i.ZERO
var facing_direction: FacingDirection = FacingDirection.DOWN

var _grid_world: Node
var _is_moving: bool = false
var _idle_seconds_remaining: float = 0.0
var _random := RandomNumberGenerator.new()
var dialogue_active: bool = false
var _movement_tween: Tween
var _reserved_target: Vector2i = Vector2i.ZERO
var _has_reserved_target: bool = false


func _ready() -> void:
	add_to_group("grid_entities")
	_random.randomize()
	_visual.color = placeholder_color
	if not visual_polygon.is_empty():
		_visual.polygon = visual_polygon
	_reset_idle_timer()


func configure(grid_world: Node, spawn_grid_position: Vector2i) -> void:
	_grid_world = grid_world
	set_grid_position(spawn_grid_position)


func set_grid_position(new_grid_position: Vector2i) -> void:
	grid_position = new_grid_position
	position = GridUtils.grid_to_world(grid_position)


func request_move(direction: Vector2i) -> bool:
	if _is_moving or not _is_cardinal_direction(direction):
		return false

	return _start_move(direction)


func is_moving() -> bool:
	return _is_moving


func set_dialogue_active(active: bool, player: Node) -> void:
	dialogue_active = active
	if active:
		_stop_active_movement()
		if player != null:
			_set_facing_direction(player.get("grid_position") - grid_position)
		return

	_reset_idle_timer()


func _process(delta: float) -> void:
	if _is_moving:
		_visual.position.y = sin(Time.get_ticks_msec() * 0.001 * WALK_BOB_SPEED) * WALK_BOB_HEIGHT
		return

	_visual.position.y = sin(Time.get_ticks_msec() * 0.001 * IDLE_BOB_SPEED) * IDLE_BOB_HEIGHT
	if _grid_world == null or not wandering_enabled or dialogue_active:
		return

	_idle_seconds_remaining -= delta
	if _idle_seconds_remaining > 0.0:
		return

	request_move(CARDINAL_DIRECTIONS[_random.randi_range(0, CARDINAL_DIRECTIONS.size() - 1)])
	_reset_idle_timer()


func _start_move(direction: Vector2i) -> bool:
	if _grid_world == null:
		return false

	_set_facing_direction(direction)
	var target_grid_position := grid_position + direction
	if not _grid_world.try_reserve_entity_move_to(target_grid_position, self):
		return false

	_is_moving = true
	var target_world_position := GridUtils.grid_to_world(target_grid_position)
	_movement_tween = create_tween()
	_reserved_target = target_grid_position
	_has_reserved_target = true
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
	_grid_world.release_entity_move_reservation(target_grid_position, self)
	_has_reserved_target = false
	_movement_tween = null


func _reset_idle_timer() -> void:
	_idle_seconds_remaining = _random.randf_range(IDLE_INTERVAL_MIN, IDLE_INTERVAL_MAX)


func _set_facing_direction(direction: Vector2i) -> void:
	if direction == Vector2i.UP:
		facing_direction = FacingDirection.UP
	elif direction == Vector2i.DOWN:
		facing_direction = FacingDirection.DOWN
	elif direction == Vector2i.LEFT:
		facing_direction = FacingDirection.LEFT
	elif direction == Vector2i.RIGHT:
		facing_direction = FacingDirection.RIGHT


func _stop_active_movement() -> void:
	if not _is_moving:
		return

	if _movement_tween != null:
		_movement_tween.kill()
	position = GridUtils.grid_to_world(grid_position)
	_visual.position = Vector2.ZERO
	_is_moving = false
	if _has_reserved_target:
		_grid_world.release_entity_move_reservation(_reserved_target, self)
		_has_reserved_target = false


func _is_cardinal_direction(direction: Vector2i) -> bool:
	return direction == Vector2i.UP or direction == Vector2i.DOWN or direction == Vector2i.LEFT or direction == Vector2i.RIGHT
