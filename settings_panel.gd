extends Control

signal back_pressed

@onready var resolution_option: OptionButton = $ResolutionOption
@onready var volume_slider: HSlider = $MasterVolumeSlider
@onready var back_button: Button = $BackButton

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

	var current_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	volume_slider.value = db_to_linear(current_db)

func _on_resolution_selected(index: int) -> void:
	var new_resolution: Vector2i = resolutions[index]
	get_window().size = new_resolution

func _on_volume_changed(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func _on_back_pressed() -> void:
	back_pressed.emit()
