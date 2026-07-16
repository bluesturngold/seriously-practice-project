extends Control

@onready var progress_bar: ProgressBar = $ProgressBar

func update_health(current_health: int, max_health: int) -> void:
	progress_bar.max_value = max_health
	progress_bar.value = current_health
