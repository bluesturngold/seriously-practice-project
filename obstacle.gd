extends StaticBody2D
class_name Obstacle

enum ConditionType { NPC_TALKED, ZONE_DEFEATED, QUEST_COMPLETED }

@export var condition_type: ConditionType = ConditionType.NPC_TALKED
@export var required_id: String = ""

func _ready() -> void:
	if _condition_already_met():
		queue_free()
		return

	GameManager.npc_talked_to.connect(_on_npc_talked_to)
	GameManager.zone_defeated.connect(_on_zone_defeated)
	GameManager.quest_completed.connect(_on_quest_completed)

func _condition_already_met() -> bool:
	match condition_type:
		ConditionType.NPC_TALKED:
			return GameManager.has_talked_to(required_id)
		ConditionType.ZONE_DEFEATED:
			return GameManager.is_zone_defeated(required_id)
		ConditionType.QUEST_COMPLETED:
			return GameManager.is_quest_completed(required_id)
	return false

func _on_npc_talked_to(id: String) -> void:
	if condition_type == ConditionType.NPC_TALKED and id == required_id:
		queue_free()

func _on_zone_defeated(id: String) -> void:
	if condition_type == ConditionType.ZONE_DEFEATED and id == required_id:
		queue_free()

func _on_quest_completed(quest: Quest) -> void:
	if condition_type == ConditionType.QUEST_COMPLETED and quest.quest_id == required_id:
		queue_free()
