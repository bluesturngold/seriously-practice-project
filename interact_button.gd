extends Button

func _ready() -> void:
	hide()
	pressed.connect(_on_pressed)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	visible = player.nearby_interactables.size() > 0

func _on_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.try_interact()
