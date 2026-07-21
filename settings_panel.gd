# settings_panel.gd
extends Control

signal back_pressed

@onready var resolution_option: OptionButton = $VBoxContainer/ResolutionOption
@onready var volume_slider: HSlider = $VBoxContainer/MasterVolumeSlider
@onready var back_button: Button = $VBoxContainer/BackButton

var resolutions: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

func _ready() -> void:
	for res in resolutions:
		resolution_option.add_item(str(res.x) + " x " + str(res.y))

	resolution_option.item_selected.connect(_on_resolution_selected)
	volume_slider.value_changed.connect(_on_volume_changed)
	back_button.pressed.connect(_on_back_pressed)

	# Synchronize the volume slider with Godot's live master audio bus on boot
	var current_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	volume_slider.value = db_to_linear(current_db)

	# Quality-of-Life: Set the dropdown selection to match the actual active window size
	var current_size = get_window().size
	var matched_index = resolutions.find(current_size)
	if matched_index != -1:
		resolution_option.selected = matched_index

func _on_resolution_selected(index: int) -> void:
	var new_resolution: Vector2i = resolutions[index]
	get_window().size = new_resolution

func _on_volume_changed(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func _on_back_pressed() -> void:
	back_pressed.emit()
