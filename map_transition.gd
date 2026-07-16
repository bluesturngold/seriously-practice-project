extends Area2D

@export var destination_scene_path: String = "res://scenes/town_a.tscn"
@export var spawn_point_name: String = "from_overworld"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	GameManager.pending_spawn_point = spawn_point_name
	get_tree().change_scene_to_file.call_deferred(destination_scene_path)
