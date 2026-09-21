class_name FantasyTheme
extends RefCounted

const INK := Color("#213b43")
const PANEL := Color("#304e55")
const JADE := Color("#8ed3bc")
const PAPER := Color("#f2ead8")
const MUTED := Color("#b0bfba")
const BRASS := Color("#c6aa75")
const ROSE := Color("#e48e89")
static var _theme: Theme

static func frame(fill: Color, border: Color, radius: int = 7) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

static func shared() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 16
	_theme.set_color("font_color", "Label", PAPER)
	_theme.set_color("font_color", "Button", PAPER)
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_pressed_color", "Button", JADE)
	_theme.set_color("font_disabled_color", "Button", MUTED)
	var panel := frame(INK, BRASS, 10)
	panel.shadow_color = Color(0.02, 0.06, 0.07, 0.35)
	panel.shadow_size = 6
	_theme.set_stylebox("panel", "PanelContainer", panel)
	_theme.set_stylebox("panel", "Panel", panel)
	_theme.set_stylebox("normal", "Button", frame(PANEL, Color("#608078")))
	_theme.set_stylebox("hover", "Button", frame(Color("#3d6665"), JADE))
	_theme.set_stylebox("pressed", "Button", frame(Color("#416e66"), BRASS))
	_theme.set_stylebox("disabled", "Button", frame(Color("#304246"), Color("#53625e")))
	var focus := frame(Color.TRANSPARENT, BRASS)
	focus.set_border_width_all(2)
	_theme.set_stylebox("focus", "Button", focus)
	_theme.set_stylebox("background", "ProgressBar", frame(Color("#182d35"), Color("#617c77"), 4))
	var fill := frame(JADE, JADE, 3)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	_theme.set_stylebox("fill", "ProgressBar", fill)
	_theme.set_constant("separation", "VBoxContainer", 6)
	_theme.set_constant("separation", "HBoxContainer", 10)
	return _theme

static func select(button: Button, selected: bool) -> void:
	button.theme = shared()
	button.focus_mode = Control.FOCUS_NONE
	if selected:
		button.add_theme_stylebox_override("normal", shared().get_stylebox("pressed", "Button"))
		button.add_theme_color_override("font_color", JADE)
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_color_override("font_color")

static func state_color(state: String) -> Color:
	match state:
		"READY_TO_TURN_IN", "AVAILABLE": return BRASS
		"COMPLETED", "LEARNED", "ACTIVE": return JADE
		_: return MUTED
