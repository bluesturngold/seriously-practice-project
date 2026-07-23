# battle_controller.gd
extends Node

enum State { START, PLAYER_CHOICE, PLAYER_ACTION, ENEMY_ACTION, CHECK_END, VICTORY, DEFEAT }

var current_state: State = State.START
var active_player: Battler
var party_turn_queue: Array = []

# Queue to hold sequential slides of the victory summary
var _victory_messages: Array[String] = []

func _ready() -> void:
	$"../CanvasLayer/BattleUI".target_chosen.connect(_on_target_chosen)
	$"../CanvasLayer/BattleUI".defend_chosen.connect(_on_defend_chosen)
	$"../CanvasLayer/BattleUI".proceed_chosen.connect(_on_proceed_chosen)
	$"../CanvasLayer/BattleUI".run_chosen.connect(_on_run_chosen)
	$"../CanvasLayer/BattleUI".ability_used.connect(_on_ability_used)
	$"../CanvasLayer/BattleUI".item_used.connect(_on_item_used)
	GameManager.quest_completed.connect(_on_quest_completed)
	change_state.call_deferred(State.START)

func change_state(new_state: State) -> void:
	current_state = new_state
	match current_state:
		State.START:
			_on_start()
		State.PLAYER_CHOICE:
			_on_player_choice()
		State.PLAYER_ACTION:
			_on_player_action()
		State.ENEMY_ACTION:
			_on_enemy_action()
		State.CHECK_END:
			_on_check_end()
		State.VICTORY:
			_on_victory()
		State.DEFEAT:
			print("You lost...")
			$"../CanvasLayer/BattleUI".hide()
			_heal_party_to_full()
			GameManager.start_encounter_immunity()
			get_tree().change_scene_to_file(GameManager.overworld_scene_path)

func _on_start() -> void:
	print("Battle starting...")
	_position_battlers($"../Party".get_children(), $"../PartyPositions".get_children())

	if GameManager.pending_encounter_is_boss:
		var boss: Node2D = $"../Enemies".get_children()[0]
		boss.global_position = $"../EnemyPositions/BossPosition".global_position
	else:
		_position_battlers($"../Enemies".get_children(), $"../EnemyPositions".get_children())

	_start_new_round()

func _start_new_round() -> void:
	var party: Array = get_tree().get_nodes_in_group("party")
	party_turn_queue = party.filter(func(member): return member.stats.current_health > 0)
	_advance_to_next_party_member()

func _advance_to_next_party_member() -> void:
	if party_turn_queue.is_empty():
		change_state(State.ENEMY_ACTION)
		return

	active_player = party_turn_queue.pop_front()
	
	active_player.is_defending = false

	for message in active_player.process_status_ticks():
		_log(message)

	if active_player.stats.current_health <= 0:
		_advance_to_next_party_member()
		return

	if active_player.has_pending_skip():
		active_player.consume_skip()
		_log(active_player.stats.character_name + " is slowed and skips this turn!")
		_advance_to_next_party_member()
		return

	change_state(State.PLAYER_CHOICE)

func _on_player_choice() -> void:
	$"../CanvasLayer/BattleUI".set_active_player(active_player)
	$"../CanvasLayer/BattleUI".show_turn(active_player.stats.character_name)
	print("Waiting for ", active_player.stats.character_name, " to choose an action...")

func _on_target_chosen(target: Battler) -> void:
	var damage_amount: int = int(active_player.stats.attack * active_player.get_attack_modifier())
	target.take_damage(damage_amount)
	_log(active_player.stats.character_name + " attacks " + target.stats.character_name + " for " + str(damage_amount) + " damage!")

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var all_enemies_defeated: bool = enemies.all(func(enemy): return enemy.stats.current_health <= 0)

	if all_enemies_defeated:
		change_state(State.CHECK_END)
	else:
		_advance_to_next_party_member()

