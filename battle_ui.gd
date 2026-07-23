# battle_ui.gd
extends Control

signal target_chosen(target: Battler)
signal defend_chosen
signal proceed_chosen
signal ability_used(ability: Ability, target: Battler)
signal item_used(item: Item, target: Battler)
signal run_chosen

enum Screen { MAIN, ITEM, ATTACK }

@onready var action_menu: VBoxContainer = %ActionMenu
@onready var attack_menu: VBoxContainer = %AttackMenu
@onready var target_menu: VBoxContainer = %TargetMenu
@onready var item_menu: VBoxContainer = %ItemMenu
@onready var back_button: Button = %BackButton
@onready var battle_log: RichTextLabel = %BattleLog
@onready var turn_label: Label = %TurnLabel
@onready var proceed_button: Button = %ProceedButton

var pending_item: Item = null
var pending_ability: Ability = null
var previous_screen: Screen = Screen.MAIN
var current_active_player: Battler = null

func _ready() -> void:
	attack_menu.hide()
	target_menu.hide()
	item_menu.hide()
	back_button.hide()
	proceed_button.hide()
	
	# Connect base actions
	%ActionMenu/AttackButton.pressed.connect(_on_attack_pressed)
	%ActionMenu/DefendButton.pressed.connect(_on_defend_pressed)
	%ActionMenu/ItemButton.pressed.connect(_on_item_pressed)
	%ActionMenu/RunButton.pressed.connect(_on_run_pressed)
	proceed_button.pressed.connect(func(): proceed_chosen.emit())
	back_button.pressed.connect(_on_back_pressed)

	%ActionMenu/RunButton.visible = not GameManager.pending_encounter_is_boss

	# Connect reactive party state signals once the nodes are fully ready in tree
	call_deferred("_connect_party_signals")

func set_active_player(player: Battler) -> void:
	current_active_player = player

func display_message(text: String) -> void:
	battle_log.text = text

func show_turn(character_name: String) -> void:
	turn_label.show() # Ensure the label is visible for the next battle turns
	turn_label.text = character_name + "'s turn"

func _connect_party_signals() -> void:
	var party_members = get_tree().get_nodes_in_group("party")
	for member in party_members:
		if member is Battler:
			# Prefix unused parameters with an underscore to prevent compiler warnings
			member.health_changed.connect(func(_h, _max_h): update_party_status())
			member.mp_changed.connect(func(_m, _max_m): update_party_status())
	update_party_status()

func update_party_status() -> void:
	var party_members = get_tree().get_nodes_in_group("party")
	var rows = [
		get_node_or_null("BottomBattlePanel/MarginContainer/HBoxContainer/PartyStatusColumn/MemberRow1"),
		get_node_or_null("BottomBattlePanel/MarginContainer/HBoxContainer/PartyStatusColumn/MemberRow2"),
		get_node_or_null("BottomBattlePanel/MarginContainer/HBoxContainer/PartyStatusColumn/MemberRow3"),
		get_node_or_null("BottomBattlePanel/MarginContainer/HBoxContainer/PartyStatusColumn/MemberRow4")
	]
	
	for i in range(rows.size()):
		var row = rows[i]
		if row == null:
			continue
		if i < party_members.size():
			row.show()
			var member = party_members[i]
			row.get_node("NameLabel").text = member.stats.character_name
			
			# Configure HP Text & Dynamic Color overrides
			var hp_label = row.get_node("HPLabel")
			hp_label.text = "%d/%d" % [member.stats.current_health, member.stats.max_health]
			
			var hp_pct: float = float(member.stats.current_health) / float(member.stats.max_health) if member.stats.max_health > 0 else 0.0
			if hp_pct < 0.33:
				hp_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3)) # Red at < 33%
			elif hp_pct < 0.50:
				hp_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2)) # Yellow at < 50%
			else:
				hp_label.add_theme_color_override("font_color", Color.WHITE) # Normal White
				
			# Configure MP Text & Static Crystalline Blue override
			var mp_label = row.get_node("MPLabel")
			mp_label.text = "%d/%d" % [member.stats.current_mp, member.stats.max_mp]
			mp_label.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0)) # Crystalline Blue

			# Configure Status Effect / Debuff Display Column
			var status_label = row.get_node("StatusLabel")
			if member.active_statuses.is_empty():
				status_label.text = ""
			else:
				# Since players can only have one status at a time, grab the first active effect name
				var current_status = member.active_statuses[0]["effect"]
				status_label.text = current_status.effect_name
				# Color-code status labels (e.g., golden orange for visual clarity)
				status_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.0))
		else:
			row.hide()

