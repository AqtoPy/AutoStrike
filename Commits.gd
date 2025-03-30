func _on_server_list_updated(servers: Array):
    # ... предыдущий код ...
    
    for server in servers:
        # Проверяем минимально необходимые поля
        var required_fields = {
            "name": "Unknown",
            "map": "unknown",
            "ip": server.get("adress", "127.0.0.1"),  # Поддержка старого формата
            "port": server.get("port", 9050)
        }
        
        # Автозаполнение недостающих полей
        for key in required_fields:
            if not server.has(key):
                server[key] = required_fields[key]
                printerr("Added missing field: ", key)
        
        # Создание кнопки
        var server_button = Button.new()
        server_button.text = "%s\n%s | %s:%d".format(
            server["name"],
            server["map"],
            server["ip"],
            server["port"]
        )
        # ... остальной код кнопки ...

func _on_create_server_pressed():
    # ... подготовка server_config ...
    
    # Гарантируем наличие всех полей
    var server_info = {
        "name": server_config["name"],
        "map": server_config["map"],
        "ip": "127.0.0.1",  # Явное указание
        "port": 9050,        # Явное указание
        "mode": server_config["mode"],
        "is_vip": server_config["is_vip"]
    }
    
    server_created.emit([server_info])  # Обязательно массив!

func _create_network_server():
    # Закрываем предыдущее подключение, если было
    if multiplayer.has_multiplayer_peer():
        multiplayer.multiplayer_peer.close()
    
    # Создаем новый peer
    var peer = ENetMultiplayerPeer.new()
    
    # Пробуем разные порты по очереди
    var ports_to_try = [9050, 9051, 9055, 9070, 9080]
    var success = false
    
    for port in ports_to_try:
        print("Пробуем порт:", port)
        var error = peer.create_server(port)
        if error == OK:
            print("Успешно создан сервер на порту:", port)
            current_server_info["port"] = port
            success = true
            break
        else:
            print("Ошибка создания сервера (код %d)" % error)
    
    if not success:
        printerr("Не удалось создать сервер ни на одном из портов!")
        return
    
    # Настройка подключения
    multiplayer.multiplayer_peer = peer
    
    # Сигналы подключения
    multiplayer.peer_connected.connect(_on_player_connected)
    multiplayer.peer_disconnected.connect(_on_player_disconnected)
    
    print("Сервер успешно запущен!")
    _start_game()
