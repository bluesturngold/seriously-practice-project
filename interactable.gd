# interactable.gd
@tool
extends Area2D
class_name Interactable

enum NPCClass {
	MENTOR,
	MAYOR_MAN,
	MAYOR_WOMAN,
	FARMER,
	COOK,
	LABORER,
	MAN,
	WOMAN,
	PERSON,
	BOY,
	GIRL,
	CHILD
}

enum MovementPattern {
	STATIONARY,
	PACE_HORIZONTAL,
	PACE_VERTICAL,
	CIRCLE,
	MEANDER
}

const CLASS_FILE_NAMES: Dictionary = {
	NPCClass.MENTOR: "mentor",
	NPCClass.MAYOR_MAN: "mayor_man",
	NPCClass.MAYOR_WOMAN: "mayor_woman",
	NPCClass.FARMER: "farmer",
	NPCClass.COOK: "cook",
	NPCClass.LABORER: "laborer",
	NPCClass.MAN: "man",
	NPCClass.WOMAN: "woman",
	NPCClass.PERSON: "person",
	NPCClass.BOY: "boy",
	NPCClass.GIRL: "girl",
	NPCClass.CHILD: "child"
}

@export_group("Visuals")
@export var npc_class: NPCClass = NPCClass.PERSON:
	set(value):
		npc_class = value
		if is_node_ready():
			_update_npc_sprite()

@export_group("Interaction")
@export var interactable_id: String = ""
@export var dialogue_lines: Array[String] = []
@export var one_time_only: bool = false
@export var repeat_lines: Array[String] = []
@export var is_shop: bool = false
@export var shop_inventory: Array[Item] = []
@export var is_quest_giver: bool = false
@export var quest: Quest

@export_group("Movement Patterns")
@export var movement_pattern: MovementPattern = MovementPattern.STATIONARY
@export var move_speed: float = 30.0
@export var pace_range: float = 16.0 # Grid steps (16px is exactly 1 tile)
@export var wait_time: float = 1.5

# Runtime state tracking variables
var _start_position: Vector2
var _target_position: Vector2
var _is_moving: bool = false
var _wait_timer: float = 0.0
var _pacing_direction: int = 1
var _circle_index: int = 0
var _last_facing_direction: Vector2 = Vector2.DOWN
var raycast: RayCast2D

func _ready() -> void:
	_update_npc_sprite()
	
	if not Engine.is_editor_hint():
		print_rich("[color=green]=== NPC RUNTIME STARTED: '", name, "' ===[/color]")
		print("Pattern selected: ", MovementPattern.keys()[movement_pattern])
		
		_start_position = global_position
		_wait_timer = randf_range(0.0, wait_time) # Stagger start timers slightly
		_setup_movement_raycast()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if movement_pattern == MovementPattern.STATIONARY:
		_update_animation(Vector2.ZERO)
		return
		
	# Freeze movement if any overworld UI overlays are active
	var dialogue_box: Control = get_tree().get_first_node_in_group("dialogue_box")
	var shop_ui: Control = get_tree().get_first_node_in_group("shop_ui")
	var pause_menu: Control = get_tree().get_first_node_in_group("pause_menu")
	if (dialogue_box != null and dialogue_box.is_active()) or (shop_ui != null and shop_ui.is_active()) or (pause_menu != null and pause_menu.is_active()):
		_update_animation(Vector2.ZERO)
		return
		
	if _is_moving:
		_move_towards_target(delta)
	else:
		_update_animation(Vector2.ZERO)
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_determine_next_move()

func _setup_movement_raycast() -> void:
	raycast = RayCast2D.new()
	add_child(raycast)
	
	# Exclude the root Area2D overlap detection shape
	raycast.add_exception(self)
	
	# Recursively find and exclude ALL nested child collision shapes (including StaticBody2D)
	_exclude_child_colliders(self)
			
	# Collide only with standard solid world layers (Layer 1)
	raycast.collision_mask = 1
	raycast.hit_from_inside = false # Prevent starting inside a shape from blocking movement
	raycast.enabled = true

