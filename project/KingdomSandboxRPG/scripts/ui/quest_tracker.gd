class_name QuestTracker
extends Control
@onready var _label: Label = $Panel/Margin/Label
var _quests: QuestSystem
func configure(quests: QuestSystem) -> void:
	_quests = quests
	_quests.quest_state_changed.connect(_refresh)
	_quests.quest_progress_changed.connect(_refresh)
	_refresh("")
func _refresh(_quest_id: String = "", _state: String = "") -> void:
	if _quests == null: return
	for quest: Dictionary in _quests.get_quests():
		if str(quest.get("state", "")) == QuestSystem.ACTIVE or str(quest.get("state", "")) == QuestSystem.READY_TO_TURN_IN:
			_label.text = "%s\n%s" % [str(quest.get("display_name", "Quest")), _quests.get_objective_text(str(quest.get("quest_id", "")))]
			visible = true; return
	visible = false
