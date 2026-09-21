class_name ActorPresentation
extends Node
## Cosmetics only. Never writes an entity transform, HP, cooldown or reservation.
enum State { IDLE, MOVE, BASIC_ATTACK, SKILL_CAST, ATTACK, HURT, DEATH }
var state: State = State.IDLE
var _visual: Node2D
var _moving: bool = false
var _remaining: float = 0.0
var _duration: float = 0.0
var _phase: float = 0.0
var _direction := Vector2.DOWN

func configure(visual: Node2D) -> void:
	_visual = visual

func set_moving(moving: bool) -> void:
	_moving = moving

func play(next: State, direction: Vector2 = Vector2.DOWN, duration: float = 0.2) -> void:
	if state == State.DEATH:
		return
	if _remaining > 0.0 and _priority(next) < _priority(state):
		return
	state = next
	_direction = direction
	_duration = maxf(duration, 0.01)
	_remaining = _duration
	_render()

func _priority(value: State) -> int:
	match value:
		State.DEATH: return 4
		State.HURT: return 3
		State.BASIC_ATTACK, State.SKILL_CAST, State.ATTACK: return 2
		_: return 1

func _process(delta: float) -> void:
	_phase += delta
	_remaining = maxf(_remaining - delta, 0.0)
	if _remaining == 0.0 and state != State.DEATH:
		state = State.MOVE if _moving else State.IDLE
	_render()

func _render() -> void:
	if not is_instance_valid(_visual):
		return
	_visual.position = Vector2.ZERO
	_visual.scale = Vector2.ONE
	_visual.rotation = 0.0
	_visual.modulate = Color.WHITE
	var pulse: float = sin((1.0 - _remaining / maxf(_duration, 0.01)) * PI)
	match state:
		State.IDLE:
			_visual.position.y = sin(_phase * 2.4) * 0.6
		State.MOVE:
			_visual.position.y = sin(_phase * 16.0) * 1.5
			_visual.scale = Vector2(1.0 + sin(_phase * 16.0) * 0.035, 1.0 - sin(_phase * 16.0) * 0.035)
		State.BASIC_ATTACK, State.ATTACK:
			_visual.position = _direction * pulse * 7.0
			_visual.scale = Vector2(1.0 + pulse * 0.14, 1.0 - pulse * 0.1)
			_visual.modulate = Color(1.2, 1.1, 0.85)
		State.SKILL_CAST:
			_visual.scale = Vector2.ONE * (1.0 + pulse * 0.22)
			_visual.rotation = pulse * 0.18
			_visual.modulate = Color(0.65, 1.4, 1.3)
		State.HURT:
			_visual.position.x = sin(_remaining * 95.0) * 2.5
			_visual.rotation = sin(_remaining * 50.0) * 0.1
			_visual.modulate = Color(1.4, 0.6, 0.55)
		State.DEATH:
			var fraction: float = _remaining / _duration
			_visual.scale = Vector2(1.25 - fraction * 0.25, 0.25 + fraction * 0.75)
			_visual.modulate = Color(0.7, 0.75, 0.8, 0.25 + fraction * 0.75)

static func floating_text(source: Node2D, text: String, tint: Color = Color("#ffe6ba")) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color("#203139"))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	source.get_parent().get_parent().add_child(label)
	label.global_position = source.global_position + Vector2(-12, -34)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 25, 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)

static func death_echo(source: Node2D, visual: Node2D) -> void:
	# Independent cosmetic copy: the monster still releases occupancy/rewards immediately.
	var echo := visual.duplicate() as Node2D
	source.get_parent().get_parent().add_child(echo)
	echo.global_position = source.global_position
	var tween := echo.create_tween().set_parallel()
	tween.tween_property(echo, "scale", Vector2(1.3, 0.15), 0.24)
	tween.tween_property(echo, "modulate:a", 0.0, 0.24)
	tween.chain().tween_callback(echo.queue_free)
