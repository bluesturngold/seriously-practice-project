extends Node

var pending_spawn_point: String = ""
var overworld_scene_path: String = "res://overworld.tscn"
var player_overworld_position: Vector2 = Vector2.ZERO
var player_currency: int = 0
var distance_per_step: float = 32.0
var distance_since_last_step: float = 0.0
var steps_since_last_regen: int = 0
var steps_per_mp_regen: int = 10
var pending_encounter_is_boss: bool = false
var talked_to_npcs: Array[String] = []
var pending_load_confirmation: bool = false
signal npc_talked_to(id: String)
signal zone_defeated(id: String)
signal quest_completed(quest: Quest)

var active_quests: Dictionary = {}
var completed_quest_ids: Array[String] = []

func start_quest(quest: Quest) -> void:
	if active_quests.has(quest.quest_id) or completed_quest_ids.has(quest.quest_id):
		return
	active_quests[quest.quest_id] = {"quest": quest, "count": 0}
	print("Quest started: ", quest.quest_id, " — active quests: ", active_quests.keys())

func register_enemy_defeated(enemy_name: String) -> void:
	print("Registering defeat of: '", enemy_name, "' — checking against active quests: ", active_quests.keys())
	for quest_id in active_quests.keys():
		var entry: Dictionary = active_quests[quest_id]
		var quest: Quest = entry["quest"]
		print("Comparing to quest enemy_name: '", quest.enemy_name, "'")
		if quest.enemy_name == enemy_name:
			entry["count"] += 1
			print("Match! New count: ", entry["count"], "/", quest.required_count)
			if entry["count"] >= quest.required_count:
				_complete_quest(quest_id)

func place_player_at_spawn(scene_root: Node) -> void:
	var player := scene_root.get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if pending_spawn_point.is_empty():
		return

	for marker in scene_root.get_tree().get_nodes_in_group("spawn_points"):
		if marker.spawn_id == pending_spawn_point:
			player.global_position = marker.global_position
			pending_spawn_point = ""
			return

	push_warning("No spawn point found matching: " + pending_spawn_point)

func _complete_quest(quest_id: String) -> void:
	var entry: Dictionary = active_quests[quest_id]
	var quest: Quest = entry["quest"]
	active_quests.erase(quest_id)
	completed_quest_ids.append(quest_id)

	player_currency += quest.reward_currency
	for i in quest.reward_items.size():
		var quantity: int = 1
		if i < quest.reward_item_quantities.size():
			quantity = quest.reward_item_quantities[i]
		add_item(quest.reward_items[i], quantity)

	quest_completed.emit(quest)

func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id)

func is_quest_completed(quest_id: String) -> bool:
	return completed_quest_ids.has(quest_id)

func get_quest_progress(quest_id: String) -> int:
	if active_quests.has(quest_id):
		return active_quests[quest_id]["count"]
	return 0

const SAVE_DIR: String = "user://saves/"

func get_save_path(slot: String) -> String:
	return SAVE_DIR + slot + "_save.json"

func has_save(slot: String) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

