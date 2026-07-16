extends Resource
class_name StatusEffect

enum EffectType { DAMAGE_OVER_TIME, SLOW, ATTACK_DOWN, DEFENSE_DOWN }

@export var effect_name: String = ""
# Damage over time is like poison, slow, attack down, and defense down are self explanatory.
@export var effect_type: EffectType = EffectType.DAMAGE_OVER_TIME
# How many turns it lasts. For slow, probably just one turn, because its effect is skipping a turn.
@export var duration: int = 3
# How much damage it does per turn.
@export var damage_per_turn: int = 5
