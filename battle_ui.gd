extends Control

signal target_chosen(target: Battler)
signal ability_used(ability: Ability, target: Battler)
signal item_used(item: Item, target: Battler)
signal run_chosen

enum Screen { MAIN, ITEM, ATTACK }

@onready var action_menu: VBoxContainer = $ActionMenu
@onready var attack_menu: VBoxContainer = $AttackMenu
@onready var target_menu: VBoxContainer = $TargetMenu
@onready var item_menu: VBoxContainer = $ItemMenu
@onready var back_button: Button = $BackButton
@onready var battle_log: RichTextLabel = $BattleLog
@onready var turn_label: Label = $TurnLabel




var pending_item: Item = null
var pending_ability: Ability = null
var previous_screen: Screen = Screen.MAIN
var current_active_player: Battler = null

func _ready() -> void:
	attack_menu.hide()
	target_menu.hide()
	item_menu.hide()
	back_button.hide()
	$ActionMenu/AttackButton.pressed.connect(_on_attack_pressed)
	$ActionMenu/ItemButton.pressed.connect(_on_item_pressed)
	$ActionMenu/RunButton.pressed.connect(_on_run_pressed)
	back_button.pressed.connect(_on_back_pressed)

	$ActionMenu/RunButton.visible = not GameManager.pending_encounter_is_boss

func set_active_player(player: Battler) -> void:
	current_active_player = player

func display_message(text: String) -> void:
	battle_log.text = text

func show_turn(character_name: String) -> void:
	turn_label.text = character_name + "'s turn"

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
	regular_button.pressed.connect(func(): _on_regular_attack_selected())
	attack_menu.add_child(regular_button)

	for ability in current_active_player.stats.abilities:
		var button := Button.new()
		button.text = ability.ability_name + " (" + str(ability.mp_cost) + " MP)"
		button.disabled = current_active_player.stats.current_mp < ability.mp_cost
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
