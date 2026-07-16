extends Resource
class_name Ability

enum TargetType { SINGLE_ENEMY, ALL_ENEMIES }

@export var ability_name: String = ""
@export var mp_cost: int = 5
@export var damage_amount: int = 10
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var inflicts_status: StatusEffect = null
