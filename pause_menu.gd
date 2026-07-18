# pause_menu.gd
extends Control

enum Tab { INVENTORY, STATS }

@onready var inventory_panel: Control = $InventoryPanel
@onready var stats_panel: Control = $StatsPanel
@onready var settings_panel: Control = $SettingsPanel
@onready var load_panel: Control = $LoadPanel
@onready var save_confirmation_label: Label = $SaveConfirmationLabel
@onready var save_confirmation_timer: Timer = $SaveConfirmationTimer

func _ready() -> void:
	hide()
	add_to_group("pause_menu")
	settings_panel.hide()
	load_panel.hide()
	save_confirmation_label.hide()

	$TabBar/InventoryTabButton.pressed.connect(func(): show_tab(Tab.INVENTORY))
	$TabBar/StatsTabButton.pressed.connect(func(): show_tab(Tab.STATS))
	$CloseButton.pressed.connect(close_menu)

	$BottomBar/SaveButton.pressed.connect(_on_save_pressed)
	$BottomBar/LoadButton.pressed.connect(_on_load_pressed)
	$BottomBar/SettingsButton.pressed.connect(_on_settings_pressed)
	$BottomBar/QuitButton.pressed.connect(_on_quit_pressed)

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
	$TabBar.hide()
	$BottomBar.hide()
	settings_panel.show()

func hide_settings() -> void:
	settings_panel.hide()
	$TabBar.show()
	$BottomBar.show()

func _on_settings_back() -> void:
	hide_settings()
	show_tab(Tab.INVENTORY)

func _on_load_pressed() -> void:
	inventory_panel.hide()
	stats_panel.hide()
	$TabBar.hide()
	$BottomBar.hide()
	load_panel.show()
	load_panel.refresh()

func hide_load_panel() -> void:
	load_panel.hide()
	$TabBar.show()
	$BottomBar.show()

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
	# Return the player to the start screen
	get_tree().change_scene_to_file("res://main_menu.tscn")
