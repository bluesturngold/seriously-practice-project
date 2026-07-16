extends Control

var lines: Array[String] = []
var current_index: int = 0

@onready var label: RichTextLabel = $RichTextLabel

func _ready() -> void:
	hide()
	add_to_group("dialogue_box")

func start_dialogue(new_lines: Array[String]) -> void:
	if new_lines.is_empty():
		return
	lines = new_lines
	current_index = 0
	show()
	label.text = lines[current_index]

func advance() -> void:
	current_index += 1
	if current_index >= lines.size():
		hide()
	else:
		label.text = lines[current_index]

func is_active() -> bool:
	return visible
