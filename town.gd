extends Node2D

func _ready() -> void:
	GameManager.place_player_at_spawn(self)
