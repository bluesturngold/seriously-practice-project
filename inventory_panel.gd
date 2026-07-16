extends Control

@onready var item_list: VBoxContainer = $ItemList
@onready var party_target_list: VBoxContainer = $PartyTargetList

var pending_item: Item = null

func _ready() -> void:
	party_target_list.hide()

func refresh() -> void:
	item_list.show()
	party_target_list.hide()

	for child in item_list.get_children():
		child.queue_free()

	for entry in GameManager.inventory:
		if entry["quantity"] <= 0:
			continue
		var item: Item = entry["item"]
		if item.heal_amount <= 0 and item.mp_restore_amount <= 0:
			continue  # not a usable consumable, skip for now

		var button := Button.new()
		button.text = item.item_name + " (" + str(entry["quantity"]) + ")"
		button.pressed.connect(func(): _on_item_selected(item))
		item_list.add_child(button)

func _on_item_selected(item: Item) -> void:
	pending_item = item
	item_list.hide()
	party_target_list.show()
	
	print("Party stats count: ", GameManager.party_stats.size())
	
	for child in party_target_list.get_children():
		child.queue_free()

	for stats in GameManager.party_stats:
		var button := Button.new()
		button.text = stats.character_name + "  HP: " + str(stats.current_health) + "/" + str(stats.max_health) + "  MP: " + str(stats.current_mp) + "/" + str(stats.max_mp)
		button.pressed.connect(func(): _on_target_selected(stats))
		party_target_list.add_child(button)

func _on_target_selected(stats: CharacterStats) -> void:
	if pending_item.heal_amount > 0:
		stats.heal(pending_item.heal_amount)
	if pending_item.mp_restore_amount > 0:
		stats.restore_mp(pending_item.mp_restore_amount)

	GameManager.remove_item(pending_item, 1)
	pending_item = null
	refresh()