func save_game(slot: String) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var party_data: Array = []
	for stats in party_stats:
		party_data.append({
			"source_path": stats.source_path,
			"level": stats.level,
			"experience": stats.experience,
			"experience_to_next_level": stats.experience_to_next_level,
			"current_health": stats.current_health,
			"max_health": stats.max_health,
			"current_mp": stats.current_mp,
			"max_mp": stats.max_mp,
			"attack": stats.attack,
			"defense": stats.defense
		})

	var inventory_data: Array = []
	for entry in inventory:
		inventory_data.append({
			"source_path": entry["item"].source_path,
			"quantity": entry["quantity"]
		})

	var save_data: Dictionary = {
		"party_stats": party_data,
		"inventory": inventory_data,
		"currency": player_currency,
		"defeated_encounter_zones": defeated_encounter_zones,
		"talked_to_npcs": talked_to_npcs,
		"overworld_scene_path": overworld_scene_path,
		"player_position": {"x": player_overworld_position.x, "y": player_overworld_position.y}
	}

	var file := FileAccess.open(get_save_path(slot), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Game saved to slot: ", slot)
	else:
		push_warning("Failed to save game to slot: " + slot)

func load_game(slot: String) -> bool:
	var path: String = get_save_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("No save file found for slot: " + slot)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var save_data = JSON.parse_string(text)
	if save_data == null:
		push_warning("Failed to parse save file for slot: " + slot)
		return false

	party_stats.clear()
	for entry in save_data["party_stats"]:
		var stats: CharacterStats = load(entry["source_path"]).duplicate()
		stats.source_path = entry["source_path"]
		stats.level = int(entry["level"])
		stats.experience = int(entry["experience"])
		stats.experience_to_next_level = int(entry["experience_to_next_level"])
		stats.current_health = int(entry["current_health"])
		stats.max_health = int(entry["max_health"])
		stats.current_mp = int(entry["current_mp"])
		stats.max_mp = int(entry["max_mp"])
		stats.attack = int(entry["attack"])
		stats.defense = int(entry["defense"])
		party_stats.append(stats)

	inventory.clear()
	for entry in save_data["inventory"]:
		var item: Item = load(entry["source_path"])
		item.source_path = entry["source_path"]
		inventory.append({"item": item, "quantity": int(entry["quantity"])})

	player_currency = int(save_data["currency"])

	defeated_encounter_zones.clear()
	for id in save_data["defeated_encounter_zones"]:
		defeated_encounter_zones.append(id)

	talked_to_npcs.clear()
	for id in save_data["talked_to_npcs"]:
		talked_to_npcs.append(id)

	overworld_scene_path = save_data["overworld_scene_path"]
	var pos: Dictionary = save_data["player_position"]
	player_overworld_position = Vector2(pos["x"], pos["y"])

	start_encounter_immunity()
	pending_load_confirmation = true
	get_tree().change_scene_to_file.call_deferred(overworld_scene_path)
	return true

func mark_talked_to(id: String) -> void:
	if not talked_to_npcs.has(id):
		talked_to_npcs.append(id)
		npc_talked_to.emit(id)

func has_talked_to(id: String) -> bool:
	return talked_to_npcs.has(id)

func register_movement(distance: float) -> void:
	distance_since_last_step += distance
	while distance_since_last_step >= distance_per_step:
		distance_since_last_step -= distance_per_step
		_register_step()

func _register_step() -> void:
	steps_since_last_regen += 1
	print("Step ", steps_since_last_regen, "/", steps_per_mp_regen)
	if steps_since_last_regen >= steps_per_mp_regen:
		steps_since_last_regen = 0
		_regenerate_party_mp()

func _regenerate_party_mp() -> void:
	for stats in party_stats:
		stats.current_mp = min(stats.current_mp + 1, stats.max_mp)

func add_currency(amount: int) -> void:
	player_currency += amount

func spend_currency(amount: int) -> bool:
	if amount > player_currency:
		return false
	player_currency -= amount
	return true

var party_stats: Array[CharacterStats] = []

var pending_encounter_enemies: Array[PackedScene] = []
var pending_encounter_zone_id: String = ""
var defeated_encounter_zones: Array[String] = []

func register_stats(new_stats: CharacterStats) -> void:
	party_stats.append(new_stats)

func get_stats_for(character_name: String) -> CharacterStats:
	for stats in party_stats:
		if stats.character_name == character_name:
			return stats
	return null

func mark_zone_defeated(id: String) -> void:
	if not defeated_encounter_zones.has(id):
		defeated_encounter_zones.append(id)
		zone_defeated.emit(id)
		
func is_zone_defeated(zone_id: String) -> bool:
	return defeated_encounter_zones.has(zone_id)
	
var encounter_immunity_duration: float = 1.5
var encounter_immune_until: int = 0

func start_encounter_immunity() -> void:
	encounter_immune_until = Time.get_ticks_msec() + int(encounter_immunity_duration * 1000)

func is_encounter_immune() -> bool:
	return Time.get_ticks_msec() < encounter_immune_until
	
var inventory: Array[Dictionary] = []

func _ready() -> void:
	print_rich("[color=yellow]--- CURRENT SCENE TREE ---[/color]")
	get_tree().root.print_tree_pretty()
	# Print the entire active scene tree to Output to see if nodes are missing or misplaced
	
	var starting_potion: Item = load("res://items/potion.tres")
	starting_potion.source_path = "res://items/potion.tres"
	add_item(starting_potion, 3)

	var starting_tonic: Item = load("res://items/tonic.tres")
	starting_tonic.source_path = "res://items/tonic.tres"
	add_item(starting_tonic, 2)

	var starting_party_files: Array[String] = [
		"res://party/party stats/party_one.tres",
		"res://party/party stats/party_two.tres",
		"res://party/party stats/party_three.tres",
		"res://party/party stats/party_four.tres"
	]
		
	for path in starting_party_files:
		var stats: CharacterStats = load(path).duplicate()
		stats.source_path = path
		register_stats(stats)

func add_item(item: Item, quantity: int = 1) -> void:
	for entry in inventory:
		if entry["item"] == item:
			entry["quantity"] += quantity
			return
	inventory.append({"item": item, "quantity": quantity})

func remove_item(item: Item, quantity: int = 1) -> void:
	for entry in inventory:
		if entry["item"] == item:
			entry["quantity"] = max(entry["quantity"] - quantity, 0)
			return
