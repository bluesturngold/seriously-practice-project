extends Node2D

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if GameManager.player_overworld_position != Vector2.ZERO:
		player.global_position = GameManager.player_overworld_position
