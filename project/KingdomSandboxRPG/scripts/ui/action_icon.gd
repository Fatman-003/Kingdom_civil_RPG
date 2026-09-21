class_name ActionIcon
extends Control
## Replace this procedural icon with a TextureRect when skill art is available.
var state: String = "EMPTY"
var fraction: float = 0.0
var item_slot: bool = false
var icon_index: int = 0

func _ready() -> void:
	custom_minimum_size = Vector2(36, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size * 0.5
	var tint: Color = FantasyTheme.JADE if state == "READY" else FantasyTheme.MUTED
	if item_slot:
		tint = FantasyTheme.BRASS
	if state == "EMPTY" or state == "UNAVAILABLE" or state == "OUT_OF_STOCK":
		tint.a = 0.4
	draw_arc(center, 13.0, 0.0, TAU, 24, tint, 1.0, true)
	if state == "EMPTY":
		draw_line(center - Vector2(5, 0), center + Vector2(5, 0), tint, 2, true)
	elif item_slot:
		draw_rect(Rect2(center - Vector2(5, 7), Vector2(10, 14)), tint, false, 2)
	else:
		draw_line(center + Vector2(-8, 9), center + Vector2(7, -10), tint, 3, true)
		draw_line(center + Vector2(-7, 1), center + Vector2(1, 7), tint, 2, true)
		if icon_index > 0:
			draw_arc(center, 18, -1.5, 1.4, 16, tint, 2, true)
	if state == "COOLDOWN":
		draw_rect(Rect2(Vector2(0, size.y * (1.0 - fraction)), Vector2(size.x, size.y * fraction)), Color(0.04, 0.08, 0.1, 0.7))
