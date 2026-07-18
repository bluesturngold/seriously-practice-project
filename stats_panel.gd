# stats_panel.gd
extends Control

@onready var party_selector: HBoxContainer = $PartySelector
@onready var portrait_rect: TextureRect = $StatsDisplay/PortraitRect
@onready var name_label: Label = $StatsDisplay/NameLabel
@onready var level_label: Label = $StatsDisplay/LevelLabel
@onready var health_label: Label = $StatsDisplay/HealthLabel
@onready var mana_label: Label = $StatsDisplay/ManaLabel
@onready var attack_label: Label = $StatsDisplay/AttackLabel
@onready var defense_label: Label = $StatsDisplay/DefenseLabel
@onready var experience_label: Label = $StatsDisplay/ExperienceLabel

func refresh() -> void:
	# Instantly remove children from the tree so the HBoxContainer layout updates immediately
	for child in party_selector.get_children():
		party_selector.remove_child(child)
		child.queue_free()

	for stats in GameManager.party_stats:
		var button := Button.new()
		button.text = stats.character_name
		button.pressed.connect(func(): _show_stats(stats))
		party_selector.add_child(button)

	if GameManager.party_stats.size() > 0:
		_show_stats(GameManager.party_stats[0])

func _show_stats(stats: CharacterStats) -> void:
	# Poland fallback: Use the default icon if no portrait is set
	if stats.portrait != null:
		portrait_rect.texture = stats.portrait
	else:
		portrait_rect.texture = preload("res://icon.svg")
		
	name_label.text = stats.character_name
	level_label.text = "Level " + str(stats.level)
	health_label.text = "HP: " + str(stats.current_health) + "/" + str(stats.max_health)
	mana_label.text = "MP: " + str(stats.current_mp) + "/" + str(stats.max_mp)
	attack_label.text = "Attack: " + str(stats.attack)
	defense_label.text = "Defense: " + str(stats.defense)
	experience_label.text = "EXP: " + str(stats.experience) + "/" + str(stats.experience_to_next_level)
