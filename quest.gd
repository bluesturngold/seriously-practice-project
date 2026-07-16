extends Resource
class_name Quest

@export var quest_id: String = ""
@export var enemy_name: String = ""
@export var required_count: int = 1
@export var offer_lines: Array[String] = []
@export var reminder_lines: Array[String] = []
@export var completion_lines: Array[String] = []
@export var reward_currency: int = 0
@export var reward_items: Array[Item] = []
@export var reward_item_quantities: Array[int] = []
