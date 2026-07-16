extends Control

@onready var item_list: VBoxContainer = $ItemList
@onready var currency_label: Label = $CurrencyLabel
@onready var close_button: Button = $CloseButton

var current_shop_items: Array[Item] = []

func _ready() -> void:
	hide()
	add_to_group("shop_ui")
	close_button.pressed.connect(close_shop)

func is_active() -> bool:
	return visible

func open_shop(items: Array[Item]) -> void:
	current_shop_items = items
	show()
	_refresh()

func _refresh() -> void:
	currency_label.text = "Gold: " + str(GameManager.player_currency)

	for child in item_list.get_children():
		child.queue_free()

	for item in current_shop_items:
		var button := Button.new()
		button.text = item.item_name + " - " + str(item.price) + "g"
		button.disabled = GameManager.player_currency < item.price
		button.pressed.connect(func(): _on_buy_pressed(item))
		item_list.add_child(button)

func _on_buy_pressed(item: Item) -> void:
	if GameManager.spend_currency(item.price):
		GameManager.add_item(item, 1)
		_refresh()

func close_shop() -> void:
	hide()
