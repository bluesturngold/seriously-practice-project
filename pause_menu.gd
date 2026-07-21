# pause_menu.gd
extends Control

enum Tab { INVENTORY, STATS }

# Fetch nodes using Scene Unique Names (%) to prevent layout breaking
@onready var inventory_panel: Control = %InventoryPanel
@onready var stats_panel: Control = %StatsPanel
@onready var settings_panel: Control = %SettingsPanel
@onready var load_panel: Control = %LoadPanel
@onready var save_confirmation_label: Label = %SaveConfirmationLabel
@onready var save_confirmation_timer: Timer = %SaveConfirmationTimer

@onready var inventory_tab_button: Button = %InventoryTabButton
@onready var stats_tab_button: Button = %StatsTabButton
@onready var close_button: Button = %CloseButton

@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

@onready var tab_bar: HBoxContainer = %TabBar
@onready var bottom_bar: HBoxContainer = %BottomBar

func _ready() -> void:
	hide()
	add_to_group("pause_menu")
	settings_panel.hide()
	load_panel.hide()
	save_confirmation_label.hide()

	# Connect tab navigation
	inventory_tab_button.pressed.connect(func(): show_tab(Tab.INVENTORY))
	stats_tab_button.pressed.connect(func(): show_tab(Tab.STATS))
	close_button.pressed.connect(close_menu)

	# Connect action bar operations
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	settings_panel.back_pressed.connect(_on_settings_back)
	load_panel.back_pressed.connect(_on_load_back)
	save_confirmation_timer.timeout.connect(_on_save_confirmation_timeout)

func is_active() -> bool:
	return visible

func open_menu() -> void:
	show()
	hide_settings()
	hide_load_panel()
	show_tab(Tab.INVENTORY)

func close_menu() -> void:
	hide()

func show_tab(tab: Tab) -> void:
	inventory_panel.visible = (tab == Tab.INVENTORY)
	stats_panel.visible = (tab == Tab.STATS)
	if tab == Tab.INVENTORY:
		inventory_panel.refresh()
	elif tab == Tab.STATS:
		stats_panel.refresh()

func _on_settings_pressed() -> void:
	inventory_panel.hide()
	stats_panel.hide()
	tab_bar.hide()
	bottom_bar.hide()
	settings_panel.show()

func hide_settings() -> void:
	settings_panel.hide()
	tab_bar.show()
	bottom_bar.show()

func _on_settings_back() -> void:
	hide_settings()
	show_tab(Tab.INVENTORY)

func _on_load_pressed() -> void:
	inventory_panel.hide()
	stats_panel.hide()
	tab_bar.hide()
	bottom_bar.hide()
	load_panel.show()
	load_panel.refresh()

func hide_load_panel() -> void:
	load_panel.hide()
	tab_bar.show()
	bottom_bar.show()

func _on_load_back() -> void:
	hide_load_panel()
	show_tab(Tab.INVENTORY)

func _on_save_pressed() -> void:
	GameManager.save_game("manual")
	save_confirmation_label.text = "Manual save successful!"
	save_confirmation_label.show()
	save_confirmation_timer.start(2.0)

func _on_save_confirmation_timeout() -> void:
	save_confirmation_label.hide()

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
