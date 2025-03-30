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
        "current_players": 1,
        "creator_id": player_data["player_id"],
        "ping": 0,
        "has_password": false,
        "is_vip": player_data["is_vip"],
        "is_local": true  # Добавляем флаг локального сервера
    }
    
    # Создаем локальный сервер без регистрации в глобальном списке
    current_server_info = server_config
    current_server_info["port"] = SERVER_PORT  # Используем стандартный порт
    current_server_info["players"] = []
    
    # Создаем сетевой сервер
    _create_network_server()
    
    var status_msg = "Local server '%s' created!" % server_name
    if player_data["is_vip"]:
        status_msg += " ⭐"
    status_label.text = status_msg
    status_label.modulate = Color.GREEN

func discover_local_servers():
    var local_servers = []
    var upnp = UPNP.new()
    
    # Обнаруживаем UPnP устройства в локальной сети
    if upnp.discover() == UPNP.UPNP_RESULT_SUCCESS:
        # Ищем серверы нашего приложения
        for device in upnp.get_devices():
            if "OurGameServer" in device.get_service_name():  # Замените на уникальный идентификатор
                var server_info = {
                    "name": device.get_friendly_name(),
                    "ip": device.get_external_ip(),
                    "port": device.get_external_port(),
                    "is_local": true
                }
                local_servers.append(server_info)
    
    return local_servers

func _on_server_list_updated(servers: Array):
    for child in server_list.get_children():
        child.queue_free()
    
    # Добавляем локальные серверы
    var local_servers = discover_local_servers()
    servers.append_array(local_servers)
    
    # Остальной код остается прежним...
    for server in servers:
        # ...

func _create_network_server():
    status_label.text = "Creating local server..."
    status_label.modulate = Color.YELLOW
    
    multiplayer_peer = ENetMultiplayerPeer.new()
    var error = multiplayer_peer.create_server(current_server_info["port"], current_server_info["max_players"])
    
    if error != OK:
        status_label.text = "Server creation error (code %d)" % error
        status_label.modulate = Color.RED
        return
    
    multiplayer.multiplayer_peer = multiplayer_peer
    is_server = true
    
    # Настраиваем обработчики
    multiplayer.peer_connected.connect(_on_player_connected)
    multiplayer.peer_disconnected.connect(_on_player_disconnected)
    
    status_label.text = "Local server '%s' created!" % current_server_info["name"]
    status_label.modulate = Color.GREEN
    
    # Автоматически подключаем создателя к серверу
    _start_game()

func _ready():
    # ... существующий код ...
    # Добавляем таймер для обновления списка локальных серверов
    var timer = Timer.new()
    timer.wait_time = 2.0  # Обновляем каждые 2 секунды
    timer.autostart = true
    timer.timeout.connect(_on_refresh_button_pressed)
    add_child(timer)
