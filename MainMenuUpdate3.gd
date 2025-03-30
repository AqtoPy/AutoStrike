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



func _on_server_list_updated(servers: Array) -> void:
    # Очищаем текущий список серверов
    for child in server_list.get_children():
        child.queue_free()
    
    # Добавляем локальные серверы с проверкой типа
    var local_servers: Array = discover_local_servers()
    if local_servers is Array:
        servers.append_array(local_servers)
    else:
        push_error("Local servers should be Array, got ", typeof(local_servers))
    
    # Обрабатываем каждый сервер
    for server in servers:
        # Проверяем тип данных сервера
        if not server is Dictionary:
            push_error("Invalid server type: ", typeof(server), " value: ", server)
            continue
            
        # Проверяем обязательные поля
        if not server.has_all(["name", "map", "ip", "port"]):
            push_error("Server missing required fields: ", server)
            continue
            
        # Создаем кнопку сервера
        var server_button := Button.new()
        server_button.name = "ServerButton_%s" % server["name"]
        server_button.text = _format_server_info(server)
        server_button.custom_minimum_size = Vector2(0, 60)
        server_button.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        
        # Стилизация VIP серверов
        if server.get("is_vip", false):
            var vip_style := StyleBoxFlat.new()
            vip_style.bg_color = Color(0.2, 0.1, 0.3)
            vip_style.border_color = Color.GOLD
            vip_style.border_width_left = 4
            vip_style.border_width_right = 4
            vip_style.border_width_top = 4
            vip_style.border_width_bottom = 4
            
            server_button.add_theme_stylebox_override("normal", vip_style)
            server_button.add_theme_stylebox_override("hover", vip_style)
            server_button.add_theme_color_override("font_color", Color.GOLD)
        
        # Подключаем сигнал с проверкой данных
        if server.has("ip") and server.has("port"):
            server_button.pressed.connect(
                _on_server_selected.bind(server), 
                CONNECT_DEFERRED
            )
        else:
            push_error("Server missing connection info: ", server)
            
        server_list.add_child(server_button)

    # Обновляем статус
    status_label.text = "Found %d servers" % servers.size()
    status_label.modulate = Color.WHITE
    
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