func _exclude_child_colliders(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionObject2D:
			raycast.add_exception(child)
		_exclude_child_colliders(child) # Recursively search nested nodes

func _update_npc_sprite() -> void:
	var file_name: String = CLASS_FILE_NAMES.get(npc_class, "person")
	
	var anim_sprite: AnimatedSprite2D = null
	for child in get_children():
		if child is AnimatedSprite2D:
			anim_sprite = child
			break
			
	if anim_sprite == null:
		return
		
	var frames_path: String = "res://sprites/npcs/" + file_name + "_frames.tres"
	
	if ResourceLoader.exists(frames_path):
		anim_sprite.sprite_frames = load(frames_path)
		anim_sprite.scale = Vector2.ONE
	elif ResourceLoader.exists("res://icon.svg"):
		# Fallback: Create a clean single-frame SpriteFrames using icon.svg
		var fallback_texture = load("res://icon.svg")
		var new_frames = SpriteFrames.new()
		
		# Safely ensure "default" exists without causing duplicate errors
		if not new_frames.has_animation("default"):
			new_frames.add_animation("default")
		new_frames.add_frame("default", fallback_texture)
		
		anim_sprite.sprite_frames = new_frames
		anim_sprite.animation = "default"
		
		# Scale the AnimatedSprite2D node to exactly 16x16
		var tex_size = fallback_texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			anim_sprite.scale = Vector2(16.0 / tex_size.x, 16.0 / tex_size.y)
	else:
		anim_sprite.sprite_frames = null
		anim_sprite.scale = Vector2.ONE

func _update_animation(move_vector: Vector2) -> void:
	var anim_sprite: AnimatedSprite2D = null
	for child in get_children():
		if child is AnimatedSprite2D:
			anim_sprite = child
			break
			
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
		
	# Do not override animations if we are using the default icon.svg fallback
	if anim_sprite.sprite_frames.has_animation("default") and anim_sprite.animation == "default":
		return
		
	if move_vector != Vector2.ZERO:
		_last_facing_direction = move_vector
		
	var facing: String = _get_facing_string(_last_facing_direction)
	if move_vector == Vector2.ZERO:
		if anim_sprite.sprite_frames.has_animation("idle_" + facing):
			anim_sprite.play("idle_" + facing)
	else:
		if anim_sprite.sprite_frames.has_animation("walk_" + facing):
			anim_sprite.play("walk_" + facing)

func _get_facing_string(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "right" if direction.x > 0 else "left"
	else:
		return "down" if direction.y > 0 else "up"

func _can_move_to(dir: Vector2, distance: float) -> bool:
	if raycast == null:
		return true
		
	raycast.target_position = dir * distance
	raycast.force_raycast_update()
	return not raycast.is_colliding()

func _move_towards_target(delta: float) -> void:
	var distance_to_target = global_position.distance_to(_target_position)
	var step_distance = move_speed * delta
	var move_vector = (_target_position - global_position).normalized()
	
	_update_animation(move_vector)
	
	# Check ahead with a tiny buffer (4px) to detect walls early and turn around cleanly
	if not _can_move_to(move_vector, step_distance + 4.0):
		if raycast != null and raycast.is_colliding():
			var collider = raycast.get_collider()
			print("NPC '", name, "' movement step blocked by: ", collider.name if collider != null else "Unknown")
		_is_moving = false
		_wait_timer = wait_time
		if movement_pattern == MovementPattern.PACE_HORIZONTAL or movement_pattern == MovementPattern.PACE_VERTICAL:
			_pacing_direction *= -1
		return
		
	if step_distance >= distance_to_target:
		global_position = _target_position
		_is_moving = false
		_wait_timer = wait_time
		# Invert direction when we reach our target successfully so we head back!
		if movement_pattern == MovementPattern.PACE_HORIZONTAL or movement_pattern == MovementPattern.PACE_VERTICAL:
			_pacing_direction *= -1
	else:
		global_position += move_vector * step_distance

func _determine_next_move() -> void:
	match movement_pattern:
		MovementPattern.PACE_HORIZONTAL:
			var offset = pace_range * _pacing_direction
			var potential_target = _start_position + Vector2(offset, 0.0)
			var dir = Vector2(_pacing_direction, 0.0)
			
			if _can_move_to(dir, 16.0):
				_target_position = potential_target
				_is_moving = true
			else:
				if raycast != null and raycast.is_colliding():
					var collider = raycast.get_collider()
					print("NPC '", name, "' PACE_HORIZONTAL blocked by: ", collider.name if collider != null else "Unknown")
				_pacing_direction *= -1
				_wait_timer = wait_time
				
		MovementPattern.PACE_VERTICAL:
			var offset = pace_range * _pacing_direction
			var potential_target = _start_position + Vector2(0.0, offset)
			var dir = Vector2(0.0, _pacing_direction)
			
			if _can_move_to(dir, 16.0):
				_target_position = potential_target
				_is_moving = true
			else:
				if raycast != null and raycast.is_colliding():
					var collider = raycast.get_collider()
					print("NPC '", name, "' PACE_VERTICAL blocked by: ", collider.name if collider != null else "Unknown")
				_pacing_direction *= -1
				_wait_timer = wait_time
				
		MovementPattern.CIRCLE:
			var next_index = (_circle_index + 1) % 4
			var offset = Vector2.ZERO
			match next_index:
				0: offset = Vector2.ZERO
				1: offset = Vector2(pace_range, 0.0)
				2: offset = Vector2(pace_range, pace_range)
				3: offset = Vector2(0.0, pace_range)
				
			var potential_target = _start_position + offset
			var dir = (potential_target - global_position).normalized()
			var dist = global_position.distance_to(potential_target)
			
			if dist > 0.1 and _can_move_to(dir, 16.0):
				_target_position = potential_target
				_circle_index = next_index
				_is_moving = true
			else:
				if raycast != null and raycast.is_colliding():
					var collider = raycast.get_collider()
					print("NPC '", name, "' CIRCLE blocked by: ", collider.name if collider != null else "Unknown")
				_wait_timer = wait_time
				
		MovementPattern.MEANDER:
			var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
			var dir = directions.pick_random()
			
			var steps = [16.0, 32.0, 48.0]
			var dist = steps.pick_random()
			
			var potential_target = global_position + dir * dist
			
			if potential_target.distance_to(_start_position) <= pace_range:
				if _can_move_to(dir, dist):
					_target_position = potential_target
					_is_moving = true
					return
					
			if raycast != null and raycast.is_colliding():
				var collider = raycast.get_collider()
				print("NPC '", name, "' MEANDER path blocked by: ", collider.name if collider != null else "Unknown")
			_wait_timer = wait_time

func interact_as_quest_giver() -> Array[String]:
	if quest == null:
		return []

	if GameManager.is_quest_completed(quest.quest_id):
		return quest.completion_lines

	if GameManager.is_quest_active(quest.quest_id):
		var progress: int = GameManager.get_quest_progress(quest.quest_id)
		var lines: Array[String] = quest.reminder_lines.duplicate()
		lines.append(quest.enemy_name + " defeated: " + str(progress) + "/" + str(quest.required_count))
		return lines

	GameManager.start_quest(quest)
	return quest.offer_lines

func get_dialogue_to_show() -> Array[String]:
	if one_time_only and GameManager.has_talked_to(interactable_id):
		return repeat_lines
	return dialogue_lines

func mark_as_talked_to() -> void:
	if one_time_only:
		GameManager.mark_talked_to(interactable_id)
