extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var pause_menu: Control = get_tree().get_first_node_in_group("pause_menu")
	if pause_menu != null:
		pause_menu.open_menu()
