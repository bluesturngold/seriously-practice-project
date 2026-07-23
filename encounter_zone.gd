# encounter_zone.gd
extends Area2D

@export var possible_enemies: Array[PackedScene] = []
@export var min_enemies: int = 1
@export var max_enemies: int = 3
@export var encounter_chance: float = 0.1
@export var cooldown_time: float = 0.5
@export var zone_id: String = ""
@export var one_time_only: bool = false

@export_group("Rewards")
@export var reward_gold: int = 0
@export var reward_items: Array[Item] = []

var can_trigger: bool = true
var has_been_used: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

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
	if randf() < encounter_chance:
		start_encounter()

	await get_tree().create_timer(cooldown_time).timeout
	can_trigger = true

func start_encounter() -> void:
	var player := get_tree().get_first_node_in_group("player")
	GameManager.player_overworld_position = player.global_position
	GameManager.overworld_scene_path = get_tree().current_scene.scene_file_path
	GameManager.pending_encounter_zone_id = zone_id
	GameManager.pending_encounter_is_boss = false

	# Cache rewards for the battle scene
	GameManager.pending_encounter_reward_gold = reward_gold
	GameManager.pending_encounter_reward_items = reward_items

	var enemy_count: int = randi_range(min_enemies, max_enemies)
	var chosen_enemies: Array[PackedScene] = []
	for i in enemy_count:
		chosen_enemies.append(possible_enemies.pick_random())
	GameManager.pending_encounter_enemies = chosen_enemies

	get_tree().change_scene_to_file.call_deferred("res://battle.tscn")
