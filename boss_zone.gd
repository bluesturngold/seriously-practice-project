extends Area2D

@export var boss_scene: PackedScene
@export var zone_id: String = ""
@export var one_time_only: bool = true

var can_trigger: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not can_trigger:
		return
	if GameManager.is_encounter_immune():
		return
	if one_time_only and GameManager.is_zone_defeated(zone_id):
		return
	if not body.is_in_group("player"):
		return

	can_trigger = false
	start_encounter()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_trigger = true

func start_encounter() -> void:
	var player := get_tree().get_first_node_in_group("player")
	GameManager.player_overworld_position = player.global_position
	GameManager.overworld_scene_path = get_tree().current_scene.scene_file_path
	GameManager.pending_encounter_zone_id = zone_id
	GameManager.pending_encounter_enemies = [boss_scene]
	GameManager.pending_encounter_is_boss = true


	get_tree().change_scene_to_file.call_deferred("res://battle.tscn")
