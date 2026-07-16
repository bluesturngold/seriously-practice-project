extends Area2D
class_name Interactable

@export var interactable_id: String = ""
@export var dialogue_lines: Array[String] = []
@export var one_time_only: bool = false
@export var repeat_lines: Array[String] = []
@export var is_shop: bool = false
@export var shop_inventory: Array[Item] = []
@export var is_quest_giver: bool = false
@export var quest: Quest

func interact_as_quest_giver() -> Array[String]:
	if quest == null:
		return []

	if GameManager.is_quest_completed(quest.quest_id):
		return quest.completion_lines

	if GameManager.is_quest_active(quest.quest_id):
		var progress: int = GameManager.get_quest_progress(quest.quest_id)
		var lines: Array[String] = quest.reminder_lines.duplicate()
		lines.append(quest.enemy_name + " defeated: " + str(progress) + "/" + str(quest.required_count))
		return lines

	GameManager.start_quest(quest)
	return quest.offer_lines

func get_dialogue_to_show() -> Array[String]:
	if one_time_only and GameManager.has_talked_to(interactable_id):
		return repeat_lines
	return dialogue_lines

func mark_as_talked_to() -> void:
	if one_time_only:
		GameManager.mark_talked_to(interactable_id)
