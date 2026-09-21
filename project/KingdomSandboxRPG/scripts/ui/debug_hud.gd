extends Control

const FPS_UPDATE_INTERVAL: float = 0.25

@onready var _fps_label: Label = $MarginContainer/VBoxContainer/FPSLabel
@onready var _grid_label: Label = $MarginContainer/VBoxContainer/GridLabel
@onready var _facing_label: Label = $MarginContainer/VBoxContainer/FacingLabel

var _elapsed_since_update: float = 0.0


func _ready() -> void:
	theme = FantasyTheme.shared()
	$MarginContainer.position = Vector2(1040, 16)
	$MarginContainer.size = Vector2(224, 140)
	modulate = Color(0.8, 0.9, 0.86, 0.85)
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.connect("player_grid_position_changed", _on_player_grid_position_changed)
		event_bus.connect("player_facing_changed", _on_player_facing_changed)
	_update_fps_label()


func _process(delta: float) -> void:
	_elapsed_since_update += delta
	if _elapsed_since_update < FPS_UPDATE_INTERVAL:
		return

	_elapsed_since_update = 0.0
	_update_fps_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _update_fps_label() -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_player_grid_position_changed(grid_position: Vector2i) -> void:
	_grid_label.text = "Grid: %d, %d" % [grid_position.x, grid_position.y]


func _on_player_facing_changed(direction: String) -> void:
	_facing_label.text = "Facing: %s" % direction
