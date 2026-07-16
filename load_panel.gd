extends Control

signal back_pressed

@onready var manual_button: Button = $ManualSaveButton
@onready var auto_button: Button = $AutoSaveButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	manual_button.pressed.connect(func(): GameManager.load_game("manual"))
	auto_button.pressed.connect(func(): GameManager.load_game("auto"))
	back_button.pressed.connect(func(): back_pressed.emit())

func refresh() -> void:
	manual_button.disabled = not GameManager.has_save("manual")
	auto_button.disabled = not GameManager.has_save("auto")
