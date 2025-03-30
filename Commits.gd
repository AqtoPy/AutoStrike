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