func show_victory_state() -> void:
	# Hide all combat submenus, back buttons, and active turn indicators
	turn_label.hide()
	attack_menu.hide()
	item_menu.hide()
	target_menu.hide()
	back_button.hide()
	
	# Hide all individual standard combat action commands
	%ActionMenu/AttackButton.hide()
	%ActionMenu/DefendButton.hide()
	%ActionMenu/ItemButton.hide()
	%ActionMenu/RunButton.hide()
	
	# Reveal the centered Proceed command and grab keyboard focus
	action_menu.show()
	proceed_button.show()
	proceed_button.grab_focus()

func _on_defend_pressed() -> void:
	defend_chosen.emit()

func _on_attack_pressed() -> void:
	previous_screen = Screen.MAIN
	show_attack_menu()

func show_attack_menu() -> void:
	action_menu.hide()
	attack_menu.show()
	back_button.show()

	for child in attack_menu.get_children():
		child.queue_free()

	var regular_button := Button.new()
	regular_button.text = "Attack"
	regular_button.custom_minimum_size = Vector2(0, 40) # Lock height to 40px
	regular_button.pressed.connect(func(): _on_regular_attack_selected())
	attack_menu.add_child(regular_button)

	for ability in current_active_player.stats.abilities:
		var button := Button.new()
		button.text = ability.ability_name + " (" + str(ability.mp_cost) + " MP)"
		button.disabled = current_active_player.stats.current_mp < ability.mp_cost
		button.custom_minimum_size = Vector2(0, 40) # Lock height to 40px
		button.pressed.connect(func(): _on_ability_selected(ability))
		attack_menu.add_child(button)

func _on_regular_attack_selected() -> void:
	pending_ability = null
	previous_screen = Screen.ATTACK
	var living_enemies: Array = get_tree().get_nodes_in_group("enemies").filter(
		func(enemy): return enemy.stats.current_health > 0
	)
	show_target_menu(living_enemies)

func _on_ability_selected(ability: Ability) -> void:
	var living_enemies: Array = get_tree().get_nodes_in_group("enemies").filter(
		func(enemy): return enemy.stats.current_health > 0
	)

	if ability.target_type == Ability.TargetType.ALL_ENEMIES:
		ability_used.emit(ability, null)
		attack_menu.hide()
		action_menu.show()
		back_button.hide()
	else:
		pending_ability = ability
		previous_screen = Screen.ATTACK
		show_target_menu(living_enemies)

func _on_item_pressed() -> void:
	previous_screen = Screen.MAIN
	show_item_menu()

func _on_run_pressed() -> void:
	run_chosen.emit()

func _on_back_pressed() -> void:
	action_menu.hide()
	attack_menu.hide()
	item_menu.hide()
	target_menu.hide()
	back_button.hide()
	pending_item = null
	pending_ability = null

	match previous_screen:
		Screen.ITEM:
			previous_screen = Screen.MAIN
			show_item_menu()
		Screen.ATTACK:
			previous_screen = Screen.MAIN
			show_attack_menu()
		Screen.MAIN:
			action_menu.show()

func show_item_menu() -> void:
	action_menu.hide()
	attack_menu.hide()
	item_menu.show()
	back_button.show()

	for child in item_menu.get_children():
		child.queue_free()

	for entry in GameManager.inventory:
		if entry["quantity"] <= 0:
			continue
		var item: Item = entry["item"]
		var button := Button.new()
		button.text = item.item_name + " (" + str(entry["quantity"]) + ")"
		button.custom_minimum_size = Vector2(0, 40) # Lock height to 40px
		button.pressed.connect(func(): _on_item_selected(item))
		item_menu.add_child(button)

func _on_item_selected(item: Item) -> void:
	pending_item = item
	previous_screen = Screen.ITEM
	item_menu.hide()
	var living_party: Array = get_tree().get_nodes_in_group("party").filter(
		func(member): return member.stats.current_health > 0
	)
	show_target_menu(living_party)

func show_target_menu(targets: Array) -> void:
	action_menu.hide()
	attack_menu.hide()
	item_menu.hide()
	target_menu.show()
	back_button.show()

	for child in target_menu.get_children():
		child.queue_free()

	for target in targets:
		var button := Button.new()
		button.text = target.stats.character_name
		button.custom_minimum_size = Vector2(0, 40) # Lock height to 40px
		button.pressed.connect(func(): _on_target_selected(target))
		target_menu.add_child(button)

func _on_target_selected(target: Battler) -> void:
	target_menu.hide()
	action_menu.show()
	back_button.hide()

	if pending_item != null:
		item_used.emit(pending_item, target)
		pending_item = null
	elif pending_ability != null:
		ability_used.emit(pending_ability, target)
		pending_ability = null
	else:
		target_chosen.emit(target)
