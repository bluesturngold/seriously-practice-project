extends Node2D
class_name Battler

@export var stats: CharacterStats
@export var persist_across_scenes: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: Control = $HealthBarUI
@onready var mp_label: Label = get_node_or_null("MPLabel")

signal health_changed(new_health: int, max_health: int)
signal mp_changed(new_mp: int, max_mp: int)
signal died

var active_statuses: Array = []

func _ready() -> void:
	if persist_across_scenes:
		var existing_stats: CharacterStats = GameManager.get_stats_for(stats.character_name)
		if existing_stats != null:
			stats = existing_stats
		else:
			stats = stats.duplicate()
			stats.current_health = stats.max_health
			stats.current_mp = stats.max_mp
			GameManager.register_stats(stats)
	else:
		stats = stats.duplicate()
		stats.current_health = stats.max_health
		stats.current_mp = stats.max_mp

	died.connect(_on_died)
	health_changed.connect(_on_health_changed)
	mp_changed.connect(_on_mp_changed)
	stats.leveled_up.connect(_on_leveled_up)
	health_bar.update_health(stats.current_health, stats.max_health)
	mp_changed.emit(stats.current_mp, stats.max_mp)

func take_damage(amount: int) -> void:
	var effective_defense: int = int(stats.defense * get_defense_modifier())
	var actual_damage: int = max(amount - effective_defense, 1)
	stats.current_health = max(stats.current_health - actual_damage, 0)
	health_changed.emit(stats.current_health, stats.max_health)
	print(stats.character_name, " took ", actual_damage, " damage. HP: ", stats.current_health, "/", stats.max_health)
	if stats.current_health <= 0:
		died.emit()

func take_status_damage(amount: int) -> void:
	stats.current_health = max(stats.current_health - amount, 0)
	health_changed.emit(stats.current_health, stats.max_health)
	if stats.current_health <= 0:
		died.emit()

func heal(amount: int) -> void:
	stats.heal(amount)
	health_changed.emit(stats.current_health, stats.max_health)

func restore_mp(amount: int) -> void:
	stats.restore_mp(amount)
	mp_changed.emit(stats.current_mp, stats.max_mp)

func spend_mp(amount: int) -> void:
	stats.current_mp = max(stats.current_mp - amount, 0)
	mp_changed.emit(stats.current_mp, stats.max_mp)

func apply_status(effect: StatusEffect) -> void:
	for existing in active_statuses:
		if existing["effect"].effect_type == effect.effect_type:
			active_statuses.erase(existing)
			break
	active_statuses.append({
		"effect": effect,
		"turns_remaining": effect.duration,
		"skip_pending": effect.effect_type == StatusEffect.EffectType.SLOW
	})

func has_pending_skip() -> bool:
	for status in active_statuses:
		if status["skip_pending"]:
			return true
	return false

func consume_skip() -> void:
	for status in active_statuses.duplicate():
		if status["skip_pending"]:
			active_statuses.erase(status)

func process_status_ticks() -> Array[String]:
	var messages: Array[String] = []
	var expired: Array = []

	for status in active_statuses:
		var effect: StatusEffect = status["effect"]
		if effect.effect_type == StatusEffect.EffectType.DAMAGE_OVER_TIME:
			take_status_damage(effect.damage_per_turn)
			messages.append(stats.character_name + " takes " + str(effect.damage_per_turn) + " damage from " + effect.effect_name + "!")

		if effect.effect_type != StatusEffect.EffectType.SLOW:
			status["turns_remaining"] -= 1
			if status["turns_remaining"] <= 0:
				expired.append(status)

	for status in expired:
		messages.append(stats.character_name + "'s " + status["effect"].effect_name + " wore off.")
		active_statuses.erase(status)

	return messages

func get_attack_modifier() -> float:
	var modifier: float = 1.0
	for status in active_statuses:
		if status["effect"].effect_type == StatusEffect.EffectType.ATTACK_DOWN:
			modifier *= 0.5
	return modifier

func get_defense_modifier() -> float:
	var modifier: float = 1.0
	for status in active_statuses:
		if status["effect"].effect_type == StatusEffect.EffectType.DEFENSE_DOWN:
			modifier *= 0.75
	return modifier

func _on_health_changed(new_health: int, max_health: int) -> void:
	health_bar.update_health(new_health, max_health)

func _on_mp_changed(new_mp: int, max_mp: int) -> void:
	if mp_label != null:
		mp_label.text = str(new_mp) + "/" + str(max_mp)

func _on_died() -> void:
	animated_sprite.rotation_degrees = 180

func _on_leveled_up(_new_level: int) -> void:
	health_changed.emit(stats.current_health, stats.max_health)
	mp_changed.emit(stats.current_mp, stats.max_mp)
