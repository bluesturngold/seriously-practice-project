extends Node

enum State { START, PLAYER_CHOICE, PLAYER_ACTION, ENEMY_ACTION, CHECK_END, VICTORY, DEFEAT }

var current_state: State = State.START
var active_player: Battler
var party_turn_queue: Array = []

func _ready() -> void:
	$"../CanvasLayer/BattleUI".target_chosen.connect(_on_target_chosen)
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
			print("You win!")
			_award_experience()
			_award_currency()
			_revive_fallen_party_members()
			if not GameManager.pending_encounter_zone_id.is_empty():
				GameManager.mark_zone_defeated(GameManager.pending_encounter_zone_id)
			GameManager.save_game("auto")
			$"../CanvasLayer/BattleUI".hide()
			GameManager.start_encounter_immunity()
			get_tree().change_scene_to_file(GameManager.overworld_scene_path)
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

func _position_battlers(battlers: Array, markers: Array) -> void:
	for i in battlers.size():
		if i >= markers.size():
			push_warning("Not enough position markers for all battlers!")
			break
		battlers[i].global_position = markers[i].global_position

func _award_experience() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var party: Array = get_tree().get_nodes_in_group("party")

	var total_experience: int = 0
	for enemy in enemies:
		total_experience += enemy.stats.experience_reward

	for member in party:
		member.stats.add_experience(total_experience)
		print(member.stats.character_name, " gained ", total_experience, " EXP.")

func _award_currency() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	var total_currency: int = 0
	for enemy in enemies:
		total_currency += enemy.stats.currency_reward

	GameManager.add_currency(total_currency)
	_log("Found " + str(total_currency) + " gold!")

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
