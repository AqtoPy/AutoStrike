extends VBoxContainer

@export var items: Dictionary = {}

func _ready():
    for item_id in items:
        var item = items[item_id]
        var btn = Button.new()
        btn.text = "%s (%d монет)" % [item.name, item.cost]
        btn.tooltip_text = item.description
        btn.pressed.connect(_on_item_pressed.bind(item_id))
        add_child(btn)

func _on_item_pressed(item_id: String):
    get_node("/root/GameModeAPI").purchase_item(get_player_id(), item_id)
