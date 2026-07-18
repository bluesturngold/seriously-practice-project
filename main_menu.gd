# main_menu.gd
extends Control

@onready var main_buttons_container: VBoxContainer = $VBoxContainer
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

# Load Panel elements (for slot selection)
@onready var load_panel: Control = $LoadPanel
@onready var manual_save_button: Button = $LoadPanel/VBoxContainer/ManualSaveButton
@onready var auto_save_button: Button = $LoadPanel/VBoxContainer/AutoSaveButton
@onready var back_button: Button = $LoadPanel/VBoxContainer/BackButton

func _ready() -> void:
	# Hide the load panel by default
	load_panel.hide()
	main_buttons_container.show()

	# Dynamically check for save availability to update the Continue button
	_refresh_continue_button()

	# Connect Main Buttons
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Connect Load Panel Buttons
	manual_save_button.pressed.connect(func(): _load_save_slot("manual"))
	auto_save_button.pressed.connect(func(): _load_save_slot("auto"))
	back_button.pressed.connect(_on_back_pressed)

	# Keyboard/controller accessibility: Grab default focus
	_grab_initial_focus()

func _refresh_continue_button() -> void:
	var has_manual: bool = GameManager.has_save("manual")
	var has_auto: bool = GameManager.has_save("auto")
	
	# Diagnostics: Check your editor Output tab to see what these print!
	print_rich("[color=cyan]--- Main Menu Save Path Diagnostics ---[/color]")
	print("Checking manual save at: ", GameManager.get_save_path("manual"), " -> Found: ", has_manual)
	print("Checking auto save at: ", GameManager.get_save_path("auto"), " -> Found: ", has_auto)
	print_rich("[color=cyan]---------------------------------------[/color]")

	continue_button.disabled = not (has_manual or has_auto)

func _grab_initial_focus() -> void:
	if not continue_button.disabled:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()

func _on_new_game_pressed() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://overworld.tscn")

func _on_continue_pressed() -> void:
	# Hide main buttons and show the load panel overlay
	main_buttons_container.hide()
	load_panel.show()
	
	# Configure individual slot button states based on files
	manual_save_button.disabled = not GameManager.has_save("manual")
	auto_save_button.disabled = not GameManager.has_save("auto")
	
	# Grab focus on the first available selection for gamepads/keyboards
	if not manual_save_button.disabled:
		manual_save_button.grab_focus()
	elif not auto_save_button.disabled:
		auto_save_button.grab_focus()
	else:
		back_button.grab_focus()

func _load_save_slot(slot: String) -> void:
	if GameManager.load_game(slot):
		print("Successfully loaded slot: ", slot)
	else:
		push_error("Failed to load slot: " + slot)

func _on_back_pressed() -> void:
	load_panel.hide()
	main_buttons_container.show()
	_refresh_continue_button()
	_grab_initial_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