func _on_defend_chosen() -> void:
	active_player.is_defending = true
	_log(active_player.stats.character_name + " defends!")
	_advance_to_next_party_member()

func _on_run_chosen() -> void:
	var living_enemies: Array = get_tree().get_nodes_in_group("enemies").filter(
		func(enemy): return enemy.stats.current_health > 0
	)

	var average_enemy_level: float = 0.0
	if living_enemies.size() > 0:
		var total_level: int = 0
		for enemy in living_enemies:
			total_level += enemy.stats.level
		average_enemy_level = float(total_level) / living_enemies.size()

	var level_bonus: float = (active_player.stats.level - average_enemy_level) * 0.01
	var run_chance: float = clamp(0.5 + level_bonus, 0.0, 1.0)

	if randf() < run_chance:
		print(active_player.stats.character_name, " fled the battle successfully!")
		$"../CanvasLayer/BattleUI".hide()
		GameManager.start_encounter_immunity()
		get_tree().change_scene_to_file(GameManager.overworld_scene_path)
	else:
		print(active_player.stats.character_name, " failed to flee!")
		_advance_to_next_party_member()

func _on_player_action() -> void:
	print("Executing player action...")
	change_state(State.ENEMY_ACTION)

func _on_ability_used(ability: Ability, target: Battler) -> void:
	active_player.spend_mp(ability.mp_cost)
	var damage_amount: int = int(ability.damage_amount * active_player.get_attack_modifier())

	if ability.target_type == Ability.TargetType.ALL_ENEMIES:
		var living_enemies: Array = get_tree().get_nodes_in_group("enemies").filter(
			func(enemy): return enemy.stats.current_health > 0
		)
		for enemy in living_enemies:
			enemy.take_damage(damage_amount)
			_log(active_player.stats.character_name + " uses " + ability.ability_name + " on " + enemy.stats.character_name + " for " + str(damage_amount) + " damage!")
			if ability.inflicts_status != null:
				enemy.apply_status(ability.inflicts_status)
				_log(enemy.stats.character_name + " is afflicted with " + ability.inflicts_status.effect_name + "!")
	else:
		target.take_damage(damage_amount)
		_log(active_player.stats.character_name + " uses " + ability.ability_name + " on " + target.stats.character_name + " for " + str(damage_amount) + " damage!")
		if ability.inflicts_status != null:
			target.apply_status(ability.inflicts_status)
			_log(target.stats.character_name + " is afflicted with " + ability.inflicts_status.effect_name + "!")

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var all_enemies_defeated: bool = enemies.all(func(enemy): return enemy.stats.current_health <= 0)

	if all_enemies_defeated:
		change_state(State.CHECK_END)
	else:
		_advance_to_next_party_member()

func _on_item_used(item: Item, target: Battler) -> void:
	if item.heal_amount > 0:
		target.heal(item.heal_amount)
		_log(active_player.stats.character_name + " uses " + item.item_name + " on " + target.stats.character_name + " for " + str(item.heal_amount) + " HP!")

	if item.mp_restore_amount > 0:
		target.restore_mp(item.mp_restore_amount)
		_log(active_player.stats.character_name + " uses " + item.item_name + " on " + target.stats.character_name + " for " + str(item.mp_restore_amount) + " MP!")

	GameManager.remove_item(item, 1)
	_advance_to_next_party_member()

