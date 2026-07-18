# overworld.gd
extends Node2D

func _ready() -> void:
	GameManager.initialize_player_position(self)
