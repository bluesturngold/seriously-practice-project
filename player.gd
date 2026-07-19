# player.gd
extends CharacterBody2D

@export var speed: float = 150.0
var nearby_interactables: Array[Interactable] = []
var last_direction: Vector2 = Vector2.DOWN

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	$Area2D.area_entered.connect(_on_area_entered)
	$Area2D.area_exited.connect(_on_area_exited)

func _physics_process(delta: float) -> void:
	var dialogue_box: Control = get_tree().get_first_node_in_group("dialogue_box")
	var shop_ui: Control = get_tree().get_first_node_in_group("shop_ui")
	var pause_menu: Control = get_tree().get_first_node_in_group("pause_menu")
	if (dialogue_box != null and dialogue_box.is_active()) or (shop_ui != null and shop_ui.is_active()) or (pause_menu != null and pause_menu.is_active()):
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	if direction != Vector2.ZERO:
		GameManager.register_movement(velocity.length() * delta)
		last_direction = direction

	_update_animation(direction)

func _update_animation(direction: Vector2) -> void:
	var facing: String = _get_facing_string(last_direction)

	if direction == Vector2.ZERO:
		animated_sprite.play("idle_" + facing)
	else:
		animated_sprite.play("walk_" + facing)

func _get_facing_string(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "right" if direction.x > 0 else "left"
	else:
		return "down" if direction.y > 0 else "up"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_interact()

func try_interact() -> void:
	var dialogue_box: Control = get_tree().get_first_node_in_group("dialogue_box")
	var shop_ui: Control = get_tree().get_first_node_in_group("shop_ui")

	if dialogue_box != null and dialogue_box.is_active():
		dialogue_box.advance()
		return

	if shop_ui != null and shop_ui.is_active():
		return

	if nearby_interactables.is_empty():
		return

	var target: Interactable = nearby_interactables[0]
	if target.is_shop:
		if shop_ui != null:
			shop_ui.open_shop(target.shop_inventory)
	elif target.is_quest_giver:
		if dialogue_box != null:
			# Forward the speaker's name to the dialogue box
			dialogue_box.start_dialogue(target.interact_as_quest_giver(), target.get_speaker_name())
	elif dialogue_box != null:
		# Forward the speaker's name to the dialogue box
		dialogue_box.start_dialogue(target.get_dialogue_to_show(), target.get_speaker_name())
		target.mark_as_talked_to()

func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		nearby_interactables.append(area)

func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		nearby_interactables.erase(area)
