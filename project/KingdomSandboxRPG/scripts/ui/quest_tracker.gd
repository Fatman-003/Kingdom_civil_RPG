class_name QuestTracker
extends CanvasLayer
@onready var _label: Label = $Panel/Margin/Label
var _quests: QuestSystem
func _ready() -> void:
	layer = 2
	$Panel.theme = FantasyTheme.shared()
	$Panel.offset_left = 18
	$Panel.offset_top = 106
	$Panel.offset_right = 310
	$Panel.offset_bottom = 190
	_label.add_theme_font_size_override("font_size", 14)
func configure(quests: QuestSystem) -> void:
	_quests = quests
	_quests.quest_state_changed.connect(_refresh)
	_quests.quest_progress_changed.connect(_refresh)
	_refresh("")
func _refresh(_quest_id: String = "", _state: String = "") -> void:
	if _quests == null: return
	for quest: Dictionary in _quests.get_quests():
		if str(quest.get("state", "")) == QuestSystem.ACTIVE or str(quest.get("state", "")) == QuestSystem.READY_TO_TURN_IN:
			_label.text = "QUEST\n%s\n%s" % [str(quest.get("display_name", "Quest")), _quests.get_objective_text(str(quest.get("quest_id", "")))]
			_label.add_theme_color_override("font_color", FantasyTheme.state_color(str(quest.get("state", ""))))
			visible = true; return
	visible = false