func _on_enemy_action() -> void:
	print("Executing enemy action...")

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var party: Array = get_tree().get_nodes_in_group("party")

	for enemy in enemies:
		if enemy.stats.current_health <= 0:
			continue

		# Clean slate: Reset defending status at the start of their active turn
		enemy.is_defending = false

		for message in enemy.process_status_ticks():
			_log(message)

		if enemy.stats.current_health <= 0:
			continue

		if enemy.has_pending_skip():
			enemy.consume_skip()
			_log(enemy.stats.character_name + " is slowed and skips this turn!")
			continue

		var living_party: Array = party.filter(func(member): return member.stats.current_health > 0)
		if living_party.is_empty():
			break

		$"../CanvasLayer/BattleUI".show_turn(enemy.stats.character_name)

		# State machine to decide current enemy action
		var action_taken: bool = false
		
		# 1. Low health defend check
		var hp_pct: float = float(enemy.stats.current_health) / float(enemy.stats.max_health) if enemy.stats.max_health > 0 else 0.0
		if hp_pct < 0.33 and randf() < 0.50:
			enemy.is_defending = true
			_log(enemy.stats.character_name + " defends!")
			action_taken = true
			
		# 2. 10% Chance to cast a random assigned ability
		if not action_taken and enemy.stats.abilities.size() > 0 and randf() < 0.10:
			var ability: Ability = enemy.stats.abilities.pick_random()
			if enemy.stats.current_mp >= ability.mp_cost:
				enemy.spend_mp(ability.mp_cost)
				var damage_amount: int = int(ability.damage_amount * enemy.get_attack_modifier())
				
				# Process Multi-Target Ability
				if ability.target_type == Ability.TargetType.ALL_ENEMIES:
					for member in living_party:
						member.take_damage(damage_amount)
						_log(enemy.stats.character_name + " uses " + ability.ability_name + " on " + member.stats.character_name + " for " + str(damage_amount) + " damage!")
						if ability.inflicts_status != null:
							member.apply_status(ability.inflicts_status)
							_log(member.stats.character_name + " is afflicted with " + ability.inflicts_status.effect_name + "!")
				# Process Single-Target Ability
				else:
					var target: Battler = living_party.pick_random()
					target.take_damage(damage_amount)
					_log(enemy.stats.character_name + " uses " + ability.ability_name + " on " + target.stats.character_name + " for " + str(damage_amount) + " damage!")
					if ability.inflicts_status != null:
						target.apply_status(ability.inflicts_status)
						_log(target.stats.character_name + " is afflicted with " + target.stats.character_name + "!")
						
				action_taken = true
				
		# 3. Regular attack fallback
		if not action_taken:
			var target: Battler = living_party.pick_random()
			var damage_amount: int = int(enemy.stats.attack * enemy.get_attack_modifier())
			target.take_damage(damage_amount)
			_log(enemy.stats.character_name + " attacks " + target.stats.character_name + " for " + str(damage_amount) + " damage!")

	change_state(State.CHECK_END)

func _on_check_end() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var party: Array = get_tree().get_nodes_in_group("party")

	var all_enemies_defeated: bool = enemies.all(func(enemy): return enemy.stats.current_health <= 0)
	var all_party_defeated: bool = party.all(func(member): return member.stats.current_health <= 0)

	if all_enemies_defeated:
		change_state(State.VICTORY)
	elif all_party_defeated:
		change_state(State.DEFEAT)
	else:
		_start_new_round()

