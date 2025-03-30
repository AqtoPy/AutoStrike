func _format_server_info(server: Dictionary) -> String:
    var password_icon = "🔒" if server.get("has_password", false) else ""
    return "%s %s\nMap: %s | Mode: %s | Players: %d/%d | Ping: %dms" % [
        server["name"], 
        password_icon,
        server["map"].capitalize(),
        server["mode"],
        server.get("current_players", 1),
        server["max_players"],
        server.get("ping", 0)
    ]



func _on_refresh_button_pressed():
    _on_server_list_updated(server_manager.get_server_list())
    status_label.text = "Server list refreshed"
    status_label.modulate = Color.WHITE



# Добавьте в начало
@onready var server_manager = $ServerManager

# Замените метод _ready()
func _ready():
    _setup_directories()
    _load_player_data()
    _generate_player_id()
    _load_custom_modes()
    _setup_ui()
    _connect_signals()
    server_manager.server_list_updated.connect(_on_server_list_updated)
    _on_server_list_updated(server_manager.get_server_list())

# Замените _refresh_server_list()
func _on_server_list_updated(servers):
    for child in server_list.get_children():
        child.queue_free()
    
    for server in servers:
        var server_button = Button.new()
        server_button.text = _format_server_info(server)
        server_button.custom_minimum_size = Vector2(0, 60)
        server_button.align = Label.ALIGN_LEFT
        server_button.pressed.connect(_on_server_selected.bind(server))
        server_list.add_child(server_button)

# Обновите _on_create_server_pressed()
func _on_create_server_pressed():
    var server_name = server_name_edit.text.strip_edges()
    if server_name.length() < 3:
        status_label.text = "Server name too short!"
        status_label.modulate = Color.RED
        return
    
    var server_config = {
        "name": server_name,
        "map": available_maps[map_option.selected],
        "mode": available_modes[mode_option.selected],
        "max_players": int(player_limit_slider.value),
        "creator_id": player_data["player_id"]
    }
    
    var server_info = server_manager.create_server(server_config)
    server_created.emit(server_info)
    status_label.text = "Server '%s' created!" % server_name
    status_label.modulate = Color.GREEN
