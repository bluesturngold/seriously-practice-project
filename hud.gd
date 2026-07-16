extends Control

@onready var load_confirmation_label: Label = $LoadConfirmationLabel
@onready var load_confirmation_timer: Timer = $LoadConfirmationTimer

func _ready() -> void:
	load_confirmation_label.hide()
	load_confirmation_timer.timeout.connect(_on_load_confirmation_timeout)

	if GameManager.pending_load_confirmation:
		GameManager.pending_load_confirmation = false
		load_confirmation_label.text = "Game loaded!"
		load_confirmation_label.show()
		load_confirmation_timer.start(2.0)

func _on_load_confirmation_timeout() -> void:
	load_confirmation_label.hide()