func _on_victory() -> void:
	print("You win!")
	_victory_messages.clear()
	
	# 1. Base enemy currency rewards + Custom Encounter/Boss Zone rewards
	var total_gold: int = GameManager.pending_encounter_reward_gold
	var total_exp: int = 0
	
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		total_gold += enemy.stats.currency_reward
		total_exp += enemy.stats.experience_reward
		
	# 2. Capture pre-victory stats to calculate exact level up delta points
	var party: Array = get_tree().get_nodes_in_group("party")
	var pre_stats: Dictionary = {}
	for member in party:
		if member is Battler:
			pre_stats[member] = {
				"level": member.stats.level,
				"max_health": member.stats.max_health,
				"max_mp": member.stats.max_mp,
				"attack": member.stats.attack,
				"defense": member.stats.defense
			}

	# 3. Award EXP to party
	for member in party:
		member.stats.add_experience(total_exp)
		
	# 4. Award currency
	GameManager.add_currency(total_gold)
	
	# 5. Award item drops
	var item_names: Array[String] = []
	for item in GameManager.pending_encounter_reward_items:
		if item != null:
			GameManager.add_item(item, 1)
			item_names.append(item.item_name)
			
	_revive_fallen_party_members()
	
	if not GameManager.pending_encounter_zone_id.is_empty():
		GameManager.mark_zone_defeated(GameManager.pending_encounter_zone_id)
		
	# 6. Slide 1: Base victory information
	var base_msg: String = "You won!\nReceived %d gold and %d EXP." % [total_gold, total_exp]
	if not item_names.is_empty():
		base_msg += "\nReceived items: " + ", ".join(item_names)
	_victory_messages.append(base_msg)
		
	# 7. Slides 2+: Dynamic Level-Up Cards
	for member in party:
		if member is Battler and pre_stats.has(member):
			var old = pre_stats[member]
			var new_stats = member.stats
			if new_stats.level > old["level"]:
				var lvl_msg: String = "%s reached Level %d!" % [new_stats.character_name, new_stats.level]
				lvl_msg += "\n  Max HP: %d -> %d (+%d)" % [old["max_health"], new_stats.max_health, new_stats.max_health - old["max_health"]]
				lvl_msg += "\n  Max MP: %d -> %d (+%d)" % [old["max_mp"], new_stats.max_mp, new_stats.max_mp - old["max_mp"]]
				lvl_msg += "\n  Attack: %d -> %d (+%d)" % [old["attack"], new_stats.attack, new_stats.attack - old["attack"]]
				lvl_msg += "\n  Defense: %d -> %d (+%d)" % [old["defense"], new_stats.defense, new_stats.defense - old["defense"]]
				_victory_messages.append(lvl_msg)
		
	# 8. Start the sequential display
	_advance_victory_sequence()

func _advance_victory_sequence() -> void:
	if _victory_messages.is_empty():
		# Out of messages: perform final exit cleanups
		_exit_battle_scene()
		return
		
	# Pop the next summary slide and print it cleanly to the box
	var next_slide: String = _victory_messages.pop_front()
	_log(next_slide)
	
	# Keep the Proceed button visible and focused
	$"../CanvasLayer/BattleUI".show_victory_state()

func _on_proceed_chosen() -> void:
	# Progress the slide queue when 'Proceed' is clicked
	_advance_victory_sequence()

func _exit_battle_scene() -> void:
	# Clean slate: Clear pending zone rewards
	GameManager.pending_encounter_reward_gold = 0
	GameManager.pending_encounter_reward_items.clear()
	
	# Auto-save and return
	GameManager.save_game("auto")
	$"../CanvasLayer/BattleUI".hide()
	GameManager.start_encounter_immunity()
	get_tree().change_scene_to_file(GameManager.overworld_scene_path)

func _position_battlers(battlers: Array, markers: Array) -> void:
	for i in battlers.size():
		if i >= markers.size():
			push_warning("Not enough position markers for all battlers!")
			break
		battlers[i].global_position = markers[i].global_position

func _award_experience() -> void:
	pass # Legacy, integrated into consolidated _on_victory

func _award_currency() -> void:
	pass # Legacy, integrated into consolidated _on_victory

func _heal_party_to_full() -> void:
	var party: Array = get_tree().get_nodes_in_group("party")
	for member in party:
		member.stats.current_health = member.stats.max_health

func _revive_fallen_party_members() -> void:
	var party: Array = get_tree().get_nodes_in_group("party")
	for member in party:
		if member.stats.current_health <= 0:
			member.stats.current_health = 1
			_log(member.stats.character_name + " struggles back to their feet with 1 HP!")

func _on_quest_completed(quest: Quest) -> void:
	_log("Quest complete! +" + str(quest.reward_currency) + " gold")

func _log(text: String) -> void:
	print(text)
	$"../CanvasLayer/BattleUI".display_message(text)
