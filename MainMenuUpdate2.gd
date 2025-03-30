func _format_server_info(server: Dictionary) -> String:
    if not server is Dictionary:
        push_error("Invalid server data type: ", typeof(server))
        return "Invalid server data"
    
    var server_name = server.get("name", "Unknown Server")
    var map = server.get("map", "unknown").capitalize()
    var mode = server.get("mode", "unknown")
    var current_players = server.get("current_players", 0)
    var max_players = server.get("max_players", 0)
    var ping = server.get("ping", 999)
    var has_password = server.get("has_password", false)
    var is_vip_server = server.get("is_vip", false)  # Новое поле для VIP серверов
    
    var password_icon = "🔒" if has_password else ""
    var vip_icon = "⭐ " if is_vip_server else ""  # Звездочка для VIP
    
    return "%s%s %s\nMap: %s | Mode: %s | Players: %d/%d | Ping: %dms" % [
        vip_icon,  # Добавляем иконку VIP
        server_name, 
        password_icon,
        map,
        mode,
        current_players,
        max_players,
        ping
    ]



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
        "is_vip": player_data["is_vip"]  # Добавляем статус VIP создателя
    }
    
    var server_info = server_manager.create_server(server_config)
    server_created.emit(server_info)
    
    var status_msg = "Server '%s' created!" % server_name
    if player_data["is_vip"]:
        status_msg += " ⭐"  # Добавляем звездочку в статус
    status_label.text = status_msg
    status_label.modulate = Color.GREEN



func _get_test_servers() -> Array:
    return [
        {
            "name": "Classic Deathmatch",
            "map": "de_dust2",
            "mode": "Deathmatch",
            "current_players": 4,
            "max_players": 12,
            "ping": 32,
            "has_password": false,
            "is_vip": false
        },
        {
            "name": "VIP Elite Server",
            "map": "de_inferno",
            "mode": "Team Deathmatch",
            "current_players": 8,
            "max_players": 16,
            "ping": 28,
            "has_password": true,
            "is_vip": true  # VIP сервер
        }
    ]



func _on_server_list_updated(servers: Array):
    for child in server_list.get_children():
        child.queue_free()
    
    if not servers is Array:
        push_error("Expected Array, got ", typeof(servers))
        return
    
    for server in servers:
        if not server is Dictionary:
            push_error("Invalid server data in list: ", typeof(server))
            continue
            
        var server_button = Button.new()
        server_button.text = _format_server_info(server)
        server_button.custom_minimum_size = Vector2(0, 60)
        server_button.align = Label.ALIGN_LEFT
        
        # Стилизация VIP серверов
        if server.get("is_vip", false):
            var style = StyleBoxFlat.new()
            style.bg_color = Color(0.2, 0.1, 0.3)  # Фиолетовый фон
            style.border_color = Color.GOLD
            style.border_width_left = 4
            style.border_width_right = 4
            style.border_width_top = 4
            style.border_width_bottom = 4
            server_button.add_theme_stylebox_override("normal", style)
            server_button.add_theme_stylebox_override("hover", style)
            server_button.add_theme_color_override("font_color", Color.GOLD)
        
        server_button.pressed.connect(_on_server_selected.bind(server))
        server_list.add_child(server_button)



const Color.GOLD = Color(1.0, 0.84, 0.0)  # Золотой цвет для VIP
