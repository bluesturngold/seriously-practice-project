# spawn_point.gd
extends Marker2D

@export var spawn_id: String = ""

func _ready() -> void:
	# Defensively guarantee this node is grouped correctly, even if added manually as a raw Marker2D
	if not is_in_group("spawn_points"):
		add_to_group("spawn_points")
