extends Node2D

func _ready() -> void:
	for enemy_scene in GameManager.pending_encounter_enemies:
		var enemy_instance: Node2D = enemy_scene.instantiate()
		add_child(enemy_instance)
		enemy_instance.add_to_group("enemies")
		enemy_instance.died.connect(func(): 
			print("Enemy died, reporting: ", enemy_instance.stats.character_name)
			GameManager.register_enemy_defeated(enemy_instance.stats.character_name)
		)

#This script has to go on Enemies, because Enemies comes before BattleController in the nodetree.
#Godot loads nodes in the order they're listed, and we need enemies to load before the battle begins.
