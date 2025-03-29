# Добавьте в начало скрипта с другими константами
const DEFAULT_PORT = 9050
var multiplayer_peer: MultiplayerPeer
var current_server_info: Dictionary

# Замените функцию _on_create_server_pressed на эту:
func _on_create_server_pressed():
    var server_name = server_name_edit.text.strip_edges()
    
    if server_name.length() < 3:
        status_label.text = "Имя сервера слишком короткое (минимум 3 символа)"
        status_label.modulate = Color.RED
        return
    
    # Создаем конфиг сервера
    current_server_info = {
        "name": server_name,
        "map": available_maps[map_option.selected],
        "mode": available_modes[mode_option.selected],
        "max_players": int(player_limit_slider.value),
        "port": DEFAULT_PORT,
        "password": "",
        "players": [player_data["player_id"]],  # Добавляем создателя в список игроков
        "is_vip": player_data["is_vip"]
    }
    
    # Пытаемся создать сервер
    _create_network_server()

func _create_network_server():
    status_label.text = "Создание сервера..."
    status_label.modulate = Color.YELLOW
    
    multiplayer_peer = ENetMultiplayerPeer.new()
    var error = multiplayer_peer.create_server(current_server_info["port"], current_server_info["max_players"])
    
    if error != OK:
        status_label.text = "Ошибка создания сервера (код %d)" % error
        status_label.modulate = Color.RED
        return
    
    # Настраиваем multiplayer
    multiplayer.multiplayer_peer = multiplayer_peer
    
    # Подключаем сигналы
    multiplayer.peer_connected.connect(_on_player_connected)
    multiplayer.peer_disconnected.connect(_on_player_disconnected)
    
    # Добавляем сервер в список
    server_list_data.append(current_server_info)
    _refresh_server_list()
    
    status_label.text = "Сервер '%s' создан!" % current_server_info["name"]
    status_label.modulate = Color.GREEN
    tabs.current_tab = 0  # Переключаем на вкладку просмотра серверов

func _on_player_connected(id: int):
    print("Игрок подключился: ", id)
    current_server_info["players"].append(id)
    # Здесь можно отправить игроку данные сервера

func _on_player_disconnected(id: int):
    print("Игрок отключился: ", id)
    current_server_info["players"].erase(id)

func _refresh_server_list():
    # Очищаем список
    for child in server_list.get_children():
        child.queue_free()
    
    # Добавляем сервера в список
    for server in server_list_data:
        var server_button = Button.new()
        server_button.text = _format_server_info(server)
        server_button.custom_minimum_size = Vector2(0, 60)
        server_button.align = Label.ALIGN_LEFT
        server_button.pressed.connect(_on_server_selected.bind(server))
        server_list.add_child(server_button)

func _format_server_info(server: Dictionary) -> String:
    var password_icon = "🔒" if server["has_password"] else ""
    var vip_icon = "⭐" if server.get("is_vip", false) else ""
    return "%s %s %s\nКарта: %s | Режим: %s | Игроки: %d/%d" % [
        server["name"],
        vip_icon,
        password_icon,
        server["map"].capitalize(),
        server["mode"],
        server["players"].size(),
        server["max_players"]
    ]
