extends Resource
class_name CharacterStats

var source_path: String = ""
@export var character_name: String = ""
@export var portrait: Texture2D
@export var max_health: int = 20
@export var attack: int = 5
@export var defense: int = 2

@export_group("Mana")
@export var max_mp: int = 10

var current_mp: int

@export_group("Abilities")
@export var abilities: Array[Ability] = []

@export_group("Leveling")
@export var level: int = 1
@export var experience: int = 0
@export var experience_to_next_level: int = 100
@export var attack_growth: int = 2
@export var defense_growth: int = 1
@export var max_health_growth: int = 5
@export var max_mp_growth: int = 2

@export_group("Rewards") # only relevant for enemies
@export var currency_reward: int = 0
@export var experience_reward: int = 20   

var current_health: int

signal leveled_up(new_level: int)

func _init() -> void:
	current_health = max_health
	current_mp = max_mp

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)

func restore_mp(amount: int) -> void:
	current_mp = min(current_mp + amount, max_mp)

func add_experience(amount: int) -> void:
	experience += amount
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		_level_up()

func _level_up() -> void:
	level += 1
	max_health += max_health_growth
	current_health = max_health
	max_mp += max_mp_growth
	current_mp = max_mp
	attack += attack_growth
	defense += defense_growth
	experience_to_next_level = int(experience_to_next_level * 1.5)
	leveled_up.emit(level)
	print(character_name, " leveled up! Now level ", level, ". ATK: ", attack, " DEF: ", defense, " Max HP: ", max_health, " Max MP: ", max_mp)
